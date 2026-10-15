import 'package:audioplayers/audioplayers.dart';

/// Short game sounds (assets/sfx/*.wav), several can overlap.
class Sfx {
  static final _pool = List.generate(4, (_) => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency));
  static int _i = 0;
  static bool on = true;

  static Future<void> play(String name, {double volume = 0.9}) async {
    if (!on) return;
    try {
      final p = _pool[_i++ % _pool.length];
      await p.stop();
      await p.play(AssetSource('sfx/$name.wav'), volume: volume);
    } catch (_) {}
  }
}
