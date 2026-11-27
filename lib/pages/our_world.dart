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

/// Open the private reading-room website in the browser's in-app tab.
/// ChatGPT sign-in may be needed because the Site remains owner-private.
const readingRoomUrl = 'https://the-enchanted-reading-room.fancyanchovy16.chatgpt.site/';

Future<void> openReadingRoom() async {
  final u = Uri.parse(readingRoomUrl);
  try {
    if (await launchUrl(u, mode: LaunchMode.inAppBrowserView)) return;
  } catch (_) {}
  await launchUrl(u, mode: LaunchMode.externalApplication);
}
