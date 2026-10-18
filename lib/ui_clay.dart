import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';

/// Clay theme (soft pink + deep indigo + off-white, puffy rounded cards).
class K {
  static const indigo = Color(0xFF4B3BA8);
  static const deep = Color(0xFF34277F);
  static const violet = Color(0xFF7D6FD0);
  static const pink = Color(0xFFF6C9D6);
  static const pinkSoft = Color(0xFFFBE3EA);
  static const card = Color(0xFFF4F2F8);
  static const bg = Color(0xFFE9E6F2);
  static const ink = Color(0xFF2B2350);
  static const muted = Color(0xFF7A7398);
  static const good = Color(0xFF2EAE7A);
  static const warn = Color(0xFFE0861F);
  static const bad = Color(0xFFD9434E);
  static const font = 'Poppins';

  static bool get te => Store.i.settings['tLang'] == 'te';
}

/// English or Telugu, by the language chosen in the app.
String tr(String en, String te) => K.te ? te : en;

ThemeData clayTheme() {
  final cs = ColorScheme.fromSeed(seedColor: K.indigo, brightness: Brightness.light).copyWith(primary: K.indigo, secondary: K.pink, surface: K.card, onSurface: K.ink);
  final base = ThemeData(useMaterial3: true, colorScheme: cs, fontFamily: K.font, scaffoldBackgroundColor: K.bg);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: K.ink, displayColor: K.ink),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, elevation: 0, foregroundColor: K.ink, titleTextStyle: TextStyle(fontFamily: K.font, fontSize: 20, fontWeight: FontWeight.w700, color: K.ink)),
    cardTheme: CardThemeData(color: K.card, elevation: 0, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), margin: const EdgeInsets.symmetric(vertical: 6)),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: K.indigo, foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15), textStyle: const TextStyle(fontFamily: K.font, fontWeight: FontWeight.w600, fontSize: 15))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: K.indigo, shape: const StadiumBorder(), side: const BorderSide(color: K.indigo, width: 1.4), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
    chipTheme: ChipThemeData(backgroundColor: K.pinkSoft, selectedColor: K.indigo, labelStyle: const TextStyle(fontFamily: K.font, color: K.ink), shape: const StadiumBorder(), side: BorderSide.none),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: K.deep, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: K.card, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32)))),
    dialogTheme: DialogThemeData(backgroundColor: K.card, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.transparent),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()}),
  );
}

Color _shade(Color c, double d) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + d).clamp(0.0, 1.0)).toColor();
}

/// A puffy clay card: soft top highlight, coloured shadow underneath, squishes when pressed.
class ClayBox extends StatefulWidget {
  final Widget child;
  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double? width, height;
  const ClayBox({super.key, required this.child, this.color = K.card, this.radius = 28, this.padding = const EdgeInsets.all(18), this.onTap, this.width, this.height});
  @override
  State<ClayBox> createState() => _ClayBoxState();
}

class _ClayBoxState extends State<ClayBox> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final dark = c.computeLuminance() < 0.3;
    final box = AnimatedScale(
      scale: down ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      child: Container(
        width: widget.width,
        height: widget.height,
        padding: widget.padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_shade(c, dark ? 0.06 : 0.03), c, _shade(c, dark ? -0.05 : -0.035)]),
          border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.12 : 0.9), width: 1.6),
          boxShadow: [
            BoxShadow(color: _shade(c, dark ? -0.18 : -0.22).withValues(alpha: dark ? 0.55 : 0.45), blurRadius: down ? 8 : 22, offset: Offset(0, down ? 4 : 12)),
            BoxShadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 14, offset: const Offset(-5, -5)),
          ],
        ),
        child: widget.child,
      ),
    );
    if (widget.onTap == null) return box;
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapCancel: () => setState(() => down = false),
      onTapUp: (_) => setState(() => down = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap!();
      },
      child: box,
    );
  }
}

/// Round clay button (like the social icons in the reference design).
class ClayCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color, iconColor;
  final bool dot;
  const ClayCircle({super.key, required this.icon, required this.label, required this.onTap, this.color = K.card, this.iconColor = K.indigo, this.dot = false});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [
        ClayBox(onTap: onTap, color: color, radius: 40, padding: const EdgeInsets.all(18), child: Icon(icon, color: iconColor, size: 26)),
        if (dot) Positioned(right: 4, top: 4, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: K.good, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
      ]),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: K.ink)),
    ]);
  }
}

/// Progress ring like "75%" in the reference.
class Ring extends StatelessWidget {
  final double value; // 0..1
  final String text;
  final double size;
  final Color color, track;
  const Ring({super.key, required this.value, required this.text, this.size = 92, this.color = Colors.white, this.track = const Color(0x40FFFFFF)});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => CustomPaint(
          painter: _RingPainter(v, color, track),
          child: Center(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: size * 0.2))),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color c, t;
  _RingPainter(this.v, this.c, this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(6, 6, s.width - 12, s.height - 12);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = t);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, p..color = c);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v;
}

/// Section title row.
class SectionTitle extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// Pill tag like "Health / Work / Education" in the reference.
class Pill extends StatelessWidget {
  final String text;
  final bool on;
  final VoidCallback? onTap;
  const Pill(this.text, {super.key, this.on = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: on ? K.indigo : K.pinkSoft,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: (on ? K.deep : const Color(0xFFE2B5C4)).withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Text(text, style: TextStyle(color: on ? Colors.white : K.ink, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

/// Page with the clay background and a big title.
class ClayPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final bool back;
  const ClayPage({super.key, required this.title, required this.children, this.actions, this.back = true});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions, automaticallyImplyLeading: back),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 120), children: children),
    );
  }
}
