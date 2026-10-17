import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';


/// Telugu voice (falls back to Hindi / Indian English) and app sounds.
class Voice {
  Voice._();
  static final Voice i = Voice._();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer music = AudioPlayer();
  final AudioPlayer fx = AudioPlayer();
  final AudioPlayer clipPlayer = AudioPlayer();
  final Set<String> clips = {};
  final Set<String> leda = {}, fallback = {};
  String? _lang;
  bool speaking = false;
  String nowPlaying = '';

  /// Recorded baby-voice clips (assets/voice/<key>.m4a) — natural voice, used instead of the robot voice.
  bool hasClip(String key) => clips.contains(key);
  String assetPath(String key) => leda.contains(key) || !fallback.contains(key) ? 'assets/voice/$key.m4a' : 'assets/voice_fb/$key.m4a';

  Future<bool> clip(String key, {double volume = 1.0}) async {
    if (!clips.contains(key)) return false;
    try {
      speaking = true;
      await clipPlayer.stop();
      await clipPlayer.setVolume(volume);
      await clipPlayer.play(AssetSource(fallback.contains(key) && !leda.contains(key) ? 'voice_fb/$key.m4a' : 'voice/$key.m4a'));
      await clipPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 20));
    } catch (_) {}
    speaking = false;
    return true;
  }

  /// Plays the clips one after another in the baby voice; if any clip is missing, speaks [text] with the phone voice.
  Future<void> sayClips(List<String> keys, String text, {double volume = 1.0}) async {
    if (keys.isNotEmpty && keys.every(clips.contains)) {
      for (final k in keys) {
        await clip(k, volume: volume);
      }
    } else {
      await say(text, volume: volume);
    }
  }

  Future<void> init() async {
    try {
      final m = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final a in m.listAssets()) {
        if (a.startsWith('assets/voice/') && a.endsWith('.m4a')) {
          clips.add(a.substring(13, a.length - 4));
          leda.add(a.substring(13, a.length - 4));
        }
        // fill-in clips (Edge voice) for lines the Gemini voice hasn't made yet
        if (a.startsWith('assets/voice_fb/') && a.endsWith('.m4a')) {
          clips.add(a.substring(16, a.length - 4));
          fallback.add(a.substring(16, a.length - 4));
        }
      }
    } catch (_) {}
    for (final l in ['te-IN', 'hi-IN', 'en-IN']) {
      try {
        final ok = await _tts.isLanguageAvailable(l);
        if (ok == true || ok == 1) {
          _lang = l;
          break;
        }
      } catch (_) {}
    }
    if (_lang != null) await _tts.setLanguage(_lang!);
    await _tts.setSpeechRate(0.45);
    await _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() => speaking = true);
    _tts.setCompletionHandler(() => speaking = false);
    _tts.setCancelHandler(() => speaking = false);
    _tts.setErrorHandler((_) => speaking = false);
  }

  bool get hasTelugu => _lang == 'te-IN';

  /// [te] Telugu text, [dev] same words in Devanagari, [lat] same words in Latin letters.
  Future<void> say(String te, {String? dev, String? lat, double pitch = 1.0, double volume = 1.0}) async {
    String text = te;
    if (_lang == 'hi-IN' && dev != null) text = dev;
    if (_lang == 'en-IN' && lat != null) text = lat;
    try {
      await _tts.setPitch(pitch);
      await _tts.setVolume(volume);
      speaking = true;
      await _tts.speak(text);
    } catch (_) {}
    speaking = false;
  }

  /// Saves the words as a .wav file (used by alarms that ring while the app is closed).
  Future<bool> synthToFile(String te, String path, {String? dev, String? lat, double pitch = 1.0}) async {
    String text = te;
    if (_lang == 'hi-IN' && dev != null) text = dev;
    if (_lang == 'en-IN' && lat != null) text = lat;
    try {
      await _tts.awaitSynthCompletion(true);
      await _tts.setPitch(pitch);
      await _tts.setSpeechRate(0.42);
      final r = await _tts.synthesizeToFile(text, path, true);
      await _tts.setSpeechRate(0.45);
      return r == 1 || r == true;
    } catch (_) {
      return false;
    }
  }

  String? get lang => _lang;

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    speaking = false;
  }

  Future<void> babyAsksMilk() async {
    if (!await clip('milk')) await say('అమ్మా… పాలు కావాలి!', dev: 'अम्मा… पालु कावालि!', lat: 'Amma… paalu kaavaali!', pitch: 1.8);
  }

  Future<void> okayAmma() async {
    if (!await clip('okay_amma')) await say('సరే అమ్మా! థాంక్యూ అమ్మా', dev: 'सरे अम्मा! थैंक्यू अम्मा', lat: 'Sare amma! Thank you amma', pitch: 1.8);
  }

  Future<void> shh() async {
    if (!await clip('shh')) await say('ష్ ష్… నేను బజ్జుంటున్నా, అరవకండి ప్లీజ్!', dev: 'श् श्… नेनु बज्जुंटुन्ना, अरवकंडि प्लीज़!', lat: 'Shh shh… nenu bajjuntunna, aravakandi please!', pitch: 1.85);
  }

  Future<void> chime() async {
    try {
      await fx.stop();
      await fx.play(AssetSource('audio/alarm.wav'), volume: 1.0);
    } catch (_) {}
  }

  bool get musicOn => music.state == PlayerState.playing;

  Future<void> playMusicBox() async {
    await music.setReleaseMode(ReleaseMode.loop);
    nowPlaying = 'Music box';
    await music.play(AssetSource('audio/music_box.wav'));
  }

  Future<void> playFile(String path, String title) async {
    await music.setReleaseMode(ReleaseMode.loop);
    nowPlaying = title;
    await music.play(DeviceFileSource(path));
  }

  Future<void> stopMusic() async {
    nowPlaying = '';
    await music.stop();
  }
}
