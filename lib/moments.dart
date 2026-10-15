import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'store.dart';

/// "Capture a moment" reminders every 2 hours in the daytime. Tapping one opens the camera.
class Moments {
  static final _n = FlutterLocalNotificationsPlugin();
  static final ValueNotifier<String?> route = ValueNotifier(null);
  static const _base = 700;
  static const _slots = 7 * 7; // 7 days × 7 reminders

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    await _n.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) => route.value = r.payload,
    );
    final d = await _n.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp == true) route.value = d!.notificationResponse?.payload;
    await reschedule();
  }

  static bool get enabled => Store.i.settings['moments'] == true;

  static const _msgs = [
    ['📸 Smile time!', 'She looks different every day — take a photo of her now.'],
    ['🎙️ Capture her voice', 'Record her little sounds today. You will love hearing them later.'],
    ['😍 పాప ఫోటో తీయండి', 'ఈ క్షణం మళ్ళీ రాదు. ఒక ఫోటో తీయండి!'],
    ['🎬 A tiny video?', '10 seconds of her yawning or stretching = a memory forever.'],
    ['😂 Try a funny filter', 'Devil horns, clown face or a 90\'s camcorder look — have fun!'],
    ['💕 Moment time', 'Hold her close and take a selfie together.'],
    ['🌟 Today\'s memory', 'Have you saved a photo of her today?'],
  ];

  /// Every 2 hours from 8 AM to 8 PM, for the next 7 days (re-planned each time the app opens).
  static Future<void> reschedule() async {
    try {
      for (var i = 0; i < _slots; i++) {
        await _n.cancel(_base + i);
      }
      if (!enabled) return;
      final now = tz.TZDateTime.now(tz.local);
      var id = 0;
      for (var day = 0; day < 7 && id < _slots; day++) {
        for (final h in [8, 10, 12, 14, 16, 18, 20]) {
          final at = tz.TZDateTime(tz.local, now.year, now.month, now.day + day, h, 3);
          if (!at.isAfter(now.add(const Duration(minutes: 20)))) continue;
          if (id >= _slots) break;
          final m = _msgs[(day * 7 + h) % _msgs.length];
          await _n.zonedSchedule(
            _base + id,
            m[0],
            m[1],
            at,
            const NotificationDetails(
              android: AndroidNotificationDetails('moments', 'Moment reminders', channelDescription: 'Every 2 hours: capture a photo, video or her voice', importance: Importance.defaultImportance, priority: Priority.defaultPriority),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: m[0].startsWith('🎙️') ? 'voices' : 'camera',
          );
          id++;
        }
      }
    } catch (_) {}
  }
}
