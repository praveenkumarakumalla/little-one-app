import 'dart:math' as math;

/// One 100 ms slice of sound.
class Fr {
  final double rel; // dB above the quiet-room level
  final bool loud;
  final double f0; // pitch in Hz (0 = none)
  final double clar; // how clean / voiced the pitch is, 0..1
  final bool cry;
  const Fr(this.rel, this.loud, this.f0, this.clar, this.cry);
}

/// What her cry *sounds* like, from its rhythm, pitch and loudness.
///
/// Based on infant-cry research: hunger cries are rhythmic (cry–pause–breath–cry) and build
/// up gradually; pain cries start suddenly, are louder and higher-pitched, with long first
/// screams, breath-holding and a rough, strained voice; tired / fussy cries are softer,
/// on-and-off whimpers; discomfort cries are steady, whiny and irregular. (Pain and colic
/// cries measured higher in pitch and energy than hunger and fussy cries — UCLA ChatterBaby.)
/// The sound is only a hint: it is combined with her feed / nappy / sleep times.
class CrySound {
  final double pain, hunger, tired, fuss;
  final String kind; // pain | hunger | tired | fuss | mixed
  final String te, en;
  final double f0, bursts, burstLen, pauseLen;
  const CrySound(this.pain, this.hunger, this.tired, this.fuss, this.kind, this.te, this.en, this.f0, this.bursts, this.burstLen, this.pauseLen);

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'pain': _r(pain),
        'hunger': _r(hunger),
        'tired': _r(tired),
        'fuss': _r(fuss),
        'f0': f0.round(),
        'burst': _r(burstLen),
        'pause': _r(pauseLen),
        'en': en,
      };
  static double _r(double x) => (x * 100).round() / 100;
}

CrySound analyseCry(List<Fr> f, double sens) {
  const dt = 0.1;
  // --- split into cry bursts (allow one quiet slice inside a burst) ---
  final bursts = <List<int>>[];
  int? s, e;
  var gap = 0;
  for (var i = 0; i < f.length; i++) {
    if (f[i].loud) {
      s ??= i;
      e = i;
      gap = 0;
    } else if (s != null) {
      gap++;
      if (gap > 1) {
        bursts.add([s, e!]);
        s = null;
        gap = 0;
      }
    }
  }
  if (s != null) bursts.add([s, e!]);
  bursts.removeWhere((b) => (b[1] - b[0] + 1) * dt < 0.2);

  double mean(List<double> x) => x.isEmpty ? 0 : x.reduce((a, b) => a + b) / x.length;
  double sd(List<double> x) {
    if (x.length < 2) return 0;
    final m = mean(x);
    return math.sqrt(x.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) / (x.length - 1));
  }

  final durs = bursts.map((b) => (b[1] - b[0] + 1) * dt).toList();
  final pauses = <double>[];
  final starts = <double>[];
  for (var i = 0; i < bursts.length; i++) {
    starts.add(bursts[i][0] * dt);
    if (i > 0) pauses.add((bursts[i][0] - bursts[i - 1][1] - 1) * dt);
  }
  final intervals = <double>[for (var i = 1; i < starts.length; i++) starts[i] - starts[i - 1]];
  final cv = intervals.length >= 2 && mean(intervals) > 0 ? sd(intervals) / mean(intervals) : 1.0;

  final loudF = f.where((x) => x.loud).toList();
  final cryF = f.where((x) => x.cry && x.f0 > 0).toList();
  final f0s = cryF.map((x) => x.f0).toList()..sort();
  final f0 = mean(f0s);
  final f0hi = f0s.isEmpty ? 0.0 : f0s[(f0s.length * 0.9).floor().clamp(0, f0s.length - 1)];
  final over = loudF.isEmpty ? 0.0 : mean(loudF.map((x) => x.rel).toList()) - sens; // how far above "loud"
  final loudFrac = f.isEmpty ? 0.0 : loudF.length / f.length;
  final voiced = loudF.isEmpty ? 1.0 : cryF.length / loudF.length; // low = rough / strained / screaming
  final half = f.length ~/ 2;
  final a = f.take(half).where((x) => x.loud).map((x) => x.rel).toList();
  final b = f.skip(half).where((x) => x.loud).map((x) => x.rel).toList();
  final building = mean(b) - mean(a) > 2 || (a.length < b.length * 0.7);
  final firstLen = durs.isEmpty ? 0.0 : durs.first;
  final maxLen = durs.isEmpty ? 0.0 : durs.reduce(math.max);
  var breathHold = false;
  for (var i = 0; i + 1 < bursts.length; i++) {
    if (durs[i] >= 2.5 && pauses[i] >= 0.8) breathHold = true;
  }
  var suddenOnset = false;
  if (bursts.isNotEmpty && bursts.first[0] > 0) {
    final i0 = bursts.first[0];
    if (i0 + 1 < f.length && f[i0 + 1].rel - f[i0 - 1].rel > 12) suddenOnset = true;
  }
  final mp = mean(pauses), mb = mean(durs);

  double sc(List<bool> c) => c.where((x) => x).length / c.length;
  final pain = sc([f0 > 520, f0hi > 680, firstLen >= 2.5 || maxLen >= 3.2, breathHold || (pauses.isNotEmpty && mp < 0.3), over > 12, voiced < 0.5, suddenOnset]);
  final hunger = sc([cv < 0.4, mb >= 0.5 && mb <= 2.2, mp >= 0.2 && mp <= 1.1, f0 >= 330 && f0 <= 540, building, bursts.length >= 4]);
  final tired = sc([over < 7, loudFrac < 0.45, mp > 1.0, cv > 0.5, f0 > 0 && f0 < 460]);
  final fuss = sc([loudFrac > 0.6, over >= 4 && over <= 13, cv >= 0.4, f0 >= 380 && f0 <= 600, !building]);

  final m = {'pain': pain * 1.05, 'hunger': hunger, 'tired': tired * 0.95, 'fuss': fuss * 0.9};
  final ord = m.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
  var kind = ord.first.value - ord[1].value < 0.1 || ord.first.value < 0.45 ? 'mixed' : ord.first.key;
  const te = {
    'pain': 'ఏడుపు సడెన్‌గా, గట్టిగా, ఎక్కువ పిచ్‌లో ఉంది, ఊపిరి బిగబట్టి ఏడుస్తోంది. నొప్పి లేదా గ్యాస్ ఉండొచ్చు.',
    'hunger': 'ఏడుపు ఒక లయలో వస్తోంది — ఏడుపు, ఆగడం, మళ్ళీ ఏడుపు — క్రమంగా పెరుగుతోంది. ఇది ఆకలి ఏడుపులా ఉంది.',
    'tired': 'ఏడుపు మెల్లగా, ఆగి ఆగి వస్తోంది. నిద్ర వస్తున్నట్టు ఉంది.',
    'fuss': 'ఏడుపు ఆగకుండా, చిరాకుగా ఉంది. డైపర్ లేదా ఏదో అసౌకర్యం ఉండొచ్చు.',
    'mixed': 'ఏడుపు శబ్దం బట్టి స్పష్టంగా చెప్పలేను.',
  };
  const en = {
    'pain': 'Sudden, loud, high-pitched, long screams with breath-holding — sounds like pain or wind.',
    'hunger': 'Rhythmic cry–pause–cry that keeps building — sounds like a hunger cry.',
    'tired': 'Soft, on-and-off whimpering — sounds tired.',
    'fuss': 'Steady, whiny, irregular — sounds like discomfort (nappy, clothes, hot/cold).',
    'mixed': 'The sound alone is not clear.',
  };
  return CrySound(pain, hunger, tired, fuss, kind, te[kind]!, en[kind]!, f0, bursts.length.toDouble(), mb, mp);
}
