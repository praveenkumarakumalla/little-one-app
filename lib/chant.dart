import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'store.dart';

/// Soft, continuous "Hare Rama Hare Krishna" while the app is open.
class Chant extends ChangeNotifier {
  Chant._();
  static final Chant i = Chant._();

  final AudioPlayer _bg = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool on = false;
  int _session = 0;
  String? _lang;

  static const te = 'హరే రామ హరే రామ, రామ రామ హరే హరే. హరే కృష్ణ హరే కృష్ణ, కృష్ణ కృష్ణ హరే హరే.';
  static const dev = 'हरे राम हरे राम, राम राम हरे हरे। हरे कृष्ण हरे कृष्ण, कृष्ण कृष्ण हरे हरे।';
  static const lat = 'Hare Rama Hare Rama, Rama Rama Hare Hare. Hare Krishna Hare Krishna, Krishna Krishna Hare Hare.';

  double get volume => ((Store.i.settings['chantVol'] as num?)?.toDouble() ?? 0.35).clamp(0.05, 1.0);
  bool get autoStart => Store.i.settings['chantOnOpen'] != false;
  String? get ownFile => Store.i.settings['chantFile'] as String?;

  Future<void> _initTts() async {
    if (_lang != null) return;
    for (final l in ['hi-IN', 'te-IN', 'en-IN']) {
      try {
        final ok = await _tts.isLanguageAvailable(l);
        if (ok == true || ok == 1) {
          _lang = l;
          break;
        }
      } catch (_) {}
    }
    _lang ??= 'en-IN';
    await _tts.setLanguage(_lang!);
    await _tts.setSpeechRate(0.38);
    await _tts.setPitch(0.9);
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> start() async {
    if (on) return;
    on = true;
    final s = ++_session;
    notifyListeners();
    await _bg.setReleaseMode(ReleaseMode.loop);
    final own = ownFile;
    if (own != null) {
      await _bg.play(DeviceFileSource(own), volume: volume);
      return;
    }
    // built-in: soft tanpura drone with the phone's voice chanting gently over it
    await _bg.play(AssetSource('audio/tanpura.wav'), volume: volume * 0.8);
    await _initTts();
    final text = _lang == 'hi-IN' ? dev : _lang == 'te-IN' ? te : lat;
    while (on && s == _session) {
      try {
        await _tts.setVolume(volume);
        await _tts.speak(text);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  Future<void> stop() async {
    on = false;
    _session++;
    notifyListeners();
    try {
      await _tts.stop();
    } catch (_) {}
    await _bg.stop();
  }

  Future<void> setVolume(double v) async {
    await Store.i.setSetting('chantVol', v);
    await _bg.setVolume(ownFile != null ? v : v * 0.8);
    notifyListeners();
  }
}
