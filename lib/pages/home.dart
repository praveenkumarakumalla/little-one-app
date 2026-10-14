import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../feed_alarm.dart';
import '../store.dart';
import '../voice.dart';
import '../watch.dart';
import 'cries.dart';
import 'profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final s = Store.i, cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          if (!s.hasProfile) _setupCard(context) else _hero(context),
          _feedCard(context),
          Row(children: [
            Expanded(child: _quick(context, '🧷', 'Nappy changed', () async { await s.addTime('nappies'); _snack('Nappy change logged'); })),
            const SizedBox(width: 10),
            Expanded(child: _quick(context, '🌤️', 'Woke up', () async { await s.addTime('sleeps'); _snack('Wake-up logged'); })),
          ]),
          const SizedBox(height: 8),
          if (s.openCry != null) _openCryCard(context),
          _bigButton(context, '😢', 'పాప ఏడుస్తోంది', 'Why is she crying? Tap — it saves the cry and tells the reason', [cs.tertiaryContainer, cs.primaryContainer], () => _crySheet(context)),
          _bigButton(context, '📊', 'ఏడుపు డైరీ · Cry tracker', '${s.countCries()} cries today · see her pattern', [cs.secondaryContainer, cs.tertiaryContainer], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CryHistoryPage()))),
          _bigButton(context, '🎧', 'నిద్ర కాపలా · Sleep watch', 'Listens for loud voices and her cry', [cs.secondaryContainer, cs.surface], () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchPage()))),
          _bigButton(context, '🤫', 'Shhh', 'Says "బేబీ బజ్జో ఉంది, అరవకండి" out loud', [cs.primaryContainer, cs.surface], () => _shh(context)),
          _lullabyCard(context),
          const SizedBox(height: 8),
          Center(child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())), child: const Text('Edit her details · Backup'))),
        ]),
      ),
    );
  }


  Widget _setupCard(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Welcome · స్వాగతం', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Add her name and birth details to start the age counter and vaccine dates.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())), child: const Text('Add her details')),
          ]),
        ),
      );

  Widget _hero(BuildContext context) {
    final s = Store.i, cs = Theme.of(context).colorScheme;
    final b = s.birth;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primaryContainer, cs.tertiaryContainer, cs.secondaryContainer]),
      ),
      child: Stack(children: [
        const Positioned(right: 0, top: 0, child: Text('🌙', style: TextStyle(fontSize: 54))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(20)),
            child: Text('Day ${dayNumber(b)}', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          Text(s.babyName, style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, height: 1.0)),
          const SizedBox(height: 6),
          Text(ageText(b), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (b != null) Text('Born ${dmy(b)}${(s.profile['birthTime'] ?? '').toString().isNotEmpty ? ', ${s.profile['birthTime']}' : ''}', style: TextStyle(color: cs.onSurfaceVariant)),
        ]),
      ]),
    );
  }

  Widget _feedCard(BuildContext context) {
    final s = Store.i, cs = Theme.of(context).colorScheme;
    final interval = (s.settings['interval'] as num?)?.toInt() ?? 150;
    final last = s.last('feeds'), due = FeedAlarm.nextDue();
    String big = '--:--', sub = 'Tap "Fed now" to start the timer';
    double frac = 0;
    bool late = false;
    if (due != null && last != null) {
      final left = due.difference(DateTime.now()).inMinutes;
      frac = (1 - left / interval).clamp(0.0, 1.0);
      if (left > 0) {
        big = '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
        sub = 'next feed at ${hm(due)}';
      } else {
        late = true;
        big = 'పాలు!';
        sub = '${-left} min past feed time';
      }
    }
    return Card(
      color: late ? cs.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('పాల సమయం · Feeding', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            if (last != null)
              TextButton(onPressed: () async { await s.removeLast('feeds'); await FeedAlarm.reschedule(); }, child: const Text('Undo last')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 110, height: 110, child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: frac), duration: const Duration(milliseconds: 700), builder: (_, v, __) => CircularProgressIndicator(value: v, strokeWidth: 10, strokeCap: StrokeCap.round, backgroundColor: cs.surfaceContainerHighest, color: late ? cs.primary : Colors.teal))),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(big, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: late ? cs.primary : null)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
                ]),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    await s.addTime('feeds');
                    await FeedAlarm.reschedule();
                    unawaited(Voice.i.okayAmma());
                    final d = FeedAlarm.nextDue();
                    if (d != null) _snack('Feed logged 🍼 Next at ${hm(d)}');
                  },
                  child: const Text('🍼 పాలు పట్టాను\nFed now', textAlign: TextAlign.center),
                ),
                const SizedBox(height: 6),
                Text(last == null ? 'No feeds yet' : 'Last fed ${hm(last)} · ${s.countToday('feeds')} today', style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Text('Every '),
            ...[120, 150, 180].map((m) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text('${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}'), selected: interval == m, onSelected: (_) async { await s.setSetting('interval', m); await FeedAlarm.reschedule(); }),
                )),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: s.settings['alarm'] != false,
            title: const Text('Baby-voice alarm (rings even when the app is closed)'),
            onChanged: (v) async { await s.setSetting('alarm', v); await FeedAlarm.reschedule(); },
          ),
        ]),
      ),
    );
  }

  Widget _quick(BuildContext context, String emoji, String label, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Column(children: [Text(emoji, style: const TextStyle(fontSize: 26)), Text(label, style: const TextStyle(fontWeight: FontWeight.w600))])),
      ),
    );
  }

  Widget _bigButton(BuildContext context, String emoji, String title, String sub, List<Color> colors, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Text(emoji, style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), Text(sub)])),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ),
          ),
        ),
      );

  Widget _lullabyCard(BuildContext context) {
    final on = Voice.i.musicOn;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(radius: 26, backgroundColor: Theme.of(context).colorScheme.primary, child: Icon(on ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 30)),
        title: const Text('జోల పాట · Lullaby', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        subtitle: Text(on ? 'Playing ${Voice.i.nowPlaying}' : 'Music box. More songs in the Songs tab.'),
        onTap: () async {
          on ? await Voice.i.stopMusic() : await Voice.i.playMusicBox();
          setState(() {});
        },
      ),
    );
  }

  Future<void> _shh(BuildContext context) async {
    showDialog(
      context: context,
      builder: (c) {
        Future.delayed(const Duration(seconds: 5), () { if (Navigator.of(c).canPop()) Navigator.of(c).pop(); });
        return const AlertDialog(
          icon: Text('🤫', style: TextStyle(fontSize: 70)),
          title: Text('బేబీ బజ్జో ఉంది,\nఅరవకండి', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
          content: Text('Baby is sleeping · please keep quiet', textAlign: TextAlign.center),
        );
      },
    );
    await Voice.i.shh();
  }

  Widget _openCryCard(BuildContext context) {
    final c = Store.i.openCry!;
    final t = DateTime.fromMillisecondsSinceEpoch((c['at'] as num).toInt());
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Text('😢', style: TextStyle(fontSize: 28)),
        title: Text('She cried at ${hm(t)}${c['src'] == 'auto' ? ' (Sleep watch heard it)' : ''}'),
        subtitle: const Text('Is she calm now? Tap and tell what worked'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => askWhatCalmed(context, c['id'].toString()),
      ),
    );
  }

  void _crySheet(BuildContext context) {
    final r = cryReasons(), top = r.first;
    final idF = Store.i.addCry('manual', top.key);
    unawaited(Voice.i.say(top.say));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (c, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
          const Center(child: Text('పాప ఎందుకు ఏడుస్తోంది?')),
          const SizedBox(height: 8),
          Card(
            color: Theme.of(c).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                const Text('MOST LIKELY', style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                Text(top.te, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
                Text(top.en, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(top.why, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(top.todo, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                TextButton.icon(onPressed: () => Voice.i.say(top.say), icon: const Icon(Icons.volume_up), label: const Text('మళ్ళీ చెప్పు')),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
            icon: const Icon(Icons.check),
            label: const Text('She is calm now · what worked?', style: TextStyle(fontSize: 16)),
            onPressed: () async {
              final id = await idF;
              if (c.mounted) Navigator.pop(c);
              if (context.mounted) await askWhatCalmed(context, id);
            },
          ),
          const SizedBox(height: 10),
          const Text('Then check these', style: TextStyle(fontWeight: FontWeight.w700)),
          ...r.skip(1).take(5).map((x) => ExpansionTile(title: Text('${x.te} · ${x.en}'), children: [ListTile(title: Text(x.why), subtitle: Text('Try: ${x.todo}'))])),
          const SizedBox(height: 8),
          Card(
            color: Theme.of(c).colorScheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Go to the hospital or call 108 now if her cry is high-pitched, weak or very different from usual, if she can\'t be calmed for hours, or if she also has fever (38°C or more), floppiness, breathing trouble, blue or very pale skin, or forceful vomiting.'),
            ),
          ),
          const Text('If you feel overwhelmed: put her safely on her back in the cot, step away for a few minutes, and ask a family member to take over. Never shake a baby.', style: TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}
