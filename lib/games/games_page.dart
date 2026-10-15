import 'package:flutter/material.dart';

import '../clay.dart';
import 'chess.dart';
import 'common.dart';
import 'ludo.dart';
import 'snakes.dart';
import 'uno.dart';

/// Family games: Chess, Ludo, Snakes & Ladders and UNO.
class GamesPage extends StatelessWidget {
  const GamesPage({super.key});

  Future<void> _start(BuildContext context, String title, Widget Function(List<GPlayer>) page) async {
    final ps = await pickPlayers(context, title: title);
    if (ps == null || !context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page(ps)));
  }

  @override
  Widget build(BuildContext context) {
    final games = [
      ('♛', 'Chess 3D', '3 themes · vs computer or each other', const Color(0xFFFFD9A8), const Color(0xFFFFB7C9), () => openChess(context)),
      ('🎲', 'Ludo', '2–4 players · pass the phone', const Color(0xFFFFB3B3), const Color(0xFFFFE08A), () => _start(context, '🎲 Ludo — who is playing?', (p) => LudoPage(players: p))),
      ('🐍', 'Snakes & Ladders', '3D board · 2–4 players', const Color(0xFFB8F0C8), const Color(0xFFA8E0FF), () => _start(context, '🐍 Snakes & Ladders', (p) => SnakesPage(players: p))),
      ('🃏', 'UNO', '2–4 players · computer or family', const Color(0xFFD8C4FF), const Color(0xFFFFC4E8), () => _start(context, '🃏 UNO — who is playing?', (p) => UnoPage(players: p))),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Games · ఆటలు')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Family game time while Chinnari naps 😴 — up to 4 players on one phone. Turn on 🤖 for any seat to play against the computer.', style: TextStyle(fontSize: 13)),
        ),
        for (final g in games)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ClayButton(
              color: g.$4,
              color2: g.$5,
              onTap: g.$6,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Row(children: [
                ClayBubble(g.$1, size: 62),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g.$2, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF3A2440))),
                    const SizedBox(height: 2),
                    Text(g.$3, style: const TextStyle(fontSize: 13, color: Color(0xFF5A3D60))),
                  ]),
                ),
                const Icon(Icons.play_circle_fill, size: 36, color: Color(0xFF3A2440)),
              ]),
            ),
          ),
      ]),
    );
  }
}
