import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'chat.dart';
import 'feed_alarm.dart';
import 'moments.dart';
import 'talk.dart';
import 'pages/camera.dart';
import 'pages/voices.dart';
import 'pages/health.dart';
import 'pages/home.dart';
import 'pages/jatakam.dart';
import 'pages/memories.dart';
import 'pages/songs.dart';
import 'store.dart';
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

const pink = Color(0xFFEE5D8E);

class LittleOneApp extends StatelessWidget {
  const LittleOneApp({super.key});

  ThemeData _theme(Brightness b) {
    final cs = ColorScheme.fromSeed(seedColor: pink, brightness: b);
    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFFCEAF2) : const Color(0xFF1A1220),
      cardTheme: CardThemeData(
        elevation: 5,
        shadowColor: b == Brightness.light ? const Color(0x66E9A0BC) : Colors.black54,
        surfaceTintColor: Colors.transparent,
        color: b == Brightness.light ? Colors.white : const Color(0xFF251A2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: b == Brightness.light ? Colors.white : Colors.white10, width: 1.5)),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(elevation: 4, shadowColor: const Color(0x99D04477), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), side: BorderSide(color: cs.primary.withValues(alpha: 0.4), width: 1.5)),
      ),
      chipTheme: ChipThemeData(elevation: 2, pressElevation: 0, shadowColor: const Color(0x55E9A0BC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 10,
        shadowColor: const Color(0x66E9A0BC),
        backgroundColor: b == Brightness.light ? Colors.white : const Color(0xFF231828),
        surfaceTintColor: Colors.transparent,
        indicatorColor: b == Brightness.light ? const Color(0xFFFFD9E6) : const Color(0xFF4A2338),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface)),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Little One',
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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
    _ringSub = Alarm.ringing.listen((set) {
      final ids = set.alarms.map((a) => a.id).toList();
      if (ids.contains(FeedAlarm.id)) _showFeedAlarm();
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
        if (Store.i.settings['autoWatch'] == true) await SleepWatch.i.start();
      } catch (_) {}
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
    final pages = [const HomePage(), const MemoriesPage(), const ChatPage(), const SongsPage(), const HealthPage(), const JatakamPage()];
    return Scaffold(
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(tab), child: pages[tab])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library), label: 'Memories'),
          NavigationDestination(
            icon: ListenableBuilder(listenable: Chat.i, builder: (_, __) => Badge(isLabelVisible: Chat.i.unread > 0, label: Text('${Chat.i.unread}'), child: const Icon(Icons.chat_bubble_outline))),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          const NavigationDestination(icon: Icon(Icons.music_note_outlined), selectedIcon: Icon(Icons.music_note), label: 'Songs'),
          const NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Health'),
          const NavigationDestination(icon: Icon(Icons.nightlight_outlined), selectedIcon: Icon(Icons.nightlight), label: 'Jatakam'),
        ],
      ),
    );
  }
}
