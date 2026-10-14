import 'store.dart';

class Vax {
  final String key, label;
  final int days, months;
  final List<String> items;
  const Vax(this.key, this.label, this.items, {this.days = 0, this.months = 0});
  DateTime due(DateTime b) => months > 0 ? DateTime(b.year, b.month + months, b.day) : b.add(Duration(days: days));
}

const vaccines = <Vax>[
  Vax('birth', 'At birth', ['BCG', 'OPV 0', 'Hepatitis B 1']),
  Vax('w6', '6 weeks', ['DTP 1', 'IPV 1', 'Hepatitis B 2', 'Hib 1', 'Rotavirus 1', 'PCV 1'], days: 42),
  Vax('w10', '10 weeks', ['DTP 2', 'IPV 2', 'Hepatitis B 3', 'Hib 2', 'Rotavirus 2', 'PCV 2'], days: 70),
  Vax('w14', '14 weeks', ['DTP 3', 'IPV 3', 'Hepatitis B 4', 'Hib 3', 'Rotavirus 3', 'PCV 3'], days: 98),
  Vax('m6', '6 months', ['Influenza 1', 'Typhoid conjugate'], months: 6),
  Vax('m7', '7 months', ['Influenza 2'], months: 7),
  Vax('m9', '9 months', ['MMR 1'], months: 9),
  Vax('m12', '12 months', ['Hepatitis A 1'], months: 12),
  Vax('m15', '15 months', ['MMR 2', 'Varicella 1', 'PCV booster'], months: 15),
  Vax('m16', '16–18 months', ['DTP booster 1', 'Hib booster', 'IPV booster'], months: 16),
  Vax('m18', '18–19 months', ['Hepatitis A 2', 'Varicella 2'], months: 18),
];

/// What each vaccine protects against and how it is given.
const vaxInfo = <String, List<String>>{
  'BCG': ['క్షయ (TB)', 'Tuberculosis', 'Injection, left upper arm. A small bump or scar forms in 4–6 weeks; that is normal.'],
  'OPV': ['పోలియో', 'Polio', 'Drops by mouth.'],
  'IPV': ['పోలియో', 'Polio', 'Injection in the thigh or arm.'],
  'Hepatitis B': ['హెపటైటిస్ B (కాలేయం)', 'Hepatitis B liver infection', 'Injection in the thigh.'],
  'DTP': ['డిఫ్తీరియా, ధనుర్వాతం, కోరింత దగ్గు', 'Diphtheria, tetanus, whooping cough', 'Injection in the thigh. Mild fever and soreness for a day are common.'],
  'Hib': ['మెదడువాపు, న్యుమోనియా', 'Hib meningitis and pneumonia', 'Injection, often combined with DTP.'],
  'Rotavirus': ['తీవ్రమైన విరేచనాలు', 'Severe diarrhoea', 'Drops by mouth.'],
  'PCV': ['న్యుమోనియా, చెవి ఇన్ఫెక్షన్లు', 'Pneumonia, ear infections, meningitis', 'Injection in the thigh.'],
  'Influenza': ['ఫ్లూ జ్వరం', 'Flu', 'Injection. Two doses a month apart the first year, then yearly.'],
  'Typhoid conjugate': ['టైఫాయిడ్', 'Typhoid fever', 'Injection.'],
  'MMR': ['తట్టు, గవదబిళ్ళలు, రుబెల్లా', 'Measles, mumps, rubella', 'Injection. A mild rash or fever a week later can happen.'],
  'Hepatitis A': ['హెపటైటిస్ A (కామెర్లు)', 'Hepatitis A (jaundice)', 'Injection.'],
  'Varicella': ['ఆటలమ్మ / చికెన్ పాక్స్', 'Chickenpox', 'Injection.'],
};

List<String>? infoFor(String item) {
  for (final k in vaxInfo.keys) {
    if (item.startsWith(k)) return vaxInfo[k];
  }
  return null;
}

const rasiTe = ['మేషం', 'వృషభం', 'మిథునం', 'కర్కాటకం', 'సింహం', 'కన్య', 'తుల', 'వృశ్చికం', 'ధనుస్సు', 'మకరం', 'కుంభం', 'మీనం'];
const nakTe = ['అశ్విని', 'భరణి', 'కృత్తిక', 'రోహిణి', 'మృగశిర', 'ఆరుద్ర', 'పునర్వసు', 'పుష్యమి', 'ఆశ్లేష', 'మఖ', 'పుబ్బ', 'ఉత్తర', 'హస్త', 'చిత్త', 'స్వాతి', 'విశాఖ', 'అనూరాధ', 'జ్యేష్ఠ', 'మూల', 'పూర్వాషాఢ', 'ఉత్తరాషాఢ', 'శ్రవణం', 'ధనిష్ఠ', 'శతభిషం', 'పూర్వాభాద్ర', 'ఉత్తరాభాద్ర', 'రేవతి'];
const planets = [
  ['Lagna', 'లగ్నం', 'లగ్నం'], ['Sun', 'రవి', 'రవి'], ['Moon', 'చంద్రుడు', 'చంద్ర'], ['Mars', 'కుజుడు', 'కుజ'], ['Mercury', 'బుధుడు', 'బుధ'],
  ['Jupiter', 'గురువు', 'గురు'], ['Venus', 'శుక్రుడు', 'శుక్ర'], ['Saturn', 'శని', 'శని'], ['Rahu', 'రాహువు', 'రాహు'], ['Ketu', 'కేతువు', 'కేతు'],
];

String ageText(DateTime? b) {
  if (b == null) return '';
  final now = DateTime.now();
  final t = DateTime(now.year, now.month, now.day);
  final days = t.difference(DateTime(b.year, b.month, b.day)).inDays;
  if (days < 0) return 'Arriving in ${-days} days';
  if (days == 0) return 'Born today';
  if (days < 91) {
    final w = days ~/ 7, d = days % 7;
    return [if (w > 0) '$w week${w > 1 ? 's' : ''}', if (d > 0) '$d day${d > 1 ? 's' : ''}'].join(', ') + ' old';
  }
  var mo = (t.year - b.year) * 12 + t.month - b.month;
  if (t.day < b.day) mo--;
  if (mo < 24) return '$mo months old';
  return '${mo ~/ 12} years, ${mo % 12} months old';
}

int dayNumber(DateTime? b) {
  if (b == null) return 0;
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).difference(DateTime(b.year, b.month, b.day)).inDays + 1;
}

String hm(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
}

const months3 = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String dmy(DateTime t) => '${t.day} ${months3[t.month - 1]} ${t.year}';
String ymd(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

class CryReason {
  final double score;
  final String te, en, why, todo, say;
  CryReason(this.score, this.te, this.en, this.why, this.todo, this.say);
}

/// Most likely reasons for crying, from her feed / nappy / sleep log, the hour and her age.
List<CryReason> cryReasons() {
  final s = Store.i, now = DateTime.now(), hr = now.hour;
  final interval = (s.settings['interval'] as num?)?.toInt() ?? 150;
  final lf = s.last('feeds'), ln = s.last('nappies'), ls = s.last('sleeps');
  final since = lf == null ? null : now.difference(lf).inMinutes;
  final nap = ln == null ? null : now.difference(ln).inMinutes;
  final b = s.birth;
  final ageDays = b == null ? null : now.difference(b).inDays;
  String ago(int m) => m >= 60 ? '${m ~/ 60} గంటల ${m % 60} నిమిషాల' : '$m నిమిషాల';
  final r = <CryReason>[];
  if (since == null) {
    r.add(CryReason(60, 'ఆకలి', 'Hungry', 'No feed logged yet, so check hunger first.', 'Offer a feed. Newborns feed 8–12 times a day.', 'పాపకి ఆకలిగా ఉండవచ్చు. పాలు పట్టి చూడండి.'));
  } else if (since >= interval - 30) {
    r.add(CryReason((95 + ((since - interval) / 6).clamp(0, 20)).toDouble(), 'ఆకలి', 'Hungry', 'Last feed was ${since ~/ 60} h ${since % 60} min ago.', 'Feed her now. Early signs: sucking fists, turning to the breast.', 'పాపకి ఆకలిగా ఉంది. చివరిగా ${ago(since)} క్రితం పాలు పట్టారు. పాలు పట్టండి.'));
  } else if (since <= 45) {
    r.add(CryReason(85, 'తేన్పు / గ్యాస్', 'Burp or wind', since < 2 ? 'She was just fed.' : 'She was fed $since min ago, so trapped air is likely.', 'Hold her upright on your shoulder and pat her back for 5–10 minutes. Gently cycle her legs.', '${since < 2 ? 'ఇప్పుడే పాలు తాగింది.' : 'పాలు తాగి $since నిమిషాలే అయింది.'} తేన్పు రావాలేమో. భుజం మీద వేసుకుని వీపు తట్టండి.'));
  } else {
    r.add(CryReason(45, 'ఆకలి', 'Hungry', 'Last feed was $since min ago. Some babies cluster-feed.', 'If she roots or sucks her fists, offer a feed early.', 'పాపకి మళ్ళీ ఆకలి వేసి ఉండవచ్చు.'));
  }
  if (nap == null || nap > 120) {
    r.add(CryReason(nap == null ? 70 : 80, 'డైపర్', 'Wet or dirty nappy', nap == null ? 'Nappy changes are not logged yet.' : 'Last nappy change was ${nap ~/ 60} h ${nap % 60} min ago.', 'Check and change her nappy; keep the skin dry.', 'డైపర్ తడిగా ఉందేమో చూడండి.'));
  } else {
    r.add(CryReason(35, 'డైపర్', 'Wet or dirty nappy', 'Nappy was changed $nap min ago, but check anyway.', 'Check for a dirty nappy or a tight fold.', 'డైపర్ ఒకసారి చూడండి.'));
  }
  final awake = ls == null ? null : now.difference(ls).inMinutes;
  if (hr >= 21 || hr < 5 || (awake != null && awake > 90)) {
    r.add(CryReason(72, 'నిద్ర', 'Tired', awake != null && awake > 90 ? 'She has been awake about ${awake ~/ 60} h ${awake % 60} min.' : 'It is night, and overtired babies cry harder.', 'Dim the lights, rock gently and play the jola paata.', 'పాపకి నిద్ర వస్తోంది. లైట్ తగ్గించి జోల పాడండి.'));
  } else {
    r.add(CryReason(50, 'నిద్ర', 'Tired', 'Newborns get tired after 45–90 minutes awake.', 'Look for yawning and staring; rock her in a quiet, dim room.', 'పాపకి నిద్ర వస్తుండవచ్చు.'));
  }
  if (hr >= 17 && hr <= 23 && ageDays != null && ageDays >= 10 && ageDays <= 120) {
    r.add(CryReason(66, 'సాయంత్రం ఏడుపు', 'Evening fussiness or colic', 'Crying peaks between 2 weeks and 4 months, often in the evening.', 'Hold her skin-to-skin, walk with her, gentle shushing, warm bath. It passes by 3–4 months.', 'సాయంత్రం ఏడుపు ఈ వయసులో సాధారణం. ఎత్తుకుని నెమ్మదిగా నడవండి.'));
  }
  r.add(CryReason(48, 'ఎత్తుకోవాలని', 'Wants cuddles', 'Sometimes she just needs your warmth.', 'Pick her up, hold her close, talk and sing softly.', 'అమ్మ ఒడి కావాలేమో. ఎత్తుకోండి.'));
  r.add(CryReason(42, 'వేడి / చలి', 'Too hot or cold', 'Babies can\'t control temperature well.', 'Feel the back of her neck: sweaty means remove a layer; cold means add one.', 'వేడిగా లేదా చలిగా ఉందేమో మెడ వెనుక తాకి చూడండి.'));
  r.add(CryReason(30, 'ఎక్కువ శబ్దం', 'Overstimulated', 'Too many people, noise or light can overwhelm her.', 'Move to a quiet, dim room.', 'చుట్టూ చాలా శబ్దం ఉంది. నిశ్శబ్దమైన గదికి తీసుకెళ్ళండి.'));
  r.sort((a, b) => b.score.compareTo(a.score));
  return r;
}

const places = <String, List<double>>{
  'Nellore': [14.44, 79.99], 'Hyderabad': [17.385, 78.4867], 'Vijayawada': [16.5062, 80.648], 'Visakhapatnam': [17.6868, 83.2185],
  'Guntur': [16.3067, 80.4365], 'Tirupati': [13.6288, 79.4192], 'Chennai': [13.0827, 80.2707], 'Bengaluru': [12.9716, 77.5946],
};
