import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../chat.dart';
import '../clay.dart';
import '../data.dart';
import '../filters.dart';
import 'camera.dart';
import '../store.dart';

const milestones = ['', 'First smile', 'First bath', 'Namakaranam', 'Barasala', 'Ashlesha shanti', 'Annaprasana', 'First tooth', 'First word', 'First steps', 'Aksharabhyasam', 'Birthday', 'Festival'];
bool isVideo(String p) => RegExp(r'\.(mp4|mov|3gp|mkv|webm)$', caseSensitive: false).hasMatch(p);

/// Saves photos/videos to the phone's Gallery (album "Little One"). Returns how many were saved.
Future<int> saveToGallery(BuildContext context, List<Map<String, dynamic>> items) async {
  try {
    if (!await Gal.hasAccess(toAlbum: true)) await Gal.requestAccess(toAlbum: true);
  } catch (_) {}
  var n = 0;
  for (final m in items) {
    final p = m['path']?.toString();
    if (p == null || !File(p).existsSync()) continue;
    try {
      m['video'] == true ? await Gal.putVideo(p, album: 'Little One') : await Gal.putImage(p, album: 'Little One');
      n++;
    } catch (_) {}
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(n == 0 ? 'Could not save – allow Photos access for Little One in Settings' : '✅ $n saved to Gallery → album "Little One"')));
  }
  return n;
}

Future<void> shareMemories(List<Map<String, dynamic>> items) async {
  final files = [for (final m in items) if (m['path'] != null && File(m['path'].toString()).existsSync()) XFile(m['path'].toString())];
  if (files.isEmpty) return;
  final cap = items.length == 1 ? (items.first['caption'] ?? '').toString() : '';
  await Share.shareXFiles(files, text: cap.isEmpty ? null : cap);
}

String _mb(int bytes) => bytes >= 1024 * 1024 * 1024 ? '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

class MemoriesPage extends StatefulWidget {
  const MemoriesPage({super.key});
  @override
  State<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends State<MemoriesPage> {
  final Set<String> sel = {};

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
      listenable: Listenable.merge([Store.i, Chat.i]),
      builder: (context, _) {
        final items = Store.i.list('memories')..sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
        final groups = <String, List<Map<String, dynamic>>>{};
        for (final m in items) {
          groups.putIfAbsent((m['date'] ?? '').toString().substring(0, 7), () => []).add(m);
        }
        final chosen = items.where((m) => sel.contains(m['id'].toString())).toList();
        var photos = 0, videos = 0, bytes = 0;
        for (final m in items) {
          final p = m['path']?.toString();
          if (p == null) continue;
          m['video'] == true ? videos++ : photos++;
          try {
            bytes += File(p).lengthSync();
          } catch (_) {}
        }
        if (sel.isNotEmpty) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(sel.clear)),
              title: Text(chosen.isEmpty ? 'Tap memories to select' : '${chosen.length} selected'),
              actions: [
                IconButton(tooltip: 'Select all', icon: const Icon(Icons.select_all), onPressed: () => setState(() => sel.addAll(items.where((m) => m['path'] != null).map((m) => m['id'].toString())))),
                IconButton(tooltip: 'Save to Gallery', icon: const Icon(Icons.download), onPressed: () async {
                  await saveToGallery(context, chosen);
                  if (mounted) setState(sel.clear);
                }),
                IconButton(tooltip: 'Share', icon: const Icon(Icons.share), onPressed: () => shareMemories(chosen)),
              ],
            ),
            body: _grid(context, groups),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Memories · జ్ఞాపకాలు'), actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'all') await saveToGallery(context, items.where((m) => m['path'] != null).toList());
                if (v == 'pick') setState(() => sel.add('_'));
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'pick', child: Text('☑️ Select to save / share')),
                PopupMenuItem(value: 'all', child: Text('⬇️ Save all to Gallery')),
              ],
            ),
            IconButton(
              tooltip: 'Share with family',
              icon: Icon(Chat.i.paired ? Icons.cloud_sync_outlined : Icons.cloud_off_outlined),
              onPressed: () => _syncInfo(context),
            ),IconButton(tooltip: 'Camera with filters', icon: const Icon(Icons.camera_alt_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraPage())))]),
          floatingActionButton: FloatingActionButton.extended(onPressed: () => _add(context), icon: const Icon(Icons.add_a_photo), label: const Text('Add')),
          body: items.isEmpty
              ? ListView(padding: const EdgeInsets.all(12), children: [
                  if (!Chat.i.paired) _connectBanner(context),
                  const Padding(padding: EdgeInsets.all(32), child: Text('Her first photos and videos will live here, grouped by month. Tap Add.', textAlign: TextAlign.center)),
                ])
              : ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), children: [
                  if (!Chat.i.paired) _connectBanner(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text('📸 $photos photos · 🎬 $videos videos · 💾 ${_mb(bytes)} on this phone\nLong-press to select · tap a memory to save or share it', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  ),
                  ..._sections(context, groups),
                ]),
        );
      },
    );
  }

  Widget _grid(BuildContext context, Map<String, List<Map<String, dynamic>>> groups) => ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), children: _sections(context, groups));

  List<Widget> _sections(BuildContext context, Map<String, List<Map<String, dynamic>>> groups) => [
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
      ];

  Widget _connectBanner(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: ClayButton(
          color: const Color(0xFFDCCBFF),
          color2: const Color(0xFFC8E0FF),
          onTap: () => _syncInfo(context),
          child: const Row(children: [
            Text('👨‍👩‍👧', style: TextStyle(fontSize: 30)),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Connect family gallery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2E2563))),
                Text('One time: enter your family code. Then everyone\'s memories appear on every family phone.', style: TextStyle(fontSize: 12, color: Color(0xFF2E2563))),
              ]),
            ),
          ]),
        ),
      );

  Future<void> _syncInfo(BuildContext context) async {
    if (!Chat.i.paired) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPage()));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Family gallery is ON 💖'),
        content: const Text('New photos and videos you save here appear on every family phone automatically (up to 14 MB each, end-to-end encrypted).\n\nShare the memories you saved before too?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Share old memories')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing… keep the app open for a minute')));
    final n = await Chat.i.shareAllMemories();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n memories shared with the family 💖')));
  }

  Widget _tile(BuildContext context, Map<String, dynamic> m) {
    if (m['path'] == null) {
      return GestureDetector(
        onTap: () => Chat.i.downloadMemory(m['id'].toString()),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            color: const Color(0xFFFFE3EE),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(height: 6),
              Text('From ${m['from'] ?? 'family'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5A1F3A))),
            ]),
          ),
        ),
      );
    }
    final path = m['path'].toString();
    final id = m['id'].toString(), picked = sel.contains(id);
    return GestureDetector(
      onLongPress: () => setState(() => sel..remove('_')..add(id)),
      onTap: () {
        if (sel.isNotEmpty) {
          setState(() {
            sel.remove('_');
            picked ? sel.remove(id) : sel.add(id);
          });
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => ViewerPage(m: m)));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(fit: StackFit.expand, children: [
          m['video'] == true
              ? Container(color: Colors.black87, child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 40))
              : Image.file(File(path), fit: BoxFit.cover, cacheWidth: 360, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
          if (m['from'] != null)
            Positioned(right: 5, bottom: 5, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)), child: Text('👤 ${m['from']}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)))),
          if (picked) Container(color: Colors.black38, alignment: Alignment.center, child: const Icon(Icons.check_circle, color: Colors.white, size: 36)),
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
          IconButton(tooltip: 'Save to Gallery', icon: const Icon(Icons.download), onPressed: () => saveToGallery(context, [m])),
          IconButton(tooltip: 'Share', icon: const Icon(Icons.share), onPressed: () => shareMemories([m])),
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
                ? GestureDetector(onTap: () => setState(() => v!.value.isPlaying ? v!.pause() : v!.play()), child: AspectRatio(aspectRatio: v!.value.aspectRatio, child: ColorFiltered(colorFilter: ColorFilter.matrix(filterById(m['filter']?.toString()).m), child: VideoPlayer(v!))))
                : const CircularProgressIndicator())
            : InteractiveViewer(child: Image.file(File(m['path'].toString()))),
      ),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(14), child: Text('${(m['date'] ?? '')}  ${(m['tag'] ?? '')}', style: const TextStyle(color: Colors.white70)))),
    );
  }
}
