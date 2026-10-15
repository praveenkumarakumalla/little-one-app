import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chat.dart';
import '../clay.dart';
import '../store.dart';
import 'chess.dart';
import 'common.dart';
import 'game3d.dart';

/// Family games. Each can be played on one phone (people + computer) or across phones with a room code.
/// A room code is only for that game – it never gives access to the family chat or memories.
class GamesPage extends StatelessWidget {
  const GamesPage({super.key});

  static const games = [
    ('chess', '♛', 'Chess 3D', 'Real 3D pieces · 3 themes · vs computer', Color(0xFFFFD9A8), Color(0xFFFFB7C9)),
    ('ludo', '🎲', 'Ludo', '3D board · rolling dice · 2–4 players', Color(0xFFFFB3B3), Color(0xFFFFE08A)),
    ('snakes', '🐍', 'Snakes & Ladders', '3D snakes & ladders · 2–4 players', Color(0xFFB8F0C8), Color(0xFFA8E0FF)),
    ('uno', '🃏', 'UNO', 'Card table · UNO button · 2–4 players', Color(0xFFD8C4FF), Color(0xFFFFC4E8)),
    ('sheep', '🐑', 'Sheep Fight', 'Push the herd · 1 vs 1 or 2 vs 2', Color(0xFFC8F7A8), Color(0xFFFFF1A8)),
  ];

  static String _myName() {
    final n = Chat.i.myName;
    if (n.isNotEmpty) return n;
    return (Store.i.settings['gameName'] ?? 'Nanna').toString();
  }

  Future<void> _open(BuildContext context, (String, String, String, String, Color, Color) g) async {
    final how = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${g.$2} ${g.$3}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ClayButton(
              color: const Color(0xFFFFE3EE),
              onTap: () => Navigator.pop(c, 'local'),
              child: const Row(children: [
                Text('📱', style: TextStyle(fontSize: 30)),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Play on this phone', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  Text('Pass the phone around, or play the computer 🤖. Works without internet.', style: TextStyle(fontSize: 12)),
                ])),
              ]),
            ),
            const SizedBox(height: 10),
            ClayButton(
              color: const Color(0xFFD7ECFF),
              onTap: () => Navigator.pop(c, 'create'),
              child: const Row(children: [
                Text('🌐', style: TextStyle(fontSize: 30)),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Create a room', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  Text('Each person plays on their own phone. Share the room code.', style: TextStyle(fontSize: 12)),
                ])),
              ]),
            ),
            const SizedBox(height: 10),
            ClayButton(
              color: const Color(0xFFE2F7D5),
              onTap: () => Navigator.pop(c, 'join'),
              child: const Row(children: [
                Text('🔑', style: TextStyle(fontSize: 30)),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Join a room', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  Text('Type the 4-letter room code someone shared with you.', style: TextStyle(fontSize: 12)),
                ])),
              ]),
            ),
            const SizedBox(height: 8),
            const Text('Room codes are only for games – they never open your family chat or memories.', style: TextStyle(fontSize: 11), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
    if (how == null || !context.mounted) return;
    final id = g.$1;
    if (how == 'local') {
      if (id == 'chess') return openChess(context);
      final ps = await pickPlayers(context, title: '${g.$2} ${g.$3} — who is playing?');
      if (ps == null || !context.mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => Game3DPage(cfg: {'game': id, 'players': [for (final p in ps) {'name': p.name, 'bot': p.bot}]})));
      return;
    }
    final room = await _roomDialog(context, how == 'create');
    if (room == null || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Game3DPage(cfg: {
          'game': id,
          'level': 2,
          'theme': (Store.i.settings['chessTheme'] as int?) ?? 0,
          'net': {'role': how == 'create' ? 'host' : 'guest', 'code': room.$1, 'name': room.$2},
        }),
      ),
    );
  }

  static String _newRoomCode() {
    const abc = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = math.Random.secure();
    return List.generate(4, (_) => abc[r.nextInt(abc.length)]).join();
  }

  Future<(String, String)?> _roomDialog(BuildContext context, bool create) {
    final name = TextEditingController(text: _myName());
    final code = TextEditingController(text: create ? _newRoomCode() : '');
    return showDialog<(String, String)>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(create ? '🌐 New room' : '🔑 Join a room'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: code,
            readOnly: create,
            textCapitalization: TextCapitalization.characters,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 8),
            decoration: InputDecoration(labelText: create ? 'Room code (share it)' : 'Room code', border: const OutlineInputBorder(), counterText: ''),
          ),
          const SizedBox(height: 4),
          const Text('Needs internet (Wi-Fi or mobile data) on every phone.', style: TextStyle(fontSize: 11)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final c = code.text.trim().toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
              final n = name.text.trim().isEmpty ? 'Player' : name.text.trim();
              if (c.length != 4) return;
              Store.i.setSetting('gameName', n);
              Navigator.pop(d, (c, n));
            },
            child: Text(create ? 'Open room' : 'Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Games · ఆటలు')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Family game time while Chinnari naps 😴 — play on one phone, or each on your own phone with a room code. Friends can join games without seeing your chat or memories.', style: TextStyle(fontSize: 13)),
        ),
        for (final g in games)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ClayButton(
              color: g.$5,
              color2: g.$6,
              onTap: () => _open(context, g),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Row(children: [
                ClayBubble(g.$2, size: 62),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g.$3, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF3A2440))),
                    const SizedBox(height: 2),
                    Text(g.$4, style: const TextStyle(fontSize: 13, color: Color(0xFF5A3D60))),
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
