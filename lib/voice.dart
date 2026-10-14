import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';


/// Telugu voice (falls back to Hindi / Indian English) and app sounds.
class Voice {
  Voice._();
  static final Voice i = Voice._();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer music = AudioPlayer();
  final AudioPlayer fx = AudioPlayer();
  String? _lang;
  bool speaking = false;
  String nowPlaying = '';

  Future<void> init() async {
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

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    speaking = false;
  }

  Future<void> babyAsksMilk() => say('అమ్మా… పాలు కావాలి!', dev: 'अम्मा… पालु कावालि!', lat: 'Amma… paalu kaavaali!', pitch: 1.8);
  Future<void> okayAmma() => say('సరే అమ్మా! థాంక్యూ అమ్మా', dev: 'सरे अम्मा! थैंक्यू अम्मा', lat: 'Sare amma! Thank you amma', pitch: 1.8);
  Future<void> shh() => say('బేబీ బజ్జో ఉంది, అరవకండి!', dev: 'बेबी बज्जो उंदी, अरवकंडि!', lat: 'Baby bajjo undi, aravakandi!', pitch: 1.1);

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
