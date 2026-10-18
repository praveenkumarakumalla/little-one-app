import 'package:flutter/material.dart';

import '../data.dart';
import '../store.dart';
import '../watch.dart';
import 'ui.dart';

/// Quick logs used by the + button and the Care tab.
const logKinds = [
  ('feeds', Icons.local_drink, 'Feed', 'పాలు'),
  ('nappies', Icons.baby_changing_station, 'Nappy', 'డైపర్'),
  ('sleeps', Icons.bedtime, 'Woke up', 'లేచింది'),
];

Future<void> quickLog(BuildContext context, String k) async {
  await Store.i.addTime(k);
  if (!context.mounted) return;
  final kind = logKinds.firstWhere((x) => x.$1 == k);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('${tr(kind.$3, kind.$4)} ${tr('saved', 'సేవ్ అయింది')} · ${hm(DateTime.now())}'),
    action: SnackBarAction(label: tr('Undo', 'రద్దు'), textColor: K.pink, onPressed: () => Store.i.removeLast(k)),
  ));
}

class CareTab extends StatefulWidget {
  const CareTab({super.key});
  @override
  State<CareTab> createState() => _CareTabState();
}

class _CareTabState extends State<CareTab> {
  int view = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, SleepWatch.i]),
      builder: (context, _) {
        final s = Store.i;
        return Scaffold(
          appBar: AppBar(title: Text(tr('Care', 'సంరక్షణ')), automaticallyImplyLeading: false),
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 130), children: [
            Wrap(spacing: 10, children: [
              Pill(tr('Today', 'ఈరోజు'), on: view == 0, onTap: () => setState(() => view = 0)),
              Pill(tr('Week', 'వారం'), on: view == 1, onTap: () => setState(() => view = 1)),
              Pill(tr('Vaccines', 'టీకాలు'), on: view == 2, onTap: () => setState(() => view = 2)),
            ]),
            const SizedBox(height: 18),
            if (view == 0) ..._today(context, s),
            if (view == 1) _week(s),
            if (view == 2) ..._vaccines(s),
          ]),
        );
      },
    );
  }

  List<Widget> _today(BuildContext context, Store s) {
    final events = <(DateTime, String, IconData)>[];
    final n0 = DateTime.now();
    final start = DateTime(n0.year, n0.month, n0.day);
    for (final k in logKinds) {
      for (final t in s.ints(k.$1)) {
        final d = DateTime.fromMillisecondsSinceEpoch(t);
        if (d.isAfter(start)) events.add((d, tr(k.$3, k.$4), k.$2));
      }
    }
    events.sort((a, b) => b.$1.compareTo(a.$1));
    return [
      Row(children: [
        for (final k in logKinds) ...[
          Expanded(
            child: ClayBox(
              onTap: () => quickLog(context, k.$1),
              color: k.$1 == 'feeds' ? K.indigo : (k.$1 == 'nappies' ? K.pink : K.card),
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(children: [
                Icon(k.$2, size: 30, color: k.$1 == 'feeds' ? Colors.white : K.indigo),
                const SizedBox(height: 6),
                Text(tr(k.$3, k.$4), style: TextStyle(fontWeight: FontWeight.w700, color: k.$1 == 'feeds' ? Colors.white : K.ink)),
                Text('${s.countToday(k.$1)} ${tr('today', 'ఈరోజు')}', style: TextStyle(fontSize: 12, color: k.$1 == 'feeds' ? Colors.white70 : K.muted)),
              ]),
            ),
          ),
          if (k != logKinds.last) const SizedBox(width: 12),
        ],
      ]),
      SectionTitle(tr('Today\'s activity', 'ఈరోజు పనులు')),
      if (events.isEmpty)
        ClayBox(child: Text(tr('Nothing logged yet today. Tap Feed, Nappy or Woke up above.', 'ఈరోజు ఇంకా ఏమీ నమోదు చేయలేదు. పైన పాలు, డైపర్ లేదా లేచింది నొక్కండి.'), style: const TextStyle(color: K.muted)))
      else
        ClayBox(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Column(children: [
            for (var i = 0; i < events.length; i++)
              Row(children: [
                Column(children: [
                  Container(width: 2, height: 10, color: i == 0 ? Colors.transparent : const Color(0xFFF2D9DF)),
                  Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: K.indigo, width: 3), color: Colors.white)),
                  Container(width: 2, height: 22, color: i == events.length - 1 ? Colors.transparent : const Color(0xFFF2D9DF)),
                ]),
                const SizedBox(width: 12),
                Icon(events[i].$3, size: 18, color: K.indigo),
                const SizedBox(width: 8),
                Expanded(child: Text(events[i].$2, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(hm(events[i].$1), style: const TextStyle(color: K.muted, fontSize: 12.5)),
              ]),
          ]),
        ),
    ];
  }

  Widget _week(Store s) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
    int count(String k, DateTime d) => s.ints(k).where((t) {
          final x = DateTime.fromMillisecondsSinceEpoch(t);
          return x.year == d.year && x.month == d.month && x.day == d.day;
        }).length;
    final feeds = days.map((d) => count('feeds', d)).toList();
    final naps = days.map((d) => count('nappies', d)).toList();
    final mx = [...feeds, ...naps, 1].reduce((a, b) => a > b ? a : b);
    const wk = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const wkTe = ['సోమ', 'మంగళ', 'బుధ', 'గురు', 'శుక్ర', 'శని', 'ఆది'];
    return ClayBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Feeds and nappies, last 7 days', 'గత 7 రోజుల్లో పాలు, డైపర్లు'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(children: [
          _legend(K.indigo, tr('Feeds', 'పాలు')),
          const SizedBox(width: 14),
          _legend(K.pink, tr('Nappies', 'డైపర్లు')),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 170,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${feeds[i]}', style: const TextStyle(fontSize: 10, color: K.muted)),
                  Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _bar(feeds[i] / mx, K.indigo),
                    const SizedBox(width: 3),
                    _bar(naps[i] / mx, K.pink),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(color: i == 6 ? K.indigo : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                    child: Text(K.te ? wkTe[days[i].weekday - 1] : wk[days[i].weekday - 1], style: TextStyle(fontSize: 10.5, color: i == 6 ? Colors.white : K.muted, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _legend(Color c, String t) => Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 6), Text(t, style: const TextStyle(fontSize: 12))]);
  Widget _bar(double v, Color c) => AnimatedContainer(duration: const Duration(milliseconds: 500), width: 11, height: 4 + 110 * v, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)));

  List<Widget> _vaccines(Store s) {
    final b = s.birth;
    if (b == null) return [const Text('Add the birth date first')];
    final now = DateTime.now();
    return [
      Text(tr('Indian Academy of Paediatrics schedule. Main vaccines are free at government centres.', 'భారతీయ పీడియాట్రిక్స్ అకాడమీ పట్టిక. ముఖ్యమైన టీకాలు ప్రభుత్వ కేంద్రాల్లో ఉచితం.'), style: const TextStyle(color: K.muted, fontSize: 12.5)),
      const SizedBox(height: 12),
      for (final v in vaccines)
        Builder(builder: (context) {
          final due = v.due(b);
          final done = s.vaxDone(v.key);
          final late = !done && due.isBefore(now.subtract(const Duration(days: 1)));
          final soon = !done && !late && due.difference(now).inDays <= 14;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ClayBox(
              color: done ? const Color(0xFFE6F5EE) : (soon ? K.pinkSoft : K.card),
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(v.items.join(', '), style: const TextStyle(fontSize: 12, color: K.muted)),
                    const SizedBox(height: 4),
                    Text(done ? tr('Done', 'పూర్తయింది') : '${tr('Due', 'తేదీ')} ${dmy(due)}${late ? tr(' · overdue', ' · ఆలస్యం') : ''}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: done ? K.good : (late ? K.bad : K.indigo))),
                  ]),
                ),
                Checkbox(value: done, activeColor: K.good, shape: const CircleBorder(), onChanged: (x) => s.toggleVax(v.key, x == true)),
              ]),
            ),
          );
        }),
    ];
  }
}
