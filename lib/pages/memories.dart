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
  int cat = 0; // 0 = photos, 1 = videos

  Future<void> _add(BuildContext context) async {
    final picked = await ImagePicker().pickMultipleMedia() // originals, 100% quality;
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
        final all = Store.i.list('memories')..sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
        final nPhotos = all.where((m) => m['video'] != true).length, nVideos = all.length - nPhotos;
        final items = all.where((m) => (m['video'] == true) == (cat == 1)).toList();
        final groups = <String, List<Map<String, dynamic>>>{};
        for (final m in items) {
          groups.putIfAbsent((m['date'] ?? '').toString().substring(0, 7), () => []).add(m);
        }
        final chosen = items.where((m) => sel.contains(m['id'].toString())).toList();
        var photos = 0, videos = 0, bytes = 0;
        for (final m in all) {
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
                  _cats(nPhotos, nVideos),
                  Padding(padding: const EdgeInsets.all(32), child: Text(cat == 1 ? 'No videos yet. Tap Add to pick videos.' : 'Her first photos will live here, grouped by month. Tap Add.', textAlign: TextAlign.center)),
                ])
              : ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), children: [
                  if (!Chat.i.paired) _connectBanner(context),
                  _cats(nPhotos, nVideos),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text('📸 $photos photos · 🎬 $videos videos · 💾 ${_mb(bytes)} on this phone\nTap to watch like reels · long-press to select', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  ),
                  ..._sections(context, groups),
                ]),
        );
      },
    );
  }

  Widget _cats(int nPhotos, int nVideos) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          for (final c in [(0, '📸 Photos', nPhotos), (1, '🎬 Videos', nVideos)]) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  cat = c.$1;
                  sel.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: cat == c.$1 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  alignment: Alignment.center,
                  child: Text('${c.$2}  ${c.$3}', style: TextStyle(fontWeight: FontWeight.w700, color: cat == c.$1 ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                ),
              ),
            ),
            if (c.$1 == 0) const SizedBox(width: 10),
          ],
        ]),
      );

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
        content: const Text('New photos and videos you save here appear on every family phone automatically (photos and videos up to 50 MB each, end-to-end encrypted).\n\nShare the memories you saved before too?'),
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
        final list = Store.i.list('memories').where((x) => x['path'] != null && (x['video'] == true) == (cat == 1)).toList()
          ..sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
        final at = list.indexWhere((x) => x['id'] == m['id']);
        Navigator.push(context, MaterialPageRoute(builder: (_) => ReelsPage(items: list, start: at < 0 ? 0 : at)));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(fit: StackFit.expand, children: [
          m['video'] == true
              ? Container(color: Colors.black87, child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 40))
              : Image.file(File(path), fit: BoxFit.cover, cacheWidth: 360, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
          if (m['from'] != null)
            Positioned(right: 5, bottom: 5, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)), child: Text('👤 ${m['from']}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)))),
          if (m['reacts'] is Map && (m['reacts'] as Map).isNotEmpty)
            Positioned(left: 5, bottom: 5, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(10)), child: Text((m['reacts'] as Map).keys.take(3).join(), style: const TextStyle(fontSize: 12)))),
          if (picked) Container(color: Colors.black38, alignment: Alignment.center, child: const Icon(Icons.check_circle, color: Colors.white, size: 36)),
          if ((m['tag'] ?? '').toString().isNotEmpty)
            Positioned(left: 6, top: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text(m['tag'].toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.pink)))),
        ]),
      ),
    );
  }
}

/// Full-screen memories, swipe up/down like reels. Videos play on their own and loop.
/// Double-tap = ❤️, the heart button opens cute emojis; reactions show on every family phone.
class ReelsPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int start;
  const ReelsPage({super.key, required this.items, required this.start});
  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

const memEmojis = ['❤️', '😍', '🥰', '😘', '😂', '👶', '🌸', '✨', '🔥', '👑', '🧿', '🙏'];

class _ReelsPageState extends State<ReelsPage> {
  late final PageController pc = PageController(initialPage: widget.start);
  late int page = widget.start;
  late final List<Map<String, dynamic>> items = List.of(widget.items);
  final List<_Burst> bursts = [];
  int _bid = 0;

  Map<String, dynamic> _live(Map<String, dynamic> m) => Store.i.list('memories').firstWhere((x) => x['id'] == m['id'], orElse: () => m);

  void _react(Map<String, dynamic> m, String e) {
    Chat.i.reactMemory(m['id'].toString(), e);
    final id = _bid++;
    setState(() => bursts.add(_Burst(id, e)));
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => bursts.removeWhere((b) => b.id == id));
    });
  }

  Future<void> _pick(Map<String, dynamic> m) async {
    final e = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            for (final e in memEmojis)
              GestureDetector(
                onTap: () => Navigator.pop(c, e),
                child: Container(width: 58, height: 58, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFF3ECFD), borderRadius: BorderRadius.circular(18)), child: Text(e, style: const TextStyle(fontSize: 32))),
              ),
          ]),
        ),
      ),
    );
    if (e != null) _react(m, e);
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete this memory?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
    if (ok != true) return;
    await Store.i.removeItem('memories', m['id'].toString());
    try {
      File(m['path'].toString()).deleteSync();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      items.removeWhere((x) => x['id'] == m['id']);
      if (page >= items.length) page = items.length - 1;
    });
    if (items.isEmpty) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) => Stack(children: [
          PageView.builder(
            controller: pc,
            scrollDirection: Axis.vertical,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => page = i),
            itemBuilder: (_, i) {
              final m = _live(items[i]);
              return GestureDetector(
                onDoubleTap: () => _react(m, '❤️'),
                child: Stack(fit: StackFit.expand, children: [
                  _ReelMedia(m: m, active: i == page),
                  // bottom: caption + reactions
                  Positioned(
                    left: 16,
                    right: 90,
                    bottom: 30,
                    child: SafeArea(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        if ((m['caption'] ?? '').toString().isNotEmpty) Text(m['caption'].toString(), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 6)])),
                        Text('${m['date'] ?? ''}  ${m['tag'] ?? ''}${m['from'] != null ? '  · 👤 ${m['from']}' : ''}', style: const TextStyle(color: Colors.white70, shadows: [Shadow(blurRadius: 6)])),
                        if (m['reacts'] is Map && (m['reacts'] as Map).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final e in (m['reacts'] as Map).entries)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(16)),
                                child: Text('${e.key} ${(e.value as List).length}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                              ),
                          ]),
                          Text('by ${{for (final v in (m['reacts'] as Map).values) ...(v as List).map((x) => x.toString())}.join(', ')}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ]),
                    ),
                  ),
                  // right side buttons
                  Positioned(
                    right: 12,
                    bottom: 40,
                    child: SafeArea(
                      child: Column(children: [
                        _side(Icons.favorite, '❤️', () => _react(m, '❤️'), color: Colors.pinkAccent),
                        _side(Icons.emoji_emotions, 'React', () => _pick(m)),
                        _side(Icons.download, 'Save', () => saveToGallery(context, [m])),
                        _side(Icons.share, 'Share', () => shareMemories([m])),
                        _side(Icons.delete_outline, 'Delete', () => _delete(m)),
                      ]),
                    ),
                  ),
                ]),
              );
            },
          ),
          // floating emojis
          for (final b in bursts) _BurstView(key: ValueKey(b.id), emoji: b.emoji),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
                Text(items.isEmpty ? '' : '${page + 1} / ${items.length}', style: const TextStyle(color: Colors.white70)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _side(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: GestureDetector(
          onTap: onTap,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 4)])),
          ]),
        ),
      );
}

class _Burst {
  final int id;
  final String emoji;
  _Burst(this.id, this.emoji);
}

/// A big emoji that pops in the middle and floats up, with a few small ones.
class _BurstView extends StatelessWidget {
  final String emoji;
  const _BurstView({super.key, required this.emoji});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1300),
        builder: (_, t, __) {
          final pop = t < 0.25 ? Curves.elasticOut.transform((t / 0.25).clamp(0.0, 1.0)) : 1.0;
          return Stack(children: [
            Align(
              alignment: Alignment(0, 0.1 - t * 0.6),
              child: Opacity(opacity: (1 - (t - 0.7).clamp(0.0, 0.3) / 0.3), child: Transform.scale(scale: 0.4 + pop * 1.2, child: Text(emoji, style: const TextStyle(fontSize: 110)))),
            ),
            for (var k = 0; k < 6; k++)
              Align(
                alignment: Alignment(-0.6 + k * 0.24, 0.5 - t * (0.9 + (k % 3) * 0.25)),
                child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: Text(emoji, style: TextStyle(fontSize: 26 + (k % 3) * 8.0))),
              ),
          ]);
        },
      ),
    );
  }
}

class _ReelMedia extends StatefulWidget {
  final Map<String, dynamic> m;
  final bool active;
  const _ReelMedia({required this.m, required this.active});
  @override
  State<_ReelMedia> createState() => _ReelMediaState();
}

class _ReelMediaState extends State<_ReelMedia> {
  VideoPlayerController? v;
  bool paused = false;

  @override
  void initState() {
    super.initState();
    if (widget.m['video'] == true) {
      v = VideoPlayerController.file(File(widget.m['path'].toString()))
        ..setLooping(true)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          if (widget.active) v!.play();
        });
    }
  }

  @override
  void didUpdateWidget(_ReelMedia old) {
    super.didUpdateWidget(old);
    final c = v;
    if (c == null || !c.value.isInitialized) return;
    if (widget.active && !paused) {
      c.play();
    } else {
      c.pause();
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
    if (m['video'] != true) {
      return Image.file(File(m['path'].toString()), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 60)));
    }
    final c = v;
    if (c == null || !c.value.isInitialized) return const Center(child: CircularProgressIndicator(color: Colors.white));
    return GestureDetector(
      onTap: () => setState(() {
        paused = !paused;
        paused ? c.pause() : c.play();
      }),
      child: Stack(alignment: Alignment.center, children: [
        Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: ColorFiltered(colorFilter: ColorFilter.matrix(filterById(m['filter']?.toString()).m), child: VideoPlayer(c)))),
        if (paused) const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 90),
        Positioned(left: 0, right: 0, bottom: 0, child: VideoProgressIndicator(c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Color(0xFFC3AEF0)))),
      ]),
    );
  }
}
