import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import 'store.dart';

/// Schedules the "అమ్మా, పాలు కావాలి" alarm. It rings even when the app is closed.
class FeedAlarm {
  static const id = 7;

  static Future<void> reschedule() async {
    final s = Store.i;
    try {
      await Alarm.stop(id);
    } catch (_) {}
    final on = s.settings['alarm'] != false;
    final last = s.last('feeds');
    if (!on || last == null) return;
    final interval = (s.settings['interval'] as num?)?.toInt() ?? 150;
    var at = last.add(Duration(minutes: interval));
    if (at.isBefore(DateTime.now().add(const Duration(seconds: 20)))) at = DateTime.now().add(const Duration(seconds: 20));
    await setAt(at);
  }

  static Future<void> snooze(int minutes) async {
    try {
      await Alarm.stop(id);
    } catch (_) {}
    await setAt(DateTime.now().add(Duration(minutes: minutes)));
  }

  static Future<void> setAt(DateTime at) async {
    final settings = AlarmSettings(
      id: id,
      dateTime: at,
      assetAudioPath: 'assets/audio/alarm.wav',
      loopAudio: true,
      vibrate: true,
      warningNotificationOnKill: Platform.isIOS,
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fade(volume: 0.9, fadeDuration: const Duration(seconds: 3), volumeEnforced: false),
      notificationSettings: NotificationSettings(
        title: 'అమ్మా, పాలు కావాలి! 🍼',
        body: '${Store.i.babyName} is ready for her feed. Open the app and tap "Feeding now".',
        stopButton: 'Stop',
        iconColor: const Color(0xFFEE5D8E),
      ),
    );
    await Alarm.set(alarmSettings: settings);
  }

  static Future<void> stop() async {
    try {
      await Alarm.stop(id);
    } catch (_) {}
  }

  static DateTime? nextDue() {
    final last = Store.i.last('feeds');
    if (last == null) return null;
    final interval = (Store.i.settings['interval'] as num?)?.toInt() ?? 150;
    return last.add(Duration(minutes: interval));
  }
}
