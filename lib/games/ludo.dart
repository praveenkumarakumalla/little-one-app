import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../clay.dart';
import 'common.dart';

/// Ludo for 2–4 players on a tilted 3D board.
class LudoPage extends StatefulWidget {
  final List<GPlayer> players;
  const LudoPage({super.key, required this.players});
  @override
  State<LudoPage> createState() => _LudoPageState();
}

// The 52-square shared track, clockwise, starting at Red's start square. (col,row)
final List<List<int>> _track = () {
  final t = <List<int>>[];
  for (var c = 1; c <= 5; c++) { t.add([c, 6]); }
  for (var r = 5; r >= 0; r--) { t.add([6, r]); }
  t.add([7, 0]);
  for (var r = 0; r <= 5; r++) { t.add([8, r]); }
  for (var c = 9; c <= 14; c++) { t.add([c, 6]); }
  t.add([14, 7]);
  for (var c = 14; c >= 9; c--) { t.add([c, 8]); }
  for (var r = 9; r <= 14; r++) { t.add([8, r]); }
  t.add([7, 14]);
  for (var r = 14; r >= 9; r--) { t.add([6, r]); }
  for (var c = 5; c >= 0; c--) { t.add([c, 8]); }
  t.add([0, 7]);
  t.add([0, 6]);
  return t;
}();

// seat colours: 0 red (top-left), 1 green (top-right), 2 yellow (bottom-right), 3 blue (bottom-left)
const _seatColors = [Color(0xFFE53950), Color(0xFF2EAE5A), Color(0xFFF2B705), Color(0xFF2F7DE1)];
const _startIdx = [0, 13, 26, 39];
const _safe = {0, 8, 13, 21, 26, 34, 39, 47};

List<int> _homeCell(int seat, int step) {
  // step 0..4 → the 5 coloured squares leading to the centre
  switch (seat) {
    case 0:
      return [1 + step, 7];
    case 1:
      return [7, 1 + step];
    case 2:
      return [13 - step, 7];
    default:
      return [7, 13 - step];
  }
}

List<double> _yardSpot(int seat, int k) {
  final ox = seat == 0 || seat == 3 ? 0.0 : 9.0;
  final oy = seat == 0 || seat == 1 ? 0.0 : 9.0;
  final dx = k % 2 == 0 ? 1.9 : 4.1;
  final dy = k < 2 ? 1.9 : 4.1;
  return [ox + dx, oy + dy];
}

class _LudoPageState extends State<LudoPage> {
  late List<int> seats; // seat for each player
  late List<List<int>> tok; // -1 yard, 0..50 track (relative), 51..55 home column, 56 finished
  int turn = 0, dice = 1, sixes = 0;
  bool rolling = false, rolled = false, busy = false;
  String msg = '';
  final rnd = math.Random();

  @override
  void initState() {
    super.initState();
    final n = widget.players.length;
    seats = n == 2 ? [0, 2] : n == 3 ? [0, 1, 2] : [0, 1, 2, 3];
    _reset();
  }

  void _reset() {
    tok = List.generate(widget.players.length, (_) => [-1, -1, -1, -1]);
    turn = 0;
    rolled = false;
    busy = false;
    msg = '${widget.players[0].name}, roll the dice!';
    setState(() {});
    _maybeBot();
  }

  GPlayer get cur => widget.players[turn];
  Color colorOf(int p) => _seatColors[seats[p]];

  int _abs(int p, int rel) => (_startIdx[seats[p]] + rel) % 52;

  bool _canMove(int p, int k, int d) {
    final t = tok[p][k];
    if (t == 56) return false;
    if (t == -1) return d == 6;
    return t + d <= 56;
  }

  List<int> _movable(int d) => [for (var k = 0; k < 4; k++) if (_canMove(turn, k, d)) k];

  void _maybeBot() {
    if (cur.bot && mounted) Future.delayed(const Duration(milliseconds: 800), () { if (mounted && cur.bot && !busy && !rolled) _roll(); });
  }

  Future<void> _roll() async {
    if (busy || rolled) return;
    busy = true;
    setState(() => rolling = true);
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    dice = 1 + rnd.nextInt(6);
    rolling = false;
    rolled = true;
    if (dice == 6) {
      sixes++;
      if (sixes == 3) {
        setState(() => msg = 'Three 6s! ${cur.name} loses the turn 😅');
        await Future.delayed(const Duration(milliseconds: 1100));
        _next(extra: false);
        return;
      }
    }
    final m = _movable(dice);
    if (m.isEmpty) {
      setState(() => msg = '${cur.name} rolled $dice — no move');
      await Future.delayed(const Duration(milliseconds: 1000));
      _next(extra: dice == 6);
      return;
    }
    busy = false;
    if (cur.bot || m.length == 1 || m.every((k) => tok[turn][k] == -1)) {
      setState(() => msg = '${cur.name} rolled $dice');
      await Future.delayed(Duration(milliseconds: cur.bot ? 500 : 300));
      if (!mounted) return;
      _move(cur.bot ? _botPick(m) : m.first);
    } else {
      setState(() => msg = '${cur.name} rolled $dice — tap a token');
    }
  }

  int _botPick(List<int> m) {
    int score(int k) {
      final t = tok[turn][k];
      if (t == -1) return 60;
      final nt = t + dice;
      if (nt == 56) return 90;
      if (nt <= 50) {
        final a = _abs(turn, nt);
        for (var q = 0; q < tok.length; q++) {
          if (q == turn) continue;
          for (final o in tok[q]) {
            if (o >= 0 && o <= 50 && _abs(q, o) == a && !_safe.contains(a)) return 100;
          }
        }
        if (_safe.contains(a)) return 40 + nt ~/ 4;
      }
      if (nt > 50) return 50;
      return 10 + nt ~/ 3;
    }

    m.sort((a, b) => score(b).compareTo(score(a)));
    return m.first;
  }

  Future<void> _move(int k) async {
    if (busy || !rolled || !_canMove(turn, k, dice)) return;
    busy = true;
    var extra = dice == 6;
    if (tok[turn][k] == -1) {
      setState(() => tok[turn][k] = 0);
    } else {
      for (var i = 0; i < dice; i++) {
        await Future.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
        setState(() => tok[turn][k]++);
      }
    }
    final t = tok[turn][k];
    if (t <= 50) {
      final a = _abs(turn, t);
      if (!_safe.contains(a)) {
        for (var q = 0; q < tok.length; q++) {
          if (q == turn) continue;
          for (var j = 0; j < 4; j++) {
            if (tok[q][j] >= 0 && tok[q][j] <= 50 && _abs(q, tok[q][j]) == a) {
              tok[q][j] = -1;
              extra = true;
              msg = '💥 ${cur.name} captured ${widget.players[q].name}!';
            }
          }
        }
      }
    }
    if (t == 56) {
      extra = true;
      msg = '🏠 ${cur.name} reached home!';
      if (tok[turn].every((x) => x == 56)) {
        setState(() {});
        await winDialog(context, '${cur.name} wins Ludo! 🎉', again: _reset);
        return;
      }
    }
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 450));
    _next(extra: extra);
  }

  void _next({required bool extra}) {
    if (!mounted) return;
    if (!extra) {
      sixes = 0;
      turn = (turn + 1) % widget.players.length;
    }
    rolled = false;
    busy = false;
    setState(() => msg = extra ? '${cur.name} gets another roll!' : '${cur.name}\'s turn');
    _maybeBot();
  }

  void _tapBoard(Offset local, double cell) {
    if (cur.bot || !rolled || busy) return;
    for (final k in _movable(dice)) {
      final p = _tokenCentre(turn, k, cell);
      if ((p - local).distance < cell * 0.9) {
        _move(k);
        return;
      }
    }
  }

  Offset _tokenCentre(int p, int k, double cell) {
    final t = tok[p][k];
    final seat = seats[p];
    List<double> xy;
    if (t == -1) {
      xy = _yardSpot(seat, k);
    } else if (t == 56) {
      xy = [7.5 + (seat == 1 || seat == 2 ? 0.45 : -0.45) * (k.isEven ? 1 : 0.4), 7.5 + (seat >= 2 ? 0.45 : -0.45) * (k < 2 ? 1 : 0.4)];
    } else if (t > 50) {
      final h = _homeCell(seat, t - 51);
      xy = [h[0] + 0.5, h[1] + 0.5];
    } else {
      final c = _track[_abs(p, t)];
      xy = [c[0] + 0.5, c[1] + 0.5];
    }
    return Offset(xy[0] * cell, xy[1] * cell);
  }

  @override
  Widget build(BuildContext context) {
    final movable = rolled && !busy && !cur.bot ? _movable(dice) : const <int>[];
    return Scaffold(
      appBar: AppBar(title: const Text('🎲 Ludo')),
      body: Column(children: [
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < widget.players.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: i == turn ? colorOf(i) : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 3))]),
              child: Text('${widget.players[i].bot ? '🤖' : '👤'} ${widget.players[i].name} ${'🏠' * tok[i].where((x) => x == 56).length}', style: TextStyle(fontWeight: FontWeight.w800, color: i == turn ? Colors.white : Colors.black87)),
            ),
        ]),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: Board3D(
                  tilt: 0.36,
                  child: LayoutBuilder(builder: (context, bc) {
                    final cell = bc.maxWidth / 15;
                    return GestureDetector(
                      onTapUp: (d) => _tapBoard(d.localPosition, cell),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CustomPaint(size: Size.infinite, painter: _LudoPainter(this, movable)),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Dice(value: dice, rolling: rolling, color: Clay.shade(colorOf(turn), 0.36), onTap: cur.bot || busy || rolled ? null : _roll),
        const SizedBox(height: 26),
      ]),
    );
  }
}

class _LudoPainter extends CustomPainter {
  final _LudoPageState s;
  final List<int> movable;
  _LudoPainter(this.s, this.movable);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 15;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    Rect cell(int x, int y) => Rect.fromLTWH(x * c, y * c, c, c);
    // yards
    for (var seat = 0; seat < 4; seat++) {
      final col = _seatColors[seat];
      final ox = seat == 0 || seat == 3 ? 0.0 : 9.0;
      final oy = seat == 0 || seat == 1 ? 0.0 : 9.0;
      final r = Rect.fromLTWH(ox * c, oy * c, 6 * c, 6 * c);
      canvas.drawRect(r, Paint()..color = col);
      final inner = RRect.fromRectAndRadius(r.deflate(c * 0.8), Radius.circular(c * 0.6));
      canvas.drawRRect(inner.shift(Offset(0, c * 0.12)), Paint()..color = Clay.shade(col, -0.2));
      canvas.drawRRect(inner, Paint()..color = Colors.white);
      for (var k = 0; k < 4; k++) {
        final sp = _yardSpot(seat, k);
        canvas.drawCircle(Offset(sp[0] * c, sp[1] * c), c * 0.62, Paint()..color = Clay.shade(col, 0.28));
      }
    }
    // track squares
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFBDB3C6)
      ..strokeWidth = 1;
    for (var i = 0; i < 52; i++) {
      final t = _track[i];
      final r = cell(t[0], t[1]);
      final startSeat = _startIdx.indexOf(i);
      if (startSeat >= 0) canvas.drawRect(r, Paint()..color = _seatColors[startSeat]);
      canvas.drawRect(r, grid);
      if (_safe.contains(i) && startSeat < 0) {
        final tp = TextPainter(text: TextSpan(text: '⭐', style: TextStyle(fontSize: c * 0.6)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
      }
    }
    for (var seat = 0; seat < 4; seat++) {
      for (var st = 0; st < 5; st++) {
        final h = _homeCell(seat, st);
        final r = cell(h[0], h[1]);
        canvas.drawRect(r, Paint()..color = _seatColors[seat]);
        canvas.drawRect(r, grid);
      }
    }
    // centre triangles
    final ctr = Offset(7.5 * c, 7.5 * c);
    final corners = [Offset(6 * c, 6 * c), Offset(9 * c, 6 * c), Offset(9 * c, 9 * c), Offset(6 * c, 9 * c)];
    // red is left, green top, yellow right, blue bottom
    final tri = [
      [corners[3], corners[0], 0],
      [corners[0], corners[1], 1],
      [corners[1], corners[2], 2],
      [corners[2], corners[3], 3],
    ];
    for (final t in tri) {
      final p = Path()
        ..moveTo((t[0] as Offset).dx, (t[0] as Offset).dy)
        ..lineTo((t[1] as Offset).dx, (t[1] as Offset).dy)
        ..lineTo(ctr.dx, ctr.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = _seatColors[t[2] as int]);
    }
    final tp = TextPainter(text: TextSpan(text: '🏠', style: TextStyle(fontSize: c * 0.9)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, ctr - Offset(tp.width / 2, tp.height / 2));

    // tokens – group those on the same square
    final spots = <String, List<List<int>>>{};
    for (var p = 0; p < s.tok.length; p++) {
      for (var k = 0; k < 4; k++) {
        final o = s._tokenCentre(p, k, c);
        spots.putIfAbsent('${o.dx.round()},${o.dy.round()}', () => []).add([p, k]);
      }
    }
    for (final g in spots.values) {
      for (var j = 0; j < g.length; j++) {
        final p = g[j][0], k = g[j][1];
        var o = s._tokenCentre(p, k, c);
        if (g.length > 1) o += Offset((j % 2 - 0.5) * c * 0.36, (j ~/ 2 - 0.5) * c * 0.36);
        final glow = p == s.turn && movable.contains(k);
        drawToken(canvas, o - Offset(0, c * 0.08), c * (g.length > 1 ? 0.28 : 0.38), s.colorOf(p), glow: glow);
      }
    }
  }

  @override
  bool shouldRepaint(_LudoPainter o) => true;
}
