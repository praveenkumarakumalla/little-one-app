import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'data.dart';
import 'pages/cries.dart';
import 'store.dart';
import 'voice.dart';

/// Listens to the room: loud voices → "బేబీ బజ్జో ఉంది, అరవకండి"; her cry → likely reason + lullaby.
class SleepWatch extends ChangeNotifier {
  SleepWatch._();
  static final SleepWatch i = SleepWatch._();
  static const sr = 16000;

  final AudioRecorder _rec = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  bool on = false;
  double level = 0; // 0..1 for the meter
  String state = 'Off';
  double? _base;
  final List<double> _calib = [];
  final List<List<bool>> _frames = []; // [loud, cry]
  final List<double> _pending = [];
  DateTime _muteUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastShh = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastCry = DateTime.fromMillisecondsSinceEpoch(0);
  final List<String> log = [];

  Future<String?> start() async {
    final p = await Permission.microphone.request();
    if (!p.isGranted) return 'Allow the microphone so the app can listen.';
    final stream = await _rec.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: sr, numChannels: 1));
    _base = null;
    _calib.clear();
    _frames.clear();
    _pending.clear();
    on = true;
    state = 'Learning how quiet the room is… stay quiet 4 seconds';
    _sub = stream.listen(_onChunk);
    await WakelockPlus.enable();
    _log('Sleep watch started');
    notifyListeners();
    return null;
  }

  Future<void> stop() async {
    on = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _rec.stop();
    } catch (_) {}
    await WakelockPlus.disable();
    level = 0;
    state = 'Off';
    _log('Sleep watch stopped');
    notifyListeners();
  }

  void _log(String t) {
    log.insert(0, '${hm(DateTime.now())}  $t');
    if (log.length > 8) log.removeLast();
  }

  void _onChunk(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      _pending.add(bd.getInt16(i, Endian.little) / 32768.0);
    }
    const frame = sr ~/ 5; // 200 ms
    while (_pending.length >= frame) {
      final f = _pending.sublist(0, frame);
      _pending.removeRange(0, frame);
      _analyze(f);
    }
  }

  static List<double> pitchOf(List<double> b) {
    final n = math.min(b.length, 2048);
    var rms = 0.0;
    for (var i = 0; i < n; i++) {
      rms += b[i] * b[i];
    }
    rms = math.sqrt(rms / n);
    if (rms < 0.004) return [0, 0];
    final minLag = sr ~/ 900, maxLag = sr ~/ 80;
    final r = List<double>.filled(maxLag + 2, 0);
    var e0 = 0.0, best = -1.0;
    final m = n - maxLag - 1;
    for (var i = 0; i < m; i++) {
      e0 += b[i] * b[i];
    }
    for (var lag = minLag; lag <= maxLag + 1; lag++) {
      var c = 0.0, e1 = 0.0;
      for (var i = 0; i < m; i++) {
        c += b[i] * b[i + lag];
        e1 += b[i + lag] * b[i + lag];
      }
      r[lag] = c / math.sqrt(e0 * e1 + 1e-12);
      if (lag <= maxLag && r[lag] > best) best = r[lag];
    }
    if (best <= 0) return [0, 0];
    for (var lag = minLag + 1; lag <= maxLag; lag++) {
      if (r[lag] >= 0.88 * best && r[lag] >= r[lag - 1] && r[lag] >= r[lag + 1]) return [sr / lag, r[lag]];
    }
    return [0, 0];
  }

  void _analyze(List<double> f) {
    var rms = 0.0;
    for (final x in f) {
      rms += x * x;
    }
    rms = math.sqrt(rms / f.length);
    final db = 20 * math.log(rms + 1e-9) / math.ln10;
    final sens = (Store.i.settings['sens'] as num?)?.toDouble() ?? 18;
    if (_base == null) {
      _calib.add(db);
      level = 0;
      if (_calib.length >= 20) {
        final s = [..._calib]..sort();
        _base = s[s.length ~/ 2];
        state = 'Listening… room is quiet';
      }
      notifyListeners();
      return;
    }
    final base = _base!;
    level = ((db - base) / (sens * 1.8)).clamp(0.0, 1.0);
    final now = DateTime.now();
    if (now.isBefore(_muteUntil) || Voice.i.speaking || Voice.i.musicOn) {
      state = 'Paused while the app plays sound';
      _frames.clear();
      notifyListeners();
      return;
    }
    final loud = db > base + sens;
    if (!loud) _base = base * 0.995 + db * 0.005;
    final pc = loud ? pitchOf(f) : [0.0, 0.0];
    final cry = loud && pc[0] >= 350 && pc[0] <= 900 && pc[1] > 0.55;
    _frames.add([loud, cry]);
    if (_frames.length > 15) _frames.removeAt(0);
    state = cry ? 'Hearing a baby cry…' : loud ? 'Hearing loud sound…' : 'Listening… room is quiet';
    notifyListeners();
    if (_frames.length < 15) return;
    final nLoud = _frames.where((x) => x[0]).length, nCry = _frames.where((x) => x[1]).length;
    final st = Store.i.settings;
    if (nCry >= 8 && st['wCry'] != false && now.difference(_lastCry).inSeconds > 120) {
      _lastCry = now;
      _onCry();
    } else if (nLoud >= 11 && nCry < 5 && st['wShh'] != false && now.difference(_lastShh).inSeconds > 45) {
      _lastShh = now;
      _onLoud();
    }
  }

  Future<void> _onLoud() async {
    _muteUntil = DateTime.now().add(const Duration(seconds: 8));
    _frames.clear();
    _log('Loud voices → said బేబీ బజ్జో ఉంది');
    notifyListeners();
    await Voice.i.shh();
  }

  Future<void> _onCry() async {
    final top = cryReasons().first;
    unawaited(Store.i.addCry('auto', top.key));
    _muteUntil = DateTime.now().add(const Duration(seconds: 12));
    _frames.clear();
    _log('She cried → ${top.te} (${top.en})');
    notifyListeners();
    await Voice.i.say('పాప ఏడుస్తోంది. ${top.say}');
    if (Store.i.settings['wLull'] != false && !Voice.i.musicOn) {
      await Voice.i.playMusicBox();
      _log('Started the lullaby');
      Timer(const Duration(minutes: 15), () => Voice.i.stopMusic());
      notifyListeners();
    }
  }
}

class WatchPage extends StatelessWidget {
  const WatchPage({super.key});
  @override
  Widget build(BuildContext context) {
    final w = SleepWatch.i, s = Store.i;
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([w, s]),
      builder: (context, _) {
        final st = s.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('నిద్ర కాపలా · Sleep watch')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(w.on ? Icons.hearing : Icons.hearing_disabled, color: w.on ? Colors.teal : cs.outline),
                    const SizedBox(width: 10),
                    Expanded(child: Text(w.state, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                  ]),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: w.level, minHeight: 14, color: w.level > 0.55 ? cs.primary : Colors.teal, backgroundColor: cs.surfaceContainerHighest),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                      icon: Icon(w.on ? Icons.stop : Icons.play_arrow),
                      label: Text(w.on ? 'Stop listening' : 'Start listening', style: const TextStyle(fontSize: 17)),
                      onPressed: () async {
                        if (w.on) {
                          await w.stop();
                        } else {
                          final err = await w.start();
                          if (err != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        }
                      },
                    ),
                  ),
                ]),
              ),
            ),
            SwitchListTile(value: st['wShh'] != false, onChanged: (v) => s.setSetting('wShh', v), title: const Text('Loud voices → say "బేబీ బజ్జో ఉంది, అరవకండి"')),
            SwitchListTile(value: st['wCry'] != false, onChanged: (v) => s.setSetting('wCry', v), title: const Text('She cries → say the likely reason')),
            SwitchListTile(value: st['wLull'] != false, onChanged: (v) => s.setSetting('wLull', v), title: const Text('…then play the jola paata')),
            const SizedBox(height: 8),
            Text('How loud before it reacts', style: Theme.of(context).textTheme.titleSmall),
            Slider(value: ((st['sens'] as num?)?.toDouble() ?? 18).clamp(8, 30), min: 8, max: 30, divisions: 22, onChanged: (v) => s.setSetting('sens', v)),
            const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('softer sounds', style: TextStyle(fontSize: 12)), Text('only very loud', style: TextStyle(fontSize: 12))]),
            const SizedBox(height: 16),
            if (w.log.isNotEmpty) Text('What happened', style: Theme.of(context).textTheme.titleSmall),
            ...w.log.map((l) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(l))),
            if (s.openCry != null)
              Card(
                color: cs.primaryContainer,
                child: ListTile(
                  leading: const Text('😢', style: TextStyle(fontSize: 26)),
                  title: Text('She cried at ${hm(DateTime.fromMillisecondsSinceEpoch((s.openCry!['at'] as num).toInt()))}'),
                  subtitle: const Text('Tap to tell what calmed her'),
                  onTap: () => askWhatCalmed(context, s.openCry!['id'].toString()),
                ),
              ),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CryHistoryPage())), icon: const Icon(Icons.insights), label: const Text('Cry tracker · every cry & pattern')),
            const SizedBox(height: 16),
            Text('Keep this screen open near her, on the charger. The screen stays on while listening.', style: TextStyle(color: cs.outline)),
          ]),
        );
      },
    );
  }
}
