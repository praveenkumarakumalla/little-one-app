import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../call.dart';
import '../chat.dart';
import '../moments.dart';
import '../store.dart';
import '../updater.dart';
import '../voice.dart';
import '../watch.dart';
import 'care.dart';
import 'home.dart';
import 'jatakam.dart';
import 'onboarding.dart';
import 'ui.dart';

/// Little One – trial app (new clay design, for any family).
final trialNav = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Updater.channel = 'trial';
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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, systemNavigationBarColor: K.bg));
  runApp(const TrialApp());
}

class TrialApp extends StatelessWidget {
  const TrialApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Little One',
      navigatorKey: trialNav,
      debugShowCheckedModeBanner: false,
      theme: clayTheme(),
      home: ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) => Store.i.settings['tOnboarded'] == true ? const TrialShell() : Onboarding(onDone: () {}),
      ),
    );
  }
}

class TrialShell extends StatefulWidget {
  const TrialShell({super.key});
  @override
  State<TrialShell> createState() => _TrialShellState();
}

class _TrialShellState extends State<TrialShell> {
  int tab = 0;
  StreamSubscription? _ring;

  @override
  void initState() {
    super.initState();
    Calls.nav = trialNav;
    _ring = Alarm.ringing.listen((set) {
      if (set.alarms.any((a) => Calls.isRing(a.id))) {
        final ctx = trialNav.currentContext;
        if (ctx != null) Calls.showIncoming(ctx);
      }
    });
    Moments.route.addListener(_route);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Permission.notification.request();
      } catch (_) {}
      try {
        if (Store.i.settings['autoWatch'] == true) await SleepWatch.i.start();
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 5));
      final ctx = trialNav.currentContext;
      if (ctx != null && ctx.mounted) unawaited(Updater.check(ctx));
    });
  }

  void _route() {
    final r = Moments.route.value;
    if (r == 'chat') {
      Moments.route.value = null;
      setState(() => tab = 2);
    }
  }

  @override
  void dispose() {
    _ring?.cancel();
    Moments.route.removeListener(_route);
    super.dispose();
  }

  void _plus() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Quick log', 'త్వరగా నమోదు'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(children: [
              for (final k in logKinds) ...[
                Expanded(
                  child: ClayBox(
                    color: k.$1 == 'feeds' ? K.indigo : K.pinkSoft,
                    onTap: () {
                      Navigator.pop(c);
                      quickLog(context, k.$1);
                    },
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(children: [
                      Icon(k.$2, size: 32, color: k.$1 == 'feeds' ? Colors.white : K.indigo),
                      const SizedBox(height: 6),
                      Text(tr(k.$3, k.$4), style: TextStyle(fontWeight: FontWeight.w700, color: k.$1 == 'feeds' ? Colors.white : K.ink)),
                    ]),
                  ),
                ),
                if (k != logKinds.last) const SizedBox(width: 12),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [HomeTab(goTab: (i) => setState(() => tab = i)), const CareTab(), const ChatPage(), const JatakamTab()];
    return Scaffold(
      extendBody: tab != 2,
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClayBox(
            radius: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              _nav(0, Icons.home_rounded, tr('Home', 'హోమ్')),
              _nav(1, Icons.favorite_rounded, tr('Care', 'సంరక్షణ')),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: _plus,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: K.indigo,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: K.deep.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 6))],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ),
              _nav(2, Icons.forum_rounded, tr('Family', 'కుటుంబం'), badge: Chat.i.unread),
              _nav(3, Icons.auto_awesome, tr('Jatakam', 'జాతకం')),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _nav(int i, IconData icon, String label, {int badge = 0}) {
    final on = tab == i;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => tab = i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListenableBuilder(
              listenable: Chat.i,
              builder: (_, __) => Badge(
                isLabelVisible: i == 2 && Chat.i.unread > 0,
                label: Text('${Chat.i.unread}'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: on ? K.pinkSoft : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: on ? K.indigo : K.muted),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? K.indigo : K.muted)),
          ]),
        ),
      ),
    );
  }
}
