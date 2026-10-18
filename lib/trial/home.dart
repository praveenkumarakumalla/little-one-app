import 'package:flutter/material.dart';

import '../call.dart';
import '../chat.dart';
import '../data.dart';
import '../store.dart';
import '../voice.dart';
import '../watch.dart';
import 'astro.dart';
import 'care.dart';
import 'jatakam.dart';
import 'knowledge.dart';
import 'more.dart';
import 'ui.dart';

class HomeTab extends StatefulWidget {
  final void Function(int tab) goTab;
  const HomeTab({super.key, required this.goTab});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final pc = PageController(viewportFraction: 0.86);
  int page = 0;

  static const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const _monthsTe = ['జనవరి', 'ఫిబ్రవరి', 'మార్చి', 'ఏప్రిల్', 'మే', 'జూన్', 'జూలై', 'ఆగస్టు', 'సెప్టెంబర్', 'అక్టోబర్', 'నవంబర్', 'డిసెంబర్'];

  String _ord(int d) => (d >= 11 && d <= 13) ? 'th' : (d % 10 == 1 ? 'st' : d % 10 == 2 ? 'nd' : d % 10 == 3 ? 'rd' : 'th');

  /// What the baby says now, by the time of day: (clip key, English, Telugu)
  (String, String, String) _line(String me) {
    final h = DateTime.now().hour;
    if (h < 11) return ('gm', 'Good morning $me! Are you up?', 'గుడ్ మార్నింగ్ $me! లేచావా?');
    if (h < 14) return ('akali', '$me, I am hungry!', '$me, నాకు ఆకలిగా ఉంది!');
    if (h < 18) return ('play', 'Play with me, please!', 'నాతో ఆడుకో, ప్లీజ్!');
    if (h < 20) return ('love', 'I love you, $me!', '$me, ఐ లవ్ యూ!');
    return ('gn', 'Good night $me! Sing me a lullaby.', 'గుడ్ నైట్ $me! జోల పాడు.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, Chat.i, SleepWatch.i]),
      builder: (context, _) {
        final s = Store.i, w = SleepWatch.i;
        final now = DateTime.now();
        final name = s.babyName;
        final role = (s.settings['tRole'] ?? 'Amma').toString();
        final me = role == 'Family' ? (s.settings['tMe'] ?? '').toString() : role;
        final h = now.hour;
        final hello = h < 12 ? tr('Good morning', 'శుభోదయం') : (h < 17 ? tr('Good afternoon', 'నమస్కారం') : tr('Good evening', 'శుభ సాయంత్రం'));
        final feeds = s.countToday('feeds');
        final c = babyChart();
        final line = _line(me);
        final b = s.birth;
        final nextVax = b == null ? null : vaccines.where((v) => !s.vaxDone(v.key)).cast<Vax?>().firstWhere((_) => true, orElse: () => null);
        final dayNo = dayNumber(b);
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 130), children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  ClayBox(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MorePage())),
                    radius: 16,
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.short_text_rounded, color: K.ink),
                  ),
                  const Spacer(),
                  ClayBox(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MorePage())),
                    radius: 16,
                    color: K.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(K.te ? '${now.day} ${_monthsTe[now.month - 1]}' : '${now.day}${_ord(now.day)} ${_monthsEn[now.month - 1]}', style: const TextStyle(color: K.muted, fontSize: 13)),
                  Text('$hello, $me!', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                ]),
              ),
              SizedBox(
                height: 178,
                child: PageView(
                  controller: pc,
                  padEnds: false,
                  onPageChanged: (i) => setState(() => page = i),
                  children: [
                    _hero(
                      K.indigo,
                      Colors.white,
                      tr('$name\'s day', '$name రోజు'),
                      '${ageText(b)} · ${tr('day', 'రోజు')} $dayNo',
                      '$feeds ${tr('of 8 feeds today', '/ 8 సార్లు పాలు ఈరోజు')}',
                      Ring(value: feeds / 8, text: '${(feeds / 8 * 100).clamp(0, 100).round()}%'),
                      () => widget.goTab(1),
                    ),
                    _hero(
                      K.pink,
                      K.deep,
                      tr('Cry listening', 'ఏడుపు వినడం'),
                      w.on ? tr('On · works with the screen locked', 'ఆన్ · స్క్రీన్ లాక్ అయినా పనిచేస్తుంది') : tr('Off · tap to start', 'ఆఫ్ · మొదలుపెట్టడానికి నొక్కండి'),
                      w.on ? tr('Tips are spoken aloud in Telugu', 'చిట్కాలు తెలుగులో గట్టిగా చెబుతుంది') : tr('Recognises crying in about 3 seconds', 'సుమారు 3 సెకన్లలో ఏడుపు గుర్తిస్తుంది'),
                      Icon(w.on ? Icons.hearing : Icons.hearing_disabled, size: 64, color: K.deep),
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchPage())),
                    ),
                    if (c != null)
                      _hero(
                        K.deep,
                        Colors.white,
                        tr('Birth star', 'జన్మ నక్షత్రం'),
                        '${nakName(c.nak)} · ${tr('Pada', 'పాదం')} ${c.pada}',
                        '${tr('Rasi', 'రాశి')}: ${rasiName(c.rasi)} · ${tr('Letter', 'అక్షరం')} ${K.te ? Astro.lettersTe[c.nak][c.pada - 1] : Astro.letters[c.nak][c.pada - 1]}',
                        const Icon(Icons.auto_awesome, size: 60, color: K.pink),
                        () => widget.goTab(3),
                      ),
                  ],
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < (c == null ? 2 : 3); i++)
                  AnimatedContainer(duration: const Duration(milliseconds: 200), width: page == i ? 18 : 6, height: 6, margin: const EdgeInsets.all(3), decoration: BoxDecoration(color: page == i ? K.indigo : const Color(0xFFC9C3DD), borderRadius: BorderRadius.circular(4))),
              ]),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: CryLiveCard()),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  ClayCircle(icon: Icons.call, label: tr('Call', 'కాల్'), onTap: () => _call(context, false)),
                  ClayCircle(icon: Icons.videocam, label: tr('Video', 'వీడియో'), onTap: () => _call(context, true)),
                  ClayCircle(icon: Icons.chat_bubble, label: tr('Chat', 'చాట్'), dot: Chat.i.unread > 0, onTap: () => widget.goTab(2)),
                  ClayCircle(
                    icon: w.on ? Icons.hearing : Icons.hearing_disabled,
                    label: tr('Listen', 'వినడం'),
                    color: w.on ? K.indigo : K.card,
                    iconColor: w.on ? Colors.white : K.indigo,
                    onTap: () async {
                      if (w.on) {
                        await w.stop();
                      } else {
                        await w.start();
                      }
                      await s.setSetting('autoWatch', w.on);
                    },
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: ClayBox(
                  color: K.pinkSoft,
                  onTap: () async {
                    if (!(K.te && await Voice.i.clip(line.$1))) await Voice.i.say(K.te ? line.$3 : line.$2, lat: line.$2, pitch: 1.8);
                  },
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: K.indigo, shape: BoxShape.circle), child: const Icon(Icons.volume_up, color: Colors.white)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('$name says…', '$name అంటోంది…'), style: const TextStyle(fontSize: 12, color: K.muted)),
                        Text(K.te ? line.$3 : line.$2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const Icon(Icons.play_circle_fill, color: K.indigo, size: 34),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(children: [
                  SectionTitle(tr('Today', 'ఈరోజు'), action: tr('See all', 'అన్నీ'), onAction: () => widget.goTab(1)),
                  Row(children: [
                    for (final k in logKinds) ...[
                      Expanded(
                        child: ClayBox(
                          onTap: () => quickLog(context, k.$1),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          child: Column(children: [
                            Icon(k.$2, color: K.indigo),
                            const SizedBox(height: 4),
                            Text(tr(k.$3, k.$4), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(s.last(k.$1) == null ? '–' : hm(s.last(k.$1)!), style: const TextStyle(fontSize: 11.5, color: K.muted)),
                          ]),
                        ),
                      ),
                      if (k != logKinds.last) const SizedBox(width: 10),
                    ],
                  ]),
                  if (nextVax != null && b != null) ...[
                    const SizedBox(height: 14),
                    ClayBox(
                      onTap: () => widget.goTab(1),
                      child: Row(children: [
                        const Icon(Icons.vaccines, color: K.indigo, size: 30),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${tr('Next vaccine', 'తర్వాతి టీకా')}: ${nextVax.label}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${dmy(nextVax.due(b))} · ${nextVax.items.take(3).join(', ')}', style: const TextStyle(fontSize: 12, color: K.muted)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                  ],
                  SectionTitle(tr('For you', 'మీ కోసం')),
                  Row(children: [
                    Expanded(
                      child: ClayBox(
                        color: K.indigo,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidesPage())),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.menu_book, color: K.pink, size: 30),
                          const SizedBox(height: 10),
                          Text(tr('Guide books', 'గైడ్ పుస్తకాలు'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          Text(tr('PDF · English, Telugu', 'PDF · ఇంగ్లీష్, తెలుగు'), style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClayBox(
                        color: K.pink,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchemesPage())),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.savings, color: K.deep, size: 30),
                          const SizedBox(height: 10),
                          Text(tr('Schemes & savings', 'పథకాలు, పొదుపు'), style: const TextStyle(color: K.deep, fontWeight: FontWeight.w700)),
                          Text(tr('Government help', 'ప్రభుత్వ సహాయం'), style: const TextStyle(color: K.deep, fontSize: 11.5)),
                        ]),
                      ),
                    ),
                  ]),
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
      widget.goTab(2);
      return;
    }
    await Calls.start(context, video: video);
  }

  Widget _hero(Color bg, Color fg, String title, String sub, String foot, Widget art, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 18, right: 4, bottom: 14),
      child: ClayBox(
        color: bg,
        onTap: onTap,
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(title, style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub, maxLines: 2, style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 13)),
              const Spacer(),
              Text(foot, maxLines: 2, style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 11.5)),
            ]),
          ),
          const SizedBox(width: 10),
          art,
        ]),
      ),
    );
  }
}
