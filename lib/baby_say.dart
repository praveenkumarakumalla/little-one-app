import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'store.dart';
import 'voice.dart';

/// "Baby says" – the master phone sends a line in the family chat and every other
/// phone speaks it out loud in the baby voice.
class BabySay {
  /// (clip key, emoji, short label, full line)
  static const presets = [
    ('amma', '👩', 'Amma em chestunnav?', 'హలో అమ్మా! నేను నీ చిన్ని బేబీని. ఏం చేస్తున్నావ్?'),
    ('nanna', '👨', 'Nanna em chestunnadu?', 'హలో! నాన్న ఏం చేస్తున్నాడు?'),
    ('akali', '🍼', 'Akali ga undi', 'అమ్మా, నాకు ఆకలిగా ఉంది!'),
    ('milk', '🥛', 'Paalu kavali', 'అమ్మా… పాలు కావాలి!'),
    ('nidra', '😴', 'Nidra vastondi', 'అమ్మా, నాకు నిద్ర వస్తోంది… జోకొట్టు!'),
    ('ettuko', '🤗', 'Nannu ettuko', 'అమ్మా, నన్ను ఎత్తుకో!'),
    ('diaper', '🧷', 'Diaper marchu', 'అమ్మా, డైపర్ తడిసిపోయింది, మార్చు!'),
    ('bath', '🛁', 'Snanam', 'అమ్మా, స్నానం చేయించు!'),
    ('play', '🧸', 'Natho aaduko', 'నాతో ఆడుకో, ప్లీజ్!'),
    ('love', '😘', 'I love you', 'అమ్మా, ఐ లవ్ యూ! ముద్దు!'),
    ('come_home', '🏠', 'Nanna intiki raa', 'నాన్నా, త్వరగా ఇంటికి రా! నిన్ను మిస్ అవుతున్నా!'),
    ('ammamma', '👵', 'Ammamma em chestundi?', 'అమ్మమ్మ ఏం చేస్తోంది?'),
    ('tatayya', '👴', 'Tatayya em chestunnadu?', 'తాతయ్య ఏం చేస్తున్నాడు?'),
    ('biryani', '🍗', 'Biryani kavali', 'అమ్మా, నాకు బిర్యానీ కావాలి!'),
    ('ram', '🙏', 'Jai Shree Ram', 'నాకు జై శ్రీ రామ్ చెప్పు అమ్మా!'),
  ];

  static int _alarmN = 0;

  /// Speak a line out loud on this phone. Uses the recorded baby clip when there is one.
  /// [background] = the app isn't on screen: play it through the alarm speaker so it is heard anyway.
  static Future<void> play(String text, String? clip, {bool background = false}) async {
    final v = Voice.i;
    if (!background) {
      if (clip != null && v.hasClip(clip)) {
        if (await v.clip(clip)) return;
      }
      await v.say(text, pitch: 1.9);
      return;
    }
    try {
      String audio;
      if (clip != null && v.hasClip(clip)) {
        audio = v.assetPath(clip);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final p = '${dir.path}/babysay_${DateTime.now().millisecondsSinceEpoch}.wav';
        final ok = await v.synthToFile(text, p, pitch: 1.9);
        if (!ok || !File(p).existsSync()) return;
        audio = p;
      }
      await Alarm.set(
        alarmSettings: AlarmSettings(
          id: 1500 + (_alarmN++ % 50),
          dateTime: DateTime.now().add(const Duration(seconds: 2)),
          assetAudioPath: audio,
          loopAudio: false,
          vibrate: false,
          androidFullScreenIntent: false,
          warningNotificationOnKill: false,
          volumeSettings: VolumeSettings.fade(volume: ((Store.i.settings['talkVol'] as num?)?.toDouble() ?? 0.9), fadeDuration: const Duration(milliseconds: 300), volumeEnforced: false),
          notificationSettings: NotificationSettings(title: '👶 ${Store.i.babyName} says…', body: text, stopButton: 'OK 😘', iconColor: const Color(0xFFEE5D8E)),
        ),
      );
    } catch (_) {}
  }
}

/// The master phone's "Baby says" sheet: tap a line (or type one) – it is spoken on the other phones.
Future<(String, String?)?> pickBabySay(BuildContext context) {
  final t = TextEditingController();
  return showModalBottomSheet<(String, String?)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('🔊 Baby says… on the other phones', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const Text('Tap a line – it is spoken out loud in the baby voice on every family phone (and appears in the chat). Tap ▶ to hear it here first.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in BabySay.presets)
                InputChip(
                  avatar: Text(p.$2, style: const TextStyle(fontSize: 18)),
                  label: Text(p.$3),
                  deleteIcon: const Icon(Icons.play_arrow, size: 20),
                  onDeleted: () => BabySay.play(p.$4, p.$1),
                  onPressed: () => Navigator.pop(c, (p.$4, p.$1)),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: t, decoration: const InputDecoration(hintText: 'Or type anything (Telugu/English)…', border: OutlineInputBorder(), isDense: true))),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () {
              if (t.text.trim().isEmpty) return;
              Navigator.pop(c, (t.text.trim(), null));
            },
            icon: const Icon(Icons.campaign),
          ),
        ]),
      ]),
    ),
  );
}
