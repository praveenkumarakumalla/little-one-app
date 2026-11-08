import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart' show openFiles, XTypeGroup;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../chat.dart';
import '../clay.dart';
import '../data.dart';
import '../filters.dart';
import 'camera.dart';
import '../store.dart';

const milestones = ['', 'First smile', 'First bath', 'Namakaranam', 'Barasala', 'Ashlesha shanti', 'Annaprasana', 'First tooth', 'First word', 'First steps', 'Aksharabhyasam', 'Birthday', 'Festival'];
const docTypes = ['', 'Birth certificate', 'Aadhaar', 'Hospital / discharge', 'Vaccination card', 'Prescription', 'Lab report', 'Insurance', 'Bank / savings', 'Jatakam', 'Other'];

/// 0 = photo, 1 = video, 2 = document (PDF etc.)
/// Small grid thumbnails (360 px) made once per photo, so the grid never decodes 12 MP originals again.
class Thumbs {
  static Directory? _dir;
  static final _have = <String, bool>{};
  static final _queue = <(String, String)>[];
  static bool _running = false;
  static final ready = ValueNotifier<int>(0);

  static File? get(String id, String path) {
    final d = _dir;
    if (d == null) {
      _init();
      return null;
    }
    final f = File('${d.path}/$id.png');
    final ok = _have[id] ??= f.existsSync();
    if (ok) return f;
    if (!_queue.any((q) => q.$1 == id)) {
      _queue.add((id, path));
      _run();
    }
    return null;
  }

  static Future<void> _init() async {
    if (_dir != null) return;
    final d = Directory('${(await getApplicationSupportDirectory()).path}/thumbs');
    if (!d.existsSync()) d.createSync(recursive: true);
    _dir = d;
    ready.value++;
  }

  static Future<void> _run() async {
    if (_running) return;
    _running = true;
    while (_queue.isNotEmpty) {
      final (id, path) = _queue.removeAt(0);
      try {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 360);
        final frame = await codec.getNextFrame();
        final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        frame.image.dispose();
        if (png != null) await File('${_dir!.path}/$id.png').writeAsBytes(png.buffer.asUint8List());
        _have[id] = png != null;
      } catch (_) {
        _have[id] = false; // keep using the original
      }
      if (_queue.isEmpty || _queue.length % 6 == 0) ready.value++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    _running = false;
  }
}

final _sizes = <String, int>{};

/// File sizes are cached – reading 100s of file sizes on every redraw made Memories laggy.
int fileSize(String p) => _sizes[p] ??= (() {
      try {
        return File(p).lengthSync();
      } catch (_) {
        return 0;
      }
    })();

int memKind(Map m) => m['doc'] == true ? 2 : m['video'] == true ? 1 : 0;
bool isVideo(String p) => RegExp(r'\.(mp4|mov|3gp|mkv|webm)$', caseSensitive: false).hasMatch(p);

/// Saves photos/videos to the phone's Gallery (album "Little One"). Returns how many were saved.
Future<int> saveToGallery(BuildContext context, List<Map<String, dynamic>> items) async {
  try {
    if (!await Gal.hasAccess(toAlbum: true)) await Gal.requestAccess(toAlbum: true);
  } catch (_) {}
  var n = 0;
  for (final m in items) {
    final p = m['path']?.toString();
    if (p == null || m['doc'] == true || !File(p).existsSync()) continue;
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
  int cat = 0; // 0 = photos, 1 = videos, 2 = documents

  /// Documents: PDFs (and scans/photos of papers) kept exactly as they are.
  Future<void> _addDocs(BuildContext context) async {
    final picked = await openFiles(acceptedTypeGroups: [const XTypeGroup(label: 'Documents', extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx'], mimeTypes: ['application/pdf', 'image/*', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])]);
    if (picked.isEmpty || !context.mounted) return;
    final cap = TextEditingController(text: picked.length == 1 ? picked.first.name.replaceAll(RegExp(r'\.[^.]+$'), '') : '');
    String tag = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('Add ${picked.length} document${picked.length > 1 ? 's' : ''}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: cap, decoration: const InputDecoration(labelText: 'Name', hintText: 'Birth certificate')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: tag,
              decoration: const InputDecoration(labelText: 'Type'),
              items: docTypes.map((m) => DropdownMenuItem(value: m, child: Text(m.isEmpty ? 'None' : m))).toList(),
              onChanged: (v) => set(() => tag = v ?? ''),
            ),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))],
        ),
      ),
    );
    if (ok != true) return;
    for (final x in picked) {
      final path = await Store.keepFile(x.path, 'documents');
      final name = cap.text.trim().isEmpty || picked.length > 1 ? x.name.replaceAll(RegExp(r'\.[^.]+$'), '') : cap.text.trim();
      await Store.i.addItem('memories', {'id': Store.newId(), 'path': path, 'video': false, 'doc': true, 'caption': name, 'tag': tag, 'date': ymd(DateTime.now())});
    }
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📄 ${picked.length} document${picked.length > 1 ? 's' : ''} saved')));
  }

  Future<void> _add(BuildContext context) async {
    if (cat == 2) return _addDocs(context);
    final picked = await ImagePicker().pickMultipleMedia(); // originals, 100% quality;
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
      listenable: Listenable.merge([Store.i, Chat.i, Thumbs.ready]),
      builder: (context, _) {
        final all = Store.i.list('memories')..sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
        final nPhotos = all.where((m) => memKind(m) == 0).length, nVideos = all.where((m) => memKind(m) == 1).length, nDocs = all.where((m) => memKind(m) == 2).length;
        final items = all.where((m) => memKind(m) == cat).toList();
        final groups = <String, List<Map<String, dynamic>>>{};
        for (final m in items) {
          groups.putIfAbsent((m['date'] ?? '').toString().substring(0, 7), () => []).add(m);
        }
        final chosen = items.where((m) => sel.contains(m['id'].toString())).toList();
        var photos = 0, videos = 0, docs = 0, bytes = 0;
        for (final m in all) {
          final p = m['path']?.toString();
          if (p == null) continue;
          switch (memKind(m)) {
            case 2:
              docs++;
            case 1:
              videos++;
            default:
              photos++;
          }
          try {
            bytes += fileSize(p);
          } catch (_) {}
        }
        if (sel.isNotEmpty) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(sel.clear)),
              title: Text(chosen.isEmpty ? 'Tap memories to select' : '${chosen.length} selected'),
              actions: [
                IconButton(tooltip: 'Select all', icon: const Icon(Icons.select_all), onPressed: () => setState(() => sel.addAll(items.where((m) => m['path'] != null).map((m) => m['id'].toString())))),
                if (cat != 2) IconButton(tooltip: 'Save to Gallery', icon: const Icon(Icons.download), onPressed: () async {
                  await saveToGallery(context, chosen);
                  if (mounted) setState(sel.clear);
                }),
                IconButton(tooltip: 'Share', icon: const Icon(Icons.share), onPressed: () => shareMemories(chosen)),
              ],
            ),
            body: cat == 2 ? ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: items.map((m) => _docTile(context, m)).toList()) : _grid(context, groups),
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
          floatingActionButton: FloatingActionButton.extended(onPressed: () => _add(context), icon: Icon(cat == 2 ? Icons.note_add : Icons.add_a_photo), label: Text(cat == 2 ? 'Add PDF' : 'Add')),
          body: items.isEmpty
              ? ListView(padding: const EdgeInsets.all(12), children: [
                  if (!Chat.i.paired) _connectBanner(context),
                  _cats(nPhotos, nVideos, nDocs),
                  Padding(padding: const EdgeInsets.all(32), child: Text(cat == 2 ? 'Keep her documents safe here – birth certificate, Aadhaar, hospital papers, vaccination card…\nTap "Add PDF".' : cat == 1 ? 'No videos yet. Tap Add to pick videos.' : 'Her first photos will live here, grouped by month. Tap Add.', textAlign: TextAlign.center)),
                ])
              : ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), children: [
                  if (!Chat.i.paired) _connectBanner(context),
                  _cats(nPhotos, nVideos, nDocs),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text('📸 $photos photos · 🎬 $videos videos · 📄 $docs docs · 💾 ${_mb(bytes)} on this phone\n${cat == 2 ? 'Tap to open · long-press to select' : 'Tap to watch like reels · long-press to select'}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  ),
                  if (cat == 2) const SizedBox(height: 8),
                  if (cat == 2) ...items.map((m) => _docTile(context, m)) else ..._sections(context, groups),
                ]),
        );
      },
    );
  }

  Widget _cats(int nPhotos, int nVideos, int nDocs) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          for (final c in [(0, '📸 Photos', nPhotos), (1, '🎬 Videos', nVideos), (2, '📄 Docs', nDocs)]) ...[
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
            if (c.$1 < 2) const SizedBox(width: 8),
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
          color: const Color(0xFFFFDDE8),
          color2: const Color(0xFFD6F2E6),
          onTap: () => _syncInfo(context),
          child: const Row(children: [
            Text('👨‍👩‍👧', style: TextStyle(fontSize: 30)),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Connect family gallery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF4A3442))),
                Text('One time: enter your family code. Then everyone\'s memories appear on every family phone.', style: TextStyle(fontSize: 12, color: Color(0xFF4A3442))),
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

  Widget _docTile(BuildContext context, Map<String, dynamic> m) {
    final id = m['id'].toString(), picked = sel.contains(id);
    final p = m['path']?.toString();
    final ext = (p ?? m['fname'] ?? '').toString().split('.').last.toLowerCase();
    var size = '';
    try {
      if (p != null) size = _mb(fileSize(p));
    } catch (_) {}
    final sub = [if ((m['tag'] ?? '').toString().isNotEmpty) m['tag'], m['date'] ?? '', if (size.isNotEmpty) size, if (m['from'] != null) '👤 ${m['from']}'].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: picked ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          leading: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: ext == 'pdf' ? const Color(0xFFFFE1E1) : const Color(0xFFFFE2EC), borderRadius: BorderRadius.circular(12)),
            child: p == null
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(ext == 'pdf' ? '📕' : ext.startsWith('doc') ? '📘' : '🖼️', style: const TextStyle(fontSize: 24)),
          ),
          title: Text((m['caption'] ?? '').toString().isEmpty ? (m['fname'] ?? 'Document').toString() : m['caption'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(p == null ? 'From ${m['from'] ?? 'family'} · tap to download' : sub, style: const TextStyle(fontSize: 12)),
          trailing: picked
              ? const Icon(Icons.check_circle)
              : p == null
                  ? null
                  : PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'share') await shareMemories([m]);
                        if (v == 'del' && context.mounted) {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              title: const Text('Delete this document?'),
                              content: const Text('It is removed from this phone. The copy in Google Drive stays.'),
                              actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete'))],
                            ),
                          );
                          if (yes == true) {
                            await Store.i.removeItem('memories', id);
                            try {
                              File(p).deleteSync();
                            } catch (_) {}
                          }
                        }
                      },
                      itemBuilder: (_) => const [PopupMenuItem(value: 'share', child: Text('📤 Share')), PopupMenuItem(value: 'del', child: Text('🗑️ Delete'))],
                    ),
          onLongPress: p == null ? null : () => setState(() => sel..remove('_')..add(id)),
          onTap: () async {
            if (p == null) {
              await Chat.i.downloadMemory(id);
              return;
            }
            if (sel.isNotEmpty) {
              setState(() {
                sel.remove('_');
                picked ? sel.remove(id) : sel.add(id);
              });
              return;
            }
            final r = await OpenFilex.open(p);
            if (r.type != ResultType.done && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No app to open this file – install a PDF viewer or use Share')));
            }
          },
        ),
      ),
    );
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
        final list = Store.i.list('memories').where((x) => x['path'] != null && memKind(x) == cat).toList()
          ..sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
        final at = list.indexWhere((x) => x['id'] == m['id']);
        Navigator.push(context, MaterialPageRoute(builder: (_) => ReelsPage(items: list, start: at < 0 ? 0 : at)));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(fit: StackFit.expand, children: [
          m['video'] == true
              ? Container(color: Colors.black87, child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 40))
              : Image.file(Thumbs.get(m['id'].toString(), path) ?? File(path), fit: BoxFit.cover, cacheWidth: 360, gaplessPlayback: true, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
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
                child: Container(width: 58, height: 58, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFFFF2F6), borderRadius: BorderRadius.circular(18)), child: Text(e, style: const TextStyle(fontSize: 32))),
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
      // originals can be 12+ MP – decode only at screen resolution so swiping stays smooth
      final mq = MediaQuery.of(context);
      final w = (mq.size.width * mq.devicePixelRatio).round().clamp(720, 1600);
      return Image.file(File(m['path'].toString()), fit: BoxFit.contain, cacheWidth: w, gaplessPlayback: true, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 60)));
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
        Positioned(left: 0, right: 0, bottom: 0, child: VideoProgressIndicator(c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Color(0xFFFFC9AE)))),
      ]),
    );
  }
}
