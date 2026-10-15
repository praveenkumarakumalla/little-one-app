import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../clay.dart';
import 'common.dart';

/// Snakes & Ladders on a tilted 3D board, 2–4 players (people or computer).
class SnakesPage extends StatefulWidget {
  final List<GPlayer> players;
  const SnakesPage({super.key, required this.players});
  @override
  State<SnakesPage> createState() => _SnakesPageState();
}

const _snakes = {99: 54, 95: 72, 87: 24, 62: 19, 64: 60, 49: 11, 47: 26, 17: 7};
const _ladders = {4: 14, 9: 31, 20: 38, 28: 84, 40: 59, 51: 67, 63: 81, 71: 91};

class _SnakesPageState extends State<SnakesPage> {
  late List<int> pos;
  int turn = 0, dice = 1;
  bool rolling = false, busy = false;
  String msg = '';
  final rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    pos = List.filled(widget.players.length, 0);
    turn = 0;
    busy = false;
    msg = '${widget.players[0].name}, tap the dice!';
    setState(() {});
    _maybeBot();
  }

  GPlayer get cur => widget.players[turn];

  void _maybeBot() {
    if (cur.bot && mounted) Future.delayed(const Duration(milliseconds: 900), () { if (mounted && cur.bot && !busy) _roll(); });
  }

  Future<void> _roll() async {
    if (busy) return;
    busy = true;
    setState(() => rolling = true);
    await Future.delayed(const Duration(milliseconds: 650));
    final d = 1 + rnd.nextInt(6);
    setState(() {
      rolling = false;
      dice = d;
    });
    final p = cur;
    if (pos[turn] + d > 100) {
      setState(() => msg = '${p.name} needs exactly ${100 - pos[turn]} 🙈');
    } else {
      for (var i = 0; i < d; i++) {
        await Future.delayed(const Duration(milliseconds: 230));
        if (!mounted) return;
        setState(() => pos[turn]++);
      }
      final at = pos[turn];
      if (_ladders.containsKey(at)) {
        setState(() => msg = '🪜 ${p.name} climbs a ladder!');
        await Future.delayed(const Duration(milliseconds: 450));
        setState(() => pos[turn] = _ladders[at]!);
      } else if (_snakes.containsKey(at)) {
        setState(() => msg = '🐍 Ssss! ${p.name} got bitten!');
        await Future.delayed(const Duration(milliseconds: 450));
        setState(() => pos[turn] = _snakes[at]!);
      } else {
        setState(() => msg = '${p.name} rolled $d');
      }
      if (pos[turn] == 100) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        await winDialog(context, '${p.name} wins! 🎉', again: _reset);
        return;
      }
    }
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (d != 6) turn = (turn + 1) % widget.players.length;
    busy = false;
    setState(() => msg = d == 6 ? '${cur.name} rolled 6 — roll again!' : '${cur.name}\'s turn');
    _maybeBot();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🐍 Snakes & Ladders')),
      body: Column(children: [
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (var i = 0; i < widget.players.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: i == turn ? widget.players[i].color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 3))],
                  ),
                  child: Text('${widget.players[i].bot ? '🤖' : '👤'} ${widget.players[i].name} · ${pos[i]}', style: TextStyle(fontWeight: FontWeight.w800, color: i == turn ? Colors.white : Colors.black87)),
                ),
              ),
          ]),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: AspectRatio(
                aspectRatio: 1,
                child: Board3D(
                  tilt: 0.38,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CustomPaint(painter: _SnakesPainter(pos, widget.players, turn), size: Size.infinite),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(msg, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Dice(value: dice, rolling: rolling, color: Clay.shade(cur.color, 0.36), onTap: cur.bot || busy ? null : _roll),
        const SizedBox(height: 26),
      ]),
    );
  }
}

/// Square number (1..100) → cell centre.
Offset _cell(int n, double c) {
  final i = n - 1;
  final row = i ~/ 10;
  var col = i % 10;
  if (row.isOdd) col = 9 - col;
  return Offset((col + 0.5) * c, (9 - row + 0.5) * c);
}

class _SnakesPainter extends CustomPainter {
  final List<int> pos;
  final List<GPlayer> players;
  final int turn;
  _SnakesPainter(this.pos, this.players, this.turn);

  static const _cols = [Color(0xFFFFE3EE), Color(0xFFDFF5E1), Color(0xFFFFF4C7), Color(0xFFDCEBFF), Color(0xFFEBDDFF)];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 10;
    for (var n = 1; n <= 100; n++) {
      final o = _cell(n, c);
      final r = Rect.fromCenter(center: o, width: c, height: c);
      canvas.drawRect(r, Paint()..color = _cols[(n * 7 + (n - 1) ~/ 10) % _cols.length]);
      canvas.drawRect(r.deflate(0.5), Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.8));
      final tp = TextPainter(text: TextSpan(text: n == 100 ? '🏁' : '$n', style: TextStyle(fontSize: c * 0.24, color: const Color(0xFF6A5A7A), fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, r.topLeft + Offset(c * 0.07, c * 0.04));
    }
    // ladders
    _ladders.forEach((a, b) {
      final p1 = _cell(a, c), p2 = _cell(b, c);
      final d = p2 - p1;
      final n = Offset(-d.dy, d.dx) / d.distance * c * 0.16;
      final rail = Paint()
        ..color = const Color(0xFF9A5B2E)
        ..strokeWidth = c * 0.09
        ..strokeCap = StrokeCap.round;
      final sh = Paint()
        ..color = Colors.black26
        ..strokeWidth = c * 0.09
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1 + n + const Offset(2, 3), p2 + n + const Offset(2, 3), sh);
      canvas.drawLine(p1 - n + const Offset(2, 3), p2 - n + const Offset(2, 3), sh);
      final steps = (d.distance / (c * 0.35)).floor();
      for (var i = 1; i < steps; i++) {
        final t = p1 + d * (i / steps);
        canvas.drawLine(t + n, t - n, Paint()
          ..color = const Color(0xFFD8954F)
          ..strokeWidth = c * 0.07
          ..strokeCap = StrokeCap.round);
      }
      canvas.drawLine(p1 + n, p2 + n, rail);
      canvas.drawLine(p1 - n, p2 - n, rail);
    });
    // snakes
    var k = 0;
    const snakeCols = [Color(0xFF2EAE5A), Color(0xFFE53950), Color(0xFF8E44AD), Color(0xFFF39C12), Color(0xFF16A085), Color(0xFFE84393), Color(0xFF2F7DE1), Color(0xFF6AB04C)];
    _snakes.forEach((a, b) {
      final head = _cell(a, c), tail = _cell(b, c);
      final d = tail - head;
      final n = Offset(-d.dy, d.dx) / d.distance;
      final path = Path()..moveTo(head.dx, head.dy);
      const waves = 4;
      for (var i = 0; i < waves; i++) {
        final s = head + d * ((i + 0.5) / waves) + n * c * 0.55 * (i.isEven ? 1 : -1);
        final e = head + d * ((i + 1) / waves);
        path.quadraticBezierTo(s.dx, s.dy, e.dx, e.dy);
      }
      final col = snakeCols[k++ % snakeCols.length];
      canvas.drawPath(path.shift(const Offset(2, 4)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = c * 0.26
        ..strokeCap = StrokeCap.round
        ..color = Colors.black26);
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = c * 0.26
        ..strokeCap = StrokeCap.round
        ..color = Clay.shade(col, -0.12));
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = c * 0.17
        ..strokeCap = StrokeCap.round
        ..color = col);
      canvas.drawPath(path.shift(Offset(-c * 0.03, -c * 0.03)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = c * 0.04
        ..strokeCap = StrokeCap.round
        ..color = Colors.white54);
      // head
      canvas.drawOval(Rect.fromCenter(center: head, width: c * 0.42, height: c * 0.36), Paint()..color = Clay.shade(col, -0.08));
      final eye = n * c * 0.09;
      for (final e in [head + eye, head - eye]) {
        canvas.drawCircle(e, c * 0.06, Paint()..color = Colors.white);
        canvas.drawCircle(e, c * 0.03, Paint()..color = Colors.black);
      }
      final dirN = d / d.distance;
      canvas.drawLine(head - dirN * c * 0.18, head - dirN * c * 0.32, Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 2);
    });
    // tokens
    final byCell = <int, List<int>>{};
    for (var i = 0; i < pos.length; i++) {
      byCell.putIfAbsent(pos[i], () => []).add(i);
    }
    byCell.forEach((cell, ps) {
      for (var j = 0; j < ps.length; j++) {
        final base = cell == 0 ? Offset(-c * 0.1 + (ps[j] + 0.5) * c * 0.5, size.height - c * 0.3) : _cell(cell, c);
        final off = ps.length > 1 && cell != 0 ? Offset((j % 2 - 0.5) * c * 0.38, (j ~/ 2 - 0.3) * c * 0.38) : Offset.zero;
        drawToken(canvas, base + off - Offset(0, c * 0.06), c * (ps.length > 1 ? 0.2 : 0.27), players[ps[j]].color, glow: ps[j] == turn);
      }
    });
  }

  @override
  bool shouldRepaint(_SnakesPainter o) => true;
}
