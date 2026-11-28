import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';

import 'store.dart';

/// Automatic backup to the baby's own Google Drive (original quality).
///  • Every photo/video in Memories → "Little One – <name>/Photos" or "/Videos"
///  • Notes, events, growth, vaccines, feeds… → "Little One – <name>/Records/little_one_records.json"
/// Only files this app creates are visible to it (drive.file scope) – it can't read anything else in the Drive.
class DriveBackup extends ChangeNotifier {
  DriveBackup._();
  static final DriveBackup i = DriveBackup._();

  final _gsi = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
  GoogleSignInAccount? account;
  drive.DriveApi? _api;
  bool busy = false;
  String status = '';
  String? lastError;
  Timer? _recTimer, _sweepTimer;
  String _lastRecHash = '';

  bool get enabled => Store.i.settings['driveOn'] == true;
  String? get email => account?.email ?? Store.i.settings['driveEmail']?.toString();
  Set<String> get _done => ((Store.i.d['driveDone'] as List?) ?? []).map((e) => e.toString()).toSet();
  int get uploaded => Store.i.list('memories').where((m) => _done.contains(m['id'].toString())).length;
  int get pending => Store.i.list('memories').where((m) => m['path'] != null && !_done.contains(m['id'].toString()) && File(m['path'].toString()).existsSync()).length;

  Future<void> init() async {
    // new memories and record changes trigger an upload
    final prev = Store.onAdd;
    Store.onAdd = (k, item) {
      prev?.call(k, item);
      if (k == 'memories') _soon();
    };
    Store.i.addListener(_recordsChanged);
    if (!enabled) return;
    try {
      account = await _gsi.signInSilently();
      if (account != null) await _connect();
    } catch (e) {
      lastError = '$e';
    }
    _sweepTimer = Timer.periodic(const Duration(minutes: 20), (_) => sweep());
    unawaited(sweep());
  }

  /// "Connect Google Drive" button.
  Future<String?> connect() async {
    try {
      account = await _gsi.signIn();
      if (account == null) return 'Sign-in was cancelled';
      final ok = await _gsi.requestScopes([drive.DriveApi.driveFileScope]);
      if (!ok) return 'Please allow Google Drive access';
      await _connect();
      // Restore first: a reinstalled phone is empty, and uploading it would overwrite the backup.
      final err = await restoreFromDrive();
      if (err != null) lastError = err;
      await Store.i.setSetting('driveOn', true);
      await Store.i.setSetting('driveIndexed', false); // look at what this Drive already has before uploading
      await Store.i.setSetting('driveEmail', account!.email);
      _sweepTimer ??= Timer.periodic(const Duration(minutes: 20), (_) => sweep());
      unawaited(sweep(records: true));
      notifyListeners();
      return null;
    } catch (e) {
      lastError = '$e';
      notifyListeners();
      return 'Could not connect: $e';
    }
  }

  Future<void> disconnect() async {
    try {
      await _gsi.disconnect();
    } catch (_) {}
    account = null;
    _api = null;
    await Store.i.setSetting('driveOn', false);
    notifyListeners();
  }

  DateTime _connectedAt = DateTime(2000);

  /// Google access tokens expire after ~1 hour – [fresh] throws the old one away and asks Google for a new one.
  Future<void> _connect({bool fresh = false}) async {
    if (fresh) {
      try {
        await account?.clearAuthCache();
      } catch (_) {}
      account = await _gsi.signInSilently(reAuthenticate: true) ?? account;
    }
    final client = await _gsi.authenticatedClient();
    if (client == null) throw 'No Google access';
    _api = drive.DriveApi(client);
    _connectedAt = DateTime.now();
  }

  static bool _authErr(Object e) {
    final t = '$e';
    return t.contains('invalid_token') || t.contains('Access was denied') || t.contains('401') || t.contains('Invalid Credentials');
  }

  void _soon() {
    if (!enabled) return;
    Timer(const Duration(seconds: 5), () => sweep());
  }

  void _recordsChanged() {
    if (!enabled) return;
    _recTimer?.cancel();
    _recTimer = Timer(const Duration(seconds: 40), () => sweep(records: true));
  }

  // ───── folders ─────
  Future<String> _folder(String name, String? parent, String key) async {
    final saved = Store.i.settings[key]?.toString();
    final api = _api!;
    if (saved != null) {
      try {
        final f = await api.files.get(saved, $fields: 'id, trashed') as drive.File;
        if (f.trashed != true) return saved;
      } catch (_) {}
    }
    final q = "mimeType='application/vnd.google-apps.folder' and name='${name.replaceAll("'", "\\'")}' and trashed=false${parent != null ? " and '$parent' in parents" : ''}";
    final found = await api.files.list(q: q, $fields: 'files(id)', spaces: 'drive');
    String id;
    if (found.files != null && found.files!.isNotEmpty) {
      id = found.files!.first.id!;
    } else {
      final f = await api.files.create(drive.File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = parent == null ? null : [parent]);
      id = f.id!;
    }
    await Store.i.setSetting(key, id);
    return id;
  }

  Future<(String, String, String, String)> _folders() async {
    final root = await _folder('Little One – ${Store.i.babyName}', null, 'driveRoot');
    final photos = await _folder('Photos', root, 'drivePhotos');
    final videos = await _folder('Videos', root, 'driveVideos');
    final docs = await _folder('Documents', root, 'driveDocs');
    return (root, photos, videos, docs);
  }

  /// Upload everything not in Drive yet (memories first, then the records file if it changed).
  Future<void> sweep({bool records = false}) async {
    if (!enabled || busy) return;
    busy = true;
    notifyListeners();
    try {
      await _sweep(records);
    } catch (e) {
      if (_authErr(e)) {
        // token ran out – get a fresh one and try once more
        try {
          await _connect(fresh: true);
          await _sweep(records);
        } catch (e2) {
          lastError = '$e2';
          status = 'Will retry automatically';
        }
      } else {
        lastError = '$e';
        status = 'Will retry automatically';
      }
    }
    busy = false;
    notifyListeners();
  }

  Future<void> _sweep(bool records) async {
    {
      account ??= await _gsi.signInSilently();
      if (account == null) throw 'Signed out – tap Connect again';
      if (_api == null || DateTime.now().difference(_connectedAt).inMinutes > 40) await _connect(fresh: _api != null);
      final (root, photos, videos, docs) = await _folders();
      if (Store.i.settings['driveIndexed'] != true) await _indexDrive([photos, videos, docs]);
      final todo = Store.i.list('memories').where((m) => m['path'] != null && !_done.contains(m['id'].toString())).toList();
      var n = 0;
      for (final m in todo) {
        final f = File(m['path'].toString());
        if (!f.existsSync()) continue;
        if (DateTime.now().difference(_connectedAt).inMinutes > 40) await _connect(fresh: true);
        status = 'Uploading ${++n} of ${todo.length}…';
        notifyListeners();
        final fn = f.path.split('/').last.replaceFirst(RegExp(r'^[a-z0-9]+_'), ''); // drop our internal id prefix
        final name = m['doc'] == true && (m['caption'] ?? '').toString().trim().isNotEmpty
            ? '${m['caption'].toString().trim()}.${fn.split('.').last}'
            : '${m['date'] ?? ''} ${(m['caption'] ?? '').toString().trim()} $fn'.trim();
        final meta = drive.File()
          ..appProperties = {'memId': m['id'].toString()}
          ..name = name.length > 120 ? name.substring(name.length - 120) : name
          ..parents = [m['doc'] == true ? docs : m['video'] == true ? videos : photos]
          ..description = [if ((m['caption'] ?? '').toString().isNotEmpty) m['caption'], if ((m['tag'] ?? '').toString().isNotEmpty) m['tag'], if (m['from'] != null) 'by ${m['from']}'].join(' · ');
        final len = await f.length();
        await _api!.files.create(meta, uploadMedia: drive.Media(f.openRead(), len), uploadOptions: drive.ResumableUploadOptions());
        final done = _done..add(m['id'].toString());
        Store.i.d['driveDone'] = done.toList();
        await Store.i.saveQuiet(); // no full-app redraw after every upload
      }
      if (records || todo.isNotEmpty) await _uploadRecords(_api!, root);
      status = 'All backed up ✓';
      lastError = null;
      await Store.i.setSetting('driveLast', DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Base file name without our id prefixes ("k3x9_abc12_IMG_2026.jpg" → "IMG_2026.jpg").
  static String _base(String path) {
    var b = path.split('/').last;
    while (RegExp(r'^[a-z0-9]{5,}_').hasMatch(b) && b.indexOf('_') < b.length - 1) {
      b = b.replaceFirst(RegExp(r'^[a-z0-9]{5,}_'), '');
    }
    return b.toLowerCase();
  }

  /// After a reinstall the phone forgets what is already in Drive. Look once at what's there and mark
  /// those memories as done, so nothing is uploaded twice.
  Future<void> _indexDrive(List<String> folders) async {
    status = 'Checking what is already in Drive…';
    notifyListeners();
    final ids = <String>{}, names = <String>{};
    for (final folder in folders) {
      String? page;
      do {
        final r = await _api!.files.list(q: "'$folder' in parents and trashed=false", $fields: 'nextPageToken, files(name, appProperties)', pageSize: 1000, pageToken: page, spaces: 'drive');
        for (final f in r.files ?? <drive.File>[]) {
          final id = f.appProperties?['memId'];
          if (id != null) ids.add(id);
          final n = (f.name ?? '').toLowerCase();
          names.add(n);
        }
        page = r.nextPageToken;
      } while (page != null);
    }
    final done = _done;
    for (final m in Store.i.list('memories')) {
      final id = m['id'].toString();
      if (done.contains(id)) continue;
      if (ids.contains(id)) {
        done.add(id);
        continue;
      }
      final p = (m['path'] ?? m['fname'] ?? '').toString();
      if (p.isEmpty) continue;
      final base = _base(p), date = (m['date'] ?? '').toString();
      final cap = (m['caption'] ?? '').toString().trim().toLowerCase();
      if (names.any((n) => n.endsWith(base) && (date.isEmpty || n.startsWith(date))) || (m['doc'] == true && cap.isNotEmpty && names.any((n) => n.startsWith('$cap.')))) {
        done.add(id);
      }
    }
    Store.i.d['driveDone'] = done.toList();
    await Store.i.saveQuiet();
    await Store.i.setSetting('driveIndexed', true);
  }

  /// After a reinstall: bring the records (profile, notes, feeds, growth, vaccines…) and every
  /// memory file back from this baby's Drive. Only adds what the phone doesn't have yet.
  Future<String?> restoreFromDrive() async {
    final api = _api;
    if (api == null) return 'Not connected to Drive';
    try {
      status = 'Restoring from Google Drive…';
      notifyListeners();
      final rf = await api.files.list(q: "name='little_one_records.json' and trashed=false", $fields: 'files(id, modifiedTime)', orderBy: 'modifiedTime desc', pageSize: 1, spaces: 'drive');
      final recId = rf.files?.isNotEmpty == true ? rf.files!.first.id : null;
      var recs = <String, dynamic>{};
      if (recId != null) {
        final media = await api.files.get(recId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        final bytes = <int>[];
        await for (final c in media.stream) {
          bytes.addAll(c);
        }
        recs = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
        await Store.i.setSetting('driveRecFile', recId);
      }
      final bp = recs['baby'];
      if (bp is Map && bp.isNotEmpty) Store.i.d['profile'] = Map<String, dynamic>.from(bp);
      for (final k in ['notes', 'events', 'growth', 'vax', 'feeds', 'nappies', 'sleeps', 'cries', 'voices']) {
        final src = recs[k];
        if (src is! List) continue;
        final local = (Store.i.d[k] as List? ?? []).toList();
        final seen = local.map((e) => jsonEncode(e)).toSet();
        for (final e in src) {
          if (seen.add(jsonEncode(e))) local.add(e);
        }
        Store.i.d[k] = local;
      }
      final meta = <String, Map<String, dynamic>>{
        for (final m in (recs['memories'] as List? ?? []))
          if (m is Map) m['id'].toString(): Map<String, dynamic>.from(m),
      };

      final folders = <String, String>{};
      String? page;
      do {
        final r = await api.files.list(q: "mimeType='application/vnd.google-apps.folder' and trashed=false", $fields: 'nextPageToken, files(id, name)', pageSize: 1000, pageToken: page, spaces: 'drive');
        for (final f in r.files ?? <drive.File>[]) {
          if (f.id != null) folders[f.id!] = f.name ?? '';
        }
        page = r.nextPageToken;
      } while (page != null);

      final have = Store.i.list('memories').map((m) => m['id'].toString()).toSet();
      final todo = <(drive.File, String)>[];
      page = null;
      do {
        final r = await api.files.list(q: "trashed=false and mimeType!='application/vnd.google-apps.folder'", $fields: 'nextPageToken, files(id, name, createdTime, parents, appProperties)', pageSize: 1000, pageToken: page, spaces: 'drive');
        for (final f in r.files ?? <drive.File>[]) {
          final id = f.appProperties?['memId'];
          if (id != null && !have.contains(id)) todo.add((f, id));
        }
        page = r.nextPageToken;
      } while (page != null);

      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/memories');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final list = Store.i.list('memories');
      final restoredIds = <String>[];
      var n = 0;
      for (final (f, id) in todo) {
        n++;
        status = 'Restoring memory $n of ${todo.length}…';
        notifyListeners();
        final parent = (f.parents?.isNotEmpty == true) ? (folders[f.parents!.first] ?? '') : '';
        final m = meta[id] ?? <String, dynamic>{};
        final name = f.name ?? '$id.jpg';
        final file = File('${dir.path}/${id}_${name.replaceAll(RegExp(r'[^\w.\- ]'), '_')}');
        try {
          final media = await api.files.get(f.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
          await media.stream.pipe(file.openWrite());
        } catch (_) {
          continue;
        }
        final date = (m['date'] ?? f.createdTime?.toIso8601String() ?? '').toString();
        list.add({
          'id': id,
          'path': file.path,
          'fname': name,
          'date': date.length >= 10 ? date.substring(0, 10) : date,
          'caption': m['caption'] ?? '',
          'tag': m['tag'] ?? '',
          'video': parent == 'Videos' || m['video'] == true,
          if (parent == 'Documents' || m['doc'] == true) 'doc': true,
          if (m['from'] != null) 'from': m['from'],
          if (m['reacts'] != null) 'reacts': m['reacts'],
          'remote': true,
        });
        restoredIds.add(id);
      }
      Store.i.d['memories'] = list;
      Store.i.d['driveDone'] = {..._done, ...restoredIds}.toList();
      await Store.i.setSetting('driveIndexed', true);
      await Store.i.save();
      status = recs.isEmpty && restoredIds.isEmpty ? 'Nothing to restore' : 'Restored ${restoredIds.length} memories ✓';
      notifyListeners();
      return null;
    } catch (e) {
      status = 'Restore did not finish – will retry';
      notifyListeners();
      return 'Restore: $e';
    }
  }

  Future<void> _uploadRecords(drive.DriveApi api, String root) async {
    final recs = <String, dynamic>{
      'baby': Store.i.profile,
      for (final k in ['notes', 'events', 'growth', 'vax', 'feeds', 'nappies', 'sleeps', 'cries', 'voices'])
        if (Store.i.d[k] != null) k: Store.i.d[k],
      'memories': Store.i.list('memories').map((m) => {for (final k in ['id', 'caption', 'tag', 'date', 'video', 'doc', 'from', 'reacts']) if (m[k] != null) k: m[k]}).toList(),
      'savedAt': DateTime.now().toIso8601String(),
    };
    // never replace a backup with an empty phone (e.g. right after a reinstall)
    if (['memories', 'notes', 'feeds', 'nappies', 'sleeps', 'growth', 'vax', 'cries', 'voices'].every((k) => (recs[k] as List?)?.isEmpty ?? true)) return;
    final body = const JsonEncoder.withIndent(' ').convert({...recs, 'savedAt': null});
    if (body == _lastRecHash) return;
    final bytes = utf8.encode(const JsonEncoder.withIndent(' ').convert(recs));
    final folder = await _folder('Records', root, 'driveRecords');
    var id = Store.i.settings['driveRecFile']?.toString();
    if (id == null) {
      // reinstall: reuse the existing records file instead of making a second one
      final r = await api.files.list(q: "name='little_one_records.json' and '$folder' in parents and trashed=false", $fields: 'files(id)', spaces: 'drive');
      id = r.files?.isNotEmpty == true ? r.files!.first.id : null;
      if (id != null) await Store.i.setSetting('driveRecFile', id);
    }
    final media = drive.Media(Stream.value(bytes), bytes.length, contentType: 'application/json');
    try {
      if (id != null) {
        await api.files.update(drive.File(), id, uploadMedia: media);
      } else {
        throw 'new';
      }
    } catch (_) {
      final f = await api.files.create(drive.File()
        ..name = 'little_one_records.json'
        ..parents = [folder], uploadMedia: drive.Media(Stream.value(bytes), bytes.length, contentType: 'application/json'));
      await Store.i.setSetting('driveRecFile', f.id);
    }
    _lastRecHash = body;
  }
}
