import 'dart:convert';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Family-chat notifications.
///  • App open in the background → shown instantly (from the live chat connection).
///  • App closed → Android wakes a tiny background check every ~15 minutes.
class ChatNotify {
  static final _n = FlutterLocalNotificationsPlugin();
  static const _alarmId = 4401;
  static const _seenKey = 'chatNotified';

  /// Set by the main app once it has initialised notifications (with the tap handler) — don't overwrite that.
  static bool ready = false;

  static Future<void> _init() async {
    if (ready) return;
    await _n.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    ready = true;
  }

  static String summary(Map m) {
    final kind = (m['kind'] ?? 'text').toString();
    final text = (m['text'] ?? '').toString();
    if (kind == 'image') return '📷 Photo${text.isNotEmpty ? ' · $text' : ''}';
    if (kind == 'video') return '🎬 Video${text.isNotEmpty ? ' · $text' : ''}';
    if (kind == 'doc') return '📄 ${m['fname'] ?? 'Document'}';
    if (kind == 'voice') return '🎤 Voice message';
    if (kind == 'say') return '🔊👶 Baby says: $text';
    if (kind == 'call') return '${m['video'] == true ? '📹 Video' : '📞 Voice'} call – open Little One to join';
    return text;
  }

  /// Shows one notification per message id (never twice, even if both the app and the background check see it).
  static Future<void> show(String id, String from, String body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final seen = prefs.getStringList(_seenKey) ?? [];
    if (seen.contains(id)) return;
    seen.add(id);
    await prefs.setStringList(_seenKey, seen.length > 300 ? seen.sublist(seen.length - 300) : seen);
    await _init();
    await _n.show(
      id.hashCode & 0x7fffffff,
      '💬 $from',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails('family_chat', 'Family chat', channelDescription: 'New messages from your family', importance: Importance.high, priority: Priority.high, groupKey: 'little_one_chat'),
      ),
      payload: 'chat',
    );
  }

  static Future<void> start() async {
    try {
      await AndroidAlarmManager.periodic(const Duration(minutes: 15), _alarmId, chatBackgroundCheck, wakeup: true, rescheduleOnReboot: true, allowWhileIdle: true);
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await AndroidAlarmManager.cancel(_alarmId);
    } catch (_) {}
  }
}

/// Runs in the background (even when the app is closed): fetch new chat messages and notify.
@pragma('vm:entry-point')
Future<void> chatBackgroundCheck() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await backgroundUpdate();
  } catch (_) {}
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString('data');
    if (raw == null) return;
    final d = jsonDecode(raw) as Map;
    final cfg = Map<String, dynamic>.from((d['chatCfg'] ?? {}) as Map);
    final code = (cfg['code'] ?? '').toString().toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (code.length != 16) return;
    final me = (cfg['device'] ?? '').toString();
    final known = ((d['chat'] as List?) ?? []).map((e) => (e as Map)['id'].toString()).toSet();
    final th = await Sha256().hash(utf8.encode('little-one-topic:$code'));
    final topic = 'lo_${th.bytes.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    final key = SecretKey((await Sha256().hash(utf8.encode('little-one-key:$code'))).bytes);
    final mainSince = int.tryParse((cfg['since'] ?? '').toString()) ?? 0;
    final bgSince = prefs.getInt('chatBgSince') ?? 0;
    var since = mainSince > bgSince ? mainSince : bgSince;
    if (since == 0) since = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 6 * 3600;
    final aes = AesGcm.with256bits();
    var latest = since;
    final lines = <String>[];
    for (final relay in const ['https://ntfy.sh', 'https://ntfy.envs.net']) {
      try {
        final r = await http.get(Uri.parse('$relay/$topic/json?poll=1&since=$since')).timeout(const Duration(seconds: 25));
        if (r.statusCode == 200) lines.addAll(const LineSplitter().convert(r.body));
      } catch (_) {}
    }
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final ev = jsonDecode(line) as Map;
      if (ev['event'] != 'message') continue;
      final t = (ev['time'] as num?)?.toInt() ?? 0;
      if (t > latest) latest = t;
      try {
        final box = SecretBox.fromConcatenation(base64Decode(ev['message'].toString()), nonceLength: 12, macLength: 16);
        final m = jsonDecode(utf8.decode(await aes.decrypt(box, secretKey: key))) as Map;
        if (m['from'] == me || (m['t'] != 'msg' && m['t'] != 'file' && m['t'] != 'mem')) continue;
        final id = m['id'].toString();
        if (known.contains(id)) continue;
        if (m['t'] == 'mem') {
          await ChatNotify.show('mem_$id', (m['name'] ?? 'Family').toString(), '🖼️ added a new memory${(m['caption'] ?? '').toString().isNotEmpty ? ': ${m['caption']}' : ''}');
        } else {
          await ChatNotify.show(id, (m['name'] ?? 'Family').toString(), ChatNotify.summary(m));
        }
      } catch (_) {}
    }
    await prefs.setInt('chatBgSince', latest);
  } catch (_) {}
}


/// Every ~2 hours (also when the app is closed): if GitHub has a newer Little One, download it quietly
/// and show "Update ready – tap to install". Tapping it opens Android's installer (one tap: Install).
@pragma('vm:entry-point')
Future<void> backgroundUpdate({bool force = false}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final now = DateTime.now().millisecondsSinceEpoch;
  if (!force && now - (prefs.getInt('updBgAt') ?? 0) < 2 * 3600 * 1000) return;
  await prefs.setInt('updBgAt', now);
  final info = await PackageInfo.fromPlatform();
  if (info.packageName.contains('trial')) return; // the trial app updates on its own channel
  final mine = (int.tryParse(info.buildNumber) ?? 0) % 1000; // split-per-abi adds 1000/2000 to the code
  final r = await http.get(Uri.parse('https://api.github.com/repos/praveenkumarakumalla/little-one-app/releases/latest'), headers: {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 20));
  if (r.statusCode != 200) return;
  final j = jsonDecode(r.body) as Map;
  final latest = int.tryParse((j['tag_name'] ?? '').toString().split('.').last) ?? 0;
  if (latest <= mine) return;
  final asset = ((j['assets'] as List?) ?? []).cast<Map>().firstWhere((a) => a['name'] == 'LittleOne.apk', orElse: () => {});
  final url = asset['browser_download_url']?.toString();
  final size = (asset['size'] as num?)?.toInt() ?? 0;
  if (url == null) return;
  final dir = Directory('${(await getApplicationSupportDirectory()).path}/updates');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final f = File('${dir.path}/LittleOne-$latest.apk');
  if (!f.existsSync() || (size > 0 && f.lengthSync() != size)) {
    // remove older downloads, then fetch this one
    for (final o in dir.listSync()) {
      try {
        o.deleteSync();
      } catch (_) {}
    }
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(url))).timeout(const Duration(seconds: 30));
      final tmp = File('${f.path}.part');
      final sink = tmp.openWrite();
      await res.stream.pipe(sink);
      if (size > 0 && tmp.lengthSync() != size) {
        tmp.deleteSync();
        return;
      }
      tmp.renameSync(f.path);
    } finally {
      client.close();
    }
  }
  await prefs.setString('updReady', '$latest|${f.path}');
  if (prefs.getInt('updNotified') == latest) return;
  await prefs.setInt('updNotified', latest);
  final n = FlutterLocalNotificationsPlugin();
  await n.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  await n.show(
    7700,
    '🎁 Little One update ready',
    'Version 1.0.$latest is downloaded. Tap to install – your data stays safe.',
    const NotificationDetails(android: AndroidNotificationDetails('app_update', 'App updates', channelDescription: 'New versions of Little One', importance: Importance.high, priority: Priority.high)),
    payload: 'update',
  );
}
