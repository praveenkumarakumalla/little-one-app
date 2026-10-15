import 'dart:io';
import 'dart:math' as math;

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'store.dart';
import 'voice.dart';

/// "Talking baby": the app itself speaks in a cute baby voice —
/// every hour 8 AM–8 PM it asks about the family, at 12 PM it wants biryani or pizza (said twice),
/// and at 8:30 PM it asks for "Jai Shree Ram". Works even when the app is closed
/// (the sentences are saved as voice files on the phone and played by the alarm service).
class Talk {
  static const base = 1000; // alarm ids 1000…1099
  static const version = 2; // bump when the words change, to re-make the voice files

  /// key: [Telugu, Devanagari (for Hindi voice), Latin (for English voice), notification title]
  static const lines = <String, List<String>>{
    'amma': ['హలో అమ్మా! నేను నీ చిన్ని బేబీని. ఏం చేస్తున్నావ్?', 'हलो अम्मा! नेनु नी चिन्नि बेबीनि. एम चेस्तुन्नाव?', 'Hello Amma! Nenu nee chinni baby ni. Em chestunnav?', '👶 హలో అమ్మా! ఏం చేస్తున్నావ్?'],
    'nanna': ['హలో! నాన్న ఏం చేస్తున్నాడు?', 'हलो! नान्ना एम चेस्तुन्नाडु?', 'Hello! Nanna em chestunnadu?', '👶 నాన్న ఏం చేస్తున్నాడు?'],
    'ammamma': ['అమ్మమ్మ ఏం చేస్తోంది?', 'अम्मम्मा एम चेस्तोंदि?', 'Ammamma em chestondi?', '👶 అమ్మమ్మ ఏం చేస్తోంది?'],
    'tatayya': ['తాతయ్య ఏం చేస్తున్నాడు?', 'तातय्या एम चेस्तुन्नाडु?', 'Tatayya em chestunnadu?', '👶 తాతయ్య ఏం చేస్తున్నాడు?'],
    'biryani': ['అమ్మా, నాకు బిర్యానీ కావాలి! ... అమ్మా, నాకు బిర్యానీ కావాలి!', 'अम्मा, नाकु बिर्यानी कावालि! ... अम्मा, नाकु बिर्यानी कावालि!', 'Amma, naku biryani kavali! ... Amma, naku biryani kavali!', '🍗 అమ్మా, నాకు బిర్యానీ కావాలి!'],
    'pizza': ['అమ్మా, నాకు పిజ్జా కావాలి! ... అమ్మా, నాకు పిజ్జా కావాలి!', 'अम्मा, नाकु पिज़्ज़ा कावालि! ... अम्मा, नाकु पिज़्ज़ा कावालि!', 'Amma, naku pizza kavali! ... Amma, naku pizza kavali!', '🍕 అమ్మా, నాకు పిజ్జా కావాలి!'],
    'ram': ['అమ్మా, నాకు జై శ్రీ రామ్ చెప్పు! జై శ్రీ రామ్!', 'अम्मा, नाकु जय श्री राम चेप्पु! जय श्री राम!', 'Amma, naku Jai Shree Ram cheppu! Jai Shree Ram!', '🙏 అమ్మా, నాకు జై శ్రీ రామ్ చెప్పు!'],
  };

  /// Quick replies shown in the app when it asks: [button, what the baby says back]
  static const replies = <String, List<List<String>>>{
    'ask': [
      ['💼 పని చేస్తున్నా', 'సరే! త్వరగా వచ్చేయ్!', 'r_work'],
      ['🍳 వంట చేస్తున్నా', 'యమ్మీ! నాకు కూడా!', 'r_cook'],
      ['😴 రెస్ట్ తీసుకుంటున్నా', 'సరే, బజ్జో!', 'r_rest'],
      ['🥰 నీ గురించే ఆలోచిస్తున్నా', 'నేను కూడా! ఐ లవ్ యూ!', 'r_love'],
    ],
    'food': [
      ['🍗 సరే, తెస్తా!', 'యే! థాంక్యూ అమ్మా!', 'r_food_yes'],
      ['🍼 ముందు పాలు తాగు', 'సరే అమ్మా… పాలే నాకు ఇష్టం!', 'r_food_milk'],
    ],
    'ram': [
      ['🙏 జై శ్రీ రామ్!', 'జై శ్రీ రామ్! థాంక్యూ అమ్మా. గుడ్ నైట్!', 'r_ram'],
    ],
  };

  static bool get enabled => Store.i.settings['talk'] != false;

  static Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/talk');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static Future<String> _path(String key) async => '${(await _dir()).path}/$key.wav';

  /// Make the voice files (once, or when the words change). Needs the phone's text-to-speech.
  static Future<void> prepare({bool force = false}) async {
    final ver = (Store.i.settings['talkVer'] as num?)?.toInt() ?? 0;
    final lang = Voice.i.lang ?? '';
    final redo = force || ver != version || Store.i.settings['talkLang'] != lang;
    for (final e in lines.entries) {
      if (Voice.i.hasClip(e.key)) continue;
      final p = await _path(e.key);
      final f = File(p);
      if (!redo && f.existsSync() && f.lengthSync() > 2000) continue;
      await Voice.i.synthToFile(e.value[0], p, dev: e.value[1], lat: e.value[2], pitch: 1.85);
    }
    await Store.i.setSetting('talkVer', version);
    await Store.i.setSetting('talkLang', lang);
  }

  static Future<void> _cancelAll() async {
    for (var i = 0; i < 100; i++) {
      try {
        await Alarm.stop(base + i);
      } catch (_) {}
    }
  }

  static bool isTalk(int id) => id >= base && id < base + 100;

  static String? keyFor(int id) => (Map<String, dynamic>.from((Store.i.settings['talkPlan'] ?? {}) as Map))['$id']?.toString();

  /// Plan the next 3 days. Called when the app opens and after each ring.
  static Future<void> reschedule() async {
    try {
      await _cancelAll();
      if (!enabled) return;
      await prepare();
      final now = DateTime.now();
      final r = math.Random();
      final plan = <String, String>{};
      var id = base;
      var lastAsk = '';
      const asks = ['amma', 'nanna', 'ammamma', 'tatayya'];
      for (var day = 0; day < 3; day++) {
        final d0 = DateTime(now.year, now.month, now.day + day);
        final slots = <MapEntry<DateTime, String>>[];
        for (var h = 8; h <= 20; h++) {
          String key;
          if (h == 12) {
            key = r.nextBool() ? 'biryani' : 'pizza';
          } else {
            final pick = asks.where((a) => a != lastAsk).toList();
            key = pick[r.nextInt(pick.length)];
            lastAsk = key;
          }
          slots.add(MapEntry(d0.add(Duration(hours: h)), key));
        }
        slots.add(MapEntry(d0.add(const Duration(hours: 20, minutes: 30)), 'ram'));
        for (final s in slots) {
          if (!s.key.isAfter(now.add(const Duration(seconds: 30)))) continue;
          final p = await _path(s.value);
          final file = File(p);
          final audio = Voice.i.hasClip(s.value)
              ? 'assets/voice/${s.value}.m4a'
              : file.existsSync() && file.lengthSync() > 2000
                  ? p
                  : 'assets/audio/music_box.wav';
          final l = lines[s.value]!;
          await Alarm.set(
            alarmSettings: AlarmSettings(
              id: id,
              dateTime: s.key,
              assetAudioPath: audio,
              loopAudio: false,
              vibrate: false,
              androidFullScreenIntent: false,
              warningNotificationOnKill: false,
              volumeSettings: VolumeSettings.fade(volume: ((Store.i.settings['talkVol'] as num?)?.toDouble() ?? 0.8), fadeDuration: const Duration(milliseconds: 600), volumeEnforced: false),
              notificationSettings: NotificationSettings(title: l[3], body: '${Store.i.babyName} is talking to you 👶 Tap to reply', stopButton: 'OK 😘', iconColor: const Color(0xFFEE5D8E)),
            ),
          );
          plan['$id'] = s.value;
          id++;
        }
      }
      await Store.i.setSetting('talkPlan', plan);
    } catch (_) {}
  }

  /// Plays one sentence now (for the "Try it" button).
  static Future<void> test([String? key]) async {
    final k = key ?? (lines.keys.toList()..shuffle()).first;
    final l = lines[k]!;
    if (!await Voice.i.clip(k, volume: (Store.i.settings['talkVol'] as num?)?.toDouble() ?? 0.8)) await Voice.i.say(l[0], dev: l[1], lat: l[2], pitch: 1.85);
  }

  static String group(String key) => key == 'ram' ? 'ram' : (key == 'biryani' || key == 'pizza') ? 'food' : 'ask';
}

/// The little sheet shown in the app when the baby talks (if the app is open).
Future<void> showTalkSheet(BuildContext context, int id) async {
  final key = Talk.keyFor(id) ?? 'amma';
  final l = Talk.lines[key]!;
  final reps = Talk.replies[Talk.group(key)]!;
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('👶', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 6),
          Text(l[3].replaceAll(RegExp(r'^\S+\s'), ''), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: reps
                .map((r) => FilledButton.tonal(
                      onPressed: () async {
                        Navigator.pop(c);
                        try {
                          await Alarm.stop(id);
                        } catch (_) {}
                        if (!await Voice.i.clip(r[2])) await Voice.i.say(r[1], pitch: 1.85);
                      },
                      child: Text(r[0]),
                    ))
                .toList(),
          ),
        ]),
      ),
    ),
  );
}
