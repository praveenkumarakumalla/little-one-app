import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

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
      await Store.i.setSetting('driveOn', true);
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

  Future<(String, String, String)> _folders() async {
    final root = await _folder('Little One – ${Store.i.babyName}', null, 'driveRoot');
    final photos = await _folder('Photos', root, 'drivePhotos');
    final videos = await _folder('Videos', root, 'driveVideos');
    return (root, photos, videos);
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
      final (root, photos, videos) = await _folders();
      final todo = Store.i.list('memories').where((m) => m['path'] != null && !_done.contains(m['id'].toString())).toList();
      var n = 0;
      for (final m in todo) {
        final f = File(m['path'].toString());
        if (!f.existsSync()) continue;
        if (DateTime.now().difference(_connectedAt).inMinutes > 40) await _connect(fresh: true);
        status = 'Uploading ${++n} of ${todo.length}…';
        notifyListeners();
        final name = '${m['date'] ?? ''} ${(m['caption'] ?? '').toString().trim()} ${f.path.split('/').last}'.trim();
        final meta = drive.File()
          ..name = name.length > 120 ? name.substring(name.length - 120) : name
          ..parents = [m['video'] == true ? videos : photos]
          ..description = [if ((m['caption'] ?? '').toString().isNotEmpty) m['caption'], if ((m['tag'] ?? '').toString().isNotEmpty) m['tag'], if (m['from'] != null) 'by ${m['from']}'].join(' · ');
        final len = await f.length();
        await _api!.files.create(meta, uploadMedia: drive.Media(f.openRead(), len), uploadOptions: drive.ResumableUploadOptions());
        final done = _done..add(m['id'].toString());
        Store.i.d['driveDone'] = done.toList();
        await Store.i.save();
      }
      if (records || todo.isNotEmpty) await _uploadRecords(_api!, root);
      status = 'All backed up ✓';
      lastError = null;
      await Store.i.setSetting('driveLast', DateTime.now().millisecondsSinceEpoch);
    }
  }

  Future<void> _uploadRecords(drive.DriveApi api, String root) async {
    final recs = <String, dynamic>{
      'baby': Store.i.profile,
      for (final k in ['notes', 'events', 'growth', 'vax', 'feeds', 'nappies', 'sleeps', 'cries', 'voices'])
        if (Store.i.d[k] != null) k: Store.i.d[k],
      'memories': Store.i.list('memories').map((m) => {for (final k in ['id', 'caption', 'tag', 'date', 'video', 'from', 'reacts']) if (m[k] != null) k: m[k]}).toList(),
      'savedAt': DateTime.now().toIso8601String(),
    };
    final body = const JsonEncoder.withIndent(' ').convert({...recs, 'savedAt': null});
    if (body == _lastRecHash) return;
    final bytes = utf8.encode(const JsonEncoder.withIndent(' ').convert(recs));
    final folder = await _folder('Records', root, 'driveRecords');
    final id = Store.i.settings['driveRecFile']?.toString();
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
