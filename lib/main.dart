import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'call.dart';
import 'chat.dart';
import 'feed_alarm.dart';
import 'games/games_page.dart';
import 'moments.dart';
import 'talk.dart';
import 'updater.dart';
import 'pages/camera.dart';
import 'pages/voices.dart';
import 'pages/health.dart';
import 'pages/home.dart';
import 'pages/jatakam.dart';
import 'pages/memories.dart';
import 'pages/songs.dart';
import 'store.dart';
import 'ui_clay.dart';
import 'voice.dart';
import 'watch.dart';

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.i.load();
  try {
    await AndroidAlarmManager.initialize();
  } catch (_) {}
  await Alarm.init();
  await Voice.i.init();
  try {
    await Chat.i.init();
  } catch (_) {}
  try {
    await Moments.init();
  } catch (_) {}
  unawaited(Talk.reschedule());
  runApp(const LittleOneApp());
}

const pink = Color(0xFFE0789C); // the app's main colour (strawberry milk)

class LittleOneApp extends StatelessWidget {
  const LittleOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Little One',
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: clayTheme(),
      themeMode: ThemeMode.light,
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  StreamSubscription? _ringSub;
  bool _dialogOpen = false;
  final Set<int> _talkShown = {};

  @override
  void initState() {
    super.initState();
    Calls.nav = navKey;
    _ringSub = Alarm.ringing.listen((set) {
      final ids = set.alarms.map((a) => a.id).toList();
      if (ids.contains(FeedAlarm.id)) _showFeedAlarm();
      if (ids.any(Calls.isRing)) {
        final ctx = navKey.currentContext;
        if (ctx != null) Calls.showIncoming(ctx);
      }
      for (final id in ids.where(Talk.isTalk)) {
        if (_talkShown.add(id)) {
          final ctx = navKey.currentContext;
          if (ctx != null) showTalkSheet(ctx, id);
        }
      }
    });
    Moments.route.addListener(_openRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRoute());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _askPermissions();
      } catch (_) {}
      try {
        if (Store.i.settings['autoWatch'] != false) await SleepWatch.i.start(); // listening is on by default
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 4));
      final ctx = navKey.currentContext;
      if (ctx != null && ctx.mounted) unawaited(Updater.check(ctx));
    });
    Timer.periodic(const Duration(hours: 3), (_) {
      final ctx = navKey.currentContext;
      if (ctx != null && ctx.mounted) unawaited(Updater.check(ctx));
    });
  }

  Future<void> _askPermissions() async {
    await Permission.notification.request();
    if (await Permission.scheduleExactAlarm.isDenied) await Permission.scheduleExactAlarm.request();
  }

  void _openRoute() {
    final r = Moments.route.value;
    if (r == null) return;
    Moments.route.value = null;
    final nav = navKey.currentState;
    if (nav == null) return;
    if (r == 'chat') {
      nav.popUntil((x) => x.isFirst);
      setState(() => tab = 2);
      return;
    }
    nav.push(MaterialPageRoute(builder: (_) => r == 'voices' ? const VoicesPage() : const CameraPage()));
  }

  @override
  void dispose() {
    Moments.route.removeListener(_openRoute);
    _ringSub?.cancel();
    super.dispose();
  }

  Future<void> _showFeedAlarm() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    unawaited(Voice.i.babyAsksMilk());
    final ctx = navKey.currentContext;
    if (ctx == null) {
      _dialogOpen = false;
      return;
    }
    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Text('🍼', style: TextStyle(fontSize: 56)),
        title: const Text('అమ్మా, పాలు కావాలి!', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: pink)),
        content: Text('Feed time for ${Store.i.babyName}', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            onPressed: () async {
              Navigator.pop(c);
              await FeedAlarm.stop();
              await Store.i.addTime('feeds');
              await FeedAlarm.reschedule();
              await Voice.i.okayAmma();
            },
            child: const Text('🍼 పాలు పడుతున్నా · Feeding now', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              await FeedAlarm.snooze(10);
              if (!await Voice.i.clip('snooze')) await Voice.i.say('సరే… కొంచెం సేపు ఆగుతా', dev: 'सरे… कोंचेम सेपु आगुता', lat: 'Sare… konchem sepu aagutha', pitch: 1.8);
            },
            child: const Text('10 నిమిషాలు ఆగు · Snooze'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [const HomePage(), const MemoriesPage(), const ChatPage(), const GamesPage(), const SongsPage(), const HealthPage(), const JatakamPage()];
    return Scaffold(
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(tab), child: pages[tab])),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: ClayBox(
            radius: 28,
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(children: [
              _nav(0, Icons.home_rounded, 'Home'),
              _nav(1, Icons.photo_library_rounded, 'Memories'),
              _nav(2, Icons.forum_rounded, 'Chat'),
              _nav(3, Icons.sports_esports_rounded, 'Games'),
              _nav(4, Icons.music_note_rounded, 'Songs'),
              _nav(5, Icons.favorite_rounded, 'Health'),
              _nav(6, Icons.auto_awesome, 'Jatakam'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _nav(int i, IconData icon, String label) {
    final on = tab == i;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => tab = i),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ListenableBuilder(
            listenable: Chat.i,
            builder: (_, __) => Badge(
              isLabelVisible: i == 2 && Chat.i.unread > 0,
              label: Text('${Chat.i.unread}'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: on ? K.pinkSoft : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 22, color: on ? K.indigo : K.muted),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: TextStyle(fontSize: 9.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? K.indigo : K.muted)),
        ]),
      ),
    );
  }
}
