import 'dart:math' as math;

/// Small, offline Vedic birth-chart calculator: Sun, Moon and Lagna (sidereal, Lahiri ayanamsa),
/// nakshatra + pada, rasi, tithi, weekday, name letters and Vimshottari dasa.
/// Accuracy: Moon about 0.02°, Lagna about 0.01° (checked against a full ephemeris).
class Birth {
  final DateTime local; // birth date and time as on the clock
  final double lat, lon, tz; // tz = hours ahead of UTC (India 5.5)
  Birth(this.local, this.lat, this.lon, {this.tz = 5.5});
}

class Chart {
  final double sun, moon, lagna, ayanamsa;
  final int nak, pada, rasi, lagnaRasi, sunRasi, tithi, weekday;
  final DateTime birthLocal;
  Chart._(this.sun, this.moon, this.lagna, this.ayanamsa, this.nak, this.pada, this.rasi, this.lagnaRasi, this.sunRasi, this.tithi, this.weekday, this.birthLocal);

  /// Vimshottari dasa periods from birth: (lord, start, end).
  List<(String, DateTime, DateTime)> dasas({int count = 9}) {
    final span = 360 / 27;
    final into = (moon % span) / span; // fraction of the nakshatra already passed
    final first = nak % 9;
    final out = <(String, DateTime, DateTime)>[];
    var t = birthLocal;
    for (var i = 0; i < count; i++) {
      final k = (first + i) % 9;
      final yrs = Astro.dasaYears[k] * (i == 0 ? (1 - into) : 1.0);
      final end = t.add(Duration(minutes: (yrs * 365.25 * 24 * 60).round()));
      out.add((Astro.dasaLords[k], t, end));
      t = end;
    }
    return out;
  }
}

class Astro {
  static const dasaLords = ['Ketu', 'Venus', 'Sun', 'Moon', 'Mars', 'Rahu', 'Jupiter', 'Saturn', 'Mercury'];
  static const dasaLordsTe = ['కేతు', 'శుక్ర', 'రవి', 'చంద్ర', 'కుజ', 'రాహు', 'గురు', 'శని', 'బుధ'];
  static const dasaYears = [7.0, 20.0, 6.0, 10.0, 7.0, 18.0, 16.0, 19.0, 17.0];

  static const nakEn = ['Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra', 'Punarvasu', 'Pushya', 'Ashlesha', 'Magha', 'Purva Phalguni', 'Uttara Phalguni', 'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha', 'Jyeshtha', 'Moola', 'Purva Ashadha', 'Uttara Ashadha', 'Shravana', 'Dhanishta', 'Shatabhisha', 'Purva Bhadrapada', 'Uttara Bhadrapada', 'Revati'];
  static const nakTe = ['అశ్విని', 'భరణి', 'కృత్తిక', 'రోహిణి', 'మృగశిర', 'ఆరుద్ర', 'పునర్వసు', 'పుష్యమి', 'ఆశ్లేష', 'మఖ', 'పుబ్బ', 'ఉత్తర', 'హస్త', 'చిత్త', 'స్వాతి', 'విశాఖ', 'అనూరాధ', 'జ్యేష్ఠ', 'మూల', 'పూర్వాషాఢ', 'ఉత్తరాషాఢ', 'శ్రవణం', 'ధనిష్ఠ', 'శతభిషం', 'పూర్వాభాద్ర', 'ఉత్తరాభాద్ర', 'రేవతి'];
  static const rasiEn = ['Mesha (Aries)', 'Vrishabha (Taurus)', 'Mithuna (Gemini)', 'Karka (Cancer)', 'Simha (Leo)', 'Kanya (Virgo)', 'Tula (Libra)', 'Vrischika (Scorpio)', 'Dhanu (Sagittarius)', 'Makara (Capricorn)', 'Kumbha (Aquarius)', 'Meena (Pisces)'];
  static const rasiShort = ['Mesha', 'Vrishabha', 'Mithuna', 'Karka', 'Simha', 'Kanya', 'Tula', 'Vrischika', 'Dhanu', 'Makara', 'Kumbha', 'Meena'];
  static const rasiTe = ['మేషం', 'వృషభం', 'మిథునం', 'కర్కాటకం', 'సింహం', 'కన్య', 'తుల', 'వృశ్చికం', 'ధనుస్సు', 'మకరం', 'కుంభం', 'మీనం'];
  static const tithiEn = ['Prathama', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami', 'Shashthi', 'Saptami', 'Ashtami', 'Navami', 'Dashami', 'Ekadashi', 'Dwadashi', 'Trayodashi', 'Chaturdashi'];
  static const tithiTe = ['పాడ్యమి', 'విదియ', 'తదియ', 'చవితి', 'పంచమి', 'షష్ఠి', 'సప్తమి', 'అష్టమి', 'నవమి', 'దశమి', 'ఏకాదశి', 'ద్వాదశి', 'త్రయోదశి', 'చతుర్దశి'];
  static const varaEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const varaTe = ['సోమవారం', 'మంగళవారం', 'బుధవారం', 'గురువారం', 'శుక్రవారం', 'శనివారం', 'ఆదివారం'];

  /// First letters for the name, by nakshatra and pada (traditional avakahada chakra).
  static const letters = [
    ['Chu', 'Che', 'Cho', 'La'], ['Li', 'Lu', 'Le', 'Lo'], ['A', 'I', 'U', 'E'], ['O', 'Va', 'Vi', 'Vu'],
    ['Ve', 'Vo', 'Ka', 'Ki'], ['Ku', 'Gha', 'Na', 'Chha'], ['Ke', 'Ko', 'Ha', 'Hi'], ['Hu', 'He', 'Ho', 'Da'],
    ['Di', 'Du', 'De', 'Do'], ['Ma', 'Mi', 'Mu', 'Me'], ['Mo', 'Ta', 'Ti', 'Tu'], ['Te', 'To', 'Pa', 'Pi'],
    ['Pu', 'Sha', 'Na', 'Tha'], ['Pe', 'Po', 'Ra', 'Ri'], ['Ru', 'Re', 'Ro', 'Ta'], ['Ti', 'Tu', 'Te', 'To'],
    ['Na', 'Ni', 'Nu', 'Ne'], ['No', 'Ya', 'Yi', 'Yu'], ['Ye', 'Yo', 'Bha', 'Bhi'], ['Bhu', 'Dha', 'Pha', 'Dha'],
    ['Bhe', 'Bho', 'Ja', 'Ji'], ['Ju', 'Je', 'Jo', 'Gha'], ['Ga', 'Gi', 'Gu', 'Ge'], ['Go', 'Sa', 'Si', 'Su'],
    ['Se', 'So', 'Da', 'Di'], ['Du', 'Tha', 'Jha', 'Da'], ['De', 'Do', 'Cha', 'Chi'],
  ];
  static const lettersTe = [
    ['చు', 'చే', 'చో', 'ల'], ['లి', 'లు', 'లే', 'లో'], ['అ', 'ఇ', 'ఉ', 'ఎ'], ['ఒ', 'వ', 'వి', 'వు'],
    ['వే', 'వో', 'క', 'కి'], ['కు', 'ఘ', 'ఙ', 'ఛ'], ['కే', 'కో', 'హ', 'హి'], ['హు', 'హే', 'హో', 'డ'],
    ['డి', 'డు', 'డే', 'డో'], ['మ', 'మి', 'ము', 'మే'], ['మో', 'ట', 'టి', 'టు'], ['టే', 'టో', 'ప', 'పి'],
    ['పు', 'ష', 'ణ', 'ఠ'], ['పే', 'పో', 'ర', 'రి'], ['రు', 'రే', 'రో', 'త'], ['తి', 'తు', 'తే', 'తో'],
    ['న', 'ని', 'ను', 'నే'], ['నో', 'య', 'యి', 'యు'], ['యే', 'యో', 'భ', 'భి'], ['భు', 'ధ', 'ఫ', 'ఢ'],
    ['భే', 'భో', 'జ', 'జి'], ['జు', 'జే', 'జో', 'ఘ'], ['గ', 'గి', 'గు', 'గే'], ['గో', 'స', 'సి', 'సు'],
    ['సే', 'సో', 'ద', 'ది'], ['దు', 'థ', 'ఝ', 'ద'], ['దే', 'దో', 'చ', 'చి'],
  ];

  static double _norm(double x) => ((x % 360) + 360) % 360;
  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;

  static double _jd(DateTime utc) {
    var y = utc.year, m = utc.month;
    final d = utc.day + (utc.hour + utc.minute / 60 + utc.second / 3600) / 24;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + d + b - 1524.5;
  }

  static double _sun(double t) {
    final l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
    final m = _rad(357.52911 + 35999.05029 * t - 0.0001537 * t * t);
    final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(m) + (0.019993 - 0.000101 * t) * math.sin(2 * m) + 0.000289 * math.sin(3 * m);
    final om = _rad(125.04 - 1934.136 * t);
    return _norm(l0 + c - 0.00569 - 0.00478 * math.sin(om));
  }

  // Meeus, Astronomical Algorithms ch. 47: (D, M, M', F, coefficient × 1e-6 degrees)
  static const _lt = [
    [0, 0, 1, 0, 6288774], [2, 0, -1, 0, 1274027], [2, 0, 0, 0, 658314], [0, 0, 2, 0, 213618], [0, 1, 0, 0, -185116], [0, 0, 0, 2, -114332],
    [2, 0, -2, 0, 58793], [2, -1, -1, 0, 57066], [2, 0, 1, 0, 53322], [2, -1, 0, 0, 45758], [0, 1, -1, 0, -40923], [1, 0, 0, 0, -34720],
    [0, 1, 1, 0, -30383], [2, 0, 0, -2, 15327], [0, 0, 1, 2, -12528], [0, 0, 1, -2, 10980], [4, 0, -1, 0, 10675], [0, 0, 3, 0, 10034],
    [4, 0, -2, 0, 8548], [2, 1, -1, 0, -7888], [2, 1, 0, 0, -6766], [1, 0, -1, 0, -5163], [1, 1, 0, 0, 4987], [2, -1, 1, 0, 4036],
    [2, 0, 2, 0, 3994], [4, 0, 0, 0, 3861], [2, 0, -3, 0, 3665], [0, 1, -2, 0, -2689], [2, 0, -1, 2, -2602], [2, -1, -2, 0, 2390],
    [1, 0, 1, 0, -2348], [2, -2, 0, 0, 2236], [0, 1, 2, 0, -2120], [0, 2, 0, 0, -2069], [2, -2, -1, 0, 2048], [2, 0, 1, -2, -1773],
    [2, 0, 0, 2, -1595], [4, -1, -1, 0, 1215], [0, 0, 2, 2, -1110], [3, 0, -1, 0, -892], [2, 1, 1, 0, -810], [4, -1, -2, 0, 759],
    [0, 2, -1, 0, -713], [2, 2, -1, 0, -700], [2, 1, -2, 0, 691], [2, -1, 0, -2, 596], [4, 0, 1, 0, 549], [0, 0, 4, 0, 537],
    [4, -1, 0, 0, 520], [1, 0, -2, 0, -487], [2, 1, 0, -2, -399], [0, 0, 2, -2, -381], [1, 1, 1, 0, 351], [3, 0, -2, 0, -340],
    [4, 0, -3, 0, 330], [2, -1, 2, 0, 327], [0, 2, 1, 0, -323], [1, 1, -1, 0, 299], [2, 0, 3, 0, 294],
  ];

  static double _moon(double t) {
    final lp = 218.3164477 + 481267.88123421 * t - 0.0015786 * t * t;
    final d = _rad(297.8501921 + 445267.1114034 * t - 0.0018819 * t * t);
    final m = _rad(357.5291092 + 35999.0502909 * t - 0.0001536 * t * t);
    final mp = _rad(134.9633964 + 477198.8675055 * t + 0.0087414 * t * t);
    final f = _rad(93.2720950 + 483202.0175233 * t - 0.0036539 * t * t);
    final e = 1 - 0.002516 * t - 0.0000074 * t * t;
    var s = 0.0;
    for (final r in _lt) {
      final em = r[1].abs() == 1 ? e : (r[1].abs() == 2 ? e * e : 1.0);
      s += r[4] * em * math.sin(r[0] * d + r[1] * m + r[2] * mp + r[3] * f);
    }
    final a1 = _rad(119.75 + 131.849 * t), a2 = _rad(53.09 + 479264.29 * t);
    s += 3958 * math.sin(a1) + 1962 * math.sin(_rad(lp) - f) + 318 * math.sin(a2);
    final om = _rad(125.04452 - 1934.136261 * t);
    return _norm(lp + s / 1e6 - 0.00478 * math.sin(om));
  }

  static Chart compute(Birth b) {
    final utc = DateTime.utc(b.local.year, b.local.month, b.local.day, b.local.hour, b.local.minute).subtract(Duration(minutes: (b.tz * 60).round()));
    final jdUt = _jd(utc);
    final jdTt = jdUt + 69.0 / 86400; // ΔT ≈ 69 s
    final t = (jdTt - 2451545) / 36525;
    final ay = 23.853 + t * 100 * 0.0139694; // Lahiri
    final sunT = _sun(t), moonT = _moon(t);
    final tu = (jdUt - 2451545) / 36525;
    final gmst = _norm(280.46061837 + 360.98564736629 * (jdUt - 2451545) + 0.000387933 * tu * tu);
    final ramc = _rad(_norm(gmst + b.lon));
    final eps = _rad(23.4392911 - 0.0130042 * t);
    final asc = _norm(_deg(math.atan2(math.cos(ramc), -(math.sin(ramc) * math.cos(eps) + math.tan(_rad(b.lat)) * math.sin(eps)))));
    final sun = _norm(sunT - ay), moon = _norm(moonT - ay), lagna = _norm(asc - ay);
    final span = 360 / 27;
    final nak = (moon / span).floor() % 27;
    final pada = ((moon % span) / (span / 4)).floor() + 1;
    final tithi = (_norm(moonT - sunT) / 12).floor(); // 0..29
    return Chart._(sun, moon, lagna, ay, nak, pada.clamp(1, 4), (moon / 30).floor() % 12, (lagna / 30).floor() % 12, (sun / 30).floor() % 12, tithi, b.local.weekday - 1, b.local);
  }

  static String tithiName(int t, bool te) {
    final paksha = t < 15 ? (te ? 'శుక్ల' : 'Shukla') : (te ? 'కృష్ణ' : 'Krishna');
    final i = t % 15;
    final name = i == 14 ? (t < 15 ? (te ? 'పౌర్ణమి' : 'Purnima') : (te ? 'అమావాస్య' : 'Amavasya')) : (te ? tithiTe[i] : tithiEn[i]);
    return '$paksha $name';
  }
}

/// Indian cities for birth place (latitude, longitude).
const cities = <(String, double, double)>[
  ('Nellore', 14.4426, 79.9865), ('Hyderabad', 17.3850, 78.4867), ('Visakhapatnam', 17.6868, 83.2185), ('Vijayawada', 16.5062, 80.6480),
  ('Guntur', 16.3067, 80.4365), ('Tirupati', 13.6288, 79.4192), ('Kurnool', 15.8281, 78.0373), ('Kakinada', 16.9891, 82.2475),
  ('Rajahmundry', 17.0005, 81.8040), ('Warangal', 17.9689, 79.5941), ('Karimnagar', 18.4386, 79.1288), ('Khammam', 17.2473, 80.1514),
  ('Anantapur', 14.6819, 77.6006), ('Kadapa', 14.4673, 78.8242), ('Ongole', 15.5057, 80.0499), ('Chennai', 13.0827, 80.2707),
  ('Bengaluru', 12.9716, 77.5946), ('Mumbai', 19.0760, 72.8777), ('Delhi', 28.6139, 77.2090), ('Kolkata', 22.5726, 88.3639),
  ('Pune', 18.5204, 73.8567), ('Kochi', 9.9312, 76.2673), ('Thiruvananthapuram', 8.5241, 76.9366), ('Coimbatore', 11.0168, 76.9558),
  ('Madurai', 9.9252, 78.1198), ('Mysuru', 12.2958, 76.6394), ('Ahmedabad', 23.0225, 72.5714), ('Jaipur', 26.9124, 75.7873),
  ('Lucknow', 26.8467, 80.9462), ('Bhubaneswar', 20.2961, 85.8245),
];
