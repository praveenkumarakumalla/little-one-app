import 'package:url_launcher/url_launcher.dart';

/// Hidden surprise: long-press the baby avatar on Home → "Our Little World".
/// Opens in Chrome's in-app tab (full Chrome engine) – the plain WebView ran out of
/// memory on this cinematic page and crashed.
const ourWorldUrl = 'https://our-new-little-word.netlify.app/';

Future<void> openOurWorld() async {
  final u = Uri.parse(ourWorldUrl);
  try {
    if (await launchUrl(u, mode: LaunchMode.inAppBrowserView)) return;
  } catch (_) {}
  await launchUrl(u, mode: LaunchMode.externalApplication);
}
