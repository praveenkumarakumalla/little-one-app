import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'feed_alarm.dart';
import 'pages/health.dart';
import 'pages/home.dart';
import 'pages/jatakam.dart';
import 'pages/memories.dart';
import 'pages/songs.dart';
import 'store.dart';
import 'voice.dart';

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.i.load();
  await Alarm.init();
  await Voice.i.init();
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
      scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFFFF7FA) : const Color(0xFF1A1220),
      cardTheme: CardThemeData(elevation: 0, color: b == Brightness.light ? Colors.white : const Color(0xFF251A2C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), margin: const EdgeInsets.symmetric(vertical: 8)),
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

  @override
  void initState() {
    super.initState();
    _ringSub = Alarm.ringing.listen((set) {
      if (set.alarms.isNotEmpty) _showFeedAlarm();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPermissions());
  }

  Future<void> _askPermissions() async {
    await Permission.notification.request();
    if (await Permission.scheduleExactAlarm.isDenied) await Permission.scheduleExactAlarm.request();
  }

  @override
  void dispose() {
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
              await Voice.i.say('సరే… కొంచెం సేపు ఆగుతా', dev: 'सरे… कोंचेम सेपु आगुता', lat: 'Sare… konchem sepu aagutha', pitch: 1.8);
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
    final pages = [const HomePage(), const MemoriesPage(), const SongsPage(), const HealthPage(), const JatakamPage()];
    return Scaffold(
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(tab), child: pages[tab])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library), label: 'Memories'),
          NavigationDestination(icon: Icon(Icons.music_note_outlined), selectedIcon: Icon(Icons.music_note), label: 'Songs'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Health'),
          NavigationDestination(icon: Icon(Icons.nightlight_outlined), selectedIcon: Icon(Icons.nightlight), label: 'Jatakam'),
        ],
      ),
    );
  }
}
