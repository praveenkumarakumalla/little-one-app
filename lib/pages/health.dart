import 'package:flutter/material.dart';

import '../clay.dart';

import '../data.dart';
import '../store.dart';

class HealthPage extends StatelessWidget {
  const HealthPage({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Health · ఆరోగ్యం'),
          bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [Tab(text: 'Vaccines'), Tab(text: 'Calendar'), Tab(text: 'Notes'), Tab(text: 'Growth')]),
        ),
        body: ListenableBuilder(
          listenable: Store.i,
          // not const: the tabs must rebuild when something is saved
          // ignore: prefer_const_constructors
          builder: (context, _) => TabBarView(children: [_Vaccines(), _Events(), _Notes(), _Growth()]),
        ),
      ),
    );
  }
}

class _Vaccines extends StatelessWidget {
  const _Vaccines();
  @override
  Widget build(BuildContext context) {
    final b = Store.i.birth;
    final now = DateTime.now(), cs = Theme.of(context).colorScheme;
    final doneCount = vaccines.where((v) => Store.i.vaxDone(v.key)).length;
    Vax? next;
    for (final v in vaccines) {
      if (!Store.i.vaxDone(v.key)) { next = v; break; }
    }
    return ListView(padding: const EdgeInsets.all(12), children: [
      ClayCard(
        color: cs.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('టీకాల పట్టిక · Vaccine schedule', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('$doneCount of ${vaccines.length} visits done${next != null && b != null ? ' · Next: ${next.label} on ${dmy(next.due(b))}' : ''}'),
            if (b == null) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Add her date of birth on Home to see exact dates.', style: TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
      ...vaccines.map((v) {
        final done = Store.i.vaxDone(v.key);
        String label = v.label;
        Color col = cs.outline;
        DateTime? due;
        if (b != null) {
          due = v.due(b);
          final diff = DateTime(due.year, due.month, due.day).difference(DateTime(now.year, now.month, now.day)).inDays;
          if (done) { label = 'Done'; col = Colors.teal; }
          else if (diff < 0) { label = '${-diff} days late'; col = cs.error; }
          else if (diff <= 7) { label = diff == 0 ? 'Today' : 'In $diff days'; col = Colors.orange; }
          else { label = 'In ${diff < 60 ? '$diff days' : '${(diff / 30.44).round()} months'}'; }
        } else if (done) { label = 'Done'; col = Colors.teal; }
        return ClayCard(
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            leading: Checkbox(value: done, onChanged: (x) => Store.i.toggleVax(v.key, x == true)),
            title: Text('${v.label}${due != null ? ' · ${dmy(due)}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(v.items.join(', '), style: const TextStyle(fontSize: 12)),
            trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Text(label, style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 12))),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: v.items.map((item) {
              final info = infoFor(item);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('💉 '),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item, style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (info != null) Text('${info[0]} · ${info[1]}', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                    if (info != null) Text(info[2], style: const TextStyle(fontSize: 12)),
                  ])),
                ]),
              );
            }).toList(),
          ),
        );
      }),
      ClayCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('After a vaccine · టీకా తర్వాత', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('• Mild fever, crankiness and a sore spot for 1–2 days are normal.'),
            Text('• Breastfeed more often and keep her comfortable. Hold her close.'),
            Text('• Don\'t rub, massage or put hot cloth or oil on the injection spot.'),
            Text('• Give fever medicine only as her pediatrician advises, with the dose they write.'),
            Text('• See the doctor quickly if fever is 38°C or more in a baby under 3 months, crying lasts over 3 hours, she is very sleepy or floppy, or the spot becomes very swollen and red.'),
            SizedBox(height: 8),
            Text('Based on the Indian Academy of Pediatrics schedule. Your pediatrician may adjust dates or brands; follow their vaccine card first. Tick each visit when it is done.', style: TextStyle(fontSize: 12)),
          ]),
        ),
      ),
    ]);
  }
}

class _Events extends StatelessWidget {
  const _Events();
  Future<void> _add(BuildContext context) async {
    final title = TextEditingController(), note = TextEditingController();
    DateTime date = DateTime.now();
    String kind = 'Doctor visit';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Add an event'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'What', hintText: 'Pediatrician check-up, Barasala…')),
              ListTile(contentPadding: EdgeInsets.zero, title: Text(dmy(date)), trailing: const Icon(Icons.calendar_month), onTap: () async {
                final d = await showDatePicker(context: c, firstDate: DateTime(2024), lastDate: DateTime(2040), initialDate: date);
                if (d != null) set(() => date = d);
              }),
              DropdownButtonFormField<String>(initialValue: kind, items: ['Doctor visit', 'Ceremony', 'Reminder', 'Other'].map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(), onChanged: (v) => set(() => kind = v ?? 'Other')),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add'))],
        ),
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      await Store.i.addItem('events', {'id': Store.newId(), 'title': title.text.trim(), 'date': ymd(date), 'kind': kind, 'note': note.text.trim()});
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = Store.i.list('events')..sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
    final today = ymd(DateTime.now());
    final up = items.where((e) => e['date'].toString().compareTo(today) >= 0).toList(), past = items.where((e) => e['date'].toString().compareTo(today) < 0).toList();
    Widget row(Map<String, dynamic> e) {
      final d = DateTime.parse(e['date'].toString());
      return ClayCard(
        child: ListTile(
          leading: CircleAvatar(child: Text('${d.day}\n${months3[d.month - 1]}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
          title: Text(e['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text([e['kind'], e['note']].where((x) => x != null && x.toString().isNotEmpty).join(' · ')),
          trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Store.i.removeItem('events', e['id'].toString())),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => _add(context), child: const Icon(Icons.add)),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
        if (up.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('No upcoming events. Add doctor visits and ceremonies with +.')),
        ...up.map(row),
        if (past.isNotEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Past', style: TextStyle(fontWeight: FontWeight.w700))),
        ...past.reversed.map(row),
      ]),
    );
  }
}

class _Notes extends StatefulWidget {
  const _Notes();
  @override
  State<_Notes> createState() => _NotesState();
}

class _NotesState extends State<_Notes> {
  final c = TextEditingController();
  String tag = 'General';
  @override
  Widget build(BuildContext context) {
    final notes = Store.i.list('notes')..sort((a, b) => (b['at'] as num).compareTo(a['at'] as num));
    return ListView(padding: const EdgeInsets.all(12), children: [
      TextField(controller: c, minLines: 2, maxLines: 6, decoration: const InputDecoration(hintText: 'Doctor said…, fed at 3 AM…, first time she held my finger…', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      Wrap(spacing: 6, children: ['General', 'Health', 'Feeding', 'Sleep', 'Firsts'].map((t) => ChoiceChip(label: Text(t), selected: tag == t, onSelected: (_) => setState(() => tag = t))).toList()),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: () async {
            if (c.text.trim().isEmpty) return;
            await Store.i.addItem('notes', {'id': Store.newId(), 'text': c.text.trim(), 'tag': tag, 'at': DateTime.now().millisecondsSinceEpoch});
            c.clear();
            FocusManager.instance.primaryFocus?.unfocus();
            if (mounted) setState(() {});
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved ✓ (shown below)')));
          },
          child: const Text('Save note'),
        ),
      ),
      ...notes.map((n) {
        final at = DateTime.fromMillisecondsSinceEpoch((n['at'] as num).toInt());
        return ClayCard(
          child: ListTile(
            title: Text(n['text'].toString()),
            subtitle: Text('${dmy(at)} ${hm(at)} · ${n['tag']}${n['by'] != null ? ' · ✍️ ${n['by']}' : ''}'),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => Store.i.removeItem('notes', n['id'].toString())),
          ),
        );
      }),
    ]);
  }
}

class _Growth extends StatelessWidget {
  const _Growth();
  Future<void> _add(BuildContext context) async {
    final wt = TextEditingController(), ht = TextEditingController(), hc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Today's measurements"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: wt, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Weight (kg)')),
          TextField(controller: ht, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Length (cm)')),
          TextField(controller: hc, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Head size (cm)')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))],
      ),
    );
    if (ok == true) {
      await Store.i.addItem('growth', {'id': Store.newId(), 'date': ymd(DateTime.now()), 'wt': double.tryParse(wt.text), 'ht': double.tryParse(ht.text), 'hc': double.tryParse(hc.text)});
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = Store.i.list('growth')..sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
    final wts = g.where((x) => x['wt'] != null).map((x) => (x['wt'] as num).toDouble()).toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => _add(context), child: const Icon(Icons.add)),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
        if (wts.length >= 2)
          ClayCard(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(height: 160, child: CustomPaint(painter: _LinePainter(wts, Theme.of(context).colorScheme.primary), child: Container())))),
        if (g.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('Add her weight, length and head size after each doctor visit. Tap +.')),
        ...g.reversed.map((x) => ClayCard(
              child: ListTile(
                title: Text([if (x['wt'] != null) '${x['wt']} kg', if (x['ht'] != null) '${x['ht']} cm long', if (x['hc'] != null) 'head ${x['hc']} cm'].join(' · ')),
                subtitle: Text(x['date'].toString()),
                trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Store.i.removeItem('growth', x['id'].toString())),
              ),
            )),
      ]),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> v;
  final Color c;
  _LinePainter(this.v, this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final mn = v.reduce((a, b) => a < b ? a : b) - 0.2, mx = v.reduce((a, b) => a > b ? a : b) + 0.2;
    final p = Paint()..color = c..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = s.width * i / (v.length - 1), y = s.height - (v[i] - mn) / (mx - mn) * s.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = c);
    }
    canvas.drawPath(path, p);
    final tp = TextPainter(text: TextSpan(text: 'Weight: ${v.first} → ${v.last} kg', style: TextStyle(color: c, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _LinePainter o) => o.v != v;
}
