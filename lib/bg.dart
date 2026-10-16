import 'package:flutter/services.dart';

/// Talks to the small Android foreground service that keeps the microphone
/// listening while the screen is off or another app is open.
class Bg {
  static const _ch = MethodChannel('little_one/bg');

  static Future<bool> start(String title, String text) async {
    try {
      return await _ch.invokeMethod<bool>('start', {'title': title, 'text': text}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> update(String title, String text) async {
    try {
      await _ch.invokeMethod('update', {'title': title, 'text': text});
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
  }

  /// Asks Android not to put the app to sleep (needed on Xiaomi / Vivo / Oppo / Realme / Samsung).
  static Future<void> askBattery() async {
    try {
      await _ch.invokeMethod('battery');
    } catch (_) {}
  }

  /// Calls: loudspeaker on/off (active=false puts the phone back to normal sound).
  static Future<void> speaker(bool on, {bool active = true}) async {
    try {
      await _ch.invokeMethod('speaker', {'on': on, 'active': active});
    } catch (_) {}
  }
}
