import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../clay.dart';

/// A player at the table: a person on this phone, or the computer.
class GPlayer {
  final String name;
  final Color color;
  final bool bot;
  const GPlayer(this.name, this.color, this.bot);
}

const playerColors = [Color(0xFFE53950), Color(0xFF2EAE5A), Color(0xFFF2B705), Color(0xFF2F7DE1)];
const defaultNames = ['Nanna', 'Amma', 'Ammamma', 'Tatayya'];

/// Pick 2–4 players, each a person or the computer.
Future<List<GPlayer>?> pickPlayers(BuildContext context, {String title = 'Who is playing?', int min = 2, int max = 4, List<Color>? colors}) {
  final cs = colors ?? playerColors;
  var count = max >= 4 ? 4 : max;
  final names = List<TextEditingController>.generate(4, (i) => TextEditingController(text: defaultNames[i]));
  final bots = [false, true, true, true];
  return showModalBottomSheet<List<GPlayer>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(children: [
            const Text('Players: ', style: TextStyle(fontWeight: FontWeight.w700)),
            for (var n = min; n <= max; n++)
              Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text('$n'), selected: count == n, onSelected: (_) => set(() => count = n))),
          ]),
          const SizedBox(height: 8),
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(width: 22, height: 22, decoration: BoxDecoration(color: cs[i], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)])),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: names[i], decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                  segments: const [ButtonSegment(value: false, label: Text('👤')), ButtonSegment(value: true, label: Text('🤖'))],
                  selected: {bots[i]},
                  onSelectionChanged: (v) => set(() => bots[i] = v.first),
                ),
              ]),
            ),
          const SizedBox(height: 6),
          const Text('👤 = person on this phone (pass the phone)   🤖 = computer', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(c, [for (var i = 0; i < count; i++) GPlayer(names[i].text.trim().isEmpty ? defaultNames[i] : names[i].text.trim(), cs[i], bots[i])]),
              child: const Text('▶ Start game', style: TextStyle(fontSize: 17)),
            ),
          ),
        ]),
      ),
    ),
  );
}

/// Tilts its child back like a board lying on a table (3D look).
class Board3D extends StatelessWidget {
  final Widget child;
  final double tilt;
  const Board3D({super.key, required this.child, this.tilt = 0.42});
  @override
  Widget build(BuildContext context) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(tilt),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 26)), BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 6))],
          ),
          child: child,
        ),
      );
}

/// A rolling 3D-ish dice.
class Dice extends StatefulWidget {
  final int value;
  final bool rolling;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  const Dice({super.key, required this.value, this.rolling = false, this.onTap, this.color = Colors.white, this.size = 70});
  @override
  State<Dice> createState() => _DiceState();
}

class _DiceState extends State<Dice> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  final r = math.Random();
  int shown = 1;
  @override
  void initState() {
    super.initState();
    shown = widget.value;
    a.addListener(() {
      if (a.isAnimating && r.nextInt(3) == 0) setState(() => shown = 1 + r.nextInt(6));
    });
  }

  @override
  void didUpdateWidget(covariant Dice old) {
    super.didUpdateWidget(old);
    if (widget.rolling && !old.rolling) {
      a.forward(from: 0);
    } else if (!widget.rolling) {
      shown = widget.value;
    }
  }

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return GestureDetector(
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onTap!();
            },
      child: AnimatedBuilder(
        animation: a,
        builder: (_, __) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(a.value * math.pi * 4)
            ..rotateZ(a.value * math.pi * 2),
          child: SizedBox(
            width: s,
            height: s + 6,
            child: Clay(
              color: widget.color,
              color2: Clay.shade(widget.color, -0.06),
              radius: s * 0.24,
              depth: 6,
              padding: EdgeInsets.all(s * 0.12),
              height: s,
              child: CustomPaint(size: Size.square(s * 0.76), painter: _Pips(shown)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pips extends CustomPainter {
  final int n;
  _Pips(this.n);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0xFF2B2240);
    final r = s.width * 0.1;
    const spots = {
      1: [[0.5, 0.5]],
      2: [[0.25, 0.25], [0.75, 0.75]],
      3: [[0.25, 0.25], [0.5, 0.5], [0.75, 0.75]],
      4: [[0.25, 0.25], [0.75, 0.25], [0.25, 0.75], [0.75, 0.75]],
      5: [[0.25, 0.25], [0.75, 0.25], [0.5, 0.5], [0.25, 0.75], [0.75, 0.75]],
      6: [[0.25, 0.2], [0.75, 0.2], [0.25, 0.5], [0.75, 0.5], [0.25, 0.8], [0.75, 0.8]],
    };
    for (final sp in spots[n.clamp(1, 6)]!) {
      c.drawCircle(Offset(sp[0] * s.width, sp[1] * s.height), r, n == 1 ? (Paint()..color = const Color(0xFFE53950)) : p);
    }
  }

  @override
  bool shouldRepaint(_Pips o) => o.n != n;
}

/// A glossy token (for Ludo / Snakes & Ladders).
void drawToken(Canvas c, Offset center, double r, Color color, {bool glow = false}) {
  if (glow) c.drawCircle(center, r * 1.5, Paint()..color = color.withValues(alpha: 0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5));
  c.drawCircle(center + Offset(0, r * 0.35), r, Paint()..color = Colors.black.withValues(alpha: 0.3)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25));
  c.drawCircle(center + Offset(0, r * 0.18), r, Paint()..color = Clay.shade(color, -0.18));
  c.drawCircle(center, r, Paint()..shader = RadialGradient(center: const Alignment(-0.4, -0.5), colors: [Clay.shade(color, 0.22), color]).createShader(Rect.fromCircle(center: center, radius: r)));
  c.drawCircle(center, r, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.16
    ..color = Colors.white);
  c.drawCircle(center - Offset(r * 0.3, r * 0.35), r * 0.25, Paint()..color = Colors.white.withValues(alpha: 0.7));
}

/// "Pass the phone" curtain between two people.
Future<void> passPhone(BuildContext context, GPlayer p) => showDialog(
      context: context,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        icon: const Text('📱', style: TextStyle(fontSize: 48)),
        title: Text('Pass the phone to ${p.name}', textAlign: TextAlign.center),
        actions: [FilledButton(onPressed: () => Navigator.pop(d), child: Text("I'm ${p.name} — show my cards"))],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );

Future<void> winDialog(BuildContext context, String text, {VoidCallback? again}) => showDialog(
      context: context,
      builder: (d) => AlertDialog(
        icon: const Text('🏆', style: TextStyle(fontSize: 60)),
        title: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(d);
                Navigator.pop(context);
              },
              child: const Text('Exit')),
          if (again != null)
            FilledButton(
                onPressed: () {
                  Navigator.pop(d);
                  again();
                },
                child: const Text('Play again')),
        ],
      ),
    );
