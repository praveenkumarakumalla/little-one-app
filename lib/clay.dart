import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Soft "clay 3D" surfaces: a glossy rounded top face sitting on a thicker, darker base,
/// with a soft shadow — like a squishy rubber key. Pressing pushes the face down into the base.
class Clay extends StatelessWidget {
  final Color color;
  final Color? color2;
  final double radius, depth;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final bool pressed;
  final double? height, width;
  const Clay({super.key, required this.color, this.color2, this.radius = 28, this.depth = 8, this.padding = const EdgeInsets.all(16), required this.child, this.pressed = false, this.height, this.width});

  static Color shade(Color c, double d) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + d).clamp(0.0, 1.0)).toColor();
  }

  static Color sat(Color c, double d) {
    final h = HSLColor.fromColor(c);
    return h.withSaturation((h.saturation + d).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c2 = color2 ?? color;
    final hi = shade(color, dark ? 0.06 : 0.09);
    final side = sat(shade(Color.lerp(color, c2, 0.5)!, dark ? -0.10 : -0.15), 0.08);
    final shadow = sat(shade(color, dark ? -0.32 : -0.28), 0.1);
    final r = BorderRadius.circular(radius);
    final press = pressed ? depth * 0.8 : 0.0;
    return SizedBox(
      width: width,
      child: Stack(children: [
        // thick candy base + soft coloured shadow
        Positioned.fill(
          top: depth,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: side,
              borderRadius: r,
              boxShadow: [
                BoxShadow(color: shadow.withValues(alpha: dark ? 0.6 : 0.38), blurRadius: pressed ? 8 : 24, spreadRadius: pressed ? -2 : 0, offset: Offset(0, pressed ? 3 : 12)),
                if (!dark) BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 12, offset: const Offset(-4, -3)),
              ],
            ),
          ),
        ),
        // the puffy glossy face
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutBack,
          margin: EdgeInsets.only(top: press, bottom: depth - press),
          height: height,
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: RadialGradient(center: const Alignment(-0.7, -0.8), radius: 1.5, colors: [hi, color, c2], stops: const [0, 0.45, 1]),
            border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.1 : 0.85), width: 2),
          ),
          child: ClipRRect(
            borderRadius: r,
            child: Stack(children: [
              // soft inner shade at the bottom (makes it look rounded/puffy)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: dark ? 0.12 : 0.05)], stops: const [0.55, 1]),
                  ),
                ),
              ),
              // candy shine blob (top-left)
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(-0.55, -0.92),
                  child: FractionallySizedBox(
                    widthFactor: 0.55,
                    heightFactor: 0.3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: dark ? 0.12 : 0.65), Colors.white.withValues(alpha: 0)]),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Round white candy bubble for icons/emojis.
class ClayBubble extends StatelessWidget {
  final String emoji;
  final double size;
  const ClayBubble(this.emoji, {super.key, this.size = 46});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Clay(
      color: dark ? const Color(0xFF3A2D42) : Colors.white,
      color2: dark ? const Color(0xFF2E2335) : const Color(0xFFECE9F5),
      radius: size / 2,
      depth: 3,
      padding: EdgeInsets.zero,
      width: size,
      height: size,
      child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.52))),
    );
  }
}

/// A [Clay] key that sinks when pressed and pops back up, with a little buzz.
class ClayButton extends StatefulWidget {
  final Color color;
  final Color? color2;
  final double radius, depth;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final VoidCallback? onTap;
  final double? height, width;
  const ClayButton({super.key, required this.color, this.color2, this.radius = 26, this.depth = 8, this.padding = const EdgeInsets.all(14), required this.child, this.onTap, this.height, this.width});
  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool down = false;
  void _set(bool v) {
    if (down != v) setState(() => down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) {
                HapticFeedback.selectionClick();
                _set(true);
              },
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: Clay(color: widget.color, color2: widget.color2, radius: widget.radius, depth: widget.depth, padding: widget.padding, pressed: down, height: widget.height, width: widget.width, child: widget.child),
      );
}

/// Small clay pill (for badges like "＋").
class ClayPill extends StatelessWidget {
  final String text;
  const ClayPill(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Clay(
        color: Colors.white,
        color2: const Color(0xFFECE9F5),
        radius: 12,
        depth: 3,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        height: 24,
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF34277F))),
      );
}

/// Drop-in replacement for [Card] with the clay 3D look.
class ClayCard extends StatelessWidget {
  final Color? color;
  final EdgeInsetsGeometry? margin;
  final Widget? child;
  final Clip? clipBehavior;
  final double? elevation;
  final ShapeBorder? shape;
  const ClayCard({super.key, this.color, this.margin, this.child, this.clipBehavior, this.elevation, this.shape});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? (dark ? const Color(0xFF2A1E31) : const Color(0xFFF7F5FB));
    final c2 = color == null ? (dark ? const Color(0xFF241A2A) : const Color(0xFFECE9F5)) : Clay.shade(base, dark ? -0.03 : -0.04);
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        type: MaterialType.transparency,
        child: Clay(color: base, color2: c2, radius: 26, depth: 7, padding: EdgeInsets.zero, child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
