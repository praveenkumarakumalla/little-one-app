import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'chat.dart';
import 'cry_ml.dart';

import 'clay.dart';

import 'bg.dart';
import 'cry_sound.dart';
import 'data.dart';
import 'feed_alarm.dart';
import 'pages/cries.dart';
import 'store.dart';
import 'voice.dart';

/// One crying spell, from the first cry until she is calm.
class CryEpisode {
  final DateTime start = DateTime.now();
  String id = '';
  int phase = 0; // 0 = listening to the cry for a few seconds, 1 = helping parents
  int frames = 0;
  DateTime lastCry = DateTime.now();
  DateTime lastPrompt = DateTime.now();
  int prompts = 0;
  int next = 1; // which reason to suggest next
  List<CryReason> reasons = [];
  CrySound? sound;
  String? tried; // what the parents said they are doing
  bool warned = false;
  bool alerted = false; // told the family phones
  int get mins => DateTime.now().difference(start).inMinutes;
}

/// Listens to the room — also in the background with the screen off.
/// Loud voices → "బేబీ బజ్జో ఉంది, అరవకండి". Her cry → listens to its rhythm, says the likely
/// reason out loud, keeps helping until she is calm, and saves it in the cry tracker.
class SleepWatch extends ChangeNotifier {
  SleepWatch._();
  static final SleepWatch i = SleepWatch._();
  static const sr = 16000;
  static const frameLen = sr ~/ 10; // 100 ms

  final AudioRecorder _rec = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  bool on = false;
  bool bgOk = false;
  double level = 0;
  String state = 'Off';
  double? _base;
  final List<double> _calib = [];
  final List<Fr> hist = [];
  final List<double> _pending = [];
  DateTime _muteUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastShh = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _epEnded = DateTime.fromMillisecondsSinceEpoch(0);
  CryEpisode? ep;
  final List<String> log = [];

  Future<String?> start() async {
    if (on) return null;
    final p = await Permission.microphone.request();
    if (!p.isGranted) return 'Allow the microphone so the app can listen.';
    await Permission.notification.request();
    unawaited(CryML.i.init());
    bgOk = await Bg.start('🎧 Little One is listening', 'Sleep watch is on. It will speak if she cries.');
    final stream = await _rec.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: sr, numChannels: 1, autoGain: false, echoCancel: false, noiseSuppress: false));
    _base = null;
    _calib.clear();
    hist.clear();
    _pending.clear();
    ep = null;
    on = true;
    state = 'Learning how quiet the room is… stay quiet 4 seconds';
    _sub = stream.listen(_onChunk, onError: (_) {}, onDone: () {
      if (on) stop(remember: false);
    });
    await Store.i.setSetting('autoWatch', true);
    // so Android doesn't stop the listening when the screen is locked
    if (Store.i.settings['askedBattery'] != true) {
      await Store.i.setSetting('askedBattery', true);
      unawaited(Bg.askBattery());
    }
    _log(bgOk ? 'Listening started (works with the screen off)' : 'Listening started (keep the app open)');
    notifyListeners();
    return null;
  }

  Future<void> stop({bool remember = true}) async {
    on = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _rec.stop();
    } catch (_) {}
    await Bg.stop();
    if (ep != null) await _calm(manual: true, quiet: true);
    level = 0;
    state = 'Off';
    if (remember) await Store.i.setSetting('autoWatch', false);
    _log('Listening stopped');
    notifyListeners();
  }

  void _log(String t) {
    log.insert(0, '${hm(DateTime.now())}  $t');
    if (log.length > 12) log.removeLast();
  }

  void _onChunk(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      _pending.add(bd.getInt16(i, Endian.little) / 32768.0);
    }
    while (_pending.length >= frameLen) {
      final f = _pending.sublist(0, frameLen);
      _pending.removeRange(0, frameLen);
      _analyze(f);
    }
  }

  static List<double> pitchOf(List<double> b) {
    final n = b.length;
    var rms = 0.0;
    for (var i = 0; i < n; i++) {
      rms += b[i] * b[i];
    }
    rms = math.sqrt(rms / n);
    if (rms < 0.004) return [0, 0];
    final minLag = sr ~/ 1000, maxLag = sr ~/ 150;
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

  int _n = 0;
  final List<double> _quietDb = []; // recent levels of the room when nobody is crying
  final List<double> _mlHist = []; // AI cry score, every half second
  void _analyze(List<double> f) {
    CryML.i.add(f);
    if (++_n % 5 == 0) {
      unawaited(CryML.i.run().then((_) {
        if (CryML.i.ready) {
          _mlHist.add(CryML.i.cry);
          if (_mlHist.length > 12) _mlHist.removeAt(0);
        }
      }));
    }
    var rms = 0.0;
    for (final x in f) {
      rms += x * x;
    }
    rms = math.sqrt(rms / f.length);
    final db = 20 * math.log(rms + 1e-9) / math.ln10;
    final sens = ((Store.i.settings['sens'] as num?)?.toDouble() ?? 12).clamp(6, 14).toDouble();
    if (_base == null) {
      _calib.add(db);
      level = 0;
      if (_calib.length >= 30) {
        final s = [..._calib]..sort();
        _base = s[s.length ~/ 4];
        state = 'Listening… room is quiet';
      }
      notifyListeners();
      return;
    }
    final ml = CryML.i;
    final mlCry = ml.ready && ml.cry >= 0.12;
    // room level = a low percentile of the last ~20 s when nobody cries (doesn't creep up while she cries)
    if (!mlCry && ep == null) {
      _quietDb.add(db);
      if (_quietDb.length > 200) _quietDb.removeAt(0);
      if (_quietDb.length >= 20 && _n % 10 == 0) {
        final q = [..._quietDb]..sort();
        _base = q[(q.length * 0.2).floor()];
      }
    }
    final base = _base!;
    level = ((db - base) / (sens * 1.8)).clamp(0.0, 1.0);
    final now = DateTime.now();
    if (now.isBefore(_muteUntil) || Voice.i.speaking) {
      // the app itself is talking — don't listen to ourselves
      if (ep != null) ep!.lastCry = ep!.lastCry.add(const Duration(milliseconds: 100));
      state = 'Paused while the app speaks';
      notifyListeners();
      return;
    }
    final loud = db > base + sens;
    final pc = db > base + 4 ? pitchOf(f) : [0.0, 0.0];
    final bool cry;
    if (ml.ready) {
      // the AI decides whether it is really a baby crying (not TV, talking, music, the cooker…)
      cry = mlCry && db > base + 3;
    } else {
      cry = loud && pc[0] >= 300 && pc[0] <= 1000 && pc[1] > 0.5;
    }
    // for the rhythm analysis a "loud" slice = a crying slice (the AI knows better than the level)
    hist.add(Fr(db - base, ml.ready ? (cry || loud) : loud, pc[0], pc[1], cry));
    if (hist.length > 200) hist.removeAt(0);

    if (ep != null) {
      _episodeFrame(cry, now, sens);
      return;
    }
    state = cry
        ? 'Hearing a baby cry…${ml.ready ? ' (AI ${(ml.cry * 100).round()}%)' : ''}'
        : loud
            ? (ml.ready && ml.speech > 0.4 ? 'Hearing people talk – not a cry' : 'Hearing sound – not a cry')
            : 'Listening… room is quiet${ml.ready ? ' · AI on' : ''}';
    notifyListeners();
    final st = Store.i.settings;
    if (st['wCry'] == false || now.difference(_epEnded).inSeconds < 20) return;
    // ~3 seconds of crying → start helping straight away
    bool start;
    if (ml.ready) {
      final last6 = _mlHist.length > 6 ? _mlHist.sublist(_mlHist.length - 6) : _mlHist;
      start = last6.where((x) => x >= 0.12).length >= 2 && last6.isNotEmpty && last6.last >= 0.12;
    } else {
      if (hist.length < 30) return;
      final last = hist.sublist(hist.length - 30);
      start = last.where((x) => x.cry).length >= 10;
    }
    if (start) {
      ep = CryEpisode();
      state = 'She is crying — finding out why…';
      _log('Heard her cry${ml.ready ? ' (AI ${(ml.cry * 100).round()}%)' : ''}');
      notifyListeners();
      unawaited(_firstPrompt(sens));
      return;
    }
    if (hist.length >= 30) {
      final last = hist.sublist(hist.length - 30);
      final nLoud = last.where((x) => x.loud).length;
      final anyCry = ml.ready ? (_mlHist.isNotEmpty && _mlHist.reduce(math.max) > 0.06) : last.where((x) => x.cry).length >= 8;
      if (nLoud >= 22 && !anyCry && st['wShh'] != false && now.difference(_lastShh).inSeconds > 45) {
        _lastShh = now;
        _onLoud();
      }
    }
  }

  void _episodeFrame(bool cry, DateTime now, double sens) {
    final e = ep!;
    if (cry) e.lastCry = now;
    final quiet = now.difference(e.lastCry).inSeconds;
    if (e.phase == 0) {
      state = 'She is crying — finding out why…';
      notifyListeners();
      return;
    }
    state = quiet < 10 ? 'Crying · ${e.mins} min' : 'Quiet for $quiet s…';
    notifyListeners();
    // after a minute of crying, tell the other family phones (spoken out loud there)
    if (!e.alerted && quiet < 10 && now.difference(e.start).inSeconds >= 60 && Store.i.settings['alertFamily'] != false && Chat.i.paired) {
      e.alerted = true;
      final r = e.reasons.isNotEmpty ? e.reasons.first : null;
      unawaited(Chat.i.send('${Store.i.babyName} ఏడుస్తోంది!${r != null ? ' ${r.te} కావొచ్చు.' : ''} ఎవరైనా చూడండి.', kind: 'say'));
      _log('Told the family phones');
    }
    if (quiet >= 45) {
      unawaited(_calm());
    } else if (quiet < 15 && now.difference(e.lastPrompt).inSeconds >= 120) {
      unawaited(_followUp());
    } else if (e.mins >= 20 && !e.warned && quiet < 15) {
      e.warned = true;
      unawaited(_speakClips(['w_20min'], 'పాప ఇరవై నిమిషాలుగా ఏడుస్తోంది. జ్వరం ఉందేమో చూడండి. ఎంత చేసినా ఆగకపోతే, డాక్టర్‌కి ఫోన్ చేయండి.'));
    } else if (e.mins >= 90) {
      unawaited(_calm(manual: true, quiet: true));
    }
  }

  Future<void> _speakClips(List<String> keys, String t, {double volume = 1.0}) async {
    _muteUntil = DateTime.now().add(const Duration(seconds: 3));
    await Voice.i.sayClips(keys, t, volume: volume);
    _muteUntil = DateTime.now().add(const Duration(milliseconds: 1200));
  }

  Future<void> _speak(String t, {double volume = 1.0}) async {
    _muteUntil = DateTime.now().add(const Duration(seconds: 3));
    await Voice.i.say(t, volume: volume);
    _muteUntil = DateTime.now().add(const Duration(milliseconds: 1200));
  }

  Future<void> _firstPrompt(double sens) async {
    final e = ep;
    if (e == null || e.phase != 0) return;
    e.phase = 1;
    e.lastPrompt = DateTime.now();
    final win = hist.length > 60 ? hist.sublist(hist.length - 60) : List<Fr>.from(hist);
    e.sound = analyseCry(win, sens);
    e.reasons = cryReasons(sound: e.sound);
    final top = e.reasons.first;
    e.id = await Store.i.addCry('auto', top.key, extra: {'sound': e.sound!.toJson()});
    _log('Cry: ${e.sound!.en}');
    _log('Likely: ${top.en}');
    await Bg.update('😢 She is crying · ${hm(e.start)}', 'Likely ${top.en.toLowerCase()} — ${top.todo}');
    notifyListeners();
    final soundTe = e.sound!.kind == 'mixed' ? '' : '${e.sound!.te} ';
    await _speakClips(['p_crying', if (e.sound!.kind != 'mixed') 's_${e.sound!.kind}', top.clip], 'పాప ఏడుస్తోంది. $soundTe${top.say}');
  }

  Future<void> _followUp() async {
    final e = ep;
    if (e == null) return;
    e.lastPrompt = DateTime.now();
    e.prompts++;
    String t;
    var keys = <String>[];
    if (e.prompts >= 3) {
      keys = ['w_soothe'];
      t = 'ఇంకా ఏడుస్తోంది. ఎత్తుకుని, భుజం మీద వేసుకుని, నెమ్మదిగా ఊపుతూ, చెవి దగ్గర ష్ ష్ అనండి. వెచ్చగా చుట్టి పట్టుకోండి.';
      _log('Still crying ${e.mins} min → soothing tips');
    } else {
      while (e.next < e.reasons.length && e.reasons[e.next].key == e.tried) {
        e.next++;
      }
      final r = e.reasons[e.next.clamp(0, e.reasons.length - 1)];
      e.next++;
      keys = ['p_still', r.clip];
      t = 'ఇంకా ఏడుస్తోంది. ఇప్పుడు ఇది చూడండి: ${r.say}';
      _log('Still crying ${e.mins} min → try ${r.en.toLowerCase()}');
      await Bg.update('😢 Still crying · ${e.mins} min', 'Try: ${r.en} — ${r.todo}');
    }
    notifyListeners();
    await _speakClips(keys, t);
  }

  /// Parents tell the app what they're doing right now.
  Future<void> trying(String key) async {
    final e = ep;
    if (e == null) return;
    e.tried = key;
    e.lastPrompt = DateTime.now(); // give them 4 minutes before the next suggestion
    if (key == 'hungry') {
      await Store.i.addTime('feeds');
      await FeedAlarm.reschedule();
    }
    if (key == 'nappy') await Store.i.addTime('nappies');
    if (e.id.isNotEmpty) await Store.i.updateCry(e.id, {'tried': key});
    _log('You: ${actualOf(key)[3]}');
    notifyListeners();
    _muteUntil = DateTime.now().add(const Duration(seconds: 3));
    if (!await Voice.i.clip('ok')) await _speak('సరే అమ్మా.');
  }

  Future<void> playLullaby() async {
    await Voice.i.playMusicBox();
    _log('Playing the jola paata for 4 minutes');
    notifyListeners();
    Timer(const Duration(minutes: 4), () async {
      await Voice.i.stopMusic();
      notifyListeners();
    });
  }

  Future<void> _calm({bool manual = false, bool quiet = false}) async {
    final e = ep;
    if (e == null) return;
    ep = null;
    _epEnded = DateTime.now();
    final calmAt = manual ? DateTime.now() : e.lastCry;
    final mins = calmAt.difference(e.start).inMinutes;
    if (e.id.isNotEmpty) {
      await Store.i.updateCry(e.id, {'calmAt': calmAt.millisecondsSinceEpoch, if (e.tried != null) 'actual': e.tried});
    }
    _log('She calmed down after ${mins < 1 ? 'less than a minute' : '$mins min'}${e.tried != null ? ' (${actualOf(e.tried!)[3].toLowerCase()})' : ''}');
    if (on) await Bg.update('🎧 Little One is listening', e.tried == null && e.id.isNotEmpty ? 'She cried at ${hm(e.start)} and calmed down. Open to tell what worked.' : 'Sleep watch is on. It will speak if she cries.');
    state = 'Listening… room is quiet';
    notifyListeners();
    if (!quiet && e.phase == 1) {
      _muteUntil = DateTime.now().add(const Duration(seconds: 4));
      if (!await Voice.i.clip('calm', volume: 0.45)) await _speak('పాప సర్దుకుంది. బాగా చేశారు!', volume: 0.45);
    }
  }

  Future<void> calmNow() => _calm(manual: true);

  Future<void> _onLoud() async {
    _muteUntil = DateTime.now().add(const Duration(seconds: 8));
    _log('Loud voices → said బేబీ బజ్జో ఉంది');
    notifyListeners();
    await Voice.i.shh();
  }
}

/// Live card shown while she is crying — on Home and on the Sleep watch screen.
class CryLiveCard extends StatelessWidget {
  const CryLiveCard({super.key});
  @override
  Widget build(BuildContext context) {
    final w = SleepWatch.i;
    return ListenableBuilder(
      listenable: w,
      builder: (context, _) {
        final e = w.ep;
        if (e == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final top = e.reasons.isEmpty ? null : e.reasons.first;
        const acts = [['hungry', '🍼 పాలు పడుతున్నా'], ['burp', '🫧 తేన్పు'], ['nappy', '🧷 డైపర్ మార్చా'], ['cuddle', '🤗 ఎత్తుకున్నా'], ['sleep', '😴 నిద్ర పుచ్చుతున్నా']];
        return ClayCard(
          color: cs.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('😢', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 10),
                Expanded(child: Text(e.phase == 0 ? 'She is crying… listening to her cry' : 'Crying since ${hm(e.start)} · ${e.mins} min', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              ]),
              if (e.sound != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('🔊 ${e.sound!.en}')),
              if (top != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Likely: ${top.te} · ${top.en}\n${top.todo}', style: const TextStyle(fontWeight: FontWeight.w600))),
              if (e.phase == 1) ...[
                const SizedBox(height: 10),
                const Text('What are you doing now?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  ...acts.map((a) => ChoiceChip(label: Text(a[1]), selected: e.tried == a[0], onSelected: (_) => w.trying(a[0]))),
                  ActionChip(avatar: const Icon(Icons.music_note, size: 18), label: const Text('జోల పాట'), onPressed: w.playLullaby),
                ]),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: w.calmNow, icon: const Icon(Icons.check), label: const Text('She is calm now')),
              ],
            ]),
          ),
        );
      },
    );
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
            ClayCard(
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
                  if (w.on && w.bgOk) const Padding(padding: EdgeInsets.only(top: 10), child: Text('✅ Keeps listening with the screen off. You can lock the phone or use other apps. Don\'t swipe Little One away from recent apps.')),
                ]),
              ),
            ),
            const CryLiveCard(),
            SwitchListTile(value: st['wCry'] != false, onChanged: (v) => s.setSetting('wCry', v), title: const Text('She cries → listen to the cry and say the reason aloud')),
            SwitchListTile(value: st['wShh'] != false, onChanged: (v) => s.setSetting('wShh', v), title: const Text('Loud voices → say "బేబీ బజ్జో ఉంది, అరవకండి"')),
            SwitchListTile(value: st['autoWatch'] == true, onChanged: (v) => s.setSetting('autoWatch', v), title: const Text('Start listening automatically when I open the app')),
            const SizedBox(height: 8),
            Text('How loud before it reacts', style: Theme.of(context).textTheme.titleSmall),
            Slider(value: ((st['sens'] as num?)?.toDouble() ?? 18).clamp(8, 30), min: 8, max: 30, divisions: 22, onChanged: (v) => s.setSetting('sens', v)),
            const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('softer sounds', style: TextStyle(fontSize: 12)), Text('only very loud', style: TextStyle(fontSize: 12))]),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: Bg.askBattery, icon: const Icon(Icons.battery_saver), label: const Text('Phone stops listening? Allow "no battery limits"')),
            if (s.openCry != null && w.ep == null)
              ClayCard(
                color: cs.primaryContainer,
                child: ListTile(
                  leading: const Text('😢', style: TextStyle(fontSize: 26)),
                  title: Text('She cried at ${hm(DateTime.fromMillisecondsSinceEpoch((s.openCry!['at'] as num).toInt()))}'),
                  subtitle: const Text('Tap to tell what calmed her'),
                  onTap: () => askWhatCalmed(context, s.openCry!['id'].toString()),
                ),
              ),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CryHistoryPage())), icon: const Icon(Icons.insights), label: const Text('Cry tracker · every cry & pattern')),
            const SizedBox(height: 8),
            if (w.log.isNotEmpty) Text('What happened', style: Theme.of(context).textTheme.titleSmall),
            ...w.log.map((l) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(l))),
            const SizedBox(height: 16),
            Text('Keep the phone near her, on the charger. When she cries it listens ~8 seconds to the rhythm, says the likely reason, gives the next idea every 4 minutes if she keeps crying, and notices when she calms down.', style: TextStyle(color: cs.outline)),
          ]),
        );
      },
    );
  }
}
