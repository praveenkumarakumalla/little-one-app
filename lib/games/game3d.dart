import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../chat.dart';
import '../store.dart';

/// Hosts the real-3D games (three.js, bundled in assets/games3d – works offline).
class Game3DPage extends StatefulWidget {
  final Map<String, dynamic> cfg;
  const Game3DPage({super.key, required this.cfg});
  @override
  State<Game3DPage> createState() => _Game3DPageState();
}

class _Game3DPageState extends State<Game3DPage> {
  late final WebViewController w;
  bool started = false;

  @override
  void initState() {
    super.initState();
    // games use the whole screen: hide the status bar and the navigation bar (swipe to show them)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    w = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF2A1D17))
      ..addJavaScriptChannel('Flutter', onMessageReceived: (m) => _msg(m.message))
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) => _start()))
      ..loadFlutterAsset('assets/games3d/index.html');
    // game sounds may start without waiting for a tap
    final p = w.platform;
    if (p is AndroidWebViewController) p.setMediaPlaybackRequiresUserGesture(false);
  }

  Future<void> _start() async {
    if (started) return;
    started = true;
    final cfg = {...widget.cfg, 'me': Chat.i.myName.isEmpty ? 'Me' : Chat.i.myName};
    await w.runJavaScript('startGame(${jsonEncode(jsonEncode(cfg))})');
  }

  void _msg(String m) {
    if (m == 'exit') {
      if (mounted) Navigator.of(context).maybePop();
    } else if (m.startsWith('haptic:')) {
      switch (m.substring(7)) {
        case 'heavy':
          HapticFeedback.heavyImpact();
        case 'medium':
          HapticFeedback.mediumImpact();
        default:
          HapticFeedback.selectionClick();
      }
    } else if (m.startsWith('share:')) {
      Share.share(m.substring(6));
    } else if (m.startsWith('theme:')) {
      Store.i.setSetting('chessTheme', int.tryParse(m.substring(6)) ?? 0);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF2A1D17),
        body: WebViewWidget(controller: w),
      ),
    );
  }
}
