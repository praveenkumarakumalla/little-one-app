import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:alarm/alarm.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'bg.dart';
import 'chat.dart';

/// Family voice & video calls (phone to phone, WebRTC – free, works on Wi-Fi or mobile data).
/// The invite travels through the encrypted family chat, so only family phones ring.
class Calls {
  static const _ringId = 1600;
  static Map<String, dynamic>? pending; // the call that is ringing right now
  static bool inCall = false;
  static final _ring = AudioPlayer();
  static GlobalKey<NavigatorState>? nav;

  static String _room() {
    const abc = 'abcdefghijkmnpqrstuvwxyz23456789';
    final r = math.Random.secure();
    return List.generate(10, (_) => abc[r.nextInt(abc.length)]).join();
  }

  static bool isRing(int id) => id == _ringId;

  /// Start a call from this phone.
  static Future<void> start(BuildContext context, {required bool video}) async {
    final c = Chat.i;
    if (!c.paired) return;
    if (!await _perms(video)) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allow microphone and camera for calls')));
      return;
    }
    final room = _room();
    await c.send(video ? '📹 Video call' : '📞 Voice call', kind: 'call', extra: {'room': room, 'video': video});
    if (!context.mounted) return;
    final others = c.members.values.map((m) => m['name'].toString()).where((n) => n.isNotEmpty).join(', ');
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CallPage(room: room, video: video, host: true, title: others.isEmpty ? 'Family' : others)));
  }

  static Future<bool> _perms(bool video) async {
    final m = await Permission.microphone.request();
    if (!m.isGranted) return false;
    if (video && !(await Permission.camera.request()).isGranted) return false;
    return true;
  }

  /// A call invite arrived in the chat.
  static Future<void> incoming(Map<String, dynamic> m, {required bool visible, BuildContext? context}) async {
    if (inCall) return;
    pending = m;
    if (visible && context != null && context.mounted) {
      unawaited(showIncoming(context));
    } else {
      // app in the background: ring loudly with a notification (tap opens the answer screen)
      try {
        await Alarm.set(
          alarmSettings: AlarmSettings(
            id: _ringId,
            dateTime: DateTime.now().add(const Duration(seconds: 1)),
            assetAudioPath: 'assets/audio/music_box.wav',
            loopAudio: true,
            vibrate: true,
            androidFullScreenIntent: true,
            warningNotificationOnKill: false,
            volumeSettings: VolumeSettings.fade(volume: 1.0, fadeDuration: const Duration(milliseconds: 500), volumeEnforced: false),
            notificationSettings: NotificationSettings(
              title: '${m['video'] == true ? '📹' : '📞'} ${m['name'] ?? 'Family'} is calling',
              body: 'Open Little One to answer',
              stopButton: 'Decline',
              iconColor: const Color(0xFFEE5D8E),
            ),
          ),
        );
      } catch (_) {}
    }
    // stop ringing after 45 s
    final id = m['id'];
    Future.delayed(const Duration(seconds: 45), () {
      if (pending != null && pending!['id'] == id) {
        pending = null;
        stopRing();
      }
    });
  }

  static Future<void> stopRing() async {
    try {
      await _ring.stop();
    } catch (_) {}
    try {
      await Alarm.stop(_ringId);
    } catch (_) {}
  }

  static bool _sheetOpen = false;
  static Future<void> showIncoming(BuildContext context) async {
    final m = pending;
    if (m == null || _sheetOpen) return;
    _sheetOpen = true;
    try {
      await Alarm.stop(_ringId);
    } catch (_) {}
    try {
      await _ring.setReleaseMode(ReleaseMode.loop);
      await _ring.play(AssetSource('audio/music_box.wav'), volume: 1.0);
    } catch (_) {}
    HapticFeedback.heavyImpact();
    final video = m['video'] == true;
    final ans = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _IncomingPage(name: (m['name'] ?? 'Family').toString(), video: video)));
    _sheetOpen = false;
    await stopRing();
    if (ans == true && pending != null && context.mounted) {
      pending = null;
      if (!await _perms(video)) return;
      if (!context.mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CallPage(room: m['room'].toString(), video: video, host: false, title: (m['name'] ?? 'Family').toString())));
    } else {
      pending = null;
    }
  }

  /// Join a call by tapping its message in the chat (if it's still going).
  static Future<void> join(BuildContext context, Map<String, dynamic> m) async {
    final at = (m['at'] as num?)?.toInt() ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - at > 60 * 60 * 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This call has ended. Tap 📞 or 📹 at the top to call again.')));
      return;
    }
    final video = m['video'] == true;
    if (!await _perms(video) || !context.mounted) return;
    final mine = m['from'] == Chat.i.me;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CallPage(room: m['room'].toString(), video: video, host: false, title: mine ? 'Family call' : (m['name'] ?? 'Family').toString())));
  }
}

class _IncomingPage extends StatelessWidget {
  final String name;
  final bool video;
  const _IncomingPage({required this.name, required this.video});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1024),
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          Text(video ? '📹' : '📞', style: const TextStyle(fontSize: 90)),
          const SizedBox(height: 16),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(video ? 'Video call…' : 'Voice call…', style: const TextStyle(color: Colors.white70, fontSize: 18)),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Column(children: [
              FloatingActionButton.large(heroTag: 'no', backgroundColor: const Color(0xFFE53950), onPressed: () => Navigator.pop(context, false), child: const Icon(Icons.call_end, color: Colors.white, size: 40)),
              const SizedBox(height: 8),
              const Text('Decline', style: TextStyle(color: Colors.white)),
            ]),
            Column(children: [
              FloatingActionButton.large(heroTag: 'yes', backgroundColor: const Color(0xFF2EAE5A), onPressed: () => Navigator.pop(context, true), child: Icon(video ? Icons.videocam : Icons.call, color: Colors.white, size: 40)),
              const SizedBox(height: 8),
              const Text('Answer', style: TextStyle(color: Colors.white)),
            ]),
          ]),
          const SizedBox(height: 60),
        ]),
      ),
    );
  }
}

class CallPage extends StatefulWidget {
  final String room, title;
  final bool video, host;
  const CallPage({super.key, required this.room, required this.video, required this.host, required this.title});
  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  late final WebViewController w;
  bool started = false;

  @override
  void initState() {
    super.initState();
    Calls.inCall = true;
    WakelockPlus.enable();
    Bg.speaker(widget.video);
    w = WebViewController(onPermissionRequest: (r) => r.grant())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1B1024))
      ..addJavaScriptChannel('Flutter', onMessageReceived: (m) => _msg(m.message))
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) => _start()))
      ..loadFlutterAsset('assets/call/index.html');
  }

  Future<void> _start() async {
    if (started) return;
    started = true;
    final cfg = {'room': widget.room, 'video': widget.video, 'role': widget.host ? 'host' : 'guest', 'name': Chat.i.myName, 'title': widget.title, 'callee': widget.title};
    await w.runJavaScript('startCall(${jsonEncode(jsonEncode(cfg))})');
  }

  void _msg(String m) {
    if (m.startsWith('end:')) {
      final why = m.substring(4);
      if (mounted) {
        if (why.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(why)));
        Navigator.of(context).maybePop();
      }
    } else if (m.startsWith('speaker:')) {
      Bg.speaker(m.endsWith('1'));
    } else if (m == 'connected') {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    Calls.inCall = false;
    WakelockPlus.disable();
    Bg.speaker(false, active: false);
    // closing the WebView hangs up
    w.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(backgroundColor: const Color(0xFF1B1024), body: SafeArea(child: WebViewWidget(controller: w))),
    );
  }
}
