import 'dart:async';

import 'package:flutter/material.dart';

import '../clay.dart';

import '../data.dart';
import '../store.dart';
import '../voice.dart';

/// Ask the parents what really calmed her, so the app learns her patterns.
Future<void> askWhatCalmed(BuildContext context, String id) async {
  final c = Store.i.list('cries').where((e) => e['id'] == id).firstOrNull;
  if (c == null) return;
  final at = DateTime.fromMillisecondsSinceEpoch((c['at'] as num).toInt());
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ఏడుపు ${hm(at)} · What calmed her?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Your answer teaches the app her own pattern.', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cryActuals
              .map((a) => ActionChip(
                    avatar: Text(a[1]),
                    label: Text('${a[2]} · ${a[3]}'),
                    onPressed: () async {
                      final now = DateTime.now();
                      await Store.i.updateCry(id, {'actual': a[0], 'calmAt': now.millisecondsSinceEpoch});
                      if (a[0] == 'hungry' && (Store.i.last('feeds') == null || now.difference(Store.i.last('feeds')!).inMinutes > 20)) await Store.i.addTime('feeds');
                      if (a[0] == 'nappy') await Store.i.addTime('nappies');
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (a[0] == 'unwell' && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 8), content: Text('If she has fever 38°C+, breathing trouble, is floppy, not feeding or crying weakly — see a doctor today or call 108.')));
                      } else {
                        unawaited(Voice.i.sayClips(['remember'], 'సరే, గుర్తు పెట్టుకున్నాను.'));
                      }
                    },
                  ))
              .toList(),
        ),
      ]),
    ),
  );
}

class CryHistoryPage extends StatelessWidget {
  const CryHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final all = Store.i.list('cries').reversed.toList();
        final now = DateTime.now();
        final today0 = DateTime(now.year, now.month, now.day);
        DateTime at(Map c) => DateTime.fromMillisecondsSinceEpoch((c['at'] as num).toInt());
        final today = all.where((c) => at(c).isAfter(today0)).length;
        final week = all.where((c) => now.difference(at(c)).inDays < 7).toList();
        final answered = all.where((c) => c['actual'] != null).toList();
        final right = answered.where((c) => c['actual'] == c['guess']).length;

        final reasons = <String, int>{};
        for (final c in answered) {
          reasons[c['actual'].toString()] = (reasons[c['actual'].toString()] ?? 0) + 1;
        }
        final rs = reasons.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        const slots = [
          ['🌙', 'Night 12–6 AM', 0, 6],
          ['🌅', 'Morning 6–12', 6, 12],
          ['☀️', 'Afternoon 12–5', 12, 17],
          ['🌆', 'Evening 5–9 PM', 17, 21],
          ['🌃', 'Late 9–12 PM', 21, 24],
        ];
        final slotN = slots.map((sl) => week.where((c) => at(c).hour >= (sl[2] as int) && at(c).hour < (sl[3] as int)).length).toList();
        final maxSlot = slotN.fold<int>(1, (a, b) => b > a ? b : a);

        final mins = answered.where((c) => c['calmAt'] != null).map((c) => ((c['calmAt'] as num) - (c['at'] as num)) / 60000).where((m) => m > 0 && m < 240).toList();
        final avgCalm = mins.isEmpty ? null : (mins.reduce((a, b) => a + b) / mins.length).round();

        final unwellWeek = week.where((c) => c['actual'] == 'unwell').length;

        Widget stat(String big, String small) => Expanded(
              child: ClayCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  child: Column(children: [
                    Text(big, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: cs.primary)),
                    Text(small, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                  ]),
                ),
              ),
            );

        Widget bar(String label, int n, int max, Color col) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 150, child: Text(label, style: const TextStyle(fontSize: 14))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: max == 0 ? 0 : n / max, minHeight: 14, color: col, backgroundColor: cs.surfaceContainerHighest),
                  ),
                ),
                SizedBox(width: 34, child: Text(' $n', style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
            );

        String insight() {
          if (answered.length < 3) return 'Each time she cries, tap what calmed her. After a few cries the app learns her own pattern and its guesses get better.';
          final top = actualOf(rs.first.key);
          final peak = slotN.indexOf(maxSlot);
          final parts = <String>['Most often she cries because of ${top[3].toLowerCase()} ${top[1]} (${rs.first.value} of ${answered.length}).'];
          if (week.length >= 4) parts.add('This week she cries most in the ${(slots[peak][1] as String).split(' ').first.toLowerCase()}.');
          parts.add('The app\'s first guess was right $right of ${answered.length} times.');
          return parts.join(' ');
        }

        // Group the list by day
        final byDay = <String, List<Map<String, dynamic>>>{};
        for (final c in all.take(200)) {
          byDay.putIfAbsent(ymd(at(c)), () => []).add(c);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('ఏడుపు డైరీ · Cry tracker')),
          body: ListView(padding: const EdgeInsets.all(14), children: [
            Row(children: [stat('$today', 'cries today'), stat('${(week.length / 7).toStringAsFixed(1)}', 'per day (7 days)'), stat(avgCalm == null ? '–' : '${avgCalm}m', 'to calm her')]),
            ClayCard(
              color: cs.primaryContainer,
              child: Padding(padding: const EdgeInsets.all(16), child: Text(insight(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            ),
            if (unwellWeek >= 2)
              ClayCard(
                color: cs.errorContainer,
                child: Padding(padding: const EdgeInsets.all(14), child: Text('You marked "unwell" $unwellWeek times this week. Please show her to the paediatrician.')),
              ),
            if (week.length >= 7 * 6)
              ClayCard(
                color: cs.errorContainer,
                child: const Padding(padding: EdgeInsets.all(14), child: Text('She is crying a lot this week. Lots of evening crying is common between 2 weeks and 4 months, but mention it to the doctor to rule out reflux, milk allergy or other problems.')),
              ),
            if (rs.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('What calmed her', style: Theme.of(context).textTheme.titleMedium),
              ...rs.map((e) {
                final a = actualOf(e.key);
                return bar('${a[1]} ${a[3]}', e.value, rs.first.value, cs.primary);
              }),
            ],
            if (week.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('When she cries (last 7 days)', style: Theme.of(context).textTheme.titleMedium),
              for (var i = 0; i < slots.length; i++) bar('${slots[i][0]} ${slots[i][1]}', slotN[i], maxSlot, Colors.teal),
            ],
            const SizedBox(height: 14),
            Text('Every cry', style: Theme.of(context).textTheme.titleMedium),
            if (all.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No cries saved yet. Tap "పాప ఏడుస్తోంది" on Home when she cries, or turn on Sleep watch — it saves cries by itself.')),
            ...byDay.entries.expand((day) => [
                  Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 4), child: Text(dmy(DateTime.parse(day.key)), style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary))),
                  ...day.value.map((c) {
                    final t = at(c);
                    final g = actualOf(c['guess'].toString());
                    final a = c['actual'] == null ? null : actualOf(c['actual'].toString());
                    final dur = c['calmAt'] == null ? '' : ' · calm in ${(((c['calmAt'] as num) - (c['at'] as num)) / 60000).round()} min';
                    final sf = c['sinceFeed'] == null ? '' : ' · ${hmDur((c['sinceFeed'] as num).toInt())} after feed';
                    return ClayCard(
                      child: ListTile(
                        leading: Text(a?[1] ?? '😢', style: const TextStyle(fontSize: 28)),
                        title: Text(a == null ? '${hm(t)} · tap: what calmed her?' : '${hm(t)} · ${a[3]}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${c['src'] == 'auto' ? '🎧 heard by Sleep watch' : '👆 logged by you'} · guess: ${g[3]}$sf$dur${c['sound'] is Map ? '\n🔊 ${(c['sound'] as Map)['en']}' : ''}'),
                        trailing: a != null && c['actual'] == c['guess'] ? const Icon(Icons.check_circle, color: Colors.teal) : null,
                        onTap: () => askWhatCalmed(context, c['id'].toString()),
                        onLongPress: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(title: const Text('Delete this cry?'), actions: [
                              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('No')),
                              FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
                            ]),
                          );
                          if (ok == true) await Store.i.removeItem('cries', c['id'].toString());
                        },
                      ),
                    );
                  }),
                ]),
            const SizedBox(height: 10),
            Text('Long-press a cry to delete it. The reasons are a guess from her feed, nappy and sleep times plus what calmed her before — no app can read the reason from the sound alone.', style: TextStyle(fontSize: 12, color: cs.outline)),
          ]),
        );
      },
    );
  }
}

String hmDur(int m) => m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';
