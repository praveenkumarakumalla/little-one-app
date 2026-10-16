import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

/// On-phone AI that recognises a baby's cry (Google's YAMNet sound model, trained on
/// 2 million YouTube sound clips; class "Baby cry, infant cry"). Works offline.
/// It tells a real cry apart from TV, talking, music, pressure cooker, fan…
class CryML {
  CryML._();
  static final CryML i = CryML._();

  static const win = 15600; // 0.975 s at 16 kHz
  static const _cry = [20, 19, 21, 22]; // baby cry, crying/sobbing, whimper, wail
  static const _babble = [4, 14]; // babbling, baby laughter
  static const _speech = [0, 1, 2]; // talking

  Interpreter? _it;
  IsolateInterpreter? _iso;
  bool failed = false, _busy = false, _loading = false;
  final Float32List _ring = Float32List(win);
  int _pos = 0, _filled = 0;

  /// 0..1 – how sure the AI is that this is a baby crying (last second of sound).
  double cry = 0, babble = 0, speech = 0;
  DateTime lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  bool get ready => _iso != null && DateTime.now().difference(lastRun).inSeconds < 3;

  Future<void> init() async {
    if (_iso != null || failed || _loading) return;
    _loading = true;
    try {
      _it = await Interpreter.fromAsset('assets/ml/yamnet.tflite', options: InterpreterOptions()..threads = 2);
      _iso = await IsolateInterpreter.create(address: _it!.address);
    } catch (_) {
      failed = true;
    }
    _loading = false;
  }

  /// Feed 100 ms of 16 kHz audio (-1..1). Every half second the AI listens to the last second.
  void add(List<double> f) {
    for (final x in f) {
      _ring[_pos] = x;
      _pos = (_pos + 1) % win;
    }
    _filled = (_filled + f.length).clamp(0, win);
  }

  Future<void> run() async {
    final iso = _iso;
    if (iso == null || _busy || _filled < win) return;
    _busy = true;
    try {
      final input = Float32List(win);
      for (var k = 0; k < win; k++) {
        input[k] = _ring[(_pos + k) % win];
      }
      final out = [List<double>.filled(521, 0)];
      await iso.run(input, out);
      final s = out[0];
      double mx(List<int> ids) => ids.map((j) => s[j]).reduce((a, b) => a > b ? a : b);
      // smooth a little so one odd second doesn't flip the answer
      cry = cry * 0.35 + mx(_cry) * 0.65;
      babble = babble * 0.35 + mx(_babble) * 0.65;
      speech = speech * 0.35 + mx(_speech) * 0.65;
      lastRun = DateTime.now();
    } catch (_) {
      failed = true;
      _iso = null;
    }
    _busy = false;
  }
}
