import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import '../clay.dart';

import '../chat.dart';
import '../data.dart';
import '../store.dart';
import '../watch.dart';

/// Record her coos, giggles and first words — kept forever with the date and her age.
class VoicesPage extends StatefulWidget {
  const VoicesPage({super.key});
  @override
  State<VoicesPage> createState() => _VoicesPageState();
}

class _VoicesPageState extends State<VoicesPage> {
  final _rec = AudioRecorder();
  final _player = AudioPlayer();
  bool recording = false;
  DateTime? start;
  Timer? tick;
  StreamSubscription<Amplitude>? ampSub;
  final List<double> bars = [];
  String? playingId;
  Duration pos = Duration.zero, total = Duration.zero;
  bool _watchWasOn = false;

  static const titles = ['🥰 Cooing', '😂 Giggles', '🗣️ Baby talk', '💕 First "Amma"?', '😢 Little cry', '🤧 Sneeze', '😴 Sleepy sounds', '🎵 Singing to her'];

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => pos = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => total = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => playingId = null);
    });
  }

  @override
  void dispose() {
    tick?.cancel();
    ampSub?.cancel();
    _rec.dispose();
    _player.dispose();
    if (_watchWasOn) SleepWatch.i.start();
    super.dispose();
  }

  Future<void> _start() async {
    if (!(await Permission.microphone.request()).isGranted) return;
    if (SleepWatch.i.on) {
      _watchWasOn = true;
      await SleepWatch.i.stop(remember: false);
    }
    await _player.stop();
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/voices');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final path = '${dir.path}/${Store.newId()}.m4a';
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100, numChannels: 1), path: path);
    HapticFeedback.heavyImpact();
    bars.clear();
    ampSub = _rec.onAmplitudeChanged(const Duration(milliseconds: 90)).listen((a) {
      final v = ((a.current + 50) / 50).clamp(0.04, 1.0);
      setState(() {
        bars.add(v);
        if (bars.length > 60) bars.removeAt(0);
      });
    });
    start = DateTime.now();
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      if (DateTime.now().difference(start!).inMinutes >= 10) _stop();
    });
    setState(() => recording = true);
  }

  Future<void> _stop() async {
    tick?.cancel();
    await ampSub?.cancel();
    final path = await _rec.stop();
    final secs = DateTime.now().difference(start ?? DateTime.now()).inSeconds;
    setState(() => recording = false);
    HapticFeedback.mediumImpact();
    if (path == null || !mounted) return;
    final name = await _askName(context);
    if (name == null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
      return;
    }
    final b = Store.i.birth;
    await Store.i.addItem('voices', {
      'id': Store.newId(),
      'path': path,
      'title': name,
      'at': DateTime.now().millisecondsSinceEpoch,
      'secs': secs,
      'day': b == null ? null : dayNumber(b),
    });
    if (_watchWasOn) {
      _watchWasOn = false;
      await SleepWatch.i.start();
    }
  }

  Future<String?> _askName(BuildContext context) {
    final t = TextEditingController(text: titles.first);
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Save this voice 🎙️'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: t, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: titles.map((x) => ActionChip(label: Text(x), onPressed: () => set(() => t.text = x))).toList()),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Delete')),
            FilledButton(onPressed: () => Navigator.pop(d, t.text.trim().isEmpty ? titles.first : t.text.trim()), child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Future<void> _play(Map<String, dynamic> v) async {
    if (playingId == v['id']) {
      await _player.stop();
      setState(() => playingId = null);
      return;
    }
    await _player.stop();
    setState(() {
      playingId = v['id'].toString();
      pos = Duration.zero;
      total = Duration.zero;
    });
    await _player.play(DeviceFileSource(v['path'].toString()));
  }

  String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final list = Store.i.list('voices').reversed.toList();
        final el = start == null ? 0 : DateTime.now().difference(start!).inSeconds;
        return Scaffold(
          appBar: AppBar(title: const Text('పాప మాటలు · Baby voices')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(colors: recording ? [const Color(0xFFFF9EB5), const Color(0xFFFFC4A3)] : [const Color(0xFFE9E0FF), const Color(0xFFDDEEFF)]),
              ),
              child: Column(children: [
                SizedBox(
                  height: 70,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: (recording ? bars : List.filled(30, 0.08))
                        .map((v) => AnimatedContainer(
                              duration: const Duration(milliseconds: 90),
                              width: 4,
                              height: 6 + 64 * v,
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              decoration: BoxDecoration(color: const Color(0xFF4A2338).withValues(alpha: 0.75), borderRadius: BorderRadius.circular(3)),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(recording ? _mmss(el) : 'Hold the phone close to her', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF3A2A35))),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: recording ? _stop : _start,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: recording ? Colors.white : const Color(0xFFF2668B),
                      boxShadow: [BoxShadow(color: const Color(0xFFF2668B).withValues(alpha: 0.5), blurRadius: recording ? 30 : 16)],
                    ),
                    child: Icon(recording ? Icons.stop_rounded : Icons.mic, size: 48, color: recording ? const Color(0xFFF2668B) : Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(recording ? 'Tap to stop' : 'Tap to record', style: const TextStyle(color: Color(0xFF3A2A35))),
              ]),
            ),
            const SizedBox(height: 18),
            if (list.isEmpty)
              Padding(padding: const EdgeInsets.all(20), child: Text('Her coos, giggles and first words will be saved here forever, with the date and her age. 💕', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant))),
            ...list.map((v) {
              final at = DateTime.fromMillisecondsSinceEpoch((v['at'] as num).toInt());
              final on = playingId == v['id'];
              final secs = (v['secs'] as num?)?.toInt() ?? 0;
              return ClayCard(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                  child: Column(children: [
                    Row(children: [
                      IconButton.filledTonal(iconSize: 30, onPressed: () => _play(v), icon: Icon(on ? Icons.stop_rounded : Icons.play_arrow_rounded)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(v['title'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          Text('${dmy(at)} ${hm(at)} · ${_mmss(secs)}${v['day'] != null ? ' · Day ${v['day']}' : ''}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ]),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (a) async {
                          if (a == 'share') await Share.shareXFiles([XFile(v['path'].toString())], text: '${v['title']} 🎙️ ${Store.i.babyName}');
                          if (a == 'chat') {
                            if (!Chat.i.paired) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join the family chat first (Chat tab)')));
                            } else {
                              await Chat.i.sendFile(v['path'].toString(), caption: '🎙️ ${v['title']}');
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent to the family chat 💬')));
                            }
                          }
                          if (a == 'del') {
                            await Store.i.removeItem('voices', v['id'].toString());
                            try {
                              File(v['path'].toString()).deleteSync();
                            } catch (_) {}
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'chat', child: Text('💬 Send to family chat')),
                          PopupMenuItem(value: 'share', child: Text('📤 Share')),
                          PopupMenuItem(value: 'del', child: Text('🗑️ Delete')),
                        ],
                      ),
                    ]),
                    if (on)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                        child: LinearProgressIndicator(value: total.inMilliseconds == 0 ? null : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0), borderRadius: BorderRadius.circular(4)),
                      ),
                  ]),
                ),
              );
            }),
          ]),
        );
      },
    );
  }
}
