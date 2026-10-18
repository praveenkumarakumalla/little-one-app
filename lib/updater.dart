import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'store.dart';

/// In-app updates: checks GitHub for a newer Little One, downloads it inside the app
/// and opens Android's installer (Android always asks for one "Install" tap).
class Updater {
  static const _api = 'https://api.github.com/repos/praveenkumarakumalla/little-one-app/releases/latest';
  static const _list = 'https://api.github.com/repos/praveenkumarakumalla/little-one-app/releases?per_page=30';

  /// '' = the family app; 'trial' = the new trial app (its releases are tagged trial-1.0.N).
  static String channel = '';
  static String get _apk => channel == 'trial' ? 'LittleOneTrial.apk' : 'LittleOne.apk';
  static bool _running = false;

  /// [manual] = the user tapped "Check for updates" (always tells the result).
  static Future<void> check(BuildContext context, {bool manual = false}) async {
    if (_running) return;
    final last = (Store.i.settings['updCheck'] as num?)?.toInt() ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!manual && now - last < 3 * 3600 * 1000) return; // at most every 3 hours
    _running = true;
    try {
      await Store.i.setSetting('updCheck', now);
      final info = await PackageInfo.fromPlatform();
      final mine = int.tryParse(info.buildNumber) ?? 0;
      final r = await http.get(Uri.parse(channel == 'trial' ? _list : _api), headers: {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw 'GitHub said ${r.statusCode}';
      final body = jsonDecode(r.body);
      final Map j = channel == 'trial'
          ? (body as List).cast<Map>().firstWhere((x) => (x['tag_name'] ?? '').toString().startsWith('trial-'), orElse: () => {})
          : body as Map;
      final tag = (j['tag_name'] ?? '').toString(); // v1.0.123
      final latest = int.tryParse(tag.split('.').last) ?? 0;
      final asset = ((j['assets'] as List?) ?? []).cast<Map>().firstWhere((a) => a['name'] == _apk, orElse: () => {});
      final url = asset['browser_download_url']?.toString();
      if (latest <= mine || url == null) {
        if (manual && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You have the latest version (1.0.$mine) ✅')));
        return;
      }
      if (!context.mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          icon: const Text('🎁', style: TextStyle(fontSize: 48)),
          title: const Text('New update ready!'),
          content: Text('Little One 1.0.$latest is available (you have 1.0.$mine).\n\nTap Update – it downloads here, then tap "Install". Your data stays safe.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Later')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Update now')),
          ],
        ),
      );
      if (go != true || !context.mounted) return;
      await _download(context, url, latest, (asset['size'] as num?)?.toInt() ?? 0);
    } catch (e) {
      if (manual && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not check for updates: $e')));
    } finally {
      _running = false;
    }
  }

  static Future<void> _download(BuildContext context, String url, int ver, int size) async {
    final progress = ValueNotifier<double>(0);
    var cancelled = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        title: const Text('Downloading update…'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, p, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: p > 0 ? p : null, minHeight: 8),
            const SizedBox(height: 8),
            Text(p > 0 ? '${(p * 100).round()}%' : 'Starting…'),
          ]),
        ),
        actions: [TextButton(onPressed: () { cancelled = true; Navigator.pop(d); }, child: const Text('Cancel'))],
      ),
    );
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/LittleOne-$ver.apk');
      final client = http.Client();
      final res = await client.send(http.Request('GET', Uri.parse(url)));
      final total = res.contentLength ?? size;
      final sink = f.openWrite();
      var got = 0;
      await for (final chunk in res.stream) {
        if (cancelled) break;
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) progress.value = got / total;
      }
      await sink.close();
      client.close();
      if (cancelled) return;
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      final r = await OpenFilex.open(f.path, type: 'application/vnd.android.package-archive');
      if (r.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Allow "Install unknown apps" for Little One, then tap Update again. (${r.message})')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }
}
