import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'data.dart';
import 'store.dart';

// ───────────────────────── encryption (runs off the UI thread for files) ─────────────────────────
Future<Uint8List> _enc(List<int> key, List<int> data) async {
  final box = await AesGcm.with256bits().encrypt(data, secretKey: SecretKey(key));
  return Uint8List.fromList(box.concatenation());
}

Future<Uint8List> _dec(List<int> key, List<int> data) async {
  final box = SecretBox.fromConcatenation(data, nonceLength: 12, macLength: 16);
  return Uint8List.fromList(await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(key)));
}

// Big files are encrypted in a background isolate so the screen never freezes.
Future<Uint8List> _encIso(List<int> key, List<int> data) => Isolate.run(() => _enc(key, data));
Future<Uint8List> _decIso(List<int> key, List<int> data) => Isolate.run(() => _dec(key, data));

/// Private family group chat (up to 10 phones).
///
/// Everything — text, photos, videos, documents — is end-to-end encrypted (AES-256-GCM) with a key
/// made from the group code, then passed through the free ntfy.sh relay, which only ever sees
/// scrambled bytes. The relay keeps text ~12 h and files ~3 h, so every phone keeps the full
/// history itself (forever, included in Backup), re-sends anything a member hasn't received yet,
/// and gives the whole history to anyone who joins later.
class Chat extends ChangeNotifier with WidgetsBindingObserver {
  Chat._();
  static final Chat i = Chat._();
  static const relay = 'https://ntfy.sh';
  static const maxMembers = 10;
  static const maxFile = 14 * 1024 * 1024;

  List<int>? _key;
  String? _topic;
  http.Client? _client;
  StreamSubscription<String>? _sub;
  bool _connecting = false;
  int _backoff = 2;
  Future<void> _chain = Future.value();
  final Set<String> _acks = {};
  Timer? _ackTimer, _resendTimer;
  final Set<String> _histDone = {};
  final Set<String> _downloading = {};
  bool pageOpen = false;
  bool online = false;
  String? notice; // e.g. "group is full"

  Map<String, dynamic> get cfg => Map<String, dynamic>.from((Store.i.d['chatCfg'] ?? {}) as Map);
  bool get paired => (cfg['code'] ?? '').toString().isNotEmpty;
  String get me => (cfg['device'] ?? '').toString();
  String get myName => (cfg['name'] ?? '').toString();
  Map<String, Map<String, dynamic>> get members =>
      Map<String, dynamic>.from((cfg['members'] ?? {}) as Map).map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
  List<Map<String, dynamic>> get msgs => (Store.i.d['chat'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  int get unread {
    final seen = (cfg['readAt'] as num?)?.toInt() ?? 0;
    return msgs.where((m) => m['from'] != me && m['from'] != 'sys' && (m['at'] as num) > seen).length;
  }

  // ───────────────────────── lifecycle ─────────────────────────
  Future<void> init() async {
    Store.i.d.putIfAbsent('chat', () => <dynamic>[]);
    WidgetsBinding.instance.addObserver(this);
    if (paired) {
      await _setup();
      unawaited(_connect());
    }
    _resendTimer = Timer.periodic(const Duration(minutes: 2), (_) => _resend());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && paired && _sub == null) {
      _backoff = 2;
      unawaited(_connect());
    }
  }

  void setPageOpen(bool v) {
    pageOpen = v;
    if (v) markRead();
  }

  static String normalise(String code) => code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  static String newCode() {
    const abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = math.Random.secure();
    final s = List.generate(16, (_) => abc[r.nextInt(abc.length)]).join();
    return '${s.substring(0, 4)}-${s.substring(4, 8)}-${s.substring(8, 12)}-${s.substring(12)}';
  }

  Future<void> _saveCfg(Map<String, dynamic> c) async {
    Store.i.d['chatCfg'] = c;
    await Store.i.save();
  }

  Future<void> _setup() async {
    final code = normalise(cfg['code'].toString());
    final h = await Sha256().hash(utf8.encode('little-one-topic:$code'));
    _topic = 'lo_${h.bytes.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    final k = await Sha256().hash(utf8.encode('little-one-key:$code'));
    _key = k.bytes;
  }

  Future<void> pair(String code, String name) async {
    final c = cfg;
    c['code'] = code;
    c['name'] = name;
    c['device'] = c['device'] ?? Store.newId();
    c.remove('since');
    c['members'] = <String, dynamic>{};
    c['joinedAt'] = DateTime.now().millisecondsSinceEpoch;
    notice = null;
    await _saveCfg(c);
    await _setup();
    _disconnect();
    _backoff = 2;
    await _connect();
    await _publish({'t': 'join', 'name': name});
    await _addSys('👋 You joined the family chat as $name');
  }

  Future<void> setName(String n) async {
    await _saveCfg(cfg..['name'] = n);
    await _publish({'t': 'name', 'name': n});
  }

  Future<void> leave() async {
    await _publish({'t': 'leave'});
    _disconnect();
    final c = cfg
      ..remove('code')
      ..remove('since')
      ..remove('members');
    await _saveCfg(c);
    _key = null;
    _topic = null;
    notifyListeners();
  }

  Future<void> markRead() async {
    Store.i.d['chatCfg'] = cfg..['readAt'] = DateTime.now().millisecondsSinceEpoch;
    await Store.i.save();
    notifyListeners();
  }

  // ───────────────────────── relay connection (live stream) ─────────────────────────
  void _disconnect() {
    _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
  }

  Future<void> _connect() async {
    if (!paired || _topic == null || _sub != null || _connecting) return;
    _connecting = true;
    try {
      final since = cfg['since']?.toString() ?? 'all';
      _client = http.Client();
      final res = await _client!.send(http.Request('GET', Uri.parse('$relay/$_topic/json?since=$since'))).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) throw 'status ${res.statusCode}';
      online = true;
      _backoff = 2;
      notifyListeners();
      _sub = res.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
            (line) => _chain = _chain.then((_) => _line(line)).catchError((_) {}),
            onDone: _reconnect,
            onError: (_) => _reconnect(),
            cancelOnError: true,
          );
      unawaited(_resend());
    } catch (_) {
      _reconnect();
    } finally {
      _connecting = false;
    }
  }

  void _reconnect() {
    _disconnect();
    online = false;
    notifyListeners();
    if (!paired) return;
    Timer(Duration(seconds: _backoff), _connect);
    _backoff = math.min(_backoff * 2, 60);
  }

  Future<void> reconnectNow() async {
    _disconnect();
    _backoff = 2;
    await _connect();
  }

  Future<String> _seal(Map<String, dynamic> m) async => base64Encode(await _enc(_key!, utf8.encode(jsonEncode(m))));

  Future<Map<String, dynamic>?> _open(String s) async {
    try {
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(await _dec(_key!, base64Decode(s)))) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _publish(Map<String, dynamic> m) async {
    if (_topic == null || _key == null) return false;
    try {
      final body = await _seal({...m, 'from': me});
      final r = await http.post(Uri.parse('$relay/$_topic'), body: body).timeout(const Duration(seconds: 20));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Encrypted file upload; [meta] travels (encrypted) as the message text.
  Future<bool> _publishFile(Map<String, dynamic> meta, List<int> bytes) async {
    if (_topic == null || _key == null) return false;
    try {
      final blob = await _encIso(_key!, bytes);
      final sealed = await _seal({...meta, 'from': me});
      final r = await http
          .put(Uri.parse('$relay/$_topic'), body: blob, headers: {'Filename': '${meta['id'] ?? 'f'}.bin', 'Message': sealed})
          .timeout(const Duration(minutes: 4));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ───────────────────────── incoming ─────────────────────────
  Future<void> _line(String line) async {
    if (line.trim().isEmpty) return;
    final ev = jsonDecode(line) as Map;
    if (ev['event'] == 'open') {
      online = true;
      notifyListeners();
      return;
    }
    if (ev['event'] != 'message') return;
    final c = cfg;
    final t = (ev['time'] as num?)?.toInt() ?? 0;
    if (t > 0) c['since'] = '${t - 5}';
    Store.i.d['chatCfg'] = c;
    final m = await _open((ev['message'] ?? '').toString());
    if (m == null) return;
    final from = (m['from'] ?? '').toString();
    if (from.isEmpty || from == me) return;
    final att = ev['attachment'] is Map ? Map<String, dynamic>.from(ev['attachment'] as Map) : null;
    final mem = members;
    final type = m['t'];
    if (type == 'leave') {
      final n = mem[from]?['name'] ?? 'Someone';
      mem.remove(from);
      _setMembers(mem);
      await _addSys('👋 $n left the chat');
      return;
    }
    final known = mem.containsKey(from);
    mem[from] = {...?mem[from], 'name': m['name'] ?? mem[from]?['name'] ?? 'Family', 'seen': DateTime.now().millisecondsSinceEpoch, 'joined': mem[from]?['joined'] ?? (m['at'] ?? DateTime.now().millisecondsSinceEpoch)};
    _setMembers(mem);

    switch (type) {
      case 'join':
        if (!known) await _addSys('👋 ${m['name']} joined the family chat');
        _histDone.remove(from);
        Timer(Duration(seconds: 3 + math.Random().nextInt(18)), () => _sendHistory(from));
        break;
      case 'name':
        break;
      case 'ack':
        final ref = (m['ref'] as List).map((e) => e.toString()).toSet();
        await _store(msgs.map((x) {
          if (x['from'] != me || !ref.contains(x['id'])) return x;
          final g = ((x['gotBy'] as List?) ?? []).map((e) => e.toString()).toSet()..add(from);
          return {...x, 'gotBy': g.toList()};
        }).toList());
        break;
      case 'react':
        await _store(msgs.map((x) {
          if (x['id'] != m['ref']) return x;
          final r = Map<String, dynamic>.from((x['reacts'] ?? {}) as Map);
          if ((m['e'] ?? '').toString().isEmpty) {
            r.remove(from);
          } else {
            r[from] = m['e'];
          }
          return {...x, 'reacts': r};
        }).toList());
        break;
      case 'hist':
        if (m['for'] != me) {
          _histDone.add(m['for'].toString());
        } else if (att != null) {
          await _takeHistory(att['url'].toString());
        }
        break;
      case 'msg':
      case 'file':
        _ack(m['id'].toString());
        final l = msgs;
        final idx = l.indexWhere((x) => x['id'] == m['id']);
        final entry = <String, dynamic>{
          'id': m['id'],
          'from': from,
          'name': m['name'],
          'at': m['at'],
          'kind': m['kind'] ?? 'text',
          'text': m['text'] ?? '',
          if (m['fname'] != null) 'fname': m['fname'],
          if (m['size'] != null) 'size': m['size'],
          if (att != null) 'url': att['url'],
        };
        if (idx < 0) {
          l.add(entry);
          l.sort((a, b) => (a['at'] as num).compareTo((b['at'] as num)));
          await _store(l);
          if (pageOpen) {
            await markRead();
          } else {
            HapticFeedback.vibrate();
          }
        } else if (att != null && l[idx]['path'] == null) {
          l[idx] = {...l[idx], 'url': att['url'], 'st': null};
          await _store(l);
        }
        if (type == 'file' && att != null) unawaited(download(m['id'].toString()));
        break;
    }
  }

  void _setMembers(Map<String, Map<String, dynamic>> m) => Store.i.d['chatCfg'] = cfg..['members'] = m;

  void _ack(String id) {
    _acks.add(id);
    _ackTimer?.cancel();
    _ackTimer = Timer(const Duration(seconds: 2), () async {
      final ids = _acks.toList();
      _acks.clear();
      if (ids.isNotEmpty) await _publish({'t': 'ack', 'ref': ids, 'name': myName});
    });
  }

  static Future<Directory> _mediaDir() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/chat_media');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// Fetch + decrypt a photo / video / document.
  Future<void> download(String id) async {
    final m = msgs.where((x) => x['id'] == id).firstOrNull;
    if (m == null || m['url'] == null || m['path'] != null || _downloading.contains(id)) return;
    _downloading.add(id);
    await _patch(id, {'st': 'dl'});
    try {
      final r = await http.get(Uri.parse(m['url'].toString())).timeout(const Duration(minutes: 4));
      if (r.statusCode != 200) throw 'gone';
      final clear = await _decIso(_key!, r.bodyBytes);
      final safe = (m['fname'] ?? 'file').toString().replaceAll(RegExp(r'[^\w.\- ]'), '_');
      final f = File('${(await _mediaDir()).path}/${id}_$safe');
      await f.writeAsBytes(clear, flush: true);
      await _patch(id, {'path': f.path, 'st': null});
    } catch (_) {
      await _patch(id, {'st': 'wait'}); // the sender's phone will send it again
    }
    _downloading.remove(id);
  }

  Future<void> _sendHistory(String forDev) async {
    if (_histDone.contains(forDev) || !paired) return;
    _histDone.add(forDev);
    final l = msgs.where((x) => x['from'] != 'sys').toList();
    if (l.isEmpty) return;
    final hist = l.length > 3000 ? l.sublist(l.length - 3000) : l;
    final slim = hist.map((x) => {for (final k in ['id', 'from', 'name', 'at', 'kind', 'text', 'fname', 'size', 'reacts']) if (x[k] != null) k: x[k]}).toList();
    final mem = members..[me] = {'name': myName, 'seen': DateTime.now().millisecondsSinceEpoch, 'joined': cfg['joinedAt'] ?? 0};
    await _publishFile({'t': 'hist', 'for': forDev, 'name': myName}, utf8.encode(jsonEncode({'msgs': slim, 'members': mem})));
  }

  Future<void> _takeHistory(String url) async {
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 2));
      if (r.statusCode != 200) return;
      final clear = await _decIso(_key!, r.bodyBytes);
      final h = jsonDecode(utf8.decode(clear)) as Map;
      final mem = members;
      (h['members'] as Map).forEach((k, v) {
        if (k != me) mem[k.toString()] = Map<String, dynamic>.from(v as Map);
      });
      _setMembers(mem);
      final l = msgs;
      final ids = l.map((x) => x['id']).toSet();
      var n = 0;
      for (final x in (h['msgs'] as List)) {
        final mm = Map<String, dynamic>.from(x as Map);
        if (ids.contains(mm['id'])) continue;
        if (mm['kind'] != 'text' && mm['kind'] != 'status' && mm['kind'] != 'join') mm['st'] = 'old';
        l.add(mm);
        n++;
      }
      l.sort((a, b) => (a['at'] as num).compareTo((b['at'] as num)));
      await _store(l);
      if (n > 0) await _addSys('📜 $n earlier messages received');
      if (mem.length + 1 > maxMembers) {
        notice = 'This group already has $maxMembers members, so you were not added.';
        await leave();
      }
    } catch (_) {}
  }

  // ───────────────────────── outgoing ─────────────────────────
  Future<void> _store(List<Map<String, dynamic>> l) async {
    Store.i.d['chat'] = l.length > 50000 ? l.sublist(l.length - 50000) : l;
    await Store.i.save();
    notifyListeners();
  }

  Future<void> _patch(String id, Map<String, dynamic> f) async => _store(msgs.map((x) => x['id'] == id ? {...x, ...f} : x).toList());

  Future<void> _addSys(String t) async {
    final l = msgs..add({'id': Store.newId(), 'from': 'sys', 'kind': 'sys', 'text': t, 'at': DateTime.now().millisecondsSinceEpoch});
    await _store(l);
  }

  Future<void> deleteLocal(String id) async => _store(msgs.where((x) => x['id'] != id).toList());

  Future<void> send(String text, {String kind = 'text'}) async {
    text = text.trim();
    if (text.isEmpty || !paired) return;
    if (text.length > 1500) text = text.substring(0, 1500);
    final m = <String, dynamic>{'id': Store.newId(), 'from': me, 'name': myName, 'text': text, 'at': DateTime.now().millisecondsSinceEpoch, 'kind': kind};
    await _store(msgs..add({...m, 'sent': false}));
    final ok = await _publish({'t': 'msg', ...m});
    if (ok) await _patch(m['id'].toString(), {'sent': true, 'pubAt': DateTime.now().millisecondsSinceEpoch});
  }

  static String kindOf(String path) {
    final e = path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'].contains(e)) return 'image';
    if (['mp4', 'mov', '3gp', 'mkv', 'webm', 'm4v'].contains(e)) return 'video';
    return 'doc';
  }

  /// Returns an error message, or null.
  Future<String?> sendFile(String srcPath, {String caption = ''}) async {
    if (!paired) return 'Join the chat first';
    final src = File(srcPath);
    final size = await src.length();
    final fname = srcPath.split('/').last;
    if (size > maxFile) return '$fname is ${(size / 1048576).toStringAsFixed(1)} MB. Max is 14 MB — trim the video or send a smaller file.';
    final id = Store.newId();
    final local = await src.copy('${(await _mediaDir()).path}/${id}_${fname.replaceAll(RegExp(r'[^\w.\- ]'), '_')}');
    final m = <String, dynamic>{'id': id, 'from': me, 'name': myName, 'text': caption, 'at': DateTime.now().millisecondsSinceEpoch, 'kind': kindOf(fname), 'fname': fname, 'size': size};
    await _store(msgs..add({...m, 'path': local.path, 'sent': false}));
    final ok = await _publishFile({'t': 'file', ...m}, await local.readAsBytes());
    if (ok) await _patch(id, {'sent': true, 'pubAt': DateTime.now().millisecondsSinceEpoch});
    return null; // if it could not go now, it is re-sent automatically
  }

  Future<void> react(String id, String emoji) async {
    final x = msgs.where((e) => e['id'] == id).firstOrNull;
    if (x == null) return;
    final r = Map<String, dynamic>.from((x['reacts'] ?? {}) as Map);
    final e = r[me] == emoji ? '' : emoji;
    if (e.isEmpty) {
      r.remove(me);
    } else {
      r[me] = e;
    }
    await _patch(id, {'reacts': r});
    await _publish({'t': 'react', 'ref': id, 'e': e, 'name': myName});
  }

  bool deliveredAll(Map<String, dynamic> m) {
    final got = ((m['gotBy'] as List?) ?? []).toSet();
    final others = members.entries.where((e) => ((e.value['joined'] as num?) ?? 0) <= (m['at'] as num) + 600000).map((e) => e.key);
    if (others.isEmpty) return m['got'] == true;
    return others.every(got.contains);
  }

  int deliveredCount(Map<String, dynamic> m) => ((m['gotBy'] as List?) ?? []).where((d) => members.containsKey(d)).length;

  /// Re-send what members haven't confirmed (the relay forgets text after ~12 h, files after ~3 h).
  Future<void> _resend() async {
    if (!paired || !online) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    var budget = 8;
    for (final x in msgs) {
      if (budget <= 0) break;
      if (x['from'] != me || x['kind'] == 'sys') continue;
      if (now - (x['at'] as num) > 7 * 86400000) continue;
      final isFile = x['path'] != null && x['kind'] != 'text' && x['kind'] != 'status' && x['kind'] != 'join';
      final pub = (x['pubAt'] as num?)?.toInt() ?? 0;
      final due = x['sent'] != true || (!deliveredAll(x) && now - pub > (isFile ? 150 : 480) * 60000);
      if (!due) continue;
      budget--;
      final meta = {for (final k in ['id', 'name', 'text', 'at', 'kind', 'fname', 'size']) if (x[k] != null) k: x[k]};
      bool ok;
      if (isFile) {
        final f = File(x['path'].toString());
        if (!f.existsSync()) continue;
        ok = await _publishFile({'t': 'file', ...meta}, await f.readAsBytes());
      } else {
        ok = await _publish({'t': 'msg', ...meta});
      }
      if (ok) await _patch(x['id'].toString(), {'sent': true, 'pubAt': now});
    }
  }
}

// ───────────────────────── quick messages + emojis ─────────────────────────
const quickMsgs = [
  '🍼 పాలు పట్టాను',
  '😴 పాప పడుకుంది',
  '😊 పాప లేచింది',
  '🧷 డైపర్ మార్చాను',
  '😢 పాప ఏడుస్తోంది, రా',
  '📞 కాల్ చెయ్',
  '🛒 డైపర్లు తెచ్చేయ్',
  '🏠 బయలుదేరాను',
  '❤️ Love you',
];

const reactEmojis = ['❤️', '😂', '😍', '👍', '🙏', '😢'];

const emojiSets = <String, String>{
  '😊': '😀 😃 😄 😁 😆 😅 🤣 😂 🙂 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😙 🥲 😋 😛 😜 🤪 😝 🤗 🤭 🤫 🤔 🤐 🤨 😐 😑 😶 😏 😒 🙄 😬 😌 😔 😪 🤤 😴 😷 🤒 🤕 🤢 🥵 🥶 🥴 😵 🤯 🥳 😎 🤓 😕 😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 🥱 😤 😡 😠',
  '❤️': '❤️ 🧡 💛 💚 💙 💜 🤎 🖤 🤍 💖 💗 💓 💞 💕 💘 💝 💟 ❣️ 💌 💋 🫶 😻 💐 🌹 🌸 🌺 🌷 🌼 🌻',
  '👶': '👶 🍼 🧸 🧷 🛁 🛏️ 🍭 🎀 🎁 🎈 🎉 🎊 🎂 🍰 👧 👦 👩 👨 👪 👨‍👩‍👧 👩‍🍼 👨‍🍼 🤱 👵 👴 🤰 👣 🌙 ⭐ 🌟 ✨ ☀️ 🌈 🦋 🐣 🐥 🐰 🐻 🐼 🐶 🐱 🦄',
  '🙏': '🙏 👍 👎 👏 🙌 👐 🤲 🤝 ✌️ 🤞 🤟 👌 🤌 👋 🤚 ✋ 🖐️ 💪 ☝️ 👆 👇 👈 👉 🫡 🫂 💯 ✅ ❌ ⚠️ ❓ ❗ 🔔 📞 📷 📍 🕉️ 🪔 🛕 🙇',
  '🍛': '🍛 🍚 🥘 🍲 🥗 🍞 🥛 ☕ 🍵 🧃 🥤 🍉 🍌 🍎 🍇 🥭 🍊 🥥 🍪 🍫 🍬 🍦 🧁 🍕 🍔 🍟 🌶️ 🧄 🥚 🍯',
  '🚗': '🏠 🏥 🏫 🛒 🚗 🛵 🚌 🚕 ✈️ 🚆 💊 🌡️ 💉 🩺 🩹 🧴 🧼 🪥 🧺 👕 👗 🧦 🧢 ☂️ 💰 📅 ⏰ 🎵 🎶 📖',
};

String babyStatus() {
  final s = Store.i;
  String t(DateTime? d) => d == null ? '–' : hm(d);
  return '👶 ${s.babyName} now:\n🍼 Last feed ${t(s.last('feeds'))} (${s.countToday('feeds')} today)\n🧷 Last nappy ${t(s.last('nappies'))} (${s.countToday('nappies')} today)\n🌤️ Woke at ${t(s.last('sleeps'))}\n😢 Cries today: ${s.countCries()}';
}

String _size(num b) => b >= 1048576 ? '${(b / 1048576).toStringAsFixed(1)} MB' : '${(b / 1024).ceil()} KB';

// ───────────────────────── UI ─────────────────────────
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool emojis = false;
  String emojiTab = emojiSets.keys.first;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    Chat.i.setPageOpen(true);
    _focus.addListener(() {
      if (_focus.hasFocus && emojis) setState(() => emojis = false);
    });
  }

  @override
  void dispose() {
    Chat.i.setPageOpen(false);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Chat.i,
      builder: (context, _) => Chat.i.paired ? _chat(context) : const _PairView(),
    );
  }

  void _insertEmoji(String e) {
    final t = _text.text, sel = _text.selection;
    final at = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    _text.value = TextEditingValue(text: t.replaceRange(at, end, e), selection: TextSelection.collapsed(offset: at + e.length));
  }

  Future<void> _sendPaths(List<String> paths) async {
    setState(() => sending = true);
    for (final p in paths) {
      final err = await Chat.i.sendFile(p);
      if (err != null && mounted) _snack(err);
    }
    if (mounted) setState(() => sending = false);
  }

  void _attach() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Text('🖼️', style: TextStyle(fontSize: 26)),
            title: const Text('Photos & videos'),
            onTap: () async {
              Navigator.pop(c);
              final l = await ImagePicker().pickMultipleMedia(maxWidth: 2048, maxHeight: 2048, imageQuality: 82);
              if (l.isNotEmpty) await _sendPaths(l.map((x) => x.path).toList());
            },
          ),
          ListTile(
            leading: const Text('📷', style: TextStyle(fontSize: 26)),
            title: const Text('Take a photo'),
            onTap: () async {
              Navigator.pop(c);
              final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2048, maxHeight: 2048, imageQuality: 82);
              if (x != null) await _sendPaths([x.path]);
            },
          ),
          ListTile(
            leading: const Text('🎥', style: TextStyle(fontSize: 26)),
            title: const Text('Record a video (up to 1 min)'),
            onTap: () async {
              Navigator.pop(c);
              final x = await ImagePicker().pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 1));
              if (x != null) await _sendPaths([x.path]);
            },
          ),
          ListTile(
            leading: const Text('📄', style: TextStyle(fontSize: 26)),
            title: const Text('Document (PDF, report, prescription…)'),
            onTap: () async {
              Navigator.pop(c);
              final l = await openFiles();
              if (l.isNotEmpty) await _sendPaths(l.map((x) => x.path).toList());
            },
          ),
        ]),
      ),
    );
  }

  Widget _chat(BuildContext context) {
    final c = Chat.i, cs = Theme.of(context).colorScheme;
    final l = c.msgs.reversed.toList();
    final n = c.members.length + 1;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('మన కుటుంబం · Family chat'),
          Text(c.online ? '🔒 $n member${n == 1 ? '' : 's'} · end-to-end encrypted' : '⚠️ Connecting… messages wait and send by themselves', style: TextStyle(fontSize: 12, color: c.online ? cs.outline : cs.error)),
        ]),
        actions: [IconButton(tooltip: 'Members & settings', onPressed: () => _settings(context), icon: const Icon(Icons.group))],
      ),
      body: Column(children: [
        Expanded(
          child: l.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No messages yet. Say hi! 👋', textAlign: TextAlign.center)))
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: l.length,
                  itemBuilder: (_, i) {
                    final m = l[i];
                    final at = DateTime.fromMillisecondsSinceEpoch((m['at'] as num).toInt());
                    final prev = i + 1 < l.length ? DateTime.fromMillisecondsSinceEpoch((l[i + 1]['at'] as num).toInt()) : null;
                    final newDay = prev == null || ymd(prev) != ymd(at);
                    return Column(children: [
                      if (newDay) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Chip(label: Text(ymd(at) == ymd(DateTime.now()) ? 'Today' : dmy(at)))),
                      _bubble(context, m, m['from'] == c.me, at),
                    ]);
                  },
                ),
        ),
        if (sending) const LinearProgressIndicator(minHeight: 2),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: ActionChip(avatar: const Icon(Icons.child_care, size: 18), label: const Text('Send baby status'), onPressed: () => c.send(babyStatus(), kind: 'status'))),
            ...quickMsgs.map((q) => Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: ActionChip(label: Text(q), onPressed: () => c.send(q)))),
          ]),
        ),
        SafeArea(
          top: false,
          bottom: !emojis,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(
                tooltip: 'Emojis',
                onPressed: () {
                  if (!emojis) _focus.unfocus();
                  setState(() => emojis = !emojis);
                  if (!emojis) _focus.requestFocus();
                },
                icon: Icon(emojis ? Icons.keyboard : Icons.emoji_emotions_outlined),
              ),
              IconButton(tooltip: 'Photo, video, document', onPressed: sending ? null : _attach, icon: const Icon(Icons.attach_file)),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 1500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(counterText: '', hintText: 'Message…', filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                iconSize: 24,
                onPressed: () {
                  final t = _text.text;
                  _text.clear();
                  c.send(t);
                },
                icon: const Icon(Icons.send),
              ),
            ]),
          ),
        ),
        if (emojis) _emojiPanel(context),
      ]),
    );
  }

  Widget _emojiPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = emojiSets[emojiTab]!.split(' ');
    return SafeArea(
      top: false,
      child: Container(
        height: 270,
        color: cs.surfaceContainerLow,
        child: Column(children: [
          Row(children: [
            ...emojiSets.keys.map((k) => Expanded(
                  child: InkWell(
                    onTap: () => setState(() => emojiTab = k),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 3, color: k == emojiTab ? cs.primary : Colors.transparent))),
                      child: Text(k, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                )),
            IconButton(
              onPressed: () {
                final t = _text.text;
                if (t.isEmpty) return;
                final chars = t.characters;
                _text.text = chars.take(chars.length - 1).toString();
              },
              icon: const Icon(Icons.backspace_outlined),
            ),
          ]),
          Expanded(
            child: GridView.count(
              crossAxisCount: 8,
              padding: const EdgeInsets.all(6),
              children: list.map((e) => InkWell(onTap: () => _insertEmoji(e), child: Center(child: Text(e, style: const TextStyle(fontSize: 28))))).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _media(BuildContext context, Map<String, dynamic> m) {
    final cs = Theme.of(context).colorScheme;
    final path = m['path']?.toString();
    final kind = m['kind'];
    final have = path != null && File(path).existsSync();
    if (!have) {
      final st = m['st'];
      final label = st == 'dl'
          ? 'Downloading…'
          : st == 'old'
              ? 'Shared before you joined'
              : m['url'] != null
                  ? 'Tap to download'
                  : 'Waiting for the sender\'s phone to send it…';
      return InkWell(
        onTap: () => Chat.i.download(m['id'].toString()),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Text(kind == 'image' ? '🖼️' : kind == 'video' ? '🎬' : '📄', style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(child: Text('${m['fname'] ?? ''}\n${m['size'] != null ? _size(m['size'] as num) : ''} · $label', style: const TextStyle(fontSize: 12))),
          ]),
        ),
      );
    }
    if (kind == 'image') {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaView(path: path, video: false))),
        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(path), width: 230, fit: BoxFit.cover, cacheWidth: 600)),
      );
    }
    if (kind == 'video') {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaView(path: path, video: true))),
        child: Container(
          width: 230,
          height: 140,
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 54),
            Text('Video · ${_size((m['size'] ?? 0) as num)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
      );
    }
    return InkWell(
      onTap: () => Share.shareXFiles([XFile(path)], text: m['fname']?.toString()),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Text('📄', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(child: Text('${m['fname']}\n${_size((m['size'] ?? 0) as num)} · tap to open', style: const TextStyle(fontSize: 13))),
        ]),
      ),
    );
  }

  Widget _bubble(BuildContext context, Map<String, dynamic> m, bool mine, DateTime at) {
    final cs = Theme.of(context).colorScheme, c = Chat.i;
    if (m['kind'] == 'sys' || m['kind'] == 'join') {
      return Padding(padding: const EdgeInsets.all(6), child: Text(m['text'].toString(), textAlign: TextAlign.center, style: TextStyle(color: cs.outline, fontSize: 13)));
    }
    final tick = !mine ? '' : c.deliveredAll(m) && (m['gotBy'] != null || m['got'] == true) ? ' ✓✓' : m['sent'] == true ? ' ✓' : ' 🕓';
    final isMedia = ['image', 'video', 'doc'].contains(m['kind']);
    final reacts = Map<String, dynamic>.from((m['reacts'] ?? {}) as Map);
    final rc = <String, int>{};
    for (final e in reacts.values) {
      rc[e.toString()] = (rc[e.toString()] ?? 0) + 1;
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _msgMenu(context, m),
        child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            margin: const EdgeInsets.only(top: 3),
            padding: EdgeInsets.fromLTRB(isMedia ? 6 : 14, isMedia ? 6 : 9, isMedia ? 6 : 14, 7),
            decoration: BoxDecoration(
              color: mine ? cs.primaryContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 4), bottomRight: Radius.circular(mine ? 4 : 18)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!mine) Padding(padding: EdgeInsets.only(left: isMedia ? 6 : 0, bottom: 2), child: Text(m['name'].toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.primary))),
              if (isMedia) _media(context, m),
              if ((m['text'] ?? '').toString().isNotEmpty) Padding(padding: EdgeInsets.only(left: isMedia ? 6 : 0, top: isMedia ? 4 : 0), child: Text(m['text'].toString(), style: TextStyle(fontSize: _onlyEmoji(m['text'].toString()) ? 34 : 16))),
              Padding(padding: EdgeInsets.only(right: isMedia ? 6 : 0), child: Align(alignment: Alignment.bottomRight, child: Text('${hm(at)}$tick', style: TextStyle(fontSize: 11, color: cs.outline)))),
            ]),
          ),
          if (rc.isNotEmpty)
            Transform.translate(
              offset: const Offset(0, -4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant)),
                child: Text(rc.entries.map((e) => e.value > 1 ? '${e.key}${e.value}' : e.key).join(' '), style: const TextStyle(fontSize: 14)),
              ),
            ),
          const SizedBox(height: 3),
        ]),
      ),
    );
  }

  static bool _onlyEmoji(String t) {
    final s = t.replaceAll(' ', '');
    return s.isNotEmpty && s.characters.length <= 3 && !RegExp(r'[A-Za-z0-9ఀ-౿ऀ-ॿ]').hasMatch(s);
  }

  void _msgMenu(BuildContext context, Map<String, dynamic> m) {
    final c = Chat.i;
    final path = m['path']?.toString();
    final hasFile = path != null && File(path).existsSync();
    final mine = m['from'] == c.me;
    showModalBottomSheet(
      context: context,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: reactEmojis
                  .map((e) => InkWell(
                        onTap: () {
                          Navigator.pop(s);
                          c.react(m['id'].toString(), e);
                        },
                        child: Padding(padding: const EdgeInsets.all(6), child: Text(e, style: const TextStyle(fontSize: 32))),
                      ))
                  .toList(),
            ),
          ),
          if ((m['text'] ?? '').toString().isNotEmpty)
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy text'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: m['text'].toString()));
                Navigator.pop(s);
              },
            ),
          if (hasFile && (m['kind'] == 'image' || m['kind'] == 'video'))
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Save to Memories'),
              onTap: () async {
                Navigator.pop(s);
                final p = await Store.keepFile(path, 'memories');
                await Store.i.addItem('memories', {'id': Store.newId(), 'path': p, 'video': m['kind'] == 'video', 'caption': (m['text'] ?? '').toString(), 'tag': 'Family chat', 'date': ymd(DateTime.fromMillisecondsSinceEpoch((m['at'] as num).toInt()))});
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Memories 💖')));
              },
            ),
          if (hasFile)
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share / open in another app'),
              onTap: () {
                Navigator.pop(s);
                Share.shareXFiles([XFile(path)]);
              },
            ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.done_all),
              title: Text('Received by ${c.deliveredCount(m)} of ${c.members.length}'),
              subtitle: Text(c.members.entries.map((e) => '${((m['gotBy'] as List?) ?? []).contains(e.key) ? '✓' : '…'} ${e.value['name']}').join('   ')),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete on this phone'),
            onTap: () {
              Navigator.pop(s);
              c.deleteLocal(m['id'].toString());
            },
          ),
        ]),
      ),
    );
  }

  void _settings(BuildContext context) {
    final c = Chat.i;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Members (${c.members.length + 1} of ${Chat.maxMembers})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Text('🙂')), title: Text('${c.myName} (you)')),
              ...c.members.entries.map((e) {
                final seen = (e.value['seen'] as num?)?.toInt();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text(e.value['name'].toString().isEmpty ? '?' : e.value['name'].toString().characters.first.toUpperCase())),
                  title: Text(e.value['name'].toString()),
                  subtitle: seen == null ? null : Text('last active ${dmy(DateTime.fromMillisecondsSinceEpoch(seen))} ${hm(DateTime.fromMillisecondsSinceEpoch(seen))}'),
                );
              }),
              const Divider(),
              const Text('Group code', style: TextStyle(fontWeight: FontWeight.w700)),
              SelectableText(c.cfg['code'].toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const Text('Send this code to family members you want to add (up to 10 people). Anyone with the code can read the chat.', style: TextStyle(fontSize: 12)),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.person_add_alt), title: const Text('Invite family (share code)'), onTap: () => Share.share('Join our Little One family chat 👶💬\nCode: ${c.cfg['code']}\nOpen Little One → Chat → "Join with code".')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text('My name: ${c.myName}'),
                onTap: () async {
                  final n = await _ask(context, 'Your name', c.myName);
                  if (n != null && n.isNotEmpty) await c.setName(n);
                },
              ),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.sync), title: const Text('Reconnect'), onTap: () => c.reconnectNow()),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout),
                title: const Text('Leave group (keeps old messages on this phone)'),
                onTap: () async {
                  Navigator.pop(s);
                  await c.leave();
                },
              ),
              const SizedBox(height: 6),
              const Text('Messages, photos and documents are saved on this phone forever and are in Profile → Backup (text). Photos/videos up to 14 MB each.', style: TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}

Future<String?> _ask(BuildContext context, String title, String init) {
  final t = TextEditingController(text: init);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(controller: t, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, t.text.trim()), child: const Text('OK'))],
    ),
  );
}

class MediaView extends StatefulWidget {
  final String path;
  final bool video;
  const MediaView({super.key, required this.path, required this.video});
  @override
  State<MediaView> createState() => _MediaViewState();
}

class _MediaViewState extends State<MediaView> {
  VideoPlayerController? v;
  @override
  void initState() {
    super.initState();
    if (widget.video) {
      v = VideoPlayerController.file(File(widget.path))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          v!.play();
        });
    }
  }

  @override
  void dispose() {
    v?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, actions: [IconButton(onPressed: () => Share.shareXFiles([XFile(widget.path)]), icon: const Icon(Icons.share))]),
      body: Center(
        child: widget.video
            ? (v != null && v!.value.isInitialized
                ? GestureDetector(
                    onTap: () => setState(() => v!.value.isPlaying ? v!.pause() : v!.play()),
                    child: AspectRatio(aspectRatio: v!.value.aspectRatio, child: VideoPlayer(v!)),
                  )
                : const CircularProgressIndicator())
            : InteractiveViewer(maxScale: 5, child: Image.file(File(widget.path))),
      ),
    );
  }
}

class _PairView extends StatefulWidget {
  const _PairView();
  @override
  State<_PairView> createState() => _PairViewState();
}

class _PairViewState extends State<_PairView> {
  late final _name = TextEditingController(text: Chat.i.myName);
  final _code = TextEditingController();
  String? newCode;
  bool busy = false;

  List<String> get _names {
    final p = Store.i.profile;
    return [
      for (final k in ['father', 'mother'])
        if ((p[k] ?? '').toString().isNotEmpty) p[k].toString(),
      'Amma',
      'Nanna',
      'Ammamma',
      'Thatayya',
      'Nanamma',
    ];
  }

  Future<void> _go(String code) async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Type your name first')));
      return;
    }
    if (Chat.normalise(code).length != 16) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The code has 16 letters/numbers, like ABCD-EFGH-JKLM-NPQR')));
      return;
    }
    setState(() => busy = true);
    await Chat.i.pair(code.trim().toUpperCase(), _name.text.trim());
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('మన కుటుంబం · Family chat')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('💬👨‍👩‍👧', style: TextStyle(fontSize: 50), textAlign: TextAlign.center),
        const Text('A private chat for your family', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Up to 10 people. Text, emojis, photos, videos and documents — all locked with your secret group code (end-to-end encrypted). Saved on every phone. Free, no sign-up.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        if (Chat.i.notice != null) Card(color: cs.errorContainer, child: Padding(padding: const EdgeInsets.all(12), child: Text(Chat.i.notice!))),
        const SizedBox(height: 20),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder())),
        Wrap(spacing: 6, children: _names.map((n) => ActionChip(label: Text(n), onPressed: () => setState(() => _name.text = n))).toList()),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('① Start the group (only one person does this)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Text('Make a code and send it to your family.'),
              const SizedBox(height: 10),
              if (newCode == null)
                FilledButton.icon(onPressed: () => setState(() => newCode = Chat.newCode()), icon: const Icon(Icons.key), label: const Text('Make a group code'))
              else ...[
                SelectableText(newCode!, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: cs.primary)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(onPressed: () => Share.share('Join our Little One family chat 👶💬\nCode: $newCode\nOpen Little One → Chat → "Join with code".'), icon: const Icon(Icons.share), label: const Text('Send code')),
                  FilledButton(onPressed: busy ? null : () => _go(newCode!), child: const Text('Start chat')),
                ]),
              ],
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('② Everyone else', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Text('Type the group code you received.'),
              const SizedBox(height: 10),
              TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'ABCD-EFGH-JKLM-NPQR', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              FilledButton(onPressed: busy ? null : () => _go(_code.text), child: const Text('Join with code')),
            ]),
          ),
        ),
        if (busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}
