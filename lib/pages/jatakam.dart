import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../clay.dart';

import '../data.dart';
import '../store.dart';

class JatakamPage extends StatefulWidget {
  const JatakamPage({super.key});
  @override
  State<JatakamPage> createState() => _JatakamPageState();
}

class _JatakamPageState extends State<JatakamPage> {
  List<Map<String, dynamic>> secs = [];
  Map<String, dynamic>? chart;
  bool d9 = false;

  @override
  void initState() {
    super.initState();
    Future.wait([rootBundle.loadString('assets/patrika.json'), rootBundle.loadString('assets/chart.json')]).then((r) => setState(() {
          secs = (jsonDecode(r[0]) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          chart = Map<String, dynamic>.from(jsonDecode(r[1]) as Map);
        }));
  }

  @override
  Widget build(BuildContext context) {
    if (chart == null) return const Center(child: CircularProgressIndicator());
    final shown = secs.where((s) => s['hidden'] != true).toList();
    final cover = secs.firstWhere((s) => s['key'] == 'cover', orElse: () => {});
    return DefaultTabController(
      length: shown.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('జాతక పత్రిక'),
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [const Tab(text: 'చక్రం'), ...shown.map((s) => Tab(text: s['label'].toString()))]),
        ),
        body: TabBarView(children: [
          ListView(padding: const EdgeInsets.all(12), children: [if (cover.isNotEmpty) _cover(context, cover), ..._chart(context)]),
          ...shown.map((s) => ListView(padding: const EdgeInsets.all(14), children: [
                Text(s['title'].toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                ...(s['blocks'] as List).map((b) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _block(context, Map<String, dynamic>.from(b as Map)))),
              ])),
        ]),
      ),
    );
  }

  Widget _rich(BuildContext context, String s, {double size = 15, FontWeight w = FontWeight.normal, TextAlign align = TextAlign.start}) {
    final parts = s.split('**');
    final base = TextStyle(fontSize: size, height: 1.6, fontWeight: w, color: Theme.of(context).colorScheme.onSurface);
    return Text.rich(
      TextSpan(children: [for (var i = 0; i < parts.length; i++) TextSpan(text: parts[i], style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary) : base)]),
      textAlign: align,
    );
  }

  Widget _cover(BuildContext context, Map<String, dynamic> c) {
    final cs = Theme.of(context).colorScheme;
    final blocks = (c['blocks'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: LinearGradient(colors: [cs.tertiaryContainer, cs.primaryContainer])),
      child: Column(children: [
        for (final b in blocks)
          if (b['type'] == 'invocation') ...(b['lines'] as List).map((l) => Text(l.toString(), style: const TextStyle(fontWeight: FontWeight.w600)))
          else if (b['type'] == 'kv') _kv(context, b)
          else if (b['type'] == 'blessing') Padding(padding: const EdgeInsets.only(top: 10), child: Text(b['text'].toString(), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary))),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _kv(BuildContext context, Map b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: (b['rows'] as List).map((r) {
          final row = (r as List).map((e) => e.toString()).toList();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 110, child: Text(row[0], style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant))),
              Expanded(child: _rich(context, row[1], size: 14)),
            ]),
          );
        }).toList()),
      );

  List<Widget> _chart(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pos = Map<String, dynamic>.from(chart!['pos'] as Map), retro = Map<String, dynamic>.from(chart!['retro'] as Map);
    int signOf(String k) {
      final x = (pos[k] as num).toDouble();
      return d9 ? (x * 9 / 30).floor() % 12 : (x / 30).floor();
    }

    final bySign = List.generate(12, (_) => <String>[]);
    for (final p in planets) {
      bySign[signOf(p[0])].add(p[2] + (retro[p[0]] == true ? ' (వ)' : ''));
    }
    final lag = signOf('Lagna');
    const cell = {11: [0, 0], 0: [0, 1], 1: [0, 2], 2: [0, 3], 10: [1, 0], 3: [1, 3], 9: [2, 0], 4: [2, 3], 8: [3, 0], 7: [3, 1], 6: [3, 2], 5: [3, 3]};
    final grid = List.generate(4, (_) => List<Widget?>.filled(4, null));
    cell.forEach((sgn, rc) {
      grid[rc[0]][rc[1]] = Container(
        decoration: BoxDecoration(color: sgn == lag ? cs.tertiaryContainer : cs.surface, border: Border.all(color: cs.outlineVariant, width: 0.5)),
        padding: const EdgeInsets.all(4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Align(alignment: Alignment.topRight, child: Text(rasiTe[sgn], style: TextStyle(fontSize: 9, color: cs.outline))),
          ...bySign[sgn].map((p) => Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.startsWith('లగ్నం') ? cs.primary : null))),
        ]),
      );
    });
    Widget row(int r) => Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var c = 0; c < 4; c++) Expanded(child: grid[r][c] ?? const SizedBox())]));
    final nak = (chart!['nak'] as num).toInt(), pada = (chart!['pada'] as num).toInt(), moon = ((pos['Moon'] as num) / 30).floor();
    final lagD1 = ((pos['Lagna'] as num) / 30).floor();
    String dms(num x) {
      final d = (x % 30).floor(), m = (((x % 30) - d) * 60).floor();
      return '$d°${m.toString().padLeft(2, '0')}′';
    }

    return [
      Row(children: [
        const Expanded(child: Text('రాశి చక్రం', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
        SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('D1')), ButtonSegment(value: true, label: Text('D9'))], selected: {d9}, onSelectionChanged: (v) => setState(() => d9 = v.first)),
      ]),
      const SizedBox(height: 10),
      AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(children: [
            Column(children: [row(0), row(1), row(2), row(3)]),
            Positioned.fill(
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [cs.primaryContainer, cs.secondaryContainer])),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(d9 ? 'నవాంశ (D9)' : 'రాశి (D1)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cs.primary)),
                    Text(Store.i.babyName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Text('6 Oct 2026 · 6:18 PM', style: TextStyle(fontSize: 11)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Text('పసుపు గడి = లగ్నం · (వ) = వక్రి${d9 ? ' · Lagna sits on a navamsa border; go by your printed patrika for D9.' : ''}', style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _fact(context, 'జన్మ నక్షత్రం', '${nakTe[nak]} · $pada వ పాదం'),
        _fact(context, 'జన్మ రాశి', rasiTe[moon]),
        _fact(context, 'లగ్నం', '${rasiTe[lagD1]} ${dms(pos['Lagna'] as num)}'),
        _fact(context, 'నామ అక్షరం', 'డొ'),
        _fact(context, 'జన్మ దశ', 'బుధ మహాదశ · 2y 11m'),
      ]),
      const SizedBox(height: 12),
      ClayCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: planets.map((p) {
            final x = (pos[p[0]] as num).toDouble();
            final s = (x / 30).floor(), n = (x / (360 / 27)).floor(), pd = ((x % (360 / 27)) / (360 / 108)).floor() + 1, bh = ((s - lagD1 + 12) % 12) + 1;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(flex: 3, child: Text(p[1] + (retro[p[0]] == true ? ' (వ)' : ''), style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(flex: 3, child: Text(rasiTe[s])),
                Expanded(flex: 2, child: Text(dms(x))),
                Expanded(flex: 3, child: Text('${nakTe[n]} $pd')),
                Expanded(flex: 1, child: Text('$bh')),
              ]),
            );
          }).toList()),
        ),
      ),
    ];
  }

  Widget _fact(BuildContext context, String k, String v) => Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(k, style: const TextStyle(fontSize: 12)), Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))]),
      );

  Widget _block(BuildContext context, Map<String, dynamic> b) {
    final cs = Theme.of(context).colorScheme;
    switch (b['type']) {
      case 'p':
        return _rich(context, b['text'].toString());
      case 'h':
        return Text(b['text'].toString(), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: cs.primary));
      case 'small':
        return _rich(context, b['text'].toString(), size: 12);
      case 'blessing':
        return Text(b['text'].toString(), textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: cs.primary));
      case 'callout':
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (b['title'] != null) Text(b['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), _rich(context, b['text'].toString())]),
        );
      case 'kv':
        return _kv(context, b);
      case 'table':
        final head = (b['head'] as List).map((e) => e.toString()).toList();
        return Column(children: (b['rows'] as List).map((r) {
          final row = (r as List).map((e) => e.toString()).toList();
          return ClayCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _rich(context, row[0], size: 16, w: FontWeight.w800),
                for (var i = 1; i < row.length; i++) Padding(padding: const EdgeInsets.only(top: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(i < head.length ? head[i] : '', style: TextStyle(fontSize: 12, color: cs.outline, fontWeight: FontWeight.w700)), _rich(context, row[i], size: 14)])),
              ]),
            ),
          );
        }).toList());
      case 'list':
        final care = b['tone'] == 'care';
        return Column(children: (b['items'] as List).map((it) {
          final x = (it as List).map((e) => e.toString()).toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 15, backgroundColor: care ? Colors.orange.withValues(alpha: 0.2) : Colors.teal.withValues(alpha: 0.2), child: Text(care ? '!' : '✓', style: TextStyle(color: care ? Colors.orange : Colors.teal, fontWeight: FontWeight.w900))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x[0], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), _rich(context, x[1], size: 14)])),
            ]),
          );
        }).toList());
      case 'dashas':
      case 'stages':
        final today = ymd(DateTime.now());
        return Column(children: (b['rows'] as List).map((r) {
          final x = (r as List).map((e) => e.toString()).toList();
          final now = today.compareTo(x[1]) >= 0 && today.compareTo(x[2]) < 0;
          return ClayCard(
            color: now ? cs.primaryContainer : null,
            child: ListTile(
              title: Text('${x[0]}${b['type'] == 'dashas' ? ' మహాదశ' : ''}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${x[1]} → ${x[2]} · వయసు ${x[3]}${now ? '  · ఇప్పుడు' : ''}', style: TextStyle(color: now ? cs.primary : cs.outline, fontWeight: FontWeight.w700)),
                _rich(context, x[4], size: 14),
              ]),
            ),
          );
        }).toList());
      case 'mantras':
        return Column(children: (b['items'] as List).map((it) {
          final x = (it as List).map((e) => e.toString()).toList();
          return ClayCard(
            child: ListTile(
              title: Text(x[2], style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: cs.primary)),
              subtitle: Text('${x[1]}\n${x[3]}'),
              trailing: IconButton(icon: const Icon(Icons.play_circle), onPressed: () => launchUrl(Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(x[2])}'), mode: LaunchMode.externalApplication)),
            ),
          );
        }).toList());
      case 'names':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((Store.i.d['shortlist'] as List).isNotEmpty)
            ClayCard(color: cs.primaryContainer, child: Padding(padding: const EdgeInsets.all(12), child: Text('Shortlist ♥  ${(Store.i.d['shortlist'] as List).join(', ')}', style: const TextStyle(fontWeight: FontWeight.w700)))),
          ...(b['groups'] as List).map((g) {
            final gl = g as List;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(gl[0].toString(), style: TextStyle(fontWeight: FontWeight.w800, color: cs.outline)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: (gl[1] as List).map((n) {
                  final x = (n as List).map((e) => e.toString()).toList();
                  final fav = Store.i.inShortlist(x[1]);
                  return FilterChip(
                    selected: fav,
                    label: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x[0], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), Text(x[2].isEmpty ? x[1] : '${x[1]} · ${x[2]}', style: const TextStyle(fontSize: 11))]),
                    onSelected: (_) async {
                      await Store.i.toggleShortlist(x[1]);
                      setState(() {});
                    },
                  );
                }).toList()),
              ]),
            );
          }),
        ]);
      default:
        return const SizedBox.shrink();
    }
  }
}
