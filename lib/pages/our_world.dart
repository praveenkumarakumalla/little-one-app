import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Hidden surprise: long-press the baby avatar on Home → "Our Little World" (full screen, cinematic).
class OurWorldPage extends StatefulWidget {
  const OurWorldPage({super.key});
  static const url = 'https://our-new-little-word.netlify.app/';
  @override
  State<OurWorldPage> createState() => _OurWorldPageState();
}

class _OurWorldPageState extends State<OurWorldPage> {
  late final WebViewController w;
  int progress = 0;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    w = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D0426))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => mounted ? setState(() => progress = p) : null,
        onPageStarted: (_) => mounted ? setState(() => failed = false) : null,
        onWebResourceError: (e) {
          if (e.isForMainFrame == true && mounted) setState(() => failed = true);
        },
      ))
      ..loadRequest(Uri.parse(OurWorldPage.url));
    final p = w.platform;
    if (p is AndroidWebViewController) p.setMediaPlaybackRequiresUserGesture(false); // music can start by itself
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) async {
        if (did) return;
        if (await w.canGoBack()) {
          await w.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0426),
        body: Stack(children: [
          Positioned.fill(child: WebViewWidget(controller: w)),
          if (progress < 100 && !failed)
            const Center(child: Text('Entering Our Little World… ❤️', style: TextStyle(color: Colors.white70, fontSize: 16))),
          if (failed)
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('💌', style: TextStyle(fontSize: 54)),
                const SizedBox(height: 10),
                const Text('Needs internet to open our world', style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => w.reload(), child: const Text('Try again')),
              ]),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black26),
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
