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
  const Clay({super.key, required this.color, this.color2, this.radius = 26, this.depth = 6, this.padding = const EdgeInsets.all(16), required this.child, this.pressed = false, this.height, this.width});

  static Color shade(Color c, double d) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + d).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c2 = color2 ?? color;
    final top = shade(color, dark ? 0.05 : 0.06);
    final side = shade(Color.lerp(color, c2, 0.5)!, dark ? -0.09 : -0.13);
    final shadow = shade(color, dark ? -0.3 : -0.32);
    final r = BorderRadius.circular(radius);
    final press = pressed ? depth * 0.8 : 0.0;
    return SizedBox(
      width: width,
      child: Stack(children: [
        // the thick base under the key + its soft shadow
        Positioned.fill(
          top: depth,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            decoration: BoxDecoration(
              color: side,
              borderRadius: r,
              boxShadow: [
                BoxShadow(color: shadow.withValues(alpha: dark ? 0.55 : 0.42), blurRadius: pressed ? 6 : 18, offset: Offset(0, pressed ? 2 : 9)),
                if (!dark) BoxShadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 10, offset: const Offset(-3, -2)),
              ],
            ),
          ),
        ),
        // the glossy top face
        AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(top: press, bottom: depth - press),
          height: height,
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, color, c2]),
            border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.08 : 0.65), width: 1.4),
          ),
          child: ClipRRect(
            borderRadius: r,
            child: Stack(children: [
              // shine on the upper half
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: (height ?? 120) * 0.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: dark ? 0.07 : 0.38), Colors.white.withValues(alpha: 0)],
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

/// A [Clay] key that sinks when pressed and pops back up, with a little buzz.
class ClayButton extends StatefulWidget {
  final Color color;
  final Color? color2;
  final double radius, depth;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final VoidCallback? onTap;
  final double? height, width;
  const ClayButton({super.key, required this.color, this.color2, this.radius = 24, this.depth = 6, this.padding = const EdgeInsets.all(14), required this.child, this.onTap, this.height, this.width});
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
        color2: const Color(0xFFF3EEF2),
        radius: 12,
        depth: 3,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        height: 24,
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF3A2A35))),
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
    final base = color ?? (dark ? const Color(0xFF2A1E31) : Colors.white);
    final c2 = color == null ? (dark ? const Color(0xFF241A2A) : const Color(0xFFFFF0F6)) : Clay.shade(base, dark ? -0.03 : -0.04);
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        type: MaterialType.transparency,
        child: Clay(color: base, color2: c2, radius: 24, depth: 6, padding: EdgeInsets.zero, child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
