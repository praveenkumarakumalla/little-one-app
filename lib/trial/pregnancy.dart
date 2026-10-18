import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../call.dart';
import '../chat.dart';
import '../data.dart';
import '../store.dart';
import '../voice.dart';
import 'astro.dart';
import 'jatakam.dart';
import 'knowledge.dart';
import 'more.dart';
import 'preg_data.dart';
import 'ui.dart';

// ───────── pregnancy state ─────────
bool get expecting => Store.i.profile['stage'] == 'pregnant';

DateTime? get dueDate => DateTime.tryParse((Store.i.profile['dueDate'] ?? '').toString());

/// Days pregnant (from the last period, 280 days to the due date).
int pregDays() {
  final d = dueDate;
  if (d == null) return 0;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return (280 - d.difference(today).inDays).clamp(0, 300);
}

int pregWeek() => pregDays() ~/ 7;

(int, String, String, String, String, String, String) weekInfo(int w) => pregWeeks.lastWhere((x) => x.$1 <= w.clamp(4, 40), orElse: () => pregWeeks.first);

List<dynamic> _list(String k) {
  Store.i.d.putIfAbsent(k, () => <dynamic>[]);
  return Store.i.d[k] as List;
}

Future<void> _save() => Store.i.save();

// ───────── Home while expecting ─────────
class PregHome extends StatelessWidget {
  final void Function(int tab) goTab;
  const PregHome({super.key, required this.goTab});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, Chat.i]),
      builder: (context, _) {
        final s = Store.i;
        final days = pregDays(), w = days ~/ 7, d = days % 7;
        final info = weekInfo(w);
        final left = (dueDate ?? DateTime.now()).difference(DateTime.now()).inDays + 1;
        final role = (s.settings['tRole'] ?? 'Amma').toString();
        final me = role == 'Family' ? (s.settings['tMe'] ?? '').toString() : role;
        final nick = s.babyName;
        final size = K.te ? info.$3 : info.$2;
        final voiceEn = 'Hello $me! I am $nick. This week I am as big as $size. ${w >= 18 ? 'I can hear your voice, talk to me!' : 'I am growing every day!'}';
        final voiceTe = 'హలో $me! నేను $nick ని. ఈ వారం నేను $size ఉన్నాను. ${w >= 18 ? 'నీ గొంతు నాకు వినిపిస్తోంది, నాతో మాట్లాడు!' : 'రోజూ పెరుగుతున్నాను!'}';
        final next = pregCheckups.where((c) => c.$2 >= w && !_list('pregDone').contains(c.$3)).cast<(int, int, String, String)?>().firstWhere((_) => true, orElse: () => null);
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 130), children: [
              Row(children: [
                ClayBox(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MorePage())), radius: 16, padding: const EdgeInsets.all(10), child: const Icon(Icons.short_text_rounded)),
                const Spacer(),
                Pill(tr('Expecting', 'గర్భిణి'), on: true),
              ]),
              const SizedBox(height: 14),
              Text(tr('Hello, $me!', 'హలో, $me!'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              Text(tr('$left days to meet $nick', '$nick ని కలవడానికి $left రోజులు'), style: const TextStyle(color: K.muted)),
              const SizedBox(height: 14),
              ClayBox(
                color: K.indigo,
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('Week $w · day $d', '$w వారాలు · $d రోజులు'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(tr('Baby is the size of $size', 'బిడ్డ $size ఉంది'), style: const TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('${info.$4}${info.$5.isEmpty ? '' : ' · ${info.$5}'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('${tr('Due', 'డ్యూ డేట్')}: ${dueDate == null ? '' : dmy(dueDate!)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                  Ring(value: days / 280, text: '${(days / 280 * 100).clamp(0, 100).round()}%'),
                ]),
              ),
              const SizedBox(height: 14),
              ClayBox(
                color: K.pinkSoft,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.spa, color: K.indigo),
                  const SizedBox(width: 12),
                  Expanded(child: Text(K.te ? info.$7 : info.$6, style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 14),
              ClayBox(
                onTap: () => Voice.i.say(K.te ? voiceTe : voiceEn, lat: voiceEn, pitch: 1.9),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: K.indigo, shape: BoxShape.circle), child: const Icon(Icons.volume_up, color: Colors.white)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('$nick says from the womb…', 'కడుపులోంచి $nick అంటోంది…'), style: const TextStyle(fontSize: 12, color: K.muted)),
                      Text(K.te ? voiceTe : voiceEn, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                ClayCircle(icon: Icons.call, label: tr('Call', 'కాల్'), onTap: () => _call(context, false)),
                ClayCircle(icon: Icons.videocam, label: tr('Video', 'వీడియో'), onTap: () => _call(context, true)),
                ClayCircle(icon: Icons.chat_bubble, label: tr('Chat', 'చాట్'), dot: Chat.i.unread > 0, onTap: () => goTab(2)),
                ClayCircle(icon: Icons.touch_app, label: tr('Kicks', 'తన్నులు'), onTap: () => goTab(1)),
              ]),
              if (next != null) ...[
                SectionTitle(tr('Next checkup', 'తర్వాతి చెకప్')),
                ClayBox(
                  onTap: () => goTab(1),
                  child: Row(children: [
                    const Icon(Icons.event_available, color: K.indigo, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(K.te ? next.$4 : next.$3, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(tr('Weeks ${next.$1}–${next.$2}', '${next.$1}–${next.$2} వారాలు'), style: const TextStyle(fontSize: 12, color: K.muted)),
                      ]),
                    ),
                  ]),
                ),
              ],
              SectionTitle(tr('Government help', 'ప్రభుత్వ సహాయం')),
              ClayBox(
                color: K.pink,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchemesPage())),
                child: Text(
                    tr('Free checkups on the 9th of every month (PMSMA), Rs 5,000 under PM Matru Vandana Yojana, and help for hospital delivery (JSY). Tap to see how to apply.',
                        'ప్రతి నెల 9వ తేదీన ఉచిత చెకప్ (PMSMA), ప్రధాన మంత్రి మాతృ వందన యోజన కింద రూ. 5,000, హాస్పిటల్ ప్రసవానికి సహాయం (JSY). ఎలా దరఖాస్తు చేయాలో చూడండి.'),
                    style: const TextStyle(color: K.deep, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 22),
              ClayBox(
                color: K.deep,
                onTap: () => showBornSheet(context),
                child: Row(children: [
                  const Text('👶', style: TextStyle(fontSize: 34)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('Baby is born!', 'బిడ్డ పుట్టింది!'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(tr('Tap at birth: saves the exact time, makes the jatakam and tells the family', 'పుట్టగానే నొక్కండి: సమయం సేవ్, జాతకం తయారీ, కుటుంబానికి వార్త'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _call(BuildContext context, bool video) async {
    if (!Chat.i.paired) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('First connect your family in Chat (one-time code).', 'ముందు చాట్‌లో మీ కుటుంబాన్ని కలపండి (ఒక్కసారి కోడ్).'))));
      goTab(2);
      return;
    }
    await Calls.start(context, video: video);
  }
}

// ───────── Care while expecting ─────────
class PregCare extends StatefulWidget {
  const PregCare({super.key});
  @override
  State<PregCare> createState() => _PregCareState();
}

class _PregCareState extends State<PregCare> {
  int view = 0;
  Timer? tick;
  DateTime? kickStart;
  int kicks = 0;
  DateTime? cStart; // contraction in progress

  @override
  void initState() {
    super.initState();
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (kickStart != null || cStart != null)) setState(() {});
    });
  }

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(tr('Pregnancy care', 'గర్భిణి సంరక్షణ')), automaticallyImplyLeading: false),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 130), children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(children: [
              for (final p in [(0, 'Kicks', 'తన్నులు'), (1, 'Contractions', 'నొప్పులు'), (2, 'Checkups', 'చెకప్‌లు'), (3, 'Hospital bag', 'హాస్పిటల్ బ్యాగ్'), (4, 'Danger signs', 'ప్రమాద సంకేతాలు')]) ...[
                Pill(tr(p.$2, p.$3), on: view == p.$1, onTap: () => setState(() => view = p.$1)),
                const SizedBox(width: 8),
              ],
            ]),
          ),
          const SizedBox(height: 18),
          if (view == 0) ..._kicks(),
          if (view == 1) ..._contractions(context),
          if (view == 2) ..._checkups(),
          if (view == 3) ..._bag(),
          if (view == 4) ..._danger(),
        ]),
      ),
    );
  }

  String _mmss(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  List<Widget> _kicks() {
    final hist = _list('kicks').reversed.take(7).toList();
    final el = kickStart == null ? Duration.zero : DateTime.now().difference(kickStart!);
    return [
      Text(tr('From 28 weeks: once a day, when the baby is usually active, count until 10 movements. Most babies reach 10 within 2 hours.', '28 వారాల నుంచి: రోజుకు ఒకసారి, బిడ్డ చురుకుగా ఉండే సమయంలో 10 కదలికల వరకు లెక్కపెట్టండి. చాలా మంది 2 గంటల్లో 10 చేరతారు.'), style: const TextStyle(color: K.muted, fontSize: 13)),
      const SizedBox(height: 20),
      Center(
        child: GestureDetector(
          onTap: () async {
            setState(() {
              kickStart ??= DateTime.now();
              kicks++;
            });
            if (kicks >= 10) {
              _list('kicks').add({'start': kickStart!.millisecondsSinceEpoch, 'mins': DateTime.now().difference(kickStart!).inMinutes, 'n': kicks});
              await _save();
              setState(() {
                kickStart = null;
                kicks = 0;
              });
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('10 kicks! Saved. Well done, baby!', '10 తన్నులు! సేవ్ అయింది. శభాష్ బుజ్జి!'))));
            }
          },
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [K.violet, K.indigo], center: Alignment(-0.3, -0.4)),
              boxShadow: [BoxShadow(color: K.deep.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 14))],
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$kicks', style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w700)),
              Text(kickStart == null ? tr('Tap at each kick', 'ప్రతి తన్నుకు నొక్కండి') : _mmss(el), style: const TextStyle(color: Colors.white70)),
            ]),
          ),
        ),
      ),
      if (kickStart != null) Center(child: TextButton(onPressed: () => setState(() {
            kickStart = null;
            kicks = 0;
          }), child: Text(tr('Reset', 'మళ్ళీ మొదలు')))),
      SectionTitle(tr('Recent days', 'ఇటీవలి రోజులు')),
      if (hist.isEmpty) Text(tr('No sessions yet.', 'ఇంకా ఏమీ లేదు.'), style: const TextStyle(color: K.muted)),
      for (final h in hist)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClayBox(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(children: [
              Text(dmy(DateTime.fromMillisecondsSinceEpoch((h as Map)['start'] as int))),
              const Spacer(),
              Text(tr('10 kicks in ${h['mins']} min', '${h['mins']} నిమిషాల్లో 10 తన్నులు'), style: const TextStyle(fontWeight: FontWeight.w600, color: K.indigo)),
            ]),
          ),
        ),
      const SizedBox(height: 8),
      Text(tr('If the baby moves much less than usual, go to your doctor or hospital today.', 'బిడ్డ కదలికలు మామూలు కంటే చాలా తక్కువగా ఉంటే, ఈరోజే డాక్టర్ దగ్గరకు లేదా హాస్పిటల్‌కు వెళ్ళండి.'), style: const TextStyle(color: K.bad, fontSize: 12.5, fontWeight: FontWeight.w600)),
    ];
  }

  List<Widget> _contractions(BuildContext context) {
    final list = _list('contractions').cast<Map>().toList();
    final recent = list.where((c) => DateTime.now().millisecondsSinceEpoch - (c['start'] as int) < 2 * 3600 * 1000).toList();
    // intervals between starts of the last contractions
    final gaps = <int>[];
    for (var i = 1; i < recent.length; i++) {
      gaps.add(((recent[i]['start'] as int) - (recent[i - 1]['start'] as int)) ~/ 1000);
    }
    final last3 = gaps.length >= 3 ? gaps.sublist(gaps.length - 3) : <int>[];
    final close = last3.isNotEmpty && last3.every((g) => g <= 300) && recent.sublist(recent.length - 3).every((c) => (c['secs'] as int) >= 45);
    final el = cStart == null ? Duration.zero : DateTime.now().difference(cStart!);
    return [
      Center(
        child: GestureDetector(
          onTap: () async {
            if (cStart == null) {
              setState(() => cStart = DateTime.now());
            } else {
              list.add({'start': cStart!.millisecondsSinceEpoch, 'secs': DateTime.now().difference(cStart!).inSeconds});
              Store.i.d['contractions'] = list;
              await _save();
              setState(() => cStart = null);
            }
          },
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cStart == null ? K.pink : K.bad,
              boxShadow: [BoxShadow(color: (cStart == null ? const Color(0xFFD9A2B4) : K.bad).withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 14))],
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(cStart == null ? tr('Start', 'మొదలు') : _mmss(el), style: TextStyle(color: cStart == null ? K.deep : Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
              Text(cStart == null ? tr('when a contraction starts', 'నొప్పి మొదలైనప్పుడు') : tr('tap when it ends', 'తగ్గినప్పుడు నొక్కండి'), style: TextStyle(color: cStart == null ? K.deep : Colors.white70)),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (close)
        ClayBox(
          color: const Color(0xFFFFE0E0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Contractions are about 5 minutes apart. Time to go to the hospital.', 'నొప్పులు సుమారు 5 నిమిషాలకు ఒకసారి వస్తున్నాయి. హాస్పిటల్‌కు వెళ్ళే సమయం.'), style: const TextStyle(fontWeight: FontWeight.w700, color: K.bad)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: K.bad),
                  onPressed: () async {
                    if (!Chat.i.paired) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Connect your family in Chat first.', 'ముందు చాట్‌లో కుటుంబాన్ని కలపండి.'))));
                      return;
                    }
                    await Chat.i.send(tr('🚨 Contractions are every 5 minutes. We are going to the hospital now. Please come / call!', '🚨 నొప్పులు 5 నిమిషాలకు ఒకసారి వస్తున్నాయి. ఇప్పుడే హాస్పిటల్‌కు వెళ్తున్నాం. దయచేసి రండి / ఫోన్ చేయండి!'));
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Family alerted', 'కుటుంబానికి తెలియజేశాం'))));
                  },
                  icon: const Icon(Icons.campaign),
                  label: Text(tr('Alert family', 'కుటుంబానికి చెప్పు')),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(style: IconButton.styleFrom(backgroundColor: K.bad), onPressed: () => launchUrl(Uri.parse('tel:108')), icon: const Icon(Icons.local_hospital)),
            ]),
          ]),
        ),
      SectionTitle(tr('Last 2 hours', 'గత 2 గంటలు'), action: list.isEmpty ? null : tr('Clear', 'తుడిచేయి'), onAction: () async {
        Store.i.d['contractions'] = <dynamic>[];
        await _save();
      }),
      if (recent.isEmpty) Text(tr('Tap Start when a contraction begins and tap again when it ends.', 'నొప్పి మొదలైనప్పుడు మొదలు నొక్కండి, తగ్గినప్పుడు మళ్ళీ నొక్కండి.'), style: const TextStyle(color: K.muted)),
      for (var i = recent.length - 1; i >= 0; i--)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClayBox(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(children: [
              Text(hm(DateTime.fromMillisecondsSinceEpoch(recent[i]['start'] as int)), style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${tr('lasted', 'వ్యవధి')} ${recent[i]['secs']}s', style: const TextStyle(color: K.indigo)),
              if (i > 0) Text('  ·  ${tr('gap', 'గ్యాప్')} ${_mmss(Duration(seconds: gaps[i - 1]))}', style: const TextStyle(color: K.muted, fontSize: 12)),
            ]),
          ),
        ),
    ];
  }

  List<Widget> _checkups() {
    final w = pregWeek();
    final done = _list('pregDone');
    final due = dueDate;
    DateTime? at(int week) => due?.subtract(Duration(days: 280 - week * 7));
    return [
      for (final c in pregCheckups)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ClayBox(
            color: done.contains(c.$3) ? const Color(0xFFE6F5EE) : (w >= c.$1 && w <= c.$2 ? K.pinkSoft : K.card),
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(K.te ? c.$4 : c.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${tr('Weeks', 'వారాలు')} ${c.$1}–${c.$2}${at(c.$1) == null ? '' : ' · ${dmy(at(c.$1)!)} – ${dmy(at(c.$2)!)}'}', style: const TextStyle(fontSize: 12, color: K.muted)),
                ]),
              ),
              Checkbox(
                value: done.contains(c.$3),
                shape: const CircleBorder(),
                activeColor: K.good,
                onChanged: (v) async {
                  v == true ? done.add(c.$3) : done.remove(c.$3);
                  await _save();
                },
              ),
            ]),
          ),
        ),
      Text(tr('Typical Indian schedule. Your doctor may plan it differently.', 'సాధారణ షెడ్యూల్. మీ డాక్టర్ వేరేలా చెప్పవచ్చు.'), style: const TextStyle(fontSize: 12, color: K.muted)),
    ];
  }

  List<Widget> _bag() {
    final done = _list('bagDone');
    return [
      Text(tr('Pack it by 36 weeks.', '36 వారాల కల్లా సిద్ధం చేయండి.'), style: const TextStyle(color: K.muted)),
      const SizedBox(height: 10),
      for (final b in hospitalBag)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClayBox(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            color: done.contains(b.$1) ? const Color(0xFFE6F5EE) : K.card,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: done.contains(b.$1),
              activeColor: K.good,
              title: Text(K.te ? b.$2 : b.$1, style: const TextStyle(fontSize: 14)),
              onChanged: (v) async {
                v == true ? done.add(b.$1) : done.remove(b.$1);
                await _save();
              },
            ),
          ),
        ),
    ];
  }

  List<Widget> _danger() => [
        ClayBox(
          color: const Color(0xFFFFE4E4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Go to a doctor or hospital immediately if you have:', 'ఇవి ఉంటే వెంటనే డాక్టర్ దగ్గరకు లేదా హాస్పిటల్‌కు వెళ్ళండి:'), style: const TextStyle(fontWeight: FontWeight.w700, color: K.bad)),
            const SizedBox(height: 8),
            for (final d in pregDanger) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• ${K.te ? d.$2 : d.$1}')),
            const SizedBox(height: 8),
            FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: K.bad), onPressed: () => launchUrl(Uri.parse('tel:108')), icon: const Icon(Icons.call), label: Text(tr('Call 108 ambulance', '108 అంబులెన్స్‌కు కాల్'))),
          ]),
        ),
      ];
}

// ───────── Jatakam tab while expecting ─────────
class PregJatakam extends StatelessWidget {
  const PregJatakam({super.key});
  @override
  Widget build(BuildContext context) {
    return ClayPage(title: tr('Jatakam', 'జాతకం'), back: false, children: [
      ClayBox(
        color: K.indigo,
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.auto_awesome, color: K.pink, size: 36),
          const SizedBox(height: 10),
          Text(tr('Your baby\'s jatakam will be ready the moment the baby is born.', 'బిడ్డ పుట్టిన క్షణమే జాతకం సిద్ధమవుతుంది.'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(tr('Tap "Baby is born!" at birth. The app saves the exact time and shows the nakshatra, rasi, lagna, name letters and dasa at once.', 'పుట్టగానే "బిడ్డ పుట్టింది!" నొక్కండి. యాప్ సరైన సమయం సేవ్ చేసి నక్షత్రం, రాశి, లగ్నం, పేరు అక్షరాలు, దశలు వెంటనే చూపిస్తుంది.'), style: const TextStyle(color: Colors.white70)),
        ]),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: () => showBornSheet(context), icon: const Text('👶'), label: Text(tr('Baby is born!', 'బిడ్డ పుట్టింది!'))),
    ]);
  }
}

// ───────── "Baby is born!" ─────────
Future<void> showBornSheet(BuildContext context) async {
  var when = DateTime.now();
  var gender = 'girl';
  final name = TextEditingController(text: Store.i.babyName == 'Little One' ? '' : Store.i.babyName);
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Congratulations! 🎉', 'అభినందనలు! 🎉'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Pill(tr('Baby girl', 'పాప'), on: gender == 'girl', onTap: () => set(() => gender = 'girl'))),
            const SizedBox(width: 10),
            Expanded(child: Pill(tr('Baby boy', 'బాబు'), on: gender == 'boy', onTap: () => set(() => gender = 'boy'))),
          ]),
          const SizedBox(height: 14),
          TextField(controller: name, decoration: InputDecoration(hintText: tr('Baby\'s name or pet name', 'బిడ్డ పేరు లేదా ముద్దు పేరు'))),
          const SizedBox(height: 14),
          ClayBox(
            onTap: () async {
              final d = await showDatePicker(context: c, firstDate: DateTime.now().subtract(const Duration(days: 60)), lastDate: DateTime.now(), initialDate: when);
              if (d == null || !c.mounted) return;
              final t = await showTimePicker(context: c, initialTime: TimeOfDay.fromDateTime(when));
              set(() => when = DateTime(d.year, d.month, d.day, t?.hour ?? when.hour, t?.minute ?? when.minute));
            },
            child: Row(children: [
              const Icon(Icons.schedule, color: K.indigo),
              const SizedBox(width: 12),
              Expanded(child: Text('${tr('Born at', 'పుట్టిన సమయం')} ${dmy(when)}, ${hm(when)}', style: const TextStyle(fontWeight: FontWeight.w600))),
              const Icon(Icons.edit, size: 18),
            ]),
          ),
          const SizedBox(height: 6),
          Text(tr('Exact time matters for the jatakam. Change it if the baby was born earlier.', 'జాతకానికి సరైన సమయం ముఖ్యం. ముందే పుడితే మార్చండి.'), style: const TextStyle(fontSize: 12, color: K.muted)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Save and tell the family', 'సేవ్ చేసి కుటుంబానికి చెప్పు'))),
        ]),
      ),
    ),
  );
  if (ok != true) return;
  final p = Store.i.profile;
  p['name'] = name.text.trim().isEmpty ? (gender == 'girl' ? tr('Baby girl', 'పాప') : tr('Baby boy', 'బాబు')) : name.text.trim();
  p['gender'] = gender;
  p['birthDate'] = ymd(when);
  p['birthTime'] = '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
  p['timeKnown'] = true;
  p['stage'] = 'born';
  await Store.i.setProfile(p);
  final c = babyChart();
  if (c != null && Chat.i.paired) {
    final star = '${Astro.nakEn[c.nak]} pada ${c.pada}';
    unawaited(Chat.i.send(tr('🎉 ${gender == 'girl' ? 'It\'s a girl!' : 'It\'s a boy!'} ${p['name']} was born on ${dmy(when)} at ${hm(when)}. Birth star: $star. Name letter: ${Astro.letters[c.nak][c.pada - 1]} 👶💕',
        '🎉 ${gender == 'girl' ? 'పాప పుట్టింది!' : 'బాబు పుట్టాడు!'} ${p['name']} ${dmy(when)} ${hm(when)}కి పుట్టారు. నక్షత్రం: ${Astro.nakTe[c.nak]} ${c.pada}వ పాదం. పేరు అక్షరం: ${Astro.lettersTe[c.nak][c.pada - 1]} 👶💕')));
  }
  if (!context.mounted || c == null) return;
  await showDialog(
    context: context,
    builder: (d) => AlertDialog(
      icon: const Text('🎉', style: TextStyle(fontSize: 52)),
      title: Text(tr('Welcome, ${p['name']}!', 'స్వాగతం, ${p['name']}!')),
      content: Text('${tr('Birth star', 'జన్మ నక్షత్రం')}: ${nakName(c.nak)} · ${tr('Pada', 'పాదం')} ${c.pada}\n${tr('Rasi', 'రాశి')}: ${rasiName(c.rasi)}\n${tr('Name letter', 'పేరు అక్షరం')}: ${K.te ? Astro.lettersTe[c.nak][c.pada - 1] : Astro.letters[c.nak][c.pada - 1]}', textAlign: TextAlign.center),
      actions: [FilledButton(onPressed: () => Navigator.pop(d), child: Text(tr('See the jatakam', 'జాతకం చూడండి')))],
    ),
  );
}
