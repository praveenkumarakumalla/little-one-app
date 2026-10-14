import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../data.dart';
import '../store.dart';

const milestones = ['', 'First smile', 'First bath', 'Namakaranam', 'Barasala', 'Ashlesha shanti', 'Annaprasana', 'First tooth', 'First word', 'First steps', 'Aksharabhyasam', 'Birthday', 'Festival'];
bool isVideo(String p) => RegExp(r'\.(mp4|mov|3gp|mkv|webm)$', caseSensitive: false).hasMatch(p);

class MemoriesPage extends StatelessWidget {
  const MemoriesPage({super.key});

  Future<void> _add(BuildContext context) async {
    final picked = await ImagePicker().pickMultipleMedia(imageQuality: 85, maxWidth: 2400);
    if (picked.isEmpty || !context.mounted) return;
    final cap = TextEditingController();
    String tag = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('Add ${picked.length} memor${picked.length > 1 ? 'ies' : 'y'}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: cap, decoration: const InputDecoration(labelText: 'Caption', hintText: 'Her first bath…')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: tag,
              decoration: const InputDecoration(labelText: 'Milestone'),
              items: milestones.map((m) => DropdownMenuItem(value: m, child: Text(m.isEmpty ? 'None' : m))).toList(),
              onChanged: (v) => set(() => tag = v ?? ''),
            ),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))],
        ),
      ),
    );
    if (ok != true) return;
    for (final x in picked) {
      final path = await Store.keepFile(x.path, 'memories');
      final mod = await File(x.path).lastModified().catchError((_) => DateTime.now());
      await Store.i.addItem('memories', {'id': Store.newId(), 'path': path, 'video': isVideo(path), 'caption': cap.text.trim(), 'tag': tag, 'date': ymd(mod)});
    }
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${picked.length} saved ♡')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final items = Store.i.list('memories')..sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
        final groups = <String, List<Map<String, dynamic>>>{};
        for (final m in items) {
          groups.putIfAbsent((m['date'] ?? '').toString().substring(0, 7), () => []).add(m);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Memories · జ్ఞాపకాలు')),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => _add(context), icon: const Icon(Icons.add_a_photo), label: const Text('Add')),
          body: items.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Her first photos and videos will live here, grouped by month. Tap Add.', textAlign: TextAlign.center)))
              : ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), children: [
                  for (final g in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                      child: Text('${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][int.parse(g.key.substring(5)) - 1]} ${g.key.substring(0, 4)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      children: g.value.map((m) => _tile(context, m)).toList(),
                    ),
                  ],
                ]),
        );
      },
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> m) {
    final path = m['path'].toString();
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewerPage(m: m))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(fit: StackFit.expand, children: [
          m['video'] == true
              ? Container(color: Colors.black87, child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 40))
              : Image.file(File(path), fit: BoxFit.cover, cacheWidth: 360, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
          if ((m['tag'] ?? '').toString().isNotEmpty)
            Positioned(left: 6, top: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text(m['tag'].toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.pink)))),
        ]),
      ),
    );
  }
}

class ViewerPage extends StatefulWidget {
  final Map<String, dynamic> m;
  const ViewerPage({super.key, required this.m});
  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  VideoPlayerController? v;
  @override
  void initState() {
    super.initState();
    if (widget.m['video'] == true) {
      v = VideoPlayerController.file(File(widget.m['path'].toString()))
        ..initialize().then((_) {
          setState(() {});
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
    final m = widget.m;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text((m['caption'] ?? '').toString(), style: const TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete this memory?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
              if (ok != true) return;
              await Store.i.removeItem('memories', m['id'].toString());
              try { File(m['path'].toString()).deleteSync(); } catch (_) {}
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: m['video'] == true
            ? (v != null && v!.value.isInitialized
                ? GestureDetector(onTap: () => setState(() => v!.value.isPlaying ? v!.pause() : v!.play()), child: AspectRatio(aspectRatio: v!.value.aspectRatio, child: VideoPlayer(v!)))
                : const CircularProgressIndicator())
            : InteractiveViewer(child: Image.file(File(m['path'].toString()))),
      ),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(14), child: Text('${(m['date'] ?? '')}  ${(m['tag'] ?? '')}', style: const TextStyle(color: Colors.white70)))),
    );
  }
}
