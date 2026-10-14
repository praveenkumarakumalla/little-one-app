import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../chant.dart';
import '../store.dart';
import '../voice.dart';

class SongsPage extends StatefulWidget {
  const SongsPage({super.key});
  @override
  State<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends State<SongsPage> {
  List<dynamic> lists = [];
  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/songs.json').then((s) => setState(() => lists = jsonDecode(s) as List));
  }

  String _search(String q) => 'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(q)}';

  Future<void> _play(BuildContext context, Map it, String title) async {
    final file = Store.i.songFile(it['id'].toString());
    if (file != null) {
      if (Voice.i.musicOn && Voice.i.nowPlaying == title) {
        await Voice.i.stopMusic();
      } else {
        await Voice.i.playFile(file, title);
      }
      setState(() {});
      return;
    }
    if (it['vid'] != null) {
      await Voice.i.stopMusic();
      await Chant.i.stop();
      if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => YtPage(vid: it['vid'].toString(), alt: it['alt']?.toString(), title: title)));
      return;
    }
    await launchUrl(Uri.parse(_search((it['q'] ?? title).toString())), mode: LaunchMode.externalApplication);
  }

  Future<void> _addFile(String id) async {
    final f = await openFile(acceptedTypeGroups: [const XTypeGroup(label: 'Songs', extensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus', 'mp4'], mimeTypes: ['audio/*'])]);
    if (f == null) return;
    final path = await Store.keepFile(f.path, 'songs');
    await Store.i.setSongFile(id, path);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Song added. It plays inside the app now ♪')));
  }

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) return const Center(child: CircularProgressIndicator());
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) => DefaultTabController(
        length: lists.length,
        child: Scaffold(
          appBar: AppBar(title: const Text('Krishna songs · పాటలు'), bottom: TabBar(tabs: lists.map((l) => Tab(text: (l as Map)['short'].toString())).toList())),
          body: TabBarView(children: lists.map((l) => _list(context, l as Map)).toList()),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, Map l) {
    final items = (l['items'] as List).cast<Map>();
    final mantras = l['kind'] == 'mantras';
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (l['subtitle'] != null) Padding(padding: const EdgeInsets.all(6), child: Text(l['subtitle'].toString())),
      ...items.map((it) {
        final id = it['id'].toString();
        final title = (mantras ? it['t'] : it['te']).toString();
        final hasFile = Store.i.songFile(id) != null;
        final playing = Voice.i.musicOn && Voice.i.nowPlaying == title;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if (mantras) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(it['m'].toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary))),
              Text(mantras ? it['mean'].toString().replaceAll('**', '') : '${it['en']} · ${it['by']}', style: const TextStyle(fontSize: 13)),
              if (hasFile) const Text('Plays your file inside the app', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                FilledButton.icon(onPressed: () => _play(context, it, title), icon: Icon(playing ? Icons.stop : Icons.play_arrow), label: Text(playing ? 'Stop' : 'Play')),
                if (!hasFile) OutlinedButton(onPressed: () => _addFile(id), child: const Text('＋ Song file')),
                if (hasFile) TextButton(onPressed: () => Store.i.setSongFile(id, null), child: const Text('Remove file')),
                if (mantras) OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MalaPage(id: id, text: it['m'].toString()))), child: Text('జపం${Store.i.mala(id) > 0 ? ' (${Store.i.mala(id)})' : ''}')),
              ]),
            ]),
          ),
        );
      }),
    ]);
  }
}

class YtPage extends StatefulWidget {
  final String vid, title;
  final String? alt;
  const YtPage({super.key, required this.vid, required this.title, this.alt});
  @override
  State<YtPage> createState() => _YtPageState();
}

class _YtPageState extends State<YtPage> {
  late YoutubePlayerController c;
  late String cur;
  Timer? sleep;
  int mins = 20;

  @override
  void initState() {
    super.initState();
    cur = widget.vid;
    c = YoutubePlayerController.fromVideoId(videoId: cur, autoPlay: true, params: const YoutubePlayerParams(showFullscreenButton: true, loop: true, strictRelatedVideos: true));
    _arm();
    WakelockPlus.enable();
  }

  void _arm() {
    sleep?.cancel();
    if (mins > 0) sleep = Timer(Duration(minutes: mins), () => c.pauseVideo());
  }

  @override
  void dispose() {
    sleep?.cancel();
    c.close();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontSize: 18))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        ClipRRect(borderRadius: BorderRadius.circular(18), child: YoutubePlayer(controller: c, aspectRatio: 16 / 9)),
        const SizedBox(height: 14),
        const Text('Stop after', style: TextStyle(fontWeight: FontWeight.w700)),
        Wrap(spacing: 8, children: [0, 10, 20, 30, 45].map((m) => ChoiceChip(label: Text(m == 0 ? 'Keep playing' : '$m min'), selected: mins == m, onSelected: (_) => setState(() { mins = m; _arm(); }))).toList()),
        const SizedBox(height: 12),
        if (widget.alt != null && widget.alt!.isNotEmpty)
          OutlinedButton(
            onPressed: () => setState(() {
              cur = cur == widget.vid ? widget.alt! : widget.vid;
              c.loadVideoById(videoId: cur);
            }),
            child: const Text("Not playing? Try another version"),
          ),
        TextButton(onPressed: () => launchUrl(Uri.parse('https://www.youtube.com/watch?v=$cur'), mode: LaunchMode.externalApplication), child: const Text('Open in YouTube')),
        const Text('Keep this screen open while it plays. The screen stays on.', style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}

class MalaPage extends StatefulWidget {
  final String id, text;
  const MalaPage({super.key, required this.id, required this.text});
  @override
  State<MalaPage> createState() => _MalaPageState();
}

class _MalaPageState extends State<MalaPage> {
  int target = 108;
  late int n = Store.i.mala(widget.id);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme, done = n >= target;
    return Scaffold(
      appBar: AppBar(title: const Text('జప మాల')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(widget.text, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.primary)),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: () async {
              setState(() => n++);
              await Store.i.setMala(widget.id, n);
              if (n == target) {
                HapticFeedback.heavyImpact();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mala complete 🙏')));
              } else {
                HapticFeedback.selectionClick();
              }
            },
            child: SizedBox(
              width: 230,
              height: 230,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 230, height: 230, child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: (n / target).clamp(0, 1).toDouble()), duration: const Duration(milliseconds: 300), builder: (_, v, __) => CircularProgressIndicator(value: v, strokeWidth: 14, strokeCap: StrokeCap.round, color: done ? Colors.teal : cs.primary, backgroundColor: cs.surfaceContainerHighest))),
                Column(mainAxisSize: MainAxisSize.min, children: [Text('$n', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900)), Text('of $target · tap')]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ChoiceChip(label: const Text('11'), selected: target == 11, onSelected: (_) => setState(() => target = 11)),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('108'), selected: target == 108, onSelected: (_) => setState(() => target = 108)),
          const SizedBox(width: 16),
          TextButton(onPressed: () async { setState(() => n = 0); await Store.i.setMala(widget.id, 0); }, child: const Text('Reset')),
        ]),
      ]),
    );
  }
}
