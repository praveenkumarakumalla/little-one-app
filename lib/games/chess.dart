import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../clay.dart';
import '../store.dart';
import 'common.dart';

// ───────────────────────── engine ─────────────────────────
// board[r*8+c], r = 0 is the top (black's back rank). + white, − black.
// 1 pawn, 2 knight, 3 bishop, 4 rook, 5 queen, 6 king.

class Mv {
  final int from, to, promo;
  const Mv(this.from, this.to, [this.promo = 0]);
  List<int> toList() => [from, to, promo];
  static Mv fromList(List<int> l) => Mv(l[0], l[1], l[2]);
}

class Pos {
  List<int> b;
  int side; // 1 white to move, -1 black
  int castle; // bits: 1 wK, 2 wQ, 4 bK, 8 bQ
  int ep; // en-passant target square or -1
  Pos(this.b, this.side, this.castle, this.ep);

  factory Pos.start() => Pos([
        -4, -2, -3, -5, -6, -3, -2, -4,
        -1, -1, -1, -1, -1, -1, -1, -1,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 1, 1, 1, 1, 1, 1,
        4, 2, 3, 5, 6, 3, 2, 4,
      ], 1, 15, -1);

  Pos copy() => Pos(List.of(b), side, castle, ep);

  int king(int s) => b.indexOf(6 * s);

  bool attacked(int sq, int by) {
    final r = sq ~/ 8, c = sq % 8;
    // pawns
    final pr = r + by; // a white pawn attacks upward, so it sits below (r+1)
    for (final dc in const [-1, 1]) {
      final cc = c + dc;
      if (pr >= 0 && pr < 8 && cc >= 0 && cc < 8 && b[pr * 8 + cc] == by) return true;
    }
    for (final d in const [[1, 2], [2, 1], [-1, 2], [-2, 1], [1, -2], [2, -1], [-1, -2], [-2, -1]]) {
      final rr = r + d[0], cc = c + d[1];
      if (rr >= 0 && rr < 8 && cc >= 0 && cc < 8 && b[rr * 8 + cc] == 2 * by) return true;
    }
    for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]) {
      final diag = d[0] != 0 && d[1] != 0;
      var rr = r + d[0], cc = c + d[1], dist = 1;
      while (rr >= 0 && rr < 8 && cc >= 0 && cc < 8) {
        final p = b[rr * 8 + cc];
        if (p != 0) {
          if (p * by > 0) {
            final t = p.abs();
            if (t == 5 || (diag && t == 3) || (!diag && t == 4) || (dist == 1 && t == 6)) return true;
          }
          break;
        }
        rr += d[0];
        cc += d[1];
        dist++;
      }
    }
    return false;
  }

  bool inCheck(int s) {
    final k = king(s);
    return k >= 0 && attacked(k, -s);
  }

  List<Mv> pseudo() {
    final out = <Mv>[];
    final s = side;
    for (var sq = 0; sq < 64; sq++) {
      final p = b[sq];
      if (p * s <= 0) continue;
      final t = p.abs(), r = sq ~/ 8, c = sq % 8;
      void add(int to) {
        if (t == 1 && (to ~/ 8 == 0 || to ~/ 8 == 7)) {
          for (final pr in const [5, 4, 3, 2]) {
            out.add(Mv(sq, to, pr));
          }
        } else {
          out.add(Mv(sq, to));
        }
      }

      if (t == 1) {
        final dr = -s, nr = r + dr;
        if (nr >= 0 && nr < 8) {
          if (b[nr * 8 + c] == 0) {
            add(nr * 8 + c);
            final startRow = s == 1 ? 6 : 1;
            if (r == startRow && b[(r + 2 * dr) * 8 + c] == 0) out.add(Mv(sq, (r + 2 * dr) * 8 + c));
          }
          for (final dc in const [-1, 1]) {
            final cc = c + dc;
            if (cc < 0 || cc > 7) continue;
            final to = nr * 8 + cc;
            if (b[to] * s < 0 || to == ep) add(to);
          }
        }
      } else if (t == 2 || t == 6) {
        final ds = t == 2
            ? const [[1, 2], [2, 1], [-1, 2], [-2, 1], [1, -2], [2, -1], [-1, -2], [-2, -1]]
            : const [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]];
        for (final d in ds) {
          final rr = r + d[0], cc = c + d[1];
          if (rr < 0 || rr > 7 || cc < 0 || cc > 7) continue;
          if (b[rr * 8 + cc] * s <= 0) out.add(Mv(sq, rr * 8 + cc));
        }
        if (t == 6) {
          final home = s == 1 ? 60 : 4;
          if (sq == home && !attacked(home, -s)) {
            final kBit = s == 1 ? 1 : 4, qBit = s == 1 ? 2 : 8;
            if (castle & kBit != 0 && b[home + 1] == 0 && b[home + 2] == 0 && b[home + 3] == 4 * s && !attacked(home + 1, -s) && !attacked(home + 2, -s)) out.add(Mv(sq, home + 2));
            if (castle & qBit != 0 && b[home - 1] == 0 && b[home - 2] == 0 && b[home - 3] == 0 && b[home - 4] == 4 * s && !attacked(home - 1, -s) && !attacked(home - 2, -s)) out.add(Mv(sq, home - 2));
          }
        }
      } else {
        final ds = t == 3
            ? const [[1, 1], [1, -1], [-1, 1], [-1, -1]]
            : t == 4
                ? const [[1, 0], [-1, 0], [0, 1], [0, -1]]
                : const [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]];
        for (final d in ds) {
          var rr = r + d[0], cc = c + d[1];
          while (rr >= 0 && rr < 8 && cc >= 0 && cc < 8) {
            final q = b[rr * 8 + cc];
            if (q * s > 0) break;
            out.add(Mv(sq, rr * 8 + cc));
            if (q != 0) break;
            rr += d[0];
            cc += d[1];
          }
        }
      }
    }
    return out;
  }

  void make(Mv m) {
    final p = b[m.from], t = p.abs(), s = p.sign;
    // en passant capture
    if (t == 1 && m.to == ep) b[m.to + 8 * s] = 0;
    ep = -1;
    if (t == 1 && (m.to - m.from).abs() == 16) ep = (m.to + m.from) ~/ 2;
    // castling rook
    if (t == 6 && (m.to - m.from).abs() == 2) {
      if (m.to > m.from) {
        b[m.to - 1] = b[m.to + 1];
        b[m.to + 1] = 0;
      } else {
        b[m.to + 1] = b[m.to - 2];
        b[m.to - 2] = 0;
      }
    }
    b[m.to] = m.promo != 0 ? m.promo * s : p;
    b[m.from] = 0;
    if (t == 6) castle &= s == 1 ? ~3 : ~12;
    for (final sq in [m.from, m.to]) {
      if (sq == 63) castle &= ~1;
      if (sq == 56) castle &= ~2;
      if (sq == 7) castle &= ~4;
      if (sq == 0) castle &= ~8;
    }
    side = -side;
  }

  List<Mv> legal() {
    final out = <Mv>[];
    for (final m in pseudo()) {
      final q = copy()..make(m);
      if (!q.inCheck(side)) out.add(m);
    }
    return out;
  }
}

const _val = [0, 100, 320, 330, 500, 900, 0];

int _eval(Pos p) {
  var s = 0;
  for (var sq = 0; sq < 64; sq++) {
    final v = p.b[sq];
    if (v == 0) continue;
    final t = v.abs(), r = sq ~/ 8, c = sq % 8;
    var x = _val[t];
    final centre = 7 - ((3.5 - r).abs() + (3.5 - c).abs()).round();
    if (t == 2 || t == 3) x += centre * 4;
    if (t == 1) x += (v > 0 ? 6 - r : r - 1) * 8 + (c >= 2 && c <= 5 ? 6 : 0);
    if (t == 5) x += centre;
    s += v > 0 ? x : -x;
  }
  return s;
}

int _search(Pos p, int depth, int alpha, int beta) {
  if (depth == 0) return _eval(p) * p.side;
  final moves = p.legal();
  if (moves.isEmpty) return p.inCheck(p.side) ? -100000 - depth : 0;
  moves.sort((a, b) => p.b[b.to].abs().compareTo(p.b[a.to].abs()));
  for (final m in moves) {
    final q = p.copy()..make(m);
    final v = -_search(q, depth - 1, -beta, -alpha);
    if (v > alpha) alpha = v;
    if (alpha >= beta) break;
  }
  return alpha;
}

List<int> _best(List<int> board, int side, int castle, int ep, int depth, int seed) {
  final p = Pos(board, side, castle, ep);
  final rnd = math.Random(seed);
  final moves = p.legal()..shuffle(rnd);
  moves.sort((a, b) => p.b[b.to].abs().compareTo(p.b[a.to].abs()));
  Mv? best;
  var bestV = -1 << 30;
  for (final m in moves) {
    final q = p.copy()..make(m);
    final v = -_search(q, depth - 1, -1 << 30, -bestV) + rnd.nextInt(8);
    if (v > bestV || best == null) {
      bestV = v;
      best = m;
    }
  }
  return best?.toList() ?? [];
}

Future<Mv?> _think(Pos p, int depth) async {
  final b = List<int>.of(p.b), s = p.side, c = p.castle, e = p.ep, seed = DateTime.now().microsecond;
  final r = await Isolate.run(() => _best(b, s, c, e, depth, seed));
  return r.isEmpty ? null : Mv.fromList(r);
}

// ───────────────────────── themes ─────────────────────────

class ChessTheme {
  final String name;
  final Color light, dark, frame, white, black;
  const ChessTheme(this.name, this.light, this.dark, this.frame, this.white, this.black);
}

const chessThemes = [
  ChessTheme('🪵 Classic Wood', Color(0xFFF0D9B5), Color(0xFFB58863), Color(0xFF6B3E1F), Color(0xFFFFF8EC), Color(0xFF3B2A20)),
  ChessTheme('🍬 Candy Pink', Color(0xFFFFE3EE), Color(0xFFF7A1C4), Color(0xFFC2185B), Color(0xFFFFFFFF), Color(0xFF7B1FA2)),
  ChessTheme('🌊 Ocean Night', Color(0xFFC9E2FF), Color(0xFF4B6CB7), Color(0xFF182848), Color(0xFFE8F4FF), Color(0xFF0B1A33)),
];

const _glyph = {1: '♟', 2: '♞', 3: '♝', 4: '♜', 5: '♛', 6: '♚'};

// ───────────────────────── UI ─────────────────────────

class ChessPage extends StatefulWidget {
  final bool vsComputer;
  final String whiteName, blackName;
  final int level; // 1 easy, 2 medium, 3 hard
  const ChessPage({super.key, required this.vsComputer, this.whiteName = 'Nanna', this.blackName = 'Amma', this.level = 2});
  @override
  State<ChessPage> createState() => _ChessPageState();
}

class _ChessPageState extends State<ChessPage> {
  Pos pos = Pos.start();
  int? sel;
  List<Mv> legal = [];
  Mv? last;
  bool thinking = false;
  int theme = (Store.i.settings['chessTheme'] as int?) ?? 0;
  final history = <(Pos, int)>[];
  final captured = <int>[];
  String status = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  ChessTheme get th => chessThemes[theme % chessThemes.length];
  String get whoName => pos.side == 1 ? widget.whiteName : (widget.vsComputer ? '🤖 Computer' : widget.blackName);

  void _refresh() {
    legal = pos.legal();
    if (legal.isEmpty) {
      status = pos.inCheck(pos.side) ? 'Checkmate! ${pos.side == 1 ? (widget.vsComputer ? 'Computer' : widget.blackName) : widget.whiteName} wins 🏆' : 'Stalemate — draw 🤝';
    } else {
      status = '${pos.inCheck(pos.side) ? '⚠️ Check! ' : ''}$whoName to move';
    }
    setState(() {});
    if (legal.isEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) winDialog(context, status, again: _newGame);
      });
    }
  }

  void _newGame() {
    pos = Pos.start();
    history.clear();
    captured.clear();
    sel = null;
    last = null;
    _refresh();
  }

  Future<void> _do(Mv m) async {
    history.add((pos.copy(), captured.length));
    final cap = pos.b[m.to] != 0 ? pos.b[m.to] : (pos.b[m.from].abs() == 1 && m.to == pos.ep ? -pos.side : 0);
    if (cap != 0) captured.add(cap);
    pos.make(m);
    last = m;
    sel = null;
    _refresh();
    if (widget.vsComputer && pos.side == -1 && legal.isNotEmpty) {
      setState(() => thinking = true);
      final r = await _think(pos, widget.level);
      if (!mounted) return;
      thinking = false;
      if (r != null) {
        await _do(r);
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _tap(int sq) async {
    if (thinking || legal.isEmpty) return;
    if (widget.vsComputer && pos.side == -1) return;
    if (sel != null) {
      final ms = legal.where((m) => m.from == sel && m.to == sq).toList();
      if (ms.isNotEmpty) {
        var m = ms.first;
        if (ms.length > 1) {
          final pr = await _pickPromo();
          if (pr == null) return;
          m = ms.firstWhere((x) => x.promo == pr);
        }
        await _do(m);
        return;
      }
    }
    if (pos.b[sq] * pos.side > 0) {
      setState(() => sel = sq);
    } else {
      setState(() => sel = null);
    }
  }

  void _undo() {
    if (thinking || history.isEmpty) return;
    // vs computer: go back to before the player's last move (two plies)
    if (widget.vsComputer && pos.side == 1 && history.length >= 2) history.removeLast();
    final h = history.removeLast();
    pos = h.$1;
    captured.removeRange(h.$2, captured.length);
    last = null;
    sel = null;
    _refresh();
  }

  Future<int?> _pickPromo() => showDialog<int>(
        context: context,
        builder: (d) => SimpleDialog(title: const Text('Promote to'), children: [
          Wrap(alignment: WrapAlignment.center, children: [
            for (final p in const [5, 4, 3, 2])
              Padding(padding: const EdgeInsets.all(6), child: GestureDetector(onTap: () => Navigator.pop(d, p), child: SizedBox(width: 58, height: 58, child: CustomPaint(painter: _CoinPainter(p * pos.side, th))))),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final targets = sel == null ? const <int>{} : legal.where((m) => m.from == sel).map((m) => m.to).toSet();
    final checkSq = pos.inCheck(pos.side) ? pos.king(pos.side) : -1;
    return Scaffold(
      appBar: AppBar(title: const Text('♛ Chess 3D'), actions: [
        IconButton(tooltip: 'Undo', onPressed: _undo, icon: const Icon(Icons.undo)),
        IconButton(tooltip: 'New game', onPressed: _newGame, icon: const Icon(Icons.refresh)),
      ]),
      body: Column(children: [
        SizedBox(
          height: 50,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [
            for (var i = 0; i < chessThemes.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(chessThemes[i].name),
                  selected: theme == i,
                  onSelected: (_) {
                    setState(() => theme = i);
                    Store.i.setSetting('chessTheme', i);
                  },
                ),
              ),
          ]),
        ),
        _capturedRow(1),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AspectRatio(
                aspectRatio: 1,
                child: Board3D(
                  tilt: 0.45,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Clay.shade(th.frame, 0.12), th.frame]),
                    ),
                    child: LayoutBuilder(builder: (context, bc) {
                      final c = bc.maxWidth / 8;
                      return GestureDetector(
                        onTapUp: (d) {
                          final col = (d.localPosition.dx / c).floor(), row = (d.localPosition.dy / c).floor();
                          if (col >= 0 && col < 8 && row >= 0 && row < 8) _tap(row * 8 + col);
                        },
                        child: CustomPaint(size: Size.infinite, painter: _BoardPainter(pos.b, th, sel, targets, last, checkSq)),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
        _capturedRow(-1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (thinking) const Padding(padding: EdgeInsets.only(right: 10), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))),
            Flexible(child: Text(thinking ? 'Computer is thinking…' : status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          ]),
        ),
      ]),
    );
  }

  // pieces of colour [s] that were captured
  Widget _capturedRow(int s) {
    final list = captured.where((p) => p.sign == s).toList()..sort((a, b) => b.abs().compareTo(a.abs()));
    return SizedBox(
      height: 30,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final p in list) SizedBox(width: 24, height: 24, child: CustomPaint(painter: _CoinPainter(p, th))),
      ]),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final List<int> b;
  final ChessTheme th;
  final int? sel;
  final Set<int> targets;
  final Mv? last;
  final int checkSq;
  _BoardPainter(this.b, this.th, this.sel, this.targets, this.last, this.checkSq);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 8;
    for (var sq = 0; sq < 64; sq++) {
      final r = sq ~/ 8, col = sq % 8;
      final rect = Rect.fromLTWH(col * c, r * c, c, c);
      final light = (r + col).isEven;
      final base = light ? th.light : th.dark;
      canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Clay.shade(base, 0.04), Clay.shade(base, -0.04)]).createShader(rect));
      if (last != null && (sq == last!.from || sq == last!.to)) canvas.drawRect(rect, Paint()..color = const Color(0x66FFE14D));
      if (sq == sel) canvas.drawRect(rect, Paint()..color = const Color(0x8845E0A0));
      if (sq == checkSq) canvas.drawRect(rect, Paint()..shader = RadialGradient(colors: [const Color(0xDDFF2D2D), const Color(0x00FF2D2D)]).createShader(rect));
      if (col == 0 || r == 7) {
        final tp = TextPainter(text: TextSpan(text: col == 0 ? '${8 - r}' : '', style: TextStyle(fontSize: c * 0.18, color: light ? th.dark : th.light, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, rect.topLeft + Offset(c * 0.04, c * 0.02));
        if (r == 7) {
          final tq = TextPainter(text: TextSpan(text: 'abcdefgh'[col], style: TextStyle(fontSize: c * 0.18, color: light ? th.dark : th.light, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
          tq.paint(canvas, rect.bottomRight - Offset(tq.width + c * 0.05, tq.height + c * 0.02));
        }
      }
    }
    for (var sq = 0; sq < 64; sq++) {
      final rect = Rect.fromLTWH((sq % 8) * c, (sq ~/ 8) * c, c, c);
      if (b[sq] != 0) {
        canvas.save();
        canvas.translate(rect.left, rect.top);
        _CoinPainter(b[sq], th).paint(canvas, Size(c, c));
        canvas.restore();
      }
      if (targets.contains(sq)) {
        if (b[sq] != 0) {
          canvas.drawCircle(rect.center, c * 0.46, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = c * 0.07
            ..color = const Color(0xCC2EAE5A));
        } else {
          canvas.drawCircle(rect.center, c * 0.15, Paint()..color = const Color(0xAA2EAE5A));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter o) => true;
}

/// A glossy 3D "coin" with the chess piece on it.
class _CoinPainter extends CustomPainter {
  final int p;
  final ChessTheme th;
  _CoinPainter(this.p, this.th);

  @override
  void paint(Canvas canvas, Size s) {
    final white = p > 0;
    final col = white ? th.white : th.black;
    final ctr = Offset(s.width / 2, s.height * 0.46);
    final r = s.width * 0.38;
    canvas.drawCircle(ctr + Offset(0, r * 0.32), r, Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18));
    // coin edge (thickness)
    canvas.drawCircle(ctr + Offset(0, r * 0.18), r, Paint()..color = Clay.shade(col, white ? -0.25 : -0.08));
    canvas.drawCircle(ctr, r, Paint()..shader = RadialGradient(center: const Alignment(-0.35, -0.45), colors: [Clay.shade(col, white ? 0.0 : 0.22), col]).createShader(Rect.fromCircle(center: ctr, radius: r)));
    canvas.drawCircle(ctr, r * 0.84, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06
      ..color = (white ? th.dark : th.light).withValues(alpha: 0.6));
    final g = '${_glyph[p.abs()]}︎';
    final ink = white ? Clay.shade(th.black, 0.05) : th.white;
    final shadow = TextPainter(text: TextSpan(text: g, style: TextStyle(fontSize: r * 1.35, height: 1, color: Colors.black.withValues(alpha: 0.25))), textDirection: TextDirection.ltr)..layout();
    shadow.paint(canvas, ctr - Offset(shadow.width / 2, shadow.height / 2) + Offset(r * 0.05, r * 0.08));
    final tp = TextPainter(text: TextSpan(text: g, style: TextStyle(fontSize: r * 1.35, height: 1, color: ink)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, ctr - Offset(tp.width / 2, tp.height / 2));
    canvas.drawOval(Rect.fromCenter(center: ctr - Offset(r * 0.32, r * 0.48), width: r * 0.6, height: r * 0.28), Paint()..color = Colors.white.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(_CoinPainter o) => o.p != p || o.th != th;
}

/// Ask: vs computer or 2 people, and the level.
Future<void> openChess(BuildContext context) async {
  var vs = true;
  var level = 2;
  final w = TextEditingController(text: 'Nanna'), bl = TextEditingController(text: 'Amma');
  final go = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('♛ Chess', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Chess is a 2-player game — the other two can be the team advisers 😄', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, label: Text('🤖 vs Computer')), ButtonSegment(value: false, label: Text('👤 vs 👤'))],
            selected: {vs},
            onSelectionChanged: (v) => set(() => vs = v.first),
          ),
          const SizedBox(height: 10),
          TextField(controller: w, decoration: const InputDecoration(labelText: 'White', isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: 8),
          if (!vs) TextField(controller: bl, decoration: const InputDecoration(labelText: 'Black', isDense: true, border: OutlineInputBorder())),
          if (vs)
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 1, label: Text('😊 Easy')), ButtonSegment(value: 2, label: Text('🙂 Medium')), ButtonSegment(value: 3, label: Text('😈 Hard'))],
              selected: {level},
              onSelectionChanged: (v) => set(() => level = v.first),
            ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('▶ Start game', style: TextStyle(fontSize: 17)))),
        ]),
      ),
    ),
  );
  if (go != true || !context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => ChessPage(vsComputer: vs, level: level, whiteName: w.text.trim().isEmpty ? 'White' : w.text.trim(), blackName: bl.text.trim().isEmpty ? 'Black' : bl.text.trim())));
}
