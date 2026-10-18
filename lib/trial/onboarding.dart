import 'package:flutter/material.dart';

import '../chat.dart';
import '../store.dart';
import 'astro.dart';
import 'ui.dart';

/// First-run setup for any family: language, baby details, who is using this phone.
class Onboarding extends StatefulWidget {
  final VoidCallback onDone;
  const Onboarding({super.key, required this.onDone});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final pc = PageController();
  int step = 0;
  String lang = 'en';
  final baby = TextEditingController();
  final me = TextEditingController();
  String gender = 'girl';
  DateTime? date;
  TimeOfDay? time;
  int city = 0;
  String role = 'Amma';
  String stage = 'born';
  DateTime? due;

  static const roles = [
    ('Amma', 'అమ్మ'), ('Nanna', 'నాన్న'), ('Ammamma', 'అమ్మమ్మ'), ('Nanamma', 'నానమ్మ'),
    ('Tatayya', 'తాతయ్య'), ('Atta', 'అత్త'), ('Mavayya', 'మావయ్య'), ('Family', 'కుటుంబం'),
  ];

  bool get te => lang == 'te';
  String t(String en, String tel) => te ? tel : en;

  void next() {
    if (step == 1 && stage == 'pregnant' && due == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Please add the due date or last period date', 'దయచేసి డ్యూ డేట్ లేదా చివరి పీరియడ్ తేదీ ఇవ్వండి'))));
      return;
    }
    if (step == 1 && stage == 'born' && (baby.text.trim().isEmpty || date == null)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Please add the baby\'s name and birth date', 'దయచేసి బిడ్డ పేరు, పుట్టిన తేదీ ఇవ్వండి'))));
      return;
    }
    if (step == 2) {
      finish();
      return;
    }
    setState(() => step++);
    pc.animateToPage(step, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  Future<void> finish() async {
    final s = Store.i;
    final c = cities[city];
    final tm = time ?? const TimeOfDay(hour: 12, minute: 0);
    if (stage == 'pregnant') {
      await s.setProfile({
        'name': baby.text.trim().isEmpty ? t('Bujji', 'బుజ్జి') : baby.text.trim(),
        'stage': 'pregnant',
        'dueDate': '${due!.year}-${due!.month.toString().padLeft(2, '0')}-${due!.day.toString().padLeft(2, '0')}',
        'place': c.$1,
        'lat': c.$2,
        'lon': c.$3,
      });
    } else {
    await s.setProfile({
      'stage': 'born',
      'name': baby.text.trim(),
      'gender': gender,
      'birthDate': '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
      'birthTime': '${tm.hour.toString().padLeft(2, '0')}:${tm.minute.toString().padLeft(2, '0')}',
      'timeKnown': time != null,
      'place': c.$1,
      'lat': c.$2,
      'lon': c.$3,
    });
    }
    s.d['events'] = <dynamic>[]; // no family-specific events in a fresh app
    await s.setSetting('tLang', lang);
    await s.setSetting('tRole', role);
    final name = me.text.trim().isEmpty ? role : me.text.trim();
    await s.setSetting('tMe', name);
    try {
      await Chat.i.setName(name);
    } catch (_) {}
    await s.setSetting('tOnboarded', true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: Row(children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(color: i <= step ? K.indigo : Colors.white, borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: PageView(controller: pc, physics: const NeverScrollableScrollPhysics(), children: [_lang(), _baby(), _me()]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(children: [
              if (step > 0)
                TextButton(
                  onPressed: () {
                    setState(() => step--);
                    pc.animateToPage(step, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  },
                  child: Text(t('Back', 'వెనక్కి')),
                ),
              const Spacer(),
              FilledButton(onPressed: next, child: Text(step == 2 ? t('Start', 'మొదలుపెట్టండి') : t('Next', 'తర్వాత'))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _lang() {
    return ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 20),
      ClayBox(
        color: K.indigo,
        padding: const EdgeInsets.all(26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Little One', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(t('Your baby, your family, your language.', 'మీ బిడ్డ, మీ కుటుంబం, మీ భాష.'), style: const TextStyle(color: Colors.white, fontSize: 16)),
        ]),
      ),
      const SizedBox(height: 30),
      Text(t('Choose your language', 'మీ భాష ఎంచుకోండి'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      for (final l in const [('en', 'English'), ('te', 'తెలుగు')])
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ClayBox(
            onTap: () => setState(() => lang = l.$1),
            color: lang == l.$1 ? K.pink : K.card,
            child: Row(children: [
              Text(l.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const Spacer(),
              Icon(lang == l.$1 ? Icons.check_circle : Icons.circle_outlined, color: K.indigo),
            ]),
          ),
        ),
      Text(t('More languages coming: Hindi, Tamil, Malayalam, Kannada.', 'మరిన్ని భాషలు త్వరలో: హిందీ, తమిళం, మలయాళం, కన్నడ.'), style: const TextStyle(color: K.muted)),
    ]);
  }

  Widget _baby() {
    String two(int n) => n.toString().padLeft(2, '0');
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text(t('About your baby', 'మీ బిడ్డ గురించి'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _stage('pregnant', t('Expecting', 'గర్భిణి'), Icons.pregnant_woman)),
        const SizedBox(width: 14),
        Expanded(child: _stage('born', t('Baby is born', 'బిడ్డ పుట్టింది'), Icons.child_friendly)),
      ]),
      const SizedBox(height: 16),
      if (stage == 'pregnant') ..._expecting() else ...[
      TextField(controller: baby, textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: t('Baby\'s name (or pet name)', 'బిడ్డ పేరు (లేదా ముద్దు పేరు)'), prefixIcon: const Icon(Icons.child_care))),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _choice('girl', t('Baby girl', 'పాప'), Icons.face_3)),
        const SizedBox(width: 14),
        Expanded(child: _choice('boy', t('Baby boy', 'బాబు'), Icons.face_6)),
      ]),
      const SizedBox(height: 16),
      ClayBox(
        onTap: () async {
          final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 280)), initialDate: date ?? DateTime.now());
          if (d != null) setState(() => date = d);
        },
        child: Row(children: [
          const Icon(Icons.cake, color: K.indigo),
          const SizedBox(width: 12),
          Expanded(child: Text(date == null ? t('Birth date', 'పుట్టిన తేదీ') : '${date!.day}-${two(date!.month)}-${date!.year}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right),
        ]),
      ),
      const SizedBox(height: 14),
      ClayBox(
        onTap: () async {
          final tm = await showTimePicker(context: context, initialTime: time ?? const TimeOfDay(hour: 12, minute: 0));
          if (tm != null) setState(() => time = tm);
        },
        child: Row(children: [
          const Icon(Icons.schedule, color: K.indigo),
          const SizedBox(width: 12),
          Expanded(child: Text(time == null ? t('Birth time (for jatakam)', 'పుట్టిన సమయం (జాతకం కోసం)') : time!.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right),
        ]),
      ),
      const SizedBox(height: 14),
      ClayBox(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Row(children: [
          const Icon(Icons.place, color: K.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<int>(
              value: city,
              isExpanded: true,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(20),
              items: [for (var i = 0; i < cities.length; i++) DropdownMenuItem(value: i, child: Text(cities[i].$1))],
              onChanged: (v) => setState(() => city = v ?? 0),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Text(t('Birth place: pick the nearest city.', 'పుట్టిన ఊరు: దగ్గరలోని నగరం ఎంచుకోండి.'), style: const TextStyle(color: K.muted, fontSize: 12)),
      ],
    ]);
  }

  Widget _stage(String v, String label, IconData icon) {
    final on = stage == v;
    return ClayBox(
      onTap: () => setState(() => stage = v),
      color: on ? K.pink : K.card,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(children: [Icon(icon, color: K.indigo, size: 30), const SizedBox(height: 4), Text(label, style: const TextStyle(fontWeight: FontWeight.w700))]),
    );
  }

  List<Widget> _expecting() {
    String fmt(DateTime d) => '${d.day}-${d.month.toString().padLeft(2, '0')}-${d.year}';
    return [
      TextField(controller: baby, textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: t('A pet name for the baby (e.g. Bujji)', 'బిడ్డకు ముద్దు పేరు (ఉదా. బుజ్జి)'), prefixIcon: const Icon(Icons.favorite))),
      const SizedBox(height: 14),
      ClayBox(
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(context: context, firstDate: now.subtract(const Duration(days: 14)), lastDate: now.add(const Duration(days: 290)), initialDate: due ?? now.add(const Duration(days: 150)), helpText: t('Due date', 'డ్యూ డేట్'));
          if (d != null) setState(() => due = d);
        },
        child: Row(children: [
          const Icon(Icons.event, color: K.indigo),
          const SizedBox(width: 12),
          Expanded(child: Text(due == null ? t('Due date', 'డ్యూ డేట్') : '${t('Due', 'డ్యూ')}: ${fmt(due!)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right),
        ]),
      ),
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: () async {
          final now = DateTime.now();
          final d = await showDatePicker(context: context, firstDate: now.subtract(const Duration(days: 300)), lastDate: now, initialDate: now.subtract(const Duration(days: 60)), helpText: t('First day of last period', 'చివరి పీరియడ్ మొదటి రోజు'));
          if (d != null) setState(() => due = d.add(const Duration(days: 280)));
        },
        icon: const Icon(Icons.calculate),
        label: Text(t('Don\'t know the due date? Use the last period date', 'డ్యూ డేట్ తెలియదా? చివరి పీరియడ్ తేదీతో లెక్కించండి')),
      ),
      const SizedBox(height: 10),
      ClayBox(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Row(children: [
          const Icon(Icons.local_hospital, color: K.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<int>(
              value: city,
              isExpanded: true,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(20),
              items: [for (var i = 0; i < cities.length; i++) DropdownMenuItem(value: i, child: Text(cities[i].$1))],
              onChanged: (v) => setState(() => city = v ?? 0),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Text(t('City where the baby will be born (for the jatakam).', 'బిడ్డ పుట్టబోయే ఊరు (జాతకం కోసం).'), style: const TextStyle(color: K.muted, fontSize: 12)),
    ];
  }

  Widget _choice(String g, String label, IconData icon) {
    final on = gender == g;
    return ClayBox(
      onTap: () => setState(() => gender = g),
      color: on ? K.indigo : K.card,
      child: Column(children: [
        Icon(icon, size: 36, color: on ? Colors.white : K.indigo),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: on ? Colors.white : K.ink)),
      ]),
    );
  }

  Widget _me() {
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text(t('Who is using this phone?', 'ఈ ఫోన్ ఎవరిది?'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 12, children: [for (final r in roles) Pill(te ? r.$2 : r.$1, on: role == r.$1, onTap: () => setState(() => role = r.$1))]),
      const SizedBox(height: 20),
      TextField(controller: me, textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: t('Your name (shown in family chat)', 'మీ పేరు (ఫ్యామిలీ చాట్‌లో కనిపిస్తుంది)'), prefixIcon: const Icon(Icons.person))),
      const SizedBox(height: 24),
      ClayBox(
        color: K.pinkSoft,
        child: Row(children: [
          const Icon(Icons.lock, color: K.indigo),
          const SizedBox(width: 12),
          Expanded(child: Text(t('Your baby\'s details stay on this phone. Cry listening happens only on the phone. Family chat is encrypted.', 'మీ బిడ్డ వివరాలు ఈ ఫోన్‌లోనే ఉంటాయి. ఏడుపు వినడం ఫోన్‌లోనే జరుగుతుంది. ఫ్యామిలీ చాట్ ఎన్‌క్రిప్ట్ చేయబడింది.'), style: const TextStyle(fontSize: 13))),
        ]),
      ),
    ]);
  }
}
