import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'data.dart';
import 'store.dart';

/// Private chat between Amma's and Nanna's phones.
/// Messages are end-to-end encrypted (AES-256-GCM) with a key made from the pairing code,
/// then passed through the free ntfy.sh relay. The relay only ever sees scrambled text,
/// and keeps it for about 12 hours; the full history lives on both phones.
class Chat extends ChangeNotifier with WidgetsBindingObserver {
  Chat._();
  static final Chat i = Chat._();
  static const relay = 'https://ntfy.sh';

  final _aes = AesGcm.with256bits();
  SecretKey? _key;
  String? _topic;
  Timer? _timer;
  bool _busy = false;
  bool pageOpen = false;
  bool online = true;
  bool _fg = true;

  Map<String, dynamic> get cfg => Map<String, dynamic>.from((Store.i.d['chatCfg'] ?? {}) as Map);
  bool get paired => (cfg['code'] ?? '').toString().isNotEmpty;
  String get me => (cfg['device'] ?? '').toString();
  String get myName => (cfg['name'] ?? '').toString();
  List<Map<String, dynamic>> get msgs => (Store.i.d['chat'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  int get unread {
    final seen = (cfg['readAt'] as num?)?.toInt() ?? 0;
    return msgs.where((m) => m['from'] != me && (m['at'] as num) > seen).length;
  }

  Future<void> init() async {
    Store.i.d.putIfAbsent('chat', () => <dynamic>[]);
    WidgetsBinding.instance.addObserver(this);
    if (paired) await _setup();
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _fg = s == AppLifecycleState.resumed;
    if (_fg) poll();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!paired || !_fg) return;
    _timer = Timer.periodic(Duration(seconds: pageOpen ? 4 : 30), (_) => poll());
  }

  void setPageOpen(bool v) {
    pageOpen = v;
    if (v) {
      markRead();
      poll();
    }
    _schedule();
  }

  static String normalise(String code) => code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  static String newCode() {
    const abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = math.Random.secure();
    final s = List.generate(16, (_) => abc[r.nextInt(abc.length)]).join();
    return '${s.substring(0, 4)}-${s.substring(4, 8)}-${s.substring(8, 12)}-${s.substring(12)}';
  }

  Future<void> _saveCfg(Map<String, dynamic> c) async {
    Store.i.d['chatCfg'] = c;
    await Store.i.save();
  }

  Future<void> pair(String code, String name) async {
    final c = cfg;
    c['code'] = code;
    c['name'] = name;
    c['device'] = c['device'] ?? Store.newId();
    c.remove('since');
    await _saveCfg(c);
    await _setup();
    _schedule();
    await poll();
    await send('👋 $name joined the chat', kind: 'join');
  }

  Future<void> setName(String n) async {
    final c = cfg..['name'] = n;
    await _saveCfg(c);
  }

  Future<void> unpair() async {
    final c = cfg
      ..remove('code')
      ..remove('since');
    await _saveCfg(c);
    _key = null;
    _topic = null;
    _schedule();
    notifyListeners();
  }

  Future<void> markRead() async {
    final c = cfg..['readAt'] = DateTime.now().millisecondsSinceEpoch;
    Store.i.d['chatCfg'] = c;
    await Store.i.save();
    notifyListeners();
  }

  Future<void> _setup() async {
    final code = normalise(cfg['code'].toString());
    final h = await Sha256().hash(utf8.encode('little-one-topic:$code'));
    _topic = 'lo_${h.bytes.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    final k = await Sha256().hash(utf8.encode('little-one-key:$code'));
    _key = SecretKey(k.bytes);
  }

  Future<String> _seal(Map<String, dynamic> m) async {
    final box = await _aes.encrypt(utf8.encode(jsonEncode(m)), secretKey: _key!);
    return base64Encode(box.concatenation());
  }

  Future<Map<String, dynamic>?> _open(String s) async {
    try {
      final box = SecretBox.fromConcatenation(base64Decode(s), nonceLength: 12, macLength: 16);
      final clear = await _aes.decrypt(box, secretKey: _key!);
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
    } catch (_) {
      return null; // not ours / wrong code
    }
  }

  Future<bool> _publish(Map<String, dynamic> m) async {
    if (_topic == null) return false;
    try {
      final r = await http.post(Uri.parse('$relay/$_topic'), body: await _seal(m), headers: {'Cache': 'yes'}).timeout(const Duration(seconds: 15));
      online = r.statusCode == 200;
    } catch (_) {
      online = false;
    }
    notifyListeners();
    return online;
  }

  Future<void> _store(List<Map<String, dynamic>> l) async {
    Store.i.d['chat'] = l.length > 3000 ? l.sublist(l.length - 3000) : l;
    await Store.i.save();
    notifyListeners();
  }

  Future<void> send(String text, {String kind = 'text'}) async {
    text = text.trim();
    if (text.isEmpty || !paired) return;
    if (text.length > 1500) text = text.substring(0, 1500);
    final m = <String, dynamic>{'id': Store.newId(), 'from': me, 'name': myName, 'text': text, 'at': DateTime.now().millisecondsSinceEpoch, 'kind': kind};
    final l = msgs..add({...m, 'sent': false});
    await _store(l);
    final ok = await _publish({'t': 'msg', ...m});
    if (ok) await _patch(m['id'].toString(), {'sent': true, 'pubAt': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> _patch(String id, Map<String, dynamic> f) async {
    await _store(msgs.map((x) => x['id'] == id ? {...x, ...f} : x).toList());
  }

  Future<void> deleteLocal(String id) async => _store(msgs.where((x) => x['id'] != id).toList());

  /// Fetch new messages, send receipts, and re-send anything the other phone hasn't confirmed.
  Future<void> poll() async {
    if (!paired || _busy || _topic == null) return;
    _busy = true;
    try {
      final c = cfg;
      final since = c['since'] == null ? 'all' : c['since'].toString();
      final r = await http.get(Uri.parse('$relay/$_topic/json?poll=1&since=$since')).timeout(const Duration(seconds: 20));
      online = r.statusCode == 200;
      if (online) {
        final l = msgs;
        final ids = l.map((x) => x['id']).toSet();
        final acks = <String>[];
        final delivered = <String>{};
        var latest = (c['since'] is String) ? int.tryParse(c['since'].toString()) ?? 0 : 0;
        var got = 0;
        for (final line in const LineSplitter().convert(r.body)) {
          if (line.trim().isEmpty) continue;
          final ev = jsonDecode(line) as Map;
          if (ev['event'] != 'message') continue;
          final t = (ev['time'] as num?)?.toInt() ?? 0;
          if (t > latest) latest = t;
          final m = await _open(ev['message'].toString());
          if (m == null || m['from'] == me) continue;
          if (m['t'] == 'ack') {
            delivered.addAll((m['ref'] as List).map((e) => e.toString()));
          } else if (m['t'] == 'msg') {
            acks.add(m['id'].toString());
            if (!ids.contains(m['id'])) {
              m.remove('t');
              l.add(m);
              ids.add(m['id']);
              got++;
            }
          }
        }
        l.sort((a, b) => (a['at'] as num).compareTo(b['at'] as num));
        final now = DateTime.now().millisecondsSinceEpoch;
        final resend = <Map<String, dynamic>>[];
        for (final x in l) {
          if (x['from'] != me) continue;
          if (delivered.contains(x['id'])) x['got'] = true;
          final pub = (x['pubAt'] as num?)?.toInt() ?? 0;
          if (x['got'] != true && (x['sent'] != true || now - pub > 8 * 3600000)) resend.add(x);
        }
        if (latest > 0) c['since'] = (latest - 5).toString();
        Store.i.d['chatCfg'] = c;
        await _store(l);
        if (acks.isNotEmpty) await _publish({'t': 'ack', 'from': me, 'ref': acks});
        for (final x in resend.take(20)) {
          final ok = await _publish({'t': 'msg', 'id': x['id'], 'from': me, 'name': x['name'], 'text': x['text'], 'at': x['at'], 'kind': x['kind'] ?? 'text'});
          if (ok) await _patch(x['id'].toString(), {'sent': true, 'pubAt': now});
        }
        if (got > 0) {
          if (pageOpen) {
            await markRead();
          } else {
            HapticFeedback.vibrate();
          }
        }
      }
    } catch (_) {
      online = false;
    }
    _busy = false;
    notifyListeners();
  }
}

/// Quick one-tap messages.
const quickMsgs = [
  '🍼 పాలు పట్టాను',
  '😴 పాప పడుకుంది',
  '😊 పాప లేచింది',
  '🧷 డైపర్ మార్చాను',
  '😢 పాప ఏడుస్తోంది, రా',
  '📞 కాల్ చెయ్',
  '🛒 డైపర్లు తెచ్చేయ్',
  '🏠 బయలుదేరాను',
  '❤️ Love you',
];

String babyStatus() {
  final s = Store.i;
  String t(DateTime? d) => d == null ? '–' : hm(d);
  return '👶 ${s.babyName} now:\n🍼 Last feed ${t(s.last('feeds'))} (${s.countToday('feeds')} today)\n🧷 Last nappy ${t(s.last('nappies'))} (${s.countToday('nappies')} today)\n🌤️ Woke at ${t(s.last('sleeps'))}\n😢 Cries today: ${s.countCries()}';
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Chat.i.setPageOpen(true);
  }

  @override
  void dispose() {
    Chat.i.setPageOpen(false);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Chat.i,
      builder: (context, _) => Chat.i.paired ? _chat(context) : const _PairView(),
    );
  }

  Widget _chat(BuildContext context) {
    final c = Chat.i, cs = Theme.of(context).colorScheme;
    final l = c.msgs.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('మన చాట్ · Our chat'),
          Text(c.online ? '🔒 Only your two phones can read this' : '⚠️ No internet — will send when back', style: TextStyle(fontSize: 12, color: c.online ? cs.outline : cs.error)),
        ]),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: c.poll, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Chat settings', onPressed: () => _settings(context), icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: l.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No messages yet. Say hi! 👋', textAlign: TextAlign.center)))
              : ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: l.length,
                  itemBuilder: (_, i) {
                    final m = l[i];
                    final at = DateTime.fromMillisecondsSinceEpoch((m['at'] as num).toInt());
                    final prev = i + 1 < l.length ? DateTime.fromMillisecondsSinceEpoch((l[i + 1]['at'] as num).toInt()) : null;
                    final newDay = prev == null || ymd(prev) != ymd(at);
                    final mine = m['from'] == c.me;
                    final bubble = _bubble(context, m, mine, at);
                    return Column(children: [
                      if (newDay) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Chip(label: Text(ymd(at) == ymd(DateTime.now()) ? 'Today' : dmy(at)))),
                      bubble,
                    ]);
                  },
                ),
        ),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: ActionChip(avatar: const Icon(Icons.child_care, size: 18), label: const Text('Send baby status'), onPressed: () => c.send(babyStatus(), kind: 'status'))),
            ...quickMsgs.map((q) => Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: ActionChip(label: Text(q), onPressed: () => c.send(q)))),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 1500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(counterText: '', hintText: 'Message…', filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                iconSize: 26,
                onPressed: () {
                  final t = _text.text;
                  _text.clear();
                  c.send(t);
                },
                icon: const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _bubble(BuildContext context, Map<String, dynamic> m, bool mine, DateTime at) {
    final cs = Theme.of(context).colorScheme;
    final tick = !mine ? '' : m['got'] == true ? ' ✓✓' : m['sent'] == true ? ' ✓' : ' 🕓';
    if (m['kind'] == 'join') {
      return Padding(padding: const EdgeInsets.all(6), child: Text(m['text'].toString(), style: TextStyle(color: cs.outline, fontSize: 13)));
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _msgMenu(context, m),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
          decoration: BoxDecoration(
            color: mine ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 4), bottomRight: Radius.circular(mine ? 4 : 18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!mine) Text(m['name'].toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.primary)),
            Text(m['text'].toString(), style: const TextStyle(fontSize: 16)),
            Align(alignment: Alignment.bottomRight, child: Text('${hm(at)}$tick', style: TextStyle(fontSize: 11, color: cs.outline))),
          ]),
        ),
      ),
    );
  }

  void _msgMenu(BuildContext context, Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: m['text'].toString()));
              Navigator.pop(c);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete on this phone'),
            onTap: () {
              Chat.i.deleteLocal(m['id'].toString());
              Navigator.pop(c);
            },
          ),
        ]),
      ),
    );
  }

  void _settings(BuildContext context) {
    final c = Chat.i;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pairing code', style: TextStyle(fontWeight: FontWeight.w700)),
            SelectableText(c.cfg['code'].toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const Text('Anyone with this code can read the chat. Share it only with your wife / husband.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.share), title: const Text('Share code'), onTap: () => Share.share('Little One chat code: ${c.cfg['code']}\nOpen Little One → Chat → "Join with code" and type this.')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: Text('My name: ${c.myName}'),
              onTap: () async {
                final n = await _ask(context, 'Your name', c.myName);
                if (n != null && n.isNotEmpty) await c.setName(n);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_off),
              title: const Text('Leave chat (keeps old messages)'),
              onTap: () async {
                Navigator.pop(s);
                await c.unpair();
              },
            ),
          ]),
        ),
      ),
    );
  }
}

Future<String?> _ask(BuildContext context, String title, String init) {
  final t = TextEditingController(text: init);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(controller: t, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, t.text.trim()), child: const Text('OK'))],
    ),
  );
}

class _PairView extends StatefulWidget {
  const _PairView();
  @override
  State<_PairView> createState() => _PairViewState();
}

class _PairViewState extends State<_PairView> {
  late final _name = TextEditingController(text: Chat.i.myName);
  final _code = TextEditingController();
  String? newCode;
  bool busy = false;

  List<String> get _names {
    final p = Store.i.profile;
    return [
      for (final k in ['father', 'mother'])
        if ((p[k] ?? '').toString().isNotEmpty) p[k].toString(),
      'Amma',
      'Nanna',
    ];
  }

  Future<void> _go(String code) async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Type your name first')));
      return;
    }
    if (Chat.normalise(code).length != 16) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The code has 16 letters/numbers, like ABCD-EFGH-JKLM-NPQR')));
      return;
    }
    setState(() => busy = true);
    await Chat.i.pair(code.trim().toUpperCase(), _name.text.trim());
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('మన చాట్ · Our chat')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('💬', style: TextStyle(fontSize: 54), textAlign: TextAlign.center),
        const Text('A private chat just for the two of you', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Messages are locked with a secret code (end-to-end encrypted). Only the two phones with the code can read them. Free, no sign-up.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 20),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder())),
        Wrap(spacing: 6, children: _names.map((n) => ActionChip(label: Text(n), onPressed: () => setState(() => _name.text = n))).toList()),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('① First phone', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Text('Make a code and send it to the other phone.'),
              const SizedBox(height: 10),
              if (newCode == null)
                FilledButton.icon(onPressed: () => setState(() => newCode = Chat.newCode()), icon: const Icon(Icons.key), label: const Text('Make a chat code'))
              else ...[
                SelectableText(newCode!, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: cs.primary)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(onPressed: () => Share.share('Little One chat code: $newCode\nOpen Little One → Chat → "Join with code" and type this.'), icon: const Icon(Icons.share), label: const Text('Send code')),
                  FilledButton(onPressed: busy ? null : () => _go(newCode!), child: const Text('Start chat')),
                ]),
              ],
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('② Second phone', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Text('Type the code from the first phone.'),
              const SizedBox(height: 10),
              TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'ABCD-EFGH-JKLM-NPQR', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              FilledButton(onPressed: busy ? null : () => _go(_code.text), child: const Text('Join with code')),
            ]),
          ),
        ),
        if (busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}
