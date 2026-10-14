import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'store.dart';

/// Soft, continuous "Hare Rama Hare Krishna" while the app is open.
class Chant extends ChangeNotifier {
  Chant._();
  static final Chant i = Chant._();

  final AudioPlayer _bg = AudioPlayer(playerId: 'chant');
  final FlutterTts _tts = FlutterTts();
  bool on = false;
  bool _starting = false;
  int _session = 0;
  String? _lang;
  String? error;

  static const te = 'హరే రామ హరే రామ, రామ రామ హరే హరే. హరే కృష్ణ హరే కృష్ణ, కృష్ణ కృష్ణ హరే హరే.';
  static const dev = 'हरे राम हरे राम, राम राम हरे हरे। हरे कृष्ण हरे कृष्ण, कृष्ण कृष्ण हरे हरे।';
  static const lat = 'Hare Rama Hare Rama, Rama Rama Hare Hare. Hare Krishna Hare Krishna, Krishna Krishna Hare Hare.';

  double get volume => ((Store.i.settings['chantVol'] as num?)?.toDouble() ?? 0.4).clamp(0.05, 1.0);
  bool get autoStart => Store.i.settings['chantOnOpen'] != false;
  String? get ownFile => Store.i.settings['chantFile'] as String?;

  Future<void> _initTts() async {
    if (_lang != null) return;
    for (final l in ['hi-IN', 'te-IN', 'en-IN', 'en-US']) {
      try {
        final ok = await _tts.isLanguageAvailable(l);
        if (ok == true || ok == 1) {
          _lang = l;
          break;
        }
      } catch (_) {}
    }
    _lang ??= 'en-US';
    try {
      await _tts.setLanguage(_lang!);
      await _tts.setSpeechRate(0.38);
      await _tts.setPitch(0.9);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  Future<void> start() async {
    if (on || _starting) return;
    _starting = true;
    on = true;
    error = null;
    final s = ++_session;
    notifyListeners();
    try {
      // play alongside other sounds instead of fighting for the speaker
      await _bg.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
      ));
    } catch (_) {}
    try {
      await _bg.setReleaseMode(ReleaseMode.loop);
      await _bg.setVolume(ownFile != null ? volume : volume * 0.8);
      final own = ownFile;
      if (own != null) {
        await _bg.play(DeviceFileSource(own));
      } else {
        await _bg.play(AssetSource('audio/tanpura.wav'));
      }
    } catch (e) {
      error = 'Could not play the sound: $e';
      notifyListeners();
    }
    _starting = false;
    if (ownFile != null) return;
    // the phone's voice chants gently over the tanpura
    await _initTts();
    while (on && s == _session) {
      try {
        await _tts.setVolume(volume);
        await _tts.speak(_lang == 'hi-IN' ? dev : _lang == 'te-IN' ? te : lat);
      } catch (_) {
        await Future.delayed(const Duration(seconds: 3));
      }
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  Future<void> stop() async {
    on = false;
    _starting = false;
    _session++;
    notifyListeners();
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _bg.stop();
    } catch (_) {}
  }

  Future<void> setVolume(double v) async {
    await Store.i.setSetting('chantVol', v);
    try {
      await _bg.setVolume(ownFile != null ? v : v * 0.8);
    } catch (_) {}
    notifyListeners();
  }
}
