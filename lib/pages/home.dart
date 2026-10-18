import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../clay.dart';
import '../data.dart';
import '../feed_alarm.dart';
import '../store.dart';
import '../voice.dart';
import '../watch.dart';
import '../talk.dart';
import 'cries.dart';
import 'fun.dart';
import 'profile.dart';
import 'voices.dart';

/// Soft baby palette — pastel in light mode, deep and gentle in dark mode.
class _Pal {
  final Color a, b, ink;
  const _Pal(this.a, this.b, this.ink);
}

_Pal _pal(BuildContext c, String name) {
  final dark = Theme.of(c).brightness == Brightness.dark;
  const light = {
    'rose': _Pal(Color(0xFFFDE4EA), Color(0xFFFAD3DE), Color(0xFF5A3D4B)),
    'lilac': _Pal(Color(0xFFE0789C), Color(0xFFF09AB5), Color(0xFFFFFFFF)),
    'mint': _Pal(Color(0xFFFFFBF6), Color(0xFFFFF0E3), Color(0xFF5A3D4B)),
    'peach': _Pal(Color(0xFFFFE3D3), Color(0xFFFFD2BF), Color(0xFF6B3B33)),
    'sky': _Pal(Color(0xFFF3E6FA), Color(0xFFEBD9F6), Color(0xFF5A3D6B)),
    'coral': _Pal(Color(0xFFC25A80), Color(0xFFE0789C), Color(0xFFFFFFFF)),
  };
  const night = light; // the clay theme is light only
  return (dark ? night : light)[name]!;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  Timer? _t;
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    _float.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  /// Gentle fade + rise for each section as the page opens.
  Widget _enter(int i, Widget child) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 450 + i * 90),
        curve: Curves.easeOutCubic,
        builder: (_, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: ch)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    return ListenableBuilder(
      listenable: Listenable.merge([s, SleepWatch.i]),
      builder: (context, _) => SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 28), children: [
          _enter(0, _topBar(context)),
          const SizedBox(height: 12),
          _enter(1, s.hasProfile ? _hero(context) : _setupCard(context)),
          const SizedBox(height: 16),
          if (!SleepWatch.i.on)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ClayButton(
                color: const Color(0xFFFFD6D6),
                color2: const Color(0xFFFFE9C7),
                onTap: () async {
                  final err = await SleepWatch.i.start();
                  if (err != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                },
                child: const Row(children: [
                  Text('🎧', style: TextStyle(fontSize: 30)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Cry listening is OFF', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF7A1F2B))),
                      Text('Tap to turn on – the app hears her cry (even with the screen locked) and tells you why in Telugu.', style: TextStyle(fontSize: 12, color: Color(0xFF7A1F2B))),
                    ]),
                  ),
                ]),
              ),
            ),
          const CryLiveCard(),
          if (s.openCry != null && SleepWatch.i.ep == null) _enter(2, _openCryCard(context)),
          _enter(2, _feedCard(context)),
          const SizedBox(height: 18),
          _enter(3, _grid(context)),
        ]),
      ),
    );
  }

  // ───────────── header ─────────────
  Widget _topBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DateTime.now().hour;
    final greet = h < 12 ? ('శుభోదయం', 'Good morning ☀️') : h < 17 ? ('నమస్కారం', 'Good afternoon 🌤️') : h < 21 ? ('శుభ సాయంత్రం', 'Good evening 🌇') : ('శుభ రాత్రి', 'Good night 🌙');
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greet.$1, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: cs.onSurface, height: 1.1)),
          Text(greet.$2, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        ]),
      ),
      Material(
        color: cs.primaryContainer,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
          child: const Padding(padding: EdgeInsets.all(12), child: Text('👶', style: TextStyle(fontSize: 24))),
        ),
      ),
    ]);
  }

  Widget _section(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
      );

  Widget _setupCard(BuildContext context) {
    final p = _pal(context, 'rose');
    return _gradBox(
      p,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome · స్వాగతం', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: p.ink)),
        const SizedBox(height: 6),
        Text('Add her name and birth details to start the age counter and vaccine dates.', style: TextStyle(color: p.ink)),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())), child: const Text('Add her details')),
      ]),
    );
  }

  Widget _gradBox(_Pal p, Widget child, {double r = 30, EdgeInsets pad = const EdgeInsets.all(22)}) => Clay(color: p.a, color2: p.b, radius: r, depth: 7, padding: pad, child: child);

  // ───────────── hero ─────────────
  Widget _hero(BuildContext context) {
    final s = Store.i;
    final b = s.birth;
    final p = _pal(context, 'rose');
    Vax? next;
    if (b != null) {
      for (final v in vaccines) {
        if (!s.vaxDone(v.key)) {
          next = v;
          break;
        }
      }
    }
    final listening = SleepWatch.i.on;
    return _gradBox(
      p,
      Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: AnimatedBuilder(
          animation: _float,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(_float.value);
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(right: -4, top: -6 + 6 * t, child: const Text('🌙', style: TextStyle(fontSize: 52))),
              Positioned(right: 62, top: 8 - 5 * t, child: Opacity(opacity: 0.85, child: Text('⭐', style: TextStyle(fontSize: 16 + 3 * t)))),
              Positioned(right: 30, top: 70 + 4 * t, child: const Opacity(opacity: 0.7, child: Text('✨', style: TextStyle(fontSize: 18)))),
              Positioned(right: 4, bottom: -8 - 4 * t, child: Opacity(opacity: 0.55, child: Transform.rotate(angle: math.sin(t * math.pi) * 0.08, child: const Text('☁️', style: TextStyle(fontSize: 40))))),
            ]);
          },
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            _pill(p, 'Day ${dayNumber(b)}'),
            if (listening) _pill(p, '🎧 Listening', dot: Colors.green),
          ]),
          const SizedBox(height: 14),
          Text(s.babyName, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, height: 1.0, color: p.ink, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text(ageText(b), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.ink)),
          if (b != null) Text('Born ${dmy(b)}${(s.profile['birthTime'] ?? '').toString().isNotEmpty ? ' · ${s.profile['birthTime']}' : ''}', style: TextStyle(color: p.ink.withValues(alpha: 0.75))),
          if (next != null && b != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.6), borderRadius: BorderRadius.circular(14)),
              child: Text('💉 Next vaccine: ${next.label} · ${dmy(next.due(b))}', style: TextStyle(color: p.ink, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _pill(_Pal p, String t, {Color? dot}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) ...[Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 6)],
          Text(t, style: const TextStyle(color: Color(0xFF5A3D4B), fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      );

  // ───────────── feeding ─────────────
  Widget _feedCard(BuildContext context) {
    final s = Store.i, cs = Theme.of(context).colorScheme;
    final interval = (s.settings['interval'] as num?)?.toInt() ?? 150;
    final last = s.last('feeds'), due = FeedAlarm.nextDue();
    String big = '--:--', sub = 'tap Fed now';
    double frac = 0;
    bool late = false;
    if (due != null && last != null) {
      final left = due.difference(DateTime.now()).inMinutes;
      frac = (1 - left / interval).clamp(0.0, 1.0);
      if (left > 0) {
        big = '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
        sub = 'left · ${hm(due)}';
      } else {
        late = true;
        big = 'పాలు!';
        sub = '${-left} min late';
      }
    }
    final p = _pal(context, late ? 'coral' : 'peach');
    return _gradBox(
      p,
      pad: const EdgeInsets.all(18),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('🍼  పాల సమయం', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: p.ink)),
          const Spacer(),
          if (last != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: p.ink, visualDensity: VisualDensity.compact),
              onPressed: () async {
                await s.removeLast('feeds');
                await FeedAlarm.reschedule();
              },
              child: const Text('Undo'),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(
            width: 124,
            height: 124,
            child: Stack(alignment: Alignment.center, children: [
              Container(width: 124, height: 124, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.06 : 0.55))),
              SizedBox(
                width: 112,
                height: 112,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: frac),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => CircularProgressIndicator(value: v, strokeWidth: 11, strokeCap: StrokeCap.round, backgroundColor: p.ink.withValues(alpha: 0.08), color: late ? cs.primary : const Color(0xFF22A88A)),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(big, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: late ? cs.primary : p.ink, height: 1.0)),
                const SizedBox(height: 3),
                Text(sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: p.ink.withValues(alpha: 0.75))),
              ]),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _GlowButton(
                label: 'పాలు పట్టాను',
                sub: 'Fed now',
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await s.addTime('feeds');
                  await FeedAlarm.reschedule();
                  unawaited(Voice.i.okayAmma());
                  final d = FeedAlarm.nextDue();
                  if (d != null) _snack('Feed logged 🍼  Next at ${hm(d)}');
                },
              ),
              const SizedBox(height: 8),
              Text(last == null ? 'No feeds yet today' : 'Last ${hm(last)} · ${s.countToday('feeds')} feeds today', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.ink.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: SegmentedButton<int>(
              style: SegmentedButton.styleFrom(foregroundColor: p.ink, selectedBackgroundColor: Colors.white.withValues(alpha: 0.8), selectedForegroundColor: const Color(0xFF4A2338), side: BorderSide(color: p.ink.withValues(alpha: 0.2)), visualDensity: VisualDensity.compact),
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 120, label: Text('2:00')), ButtonSegment(value: 150, label: Text('2:30')), ButtonSegment(value: 180, label: Text('3:00'))],
              selected: {interval},
              onSelectionChanged: (v) async {
                await s.setSetting('interval', v.first);
                await FeedAlarm.reschedule();
              },
            ),
          ),
          const SizedBox(width: 10),
          Column(children: [
            Switch(
              value: s.settings['alarm'] != false,
              onChanged: (v) async {
                await s.setSetting('alarm', v);
                await FeedAlarm.reschedule();
              },
            ),
            Text('⏰ alarm', style: TextStyle(fontSize: 11, color: p.ink)),
          ]),
        ]),
      ]),
    );
  }

  // ───────────── today ─────────────
  Widget _todayRow(BuildContext context) {
    final s = Store.i;
    String t(DateTime? d) => d == null ? '—' : hm(d);
    return Row(children: [
      Expanded(
        child: _tile(context, 'mint', '🧷', 'Nappy', '${s.countToday('nappies')} today · ${t(s.last('nappies'))}', () async {
          HapticFeedback.lightImpact();
          await s.addTime('nappies');
          _snack('Nappy change logged 🧷');
        }, action: '＋ Changed'),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _tile(context, 'lilac', '🌤️', 'Woke up', 'last ${t(s.last('sleeps'))}', () async {
          HapticFeedback.lightImpact();
          await s.addTime('sleeps');
          _snack('Wake-up logged 🌤️');
        }, action: '＋ Woke now'),
      ),
    ]);
  }

  Widget _tile(BuildContext context, String pal, String emoji, String title, String sub, VoidCallback onTap, {String? action, double height = 112}) {
    final p = _pal(context, pal);
    return ClayButton(
      onTap: onTap,
      color: p.a,
      color2: p.b,
      radius: 26,
      depth: 7,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClayBubble(emoji, size: 44),
            const Spacer(),
            if (action != null)
              ClayPill(action)
            else
              Icon(Icons.arrow_forward_rounded, color: p.ink.withValues(alpha: 0.6)),
          ]),
          const Spacer(),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: p.ink)),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.ink.withValues(alpha: 0.8))),
        ]),
    );
  }

  Widget _watchTile(BuildContext context) {
    final w = SleepWatch.i;
    return _tile(context, 'mint', w.on ? '🎧' : '🔇', 'Sleep watch', w.on ? 'Listening now 🟢' : 'Off · tap to open', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchPage())));
  }

  // ───────────── tiles ─────────────
  Widget _grid(BuildContext context) {
    final s = Store.i, w = SleepWatch.i;
    String t(DateTime? d) => d == null ? '—' : hm(d);
    final tiles = <Widget>[
      _tile(context, 'coral', '😢', 'పాప ఏడుస్తోంది', 'Why? Tap to find out', () => _crySheet(context)),
      _tile(context, 'mint', '🧷', 'Nappy', '${s.countToday('nappies')} today · ${t(s.last('nappies'))}', () async {
        HapticFeedback.lightImpact();
        await s.addTime('nappies');
        _snack('Nappy change logged 🧷');
      }, action: '＋'),
      _tile(context, 'lilac', '🌤️', 'Woke up', 'last ${t(s.last('sleeps'))}', () async {
        HapticFeedback.lightImpact();
        await s.addTime('sleeps');
        _snack('Wake-up logged 🌤️');
      }, action: '＋'),
      _tile(context, 'mint', w.on ? '🎧' : '🔇', 'Sleep watch', w.on ? 'Listening 🟢' : 'Off', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchPage()))),
      _tile(context, 'sky', '📊', 'Cry tracker', '${s.countCries()} cries today', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CryHistoryPage()))),
      _tile(context, 'peach', '🎙️', 'Baby voices', '${s.list('voices').length} saved', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoicesPage()))),
      _tile(context, 'rose', '😂', 'Fun zone', 'Farts & translator', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FunPage()))),
      _tile(context, 'lilac', '🗣️', 'Talking baby', Talk.enabled ? 'On · every hour' : 'Off', () => _talkSheet(context)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: tiles,
    );
  }

  void _talkSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => ListenableBuilder(
        listenable: Store.i,
        builder: (c, _) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: _talkCard(c))),
      ),
    );
  }

  // ───────────── talking baby ─────────────
  Widget _talkCard(BuildContext context) {
    final p = _pal(context, 'mint');
    final s = Store.i;
    final vol = ((s.settings['talkVol'] as num?)?.toDouble() ?? 0.8);
    return _gradBox(
      p,
      pad: const EdgeInsets.fromLTRB(18, 14, 10, 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🗣️', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 10),
          Expanded(child: Text('Talking baby', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: p.ink))),
          Switch(
            value: Talk.enabled,
            onChanged: (v) async {
              await s.setSetting('talk', v);
              await Talk.reschedule();
            },
          ),
        ]),
        Text('☀️ 8 AM "గుడ్ మార్నింగ్ అమ్మా, లేచావా?" · every hour she asks "అమ్మా / నాన్న / అమ్మమ్మ / తాతయ్య ఏం చేస్తున్నారు?" · 12 PM 🍗 biryani or 🍕 pizza · 🌙 8 PM "గుడ్ నైట్ అమ్మా, జై శ్రీ రామ్ చెప్పి బజ్జో". Works even when the app is closed.', style: TextStyle(fontSize: 12.5, color: p.ink.withValues(alpha: 0.85))),
        Row(children: [
          Text('🔉', style: TextStyle(color: p.ink)),
          Expanded(
            child: Slider(
              value: vol,
              min: 0.2,
              max: 1.0,
              onChanged: (v) => s.setSetting('talkVol', v),
              onChangeEnd: (_) => Talk.reschedule(),
            ),
          ),
          TextButton(style: TextButton.styleFrom(foregroundColor: p.ink), onPressed: () => Talk.test(), child: const Text('▶ Try')),
        ]),
      ]),
    );
  }

  // ───────────── crying ─────────────
  Widget _cryBig(BuildContext context) {
    final p = _pal(context, 'coral');
    return _Pressable(
      onTap: () => _crySheet(context),
      child: _gradBox(
        p,
        pad: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        Row(children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.55)),
            child: const Text('😢', style: TextStyle(fontSize: 34)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('పాప ఏడుస్తోంది', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: p.ink)),
              Text('Tap — I\'ll tell you why and save it', style: TextStyle(color: p.ink.withValues(alpha: 0.85))),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, size: 30, color: p.ink),
        ]),
      ),
    );
  }

  Widget _openCryCard(BuildContext context) {
    final c = Store.i.openCry!;
    final t = DateTime.fromMillisecondsSinceEpoch((c['at'] as num).toInt());
    final p = _pal(context, 'sky');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _Pressable(
        onTap: () => askWhatCalmed(context, c['id'].toString()),
        child: _gradBox(
          p,
          r: 22,
          pad: const EdgeInsets.all(14),
          Row(children: [
            const Text('🤔', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('She cried at ${hm(t)}${c['src'] == 'auto' ? ' · Sleep watch' : ''}', style: TextStyle(fontWeight: FontWeight.w800, color: p.ink)),
                Text('Calm now? Tap and tell what worked', style: TextStyle(fontSize: 12, color: p.ink.withValues(alpha: 0.8))),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: p.ink),
          ]),
        ),
      ),
    );
  }

  void _crySheet(BuildContext context) {
    final r = cryReasons(), top = r.first;
    final idF = Store.i.addCry('manual', top.key);
    unawaited(Voice.i.sayClips([top.clip], top.say));
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
          ClayCard(
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
                TextButton.icon(onPressed: () => Voice.i.sayClips([top.clip], top.say), icon: const Icon(Icons.volume_up), label: const Text('మళ్ళీ చెప్పు')),
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
          ClayCard(
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

/// Shrinks a little when pressed — feels soft and springy.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => down = true),
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => setState(() => down = false),
        onTap: widget.onTap,
        child: AnimatedScale(scale: down ? 0.96 : 1, duration: const Duration(milliseconds: 120), curve: Curves.easeOut, child: widget.child),
      );
}

/// The big pink "Fed now" button.
class _GlowButton extends StatelessWidget {
  final String label, sub;
  final VoidCallback onTap;
  const _GlowButton({required this.label, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => ClayButton(
        onTap: onTap,
        color: const Color(0xFFE0789C),
        color2: const Color(0xFFF09AB5),
        radius: 22,
        depth: 7,
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0x55C25A80), offset: Offset(0, 1.5), blurRadius: 2)])),
          Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}
