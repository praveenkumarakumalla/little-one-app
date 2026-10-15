import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'common.dart';
import 'sfx.dart';

/// UNO-style card game for 2–4 players (pass the phone, or play the computer).
class UnoPage extends StatefulWidget {
  final List<GPlayer> players;
  const UnoPage({super.key, required this.players});
  @override
  State<UnoPage> createState() => _UnoPageState();
}

// colour 0 red, 1 yellow, 2 green, 3 blue, 4 wild
// value 0..9, 10 skip, 11 reverse, 12 +2, 13 wild, 14 wild +4
class UCard {
  final int color, value;
  const UCard(this.color, this.value);
  bool get wild => color == 4;
  String get label => value <= 9 ? '$value' : const {10: '⊘', 11: '⇄', 12: '+2', 13: '★', 14: '+4'}[value]!;
}

const _uColors = [Color(0xFFE53950), Color(0xFFF2B705), Color(0xFF2EAE5A), Color(0xFF2F7DE1), Color(0xFF2B2240)];
const _uNames = ['Red', 'Yellow', 'Green', 'Blue'];

class _UnoPageState extends State<UnoPage> {
  final rnd = math.Random();
  List<UCard> deck = [], pile = [];
  late List<List<UCard>> hands;
  int turn = 0, dir = 1, color = 0, pendingDraw = 0;
  bool busy = false, hidden = false, drewThisTurn = false;
  String msg = '';

  int get n => widget.players.length;
  GPlayer get cur => widget.players[turn];
  UCard get top => pile.last;
  bool get humans2plus => widget.players.where((p) => !p.bot).length >= 2;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    deck = [
      for (var c = 0; c < 4; c++) ...[
        UCard(c, 0),
        for (var v = 1; v <= 12; v++) ...[UCard(c, v), UCard(c, v)],
      ],
      for (var i = 0; i < 4; i++) ...[const UCard(4, 13), const UCard(4, 14)],
    ]..shuffle(rnd);
    hands = List.generate(n, (_) => [for (var i = 0; i < 7; i++) deck.removeLast()]);
    var first = deck.removeLast();
    while (first.value > 9) {
      deck.insert(0, first);
      first = deck.removeLast();
    }
    pile = [first];
    color = first.color;
    turn = 0;
    dir = 1;
    pendingDraw = 0;
    busy = false;
    drewThisTurn = false;
    msg = '${cur.name} starts!';
    hidden = humans2plus && !cur.bot;
    setState(() {});
    _startTurn(first: true);
  }

  UCard _draw() {
    if (deck.isEmpty) {
      final t = pile.removeLast();
      deck = pile..shuffle(rnd);
      pile = [t];
    }
    return deck.isEmpty ? UCard(rnd.nextInt(4), rnd.nextInt(10)) : deck.removeLast();
  }

  bool _playable(UCard c) => c.wild || c.color == color || c.value == top.value;

  Future<void> _startTurn({bool first = false}) async {
    drewThisTurn = false;
    if (!cur.bot && !first) Sfx.play('turn', volume: 0.5);
    if (cur.bot) {
      busy = true;
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) _botPlay();
    } else if (humans2plus && !first) {
      setState(() => hidden = true);
    }
  }

  Future<void> _reveal() async {
    await passPhone(context, cur);
    if (mounted) setState(() => hidden = false);
  }

  void _botPlay() {
    final h = hands[turn];
    final options = [for (var i = 0; i < h.length; i++) if (_playable(h[i])) i];
    if (options.isEmpty) {
      final c = _draw();
      h.add(c);
      Sfx.play('draw');
      setState(() => msg = '${cur.name} draws a card');
      if (_playable(c)) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _play(h.length - 1, chosen: _bestColor(h));
        });
      } else {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _advance();
        });
      }
      return;
    }
    // prefer action cards against a player with few cards, keep wilds for later
    options.sort((a, b) {
      int sc(UCard c) => c.wild ? 0 : (c.value >= 10 ? 3 : 2) + (c.color == color ? 1 : 0);
      return sc(h[b]).compareTo(sc(h[a]));
    });
    _play(options.first, chosen: _bestColor(h));
  }

  int _bestColor(List<UCard> h) {
    final cnt = [0, 0, 0, 0];
    for (final c in h) {
      if (!c.wild) cnt[c.color]++;
    }
    var best = 0;
    for (var i = 1; i < 4; i++) {
      if (cnt[i] > cnt[best]) best = i;
    }
    return best;
  }

  Future<void> _play(int i, {int? chosen}) async {
    final h = hands[turn];
    final c = h[i];
    if (!_playable(c)) return;
    var col = c.color;
    if (c.wild) {
      col = chosen ?? (cur.bot ? _bestColor(h) : await _pickColor() ?? -1);
      if (col < 0) return;
    }
    h.removeAt(i);
    Sfx.play(c.value == 12 || c.value == 14 ? 'plus' : c.value == 10 || c.value == 11 ? 'skip' : 'flip');
    pile.add(c);
    color = col;
    final who = cur.name;
    if (h.isEmpty) {
      setState(() {});
      Sfx.play('win');
      await winDialog(context, '$who wins UNO! 🎉', again: _reset);
      return;
    }
    var skip = false;
    String extra = '';
    if (c.value == 10) {
      skip = true;
      extra = ' — skip!';
    } else if (c.value == 11) {
      if (n == 2) {
        skip = true;
      } else {
        dir = -dir;
      }
      extra = ' — reverse!';
    } else if (c.value == 12 || c.value == 14) {
      final victim = (turn + dir + n) % n;
      final k = c.value == 12 ? 2 : 4;
      for (var j = 0; j < k; j++) {
        hands[victim].add(_draw());
      }
      skip = true;
      extra = ' — ${widget.players[victim].name} draws $k!';
    }
    if (c.wild) extra += ' (${_uNames[color]})';
    if (h.length == 1) Future.delayed(const Duration(milliseconds: 300), () => Sfx.play('uno'));
    setState(() => msg = '$who played ${c.label}$extra${h.length == 1 ? '  🔔 UNO!' : ''}');
    _advance(skip: skip);
  }

  void _advance({bool skip = false}) {
    turn = (turn + dir * (skip ? 2 : 1)) % n;
    if (turn < 0) turn += n;
    busy = false;
    if (humans2plus) hidden = true;
    setState(() {});
    _startTurn();
  }

  Future<int?> _pickColor() => showDialog<int>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Pick a colour'),
          content: Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < 4; i++)
              GestureDetector(
                onTap: () => Navigator.pop(d, i),
                child: Container(width: 64, height: 64, decoration: BoxDecoration(color: _uColors[i], borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4))])),
              ),
          ]),
        ),
      );

  void _humanDraw() {
    if (cur.bot || busy || hidden) return;
    if (drewThisTurn) {
      setState(() => msg = '${cur.name} passes');
      _advance();
      return;
    }
    final c = _draw();
    hands[turn].add(c);
    Sfx.play('draw');
    drewThisTurn = true;
    setState(() => msg = _playable(c) ? 'You drew a playable card — play it or tap Pass' : 'No luck — tap Pass');
  }

  @override
  Widget build(BuildContext context) {
    final me = cur.bot ? (widget.players.indexWhere((p) => !p.bot)) : turn;
    final showHand = me >= 0 && !hidden;
    final hand = me >= 0 ? hands[me] : <UCard>[];
    return Scaffold(
      backgroundColor: const Color(0xFF1F6B45),
      appBar: AppBar(title: const Text('🃏 UNO'), backgroundColor: const Color(0xFF17573A), foregroundColor: Colors.white),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
            for (var i = 0; i < n; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: i == turn ? Colors.amber : Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: Text('${widget.players[i].bot ? '🤖' : '👤'} ${widget.players[i].name} · ${hands[i].length}🂠', style: TextStyle(fontWeight: FontWeight.w800, color: i == turn ? Colors.black : Colors.white)),
              ),
          ]),
          const SizedBox(height: 4),
          Text(dir == 1 ? '↻ clockwise' : '↺ reversed', style: const TextStyle(color: Colors.white70)),
          Expanded(
            child: Center(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                GestureDetector(onTap: _humanDraw, child: const UnoCardView(null, width: 92)),
                const SizedBox(width: 26),
                Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                  Transform.rotate(angle: -0.15, child: UnoCardView(pile.length > 1 ? pile[pile.length - 2] : top, width: 100)),
                  UnoCardView(top, width: 100, shownColor: color),
                ]),
              ]),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(14)),
            child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 18, height: 18, decoration: BoxDecoration(color: _uColors[color], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
              const SizedBox(width: 6),
              Text('Colour: ${_uNames[color]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (!cur.bot && !hidden) FilledButton.tonal(onPressed: _humanDraw, child: Text(drewThisTurn ? 'Pass ▶' : 'Draw 🂠')),
            ]),
          ),
          SizedBox(
            height: 150,
            child: hidden && !cur.bot
                ? Center(child: FilledButton.icon(onPressed: _reveal, icon: const Icon(Icons.visibility), label: Text('${cur.name}: show my cards')))
                : showHand
                    ? ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                        children: [
                          for (var i = 0; i < hand.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Opacity(
                                opacity: me == turn && !busy && _playable(hand[i]) ? 1 : 0.55,
                                child: Transform.translate(
                                  offset: Offset(0, me == turn && _playable(hand[i]) ? -10 : 0),
                                  child: GestureDetector(onTap: me == turn && !busy ? () => _play(i) : null, child: UnoCardView(hand[i], width: 76)),
                                ),
                              ),
                            ),
                        ],
                      )
                    : const SizedBox(),
          ),
        ]),
      ),
    );
  }
}

class UnoCardView extends StatelessWidget {
  final UCard? card; // null = back
  final double width;
  final int? shownColor;
  const UnoCardView(this.card, {super.key, this.width = 80, this.shownColor});

  @override
  Widget build(BuildContext context) {
    final c = card;
    final h = width * 1.5;
    final bg = c == null ? const Color(0xFF2B2240) : _uColors[c.color];
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.14),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 5))],
      ),
      padding: EdgeInsets.all(width * 0.06),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.1),
          gradient: c != null && c.wild
              ? const SweepGradient(colors: [Color(0xFFE53950), Color(0xFFF2B705), Color(0xFF2EAE5A), Color(0xFF2F7DE1), Color(0xFFE53950)])
              : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(bg, Colors.white, 0.18)!, bg]),
        ),
        child: Stack(children: [
          Center(
            child: Transform.rotate(
              angle: -0.5,
              child: Container(
                width: width * 0.78,
                height: h * 0.62,
                decoration: BoxDecoration(color: c == null ? const Color(0xFFE53950) : Colors.white, borderRadius: BorderRadius.all(Radius.elliptical(width * 0.6, h * 0.4))),
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: 0.5,
                  child: Text(
                    c == null ? 'UNO' : c.label,
                    style: TextStyle(
                      fontSize: c == null ? width * 0.26 : (c.label.length > 1 ? width * 0.34 : width * 0.46),
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: c == null ? Colors.amber : (c.wild ? (shownColor != null ? _uColors[shownColor!] : Colors.black) : bg),
                      shadows: const [Shadow(color: Colors.black26, offset: Offset(1, 2), blurRadius: 1)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (c != null) Positioned(left: 3, top: 1, child: Text(c.label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: width * 0.16))),
        ]),
      ),
    );
  }
}
