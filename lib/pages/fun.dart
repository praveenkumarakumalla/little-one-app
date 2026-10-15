import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../voice.dart';

class FunSound {
  final String file, emoji, name;
  final Color color;
  const FunSound(this.file, this.emoji, this.name, this.color);
}

const farts = [
  FunSound('fart_classic', '💨', 'The Classic', Color(0xFFFFE08A)),
  FunSound('fart_squeaker', '🐭', 'Squeaker', Color(0xFFFFC9DE)),
  FunSound('fart_machine_gun', '🔫', 'Machine Gun', Color(0xFFC9E7FF)),
  FunSound('fart_tuba', '🎺', 'Tuba Blast', Color(0xFFFFD2B8)),
  FunSound('fart_long_goodbye', '👋', 'Long Goodbye', Color(0xFFD9D2FF)),
  FunSound('fart_tiny_toot', '🐣', 'Tiny Toot', Color(0xFFD5F5E8)),
  FunSound('fart_wet_one', '💦', 'Wet One', Color(0xFFBFEAF5)),
  FunSound('fart_rocket', '🚀', 'Rocket Launch', Color(0xFFFFCACA)),
  FunSound('fart_duck', '🦆', 'Duck Fart', Color(0xFFFFF0B3)),
  FunSound('fart_silent_deadly', '☠️', 'Silent but Deadly', Color(0xFFE2E2E2)),
];

const funny = [
  FunSound('fun_boing', '🤸', 'Boing!', Color(0xFFFFE08A)),
  FunSound('fun_slide_up', '⬆️', 'Whistle Up', Color(0xFFC9E7FF)),
  FunSound('fun_slide_down', '⬇️', 'Whistle Down', Color(0xFFD9D2FF)),
  FunSound('fun_ba_dum_tss', '🥁', 'Ba-dum-tss', Color(0xFFFFD2B8)),
  FunSound('fun_pop', '🍾', 'Pop!', Color(0xFFD5F5E8)),
  FunSound('fun_cuckoo', '🐦', 'Cuckoo', Color(0xFFFFF0B3)),
  FunSound('fun_clown_horn', '🤡', 'Clown Horn', Color(0xFFFFC9DE)),
  FunSound('fun_sad_trombone', '😭', 'Sad Trombone', Color(0xFFE2E2E2)),
];

/// [Telugu, English]
const babyLines = [
  ['నాన్నా, నీ జోకులు బాగోలేవు. పాలు తీసుకురా.', 'Nanna, your jokes are bad. Bring milk.'],
  ['అమ్మా, డైపర్‌లో ఒక సర్‌ప్రైజ్ పెట్టాను.', 'Amma, I left a surprise in my diaper.'],
  ['నిద్రా? నేనా? రాత్రి మూడు గంటలకు పార్టీ!', 'Sleep? Me? Party at 3 AM!'],
  ['ఫోన్ కింద పెట్టి, నన్ను ఎత్తుకో.', 'Put the phone down and pick me up.'],
  ['ఈ ఇంట్లో బాస్ నేనే.', 'I am the boss of this house.'],
  ['ఆ ఫార్ట్ నేను కాదు... నాన్న!', "That fart wasn't me... it was Nanna!"],
  ['పాలు, నిద్ర, ముద్దులు. మళ్ళీ మొదటి నుంచి.', 'Milk, sleep, kisses. Repeat.'],
  ['ఫోటోలు ఆపండి, నేను మేకప్ వేసుకోలేదు.', "Stop the photos, I'm not wearing makeup."],
  ['అమ్మమ్మ పాట పాడితే నాకు చాలా ఇష్టం.', 'I love it when Ammamma sings.'],
  ['ఈ బట్టలు ఎవరు ఎంచారు? నా స్టైల్ కాదు.', 'Who picked these clothes? Not my style.'],
  ['నేను ఏడవడం లేదు, పాట ప్రాక్టీస్ చేస్తున్నా.', "I'm not crying, I'm practising my singing."],
  ['నాన్నా, ఆఫీస్ వద్దు, నాతో ఆడుకో.', 'Nanna, skip office, play with me.'],
  ['నా కాలు నా నోట్లోకి ఇంకా ఎందుకు రావట్లేదు?', "Why won't my foot reach my mouth yet?"],
  ['హాయ్, నేను కొత్తగా వచ్చాను. Wi-Fi పాస్‌వర్డ్ ఏంటి?', "Hi, I'm new here. What's the Wi-Fi password?"],
  ['ఈ జోల పాట మళ్ళీనా? సరే, చివరిసారి.', 'This lullaby again? Fine, one last time.'],
  ['అమ్మ ముద్దుకి ఐదు స్టార్లు.', "Amma's kiss: five stars ⭐⭐⭐⭐⭐"],
  ['తాతయ్య మీసం చూస్తే నాకు నవ్వొస్తుంది.', "Thatayya's moustache makes me laugh."],
  ['నేను పడుకున్నాను అనుకున్నారా? హహ, లేదు!', 'You thought I was asleep? Ha, no!'],
];

class FunPage extends StatefulWidget {
  const FunPage({super.key});
  @override
  State<FunPage> createState() => _FunPageState();
}

class _FunPageState extends State<FunPage> {
  final List<AudioPlayer> _pool = List.generate(4, (_) => AudioPlayer());
  int _next = 0;
  final _rnd = math.Random();
  int prank = 0;
  Timer? prankTimer;
  bool translating = false;
  List<String>? line;

  @override
  void dispose() {
    prankTimer?.cancel();
    for (final p in _pool) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _play(String file) async {
    HapticFeedback.lightImpact();
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await p.stop();
      await p.play(AssetSource('sounds/$file.m4a'), volume: 1.0);
    } catch (_) {}
  }

  void _prank() {
    prankTimer?.cancel();
    setState(() => prank = 10);
    prankTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => prank--);
      if (prank <= 0) {
        t.cancel();
        _play(farts[_rnd.nextInt(farts.length)].file);
      }
    });
  }

  Future<void> _translate() async {
    setState(() {
      translating = true;
      line = null;
    });
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 2200));
    final l = babyLines[_rnd.nextInt(babyLines.length)];
    if (!mounted) return;
    setState(() {
      translating = false;
      line = l;
    });
    await Voice.i.say(l[0], lat: l[1], pitch: 1.9);
  }

  Widget _grid(List<FunSound> list) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
        children: list
            .map((x) => _Bouncy(
                  onTap: () => _play(x.file),
                  child: Container(
                    decoration: BoxDecoration(
                      color: x.color,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: x.color.withValues(alpha: 0.6), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(x.emoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 4),
                      Text(x.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF3A2A35))),
                    ]),
                  ),
                ))
            .toList(),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('సరదా · Fun zone 😂'),
          bottom: const TabBar(tabs: [Tab(text: '💨 Farts'), Tab(text: '🎉 Funny'), Tab(text: '👶 Translator')]),
        ),
        body: TabBarView(children: [
          ListView(padding: const EdgeInsets.all(16), children: [
            Text('Top 10 farts 💨', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.onSurface)),
            const SizedBox(height: 10),
            _grid(farts),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
                  onPressed: () => _play(farts[_rnd.nextInt(farts.length)].file),
                  icon: const Text('🎲', style: TextStyle(fontSize: 20)),
                  label: const Text('Random fart'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14)),
                  onPressed: prank > 0 ? null : _prank,
                  icon: const Text('⏱️', style: TextStyle(fontSize: 20)),
                  label: Text(prank > 0 ? 'Fart in $prank…' : 'Prank in 10 s'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text('Prank: tap, hide the phone near Nanna or Thatayya, and wait 😂', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
          ListView(padding: const EdgeInsets.all(16), children: [
            Text('Funny sounds 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.onSurface)),
            const SizedBox(height: 10),
            _grid(funny),
            const SizedBox(height: 10),
            Text('Tip: use Ba-dum-tss after Nanna\'s jokes 🥁', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
          ListView(padding: const EdgeInsets.all(20), children: [
            const SizedBox(height: 10),
            const Text('పాప ఏమంటోంది?', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const Text('Baby → Telugu translator', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Center(
              child: _Bouncy(
                onTap: translating ? () {} : _translate,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFFFF9EB5), Color(0xFFFFC4A3)]),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF9EB5).withValues(alpha: 0.7), blurRadius: translating ? 40 : 18)],
                  ),
                  alignment: Alignment.center,
                  child: translating ? const CircularProgressIndicator(color: Colors.white) : const Text('👶', style: TextStyle(fontSize: 70)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(translating ? 'Translating baby language…' : 'When she babbles, tap the baby', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: line == null
                  ? const SizedBox(height: 10)
                  : Card(
                      key: ValueKey(line![0]),
                      color: cs.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          Text('"${line![0]}"', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(line![1], textAlign: TextAlign.center),
                          TextButton.icon(onPressed: () => Voice.i.say(line![0], lat: line![1], pitch: 1.9), icon: const Icon(Icons.volume_up), label: const Text('Say it again')),
                        ]),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text('Just for fun 😄 — it does not really understand her.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.outline)),
          ]),
        ]),
      ),
    );
  }
}

class _Bouncy extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Bouncy({required this.child, required this.onTap});
  @override
  State<_Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<_Bouncy> {
  bool d = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => d = true),
        onTapUp: (_) => setState(() => d = false),
        onTapCancel: () => setState(() => d = false),
        onTap: widget.onTap,
        child: AnimatedScale(scale: d ? 0.9 : 1, duration: const Duration(milliseconds: 110), curve: Curves.easeOutBack, child: widget.child),
      );
}
