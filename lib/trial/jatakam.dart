import 'package:flutter/material.dart';

import '../data.dart';
import '../store.dart';
import 'astro.dart';
import 'ui.dart';

/// The baby's birth chart, calculated on the phone from birth date, time and place.
Chart? babyChart() {
  final p = Store.i.profile;
  final d = DateTime.tryParse((p['birthDate'] ?? '').toString());
  if (d == null) return null;
  final tm = (p['birthTime'] ?? '12:00').toString().split(':');
  final h = int.tryParse(tm.first) ?? 12, m = tm.length > 1 ? int.tryParse(tm[1]) ?? 0 : 0;
  final lat = (p['lat'] as num?)?.toDouble() ?? 14.4426, lon = (p['lon'] as num?)?.toDouble() ?? 79.9865;
  return Astro.compute(Birth(DateTime(d.year, d.month, d.day, h, m), lat, lon));
}

String nakName(int i) => K.te ? Astro.nakTe[i] : Astro.nakEn[i];
String rasiName(int i) => K.te ? Astro.rasiTe[i] : Astro.rasiEn[i];

class JatakamTab extends StatelessWidget {
  const JatakamTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final c = babyChart();
        final name = Store.i.babyName;
        final timeKnown = Store.i.profile['timeKnown'] != false;
        if (c == null) return const Center(child: Text('Add the birth date in Settings'));
        final letters = Astro.letters[c.nak], lettersTe = Astro.lettersTe[c.nak];
        final dasas = c.dasas();
        final now = DateTime.now();
        return Scaffold(
          appBar: AppBar(title: Text(tr('$name\'s Jatakam', '$name జాతకం')), automaticallyImplyLeading: false),
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 130), children: [
            ClayBox(
              color: K.indigo,
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Birth star', 'జన్మ నక్షత్రం'), style: const TextStyle(color: Colors.white70)),
                Text('${nakName(c.nak)} · ${tr('Pada', 'పాదం')} ${c.pada}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${tr('Rasi', 'రాశి')}: ${rasiName(c.rasi)}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _chip(tr('Lagna', 'లగ్నం'), timeKnown ? rasiName(c.lagnaRasi) : tr('needs birth time', 'సమయం కావాలి')),
                  _chip(tr('Tithi', 'తిథి'), Astro.tithiName(c.tithi, K.te)),
                  _chip(tr('Day', 'వారం'), K.te ? Astro.varaTe[c.weekday] : Astro.varaEn[c.weekday]),
                ]),
              ]),
            ),
            SectionTitle(tr('Name letters', 'పేరు అక్షరాలు')),
            ClayBox(
              color: K.pinkSoft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Traditional first letter for ${nakName(c.nak)}, pada ${c.pada}:', '${nakName(c.nak)} ${c.pada}వ పాదానికి సంప్రదాయ మొదటి అక్షరం:'), style: const TextStyle(color: K.muted)),
                const SizedBox(height: 10),
                Row(children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: i + 1 == c.pada ? K.indigo : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: (i + 1 == c.pada ? K.deep : const Color(0xFFE2B5C4)).withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: Column(children: [
                          Text(K.te ? lettersTe[i] : letters[i], style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: i + 1 == c.pada ? Colors.white : K.ink)),
                          Text('${tr('Pada', 'పాదం')} ${i + 1}', style: TextStyle(fontSize: 10, color: i + 1 == c.pada ? Colors.white70 : K.muted)),
                        ]),
                      ),
                    ),
                ]),
              ]),
            ),
            SectionTitle(tr('Rasi chakram', 'రాశి చక్రం')),
            ClayBox(padding: const EdgeInsets.all(12), child: _SouthChart(c, timeKnown)),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(tr('Showing Lagna (La), Sun (Su) and Moon (Mo). The full chart with all planets comes in the next version.', 'లగ్నం (ల), రవి (ర), చంద్రుడు (చం) చూపిస్తున్నాం. అన్ని గ్రహాలతో పూర్తి చక్రం తర్వాతి వెర్షన్‌లో.'), style: const TextStyle(fontSize: 12, color: K.muted)),
            ),
            SectionTitle(tr('Dasa periods', 'దశలు')),
            for (final d in dasas)
              Builder(builder: (context) {
                final cur = !now.isBefore(d.$2) && now.isBefore(d.$3);
                final i = Astro.dasaLords.indexOf(d.$1);
                final age0 = d.$2.difference(c.birthLocal).inDays / 365.25, age1 = d.$3.difference(c.birthLocal).inDays / 365.25;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClayBox(
                    color: cur ? K.pink : K.card,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: cur ? K.indigo : Colors.white, shape: BoxShape.circle),
                        child: Text((K.te ? Astro.dasaLordsTe[i] : d.$1).characters.first, style: TextStyle(fontWeight: FontWeight.w700, color: cur ? Colors.white : K.indigo, fontSize: 18)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${K.te ? Astro.dasaLordsTe[i] : d.$1} ${tr('dasa', 'దశ')}${cur ? tr(' · now', ' · ఇప్పుడు') : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${dmy(d.$2)} – ${dmy(d.$3)}', style: const TextStyle(fontSize: 12, color: K.muted)),
                        ]),
                      ),
                      Text('${tr('Age', 'వయసు')} ${age0.toStringAsFixed(0)}–${age1.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: K.indigo)),
                    ]),
                  ),
                );
              }),
            const SizedBox(height: 10),
            ClayBox(
              color: K.deep,
              onTap: () => showDialog(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text(tr('Life Story report', 'జీవిత కథ నివేదిక')),
                  content: Text(tr(
                      'A warm, detailed report of $name\'s nature, studies, talents and good periods, based on Parashara Maharshi\'s Brihat Parashara Hora Shastra. Coming soon as a premium feature.\n\nTraditional astrology, not a guarantee. The child\'s own interests matter most.',
                      'పరాశర మహర్షి బృహత్ పరాశర హోరా శాస్త్రం ఆధారంగా $name స్వభావం, చదువు, ప్రతిభ, మంచి కాలాల గురించి వివరమైన నివేదిక. త్వరలో ప్రీమియం ఫీచర్‌గా వస్తుంది.\n\nఇది సంప్రదాయ జ్యోతిషం, హామీ కాదు. బిడ్డ ఇష్టాలే ముఖ్యం.')),
                  actions: [FilledButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
                ),
              ),
              child: Row(children: [
                const Icon(Icons.auto_stories, color: K.pink, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Life Story report', 'జీవిత కథ నివేదిక'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(tr('Premium · coming soon', 'ప్రీమియం · త్వరలో'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
                const Icon(Icons.lock, color: K.pink),
              ]),
            ),
            const SizedBox(height: 12),
            Text(tr('Calculated on this phone (Lahiri ayanamsa). Traditional astrology for culture and guidance, not a guarantee.', 'ఈ ఫోన్‌లోనే లెక్కించబడింది (లాహిరి అయనాంశ). సంస్కృతి, మార్గదర్శనం కోసం సంప్రదాయ జ్యోతిషం, హామీ కాదు.'), style: const TextStyle(fontSize: 11.5, color: K.muted)),
          ]),
        );
      },
    );
  }

  Widget _chip(String a, String b) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
        child: Text('$a: $b', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );
}

class _SouthChart extends StatelessWidget {
  final Chart c;
  final bool timeKnown;
  const _SouthChart(this.c, this.timeKnown);

  // South Indian chart: signs stay in fixed boxes.
  static const _grid = [
    [11, 0, 1, 2],
    [10, -1, -1, 3],
    [9, -1, -1, 4],
    [8, 7, 6, 5],
  ];

  @override
  Widget build(BuildContext context) {
    List<String> inSign(int r) => [
          if (timeKnown && c.lagnaRasi == r) tr('La', 'ల'),
          if (c.sunRasi == r) tr('Su', 'ర'),
          if (c.rasi == r) tr('Mo', 'చం'),
        ];
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(children: [
        Column(children: [
          for (final row in _grid)
            Expanded(
              child: Row(children: [
                for (final r in row)
                  Expanded(
                    child: r < 0
                        ? const SizedBox()
                        : Container(
                            margin: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(color: r == c.rasi ? K.pinkSoft : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFDCD6EC))),
                            padding: const EdgeInsets.all(4),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(K.te ? Astro.rasiTe[r] : Astro.rasiShort[r], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: K.muted)),
                              const Spacer(),
                              Center(child: Text(inSign(r).join(' '), style: const TextStyle(fontWeight: FontWeight.w700, color: K.indigo, fontSize: 13))),
                              const Spacer(),
                            ]),
                          ),
                  ),
              ]),
            ),
        ]),
        Positioned.fill(
          child: FractionallySizedBox(
            widthFactor: 0.5,
            heightFactor: 0.5,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(Store.i.babyName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(tr('Rasi', 'రాశి'), style: const TextStyle(color: K.muted, fontSize: 12)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
