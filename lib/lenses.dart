import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'face_fx.dart';

/// Trending face lenses (Snapchat / Instagram / TikTok style).
/// They are drawn on top of the camera and follow the face, so they work on every phone.
/// Lenses with [warp] ≠ 0 also bend the face on the GPU (only offered when the phone supports it).
class Lens {
  final String id, emoji, name;
  final int warp; // shader mode in shaders/face_warp.frag (0 = none)
  final double eyes, mouth; // magnifier strength (1 = none)
  final String hint; // shown while the lens is on
  const Lens(this.id, this.emoji, this.name, {this.warp = 0, this.eyes = 1, this.mouth = 1, this.hint = ''});
  bool get none => id == 'none';
}

const lenses = [
  Lens('none', '🚫', 'None'),
  Lens('puppy', '🐶', 'Puppy', hint: 'Open your mouth 👅'),
  Lens('flowers', '🌸', 'Flower Crown'),
  Lens('bigeyes', '👀', 'Big Eyes', eyes: 1.75),
  Lens('crying', '😭', 'Crying Baby', mouth: 1.7, hint: 'Make a sad face'),
  Lens('dayyam', '👻', 'Dayyam', hint: 'Look behind you…'),
  Lens('bigmouth', '😮', 'Big Mouth', mouth: 2.0, hint: 'Open your mouth wide!'),
  Lens('rainbow', '🌈', 'Rainbow', hint: 'Open your mouth 🌈'),
  Lens('thug', '😎', 'Thug Life'),
  Lens('hearts', '😍', 'Heart Eyes'),
  Lens('bunny', '🐰', 'Bunny'),
  Lens('butterfly', '🦋', 'Butterflies'),
  Lens('baby', '👶', 'Baby Face', eyes: 1.4),
  Lens('devil', '😈', 'Devil'),
  Lens('crown', '👑', 'Queen'),
  Lens('cat', '🐱', 'Kitty'),
  Lens('clown', '🤡', 'Clown'),
  Lens('alien', '👽', 'Alien', eyes: 1.6),
  Lens('mustache', '🥸', 'Gentleman'),
  Lens('party', '🥳', 'Party'),
  // GPU face-warps (only shown when the phone supports them)
  Lens('long', '🐴', 'Long Face', warp: 6),
  Lens('fat', '🍔', 'Fat Face', warp: 7),
  Lens('tiny', '🤏', 'Tiny Face', warp: 5),
  Lens('chipmunk', '🐹', 'Chipmunk', warp: 11),
  Lens('bignose', '👃', 'Big Nose', warp: 10),
  Lens('kissy', '💋', 'Kissy Lips', warp: 13),
  Lens('swirl', '🌀', 'Swirl', warp: 8),
  Lens('twin', '🪞', 'Mirror Twin', warp: 12),
];

/// A round magnifier: centre and radius in pixels, scale.
class Mag {
  final Offset c;
  final double r, s;
  const Mag(this.c, this.r, this.s);
}

List<Mag> lensMags(Lens l, FaceState? f, Size size) {
  if (f == null) return const [];
  final w = size.width, h = size.height;
  Offset px(Offset o) => Offset(o.dx * w, o.dy * h);
  final le = px(f.lEye), re = px(f.rEye);
  final eyeD = (re - le).distance;
  final out = <Mag>[];
  if (l.eyes > 1) {
    out.add(Mag(le, eyeD * 0.48, l.eyes));
    out.add(Mag(re, eyeD * 0.48, l.eyes));
  }
  if (l.mouth > 1) {
    final mw = math.max(f.mouthW * w, eyeD * 0.7);
    out.add(Mag(px(f.mouth), mw * 0.8, l.mouth));
  }
  return out;
}

/// Magnify parts of a finished photo (same look as the live preview).
Future<ui.Image> magnifyImage(ui.Image src, List<Mag> mags) async {
  if (mags.isEmpty) return src;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawImage(src, Offset.zero, Paint());
  for (final m in mags) {
    final b = Rect.fromCircle(center: m.c, radius: m.r);
    c.saveLayer(b, Paint());
    c.save();
    c.translate(m.c.dx, m.c.dy);
    c.scale(m.s);
    c.translate(-m.c.dx, -m.c.dy);
    c.drawImage(src, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    c.restore();
    c.drawRect(b, Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = ui.Gradient.radial(m.c, m.r, const [Colors.white, Colors.white, Colors.transparent], const [0, 0.62, 1]));
    c.restore();
  }
  return rec.endRecording().toImage(src.width, src.height);
}

/// Live magnifier layer: the same preview again, zoomed around one point with a soft round edge.
Widget magLayer(Widget preview, Mag m, Size size) => Positioned.fill(
      child: IgnorePointer(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (_) => ui.Gradient.radial(m.c, m.r, const [Colors.white, Colors.white, Colors.transparent], const [0, 0.62, 1]),
          child: Transform.scale(scale: m.s, origin: m.c - Offset(size.width / 2, size.height / 2), child: preview),
        ),
      ),
    );

void _emoji(Canvas c, String e, Offset at, double size, [double angle = 0]) {
  final tp = TextPainter(text: TextSpan(text: e, style: TextStyle(fontSize: size)), textDirection: TextDirection.ltr)..layout();
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(angle);
  tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
  c.restore();
}

/// Draws the lens decorations. [t] = seconds (animation), [since] = seconds since the face was found.
void drawLens(Canvas c, Size size, Lens l, FaceState? f, double t, {double since = 9}) {
  if (f == null || l.none) return;
  final w = size.width, h = size.height;
  Offset px(Offset o) => Offset(o.dx * w, o.dy * h);
  final le = px(f.lEye), re = px(f.rEye), mo = px(f.mouth), no = px(f.nose);
  final fw = f.face.width * w, fh = f.face.height * h;
  final eyeMid = (le + re) / 2;
  final eyeD = (re - le).distance;
  final roll = f.roll;
  final up = Offset(math.sin(roll), -math.cos(roll));
  final right = Offset(math.cos(roll), math.sin(roll));
  final forehead = eyeMid + up * (fh * 0.42);
  final open = f.open;

  void inFrame(Offset at, void Function() draw) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(roll);
    draw();
    c.restore();
  }

  void cheeks(Color col) {
    for (final e in [le, re]) {
      final p = e - up * (eyeD * 0.55) + (e == le ? -right : right) * (eyeD * 0.12);
      c.drawOval(Rect.fromCenter(center: p, width: eyeD * 0.5, height: eyeD * 0.3), Paint()
        ..color = col
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, eyeD * 0.08));
    }
  }

  void whiskers(Color col) {
    final p = Paint()
      ..color = col
      ..strokeWidth = math.max(1.5, fw * 0.008)
      ..strokeCap = StrokeCap.round;
    for (final sgn in [-1.0, 1.0]) {
      for (var k = -1; k <= 1; k++) {
        final a = no + right * (sgn * eyeD * 0.25) - up * (eyeD * 0.1 * k * 0.6);
        final b = no + right * (sgn * eyeD * 0.95) - up * (eyeD * 0.18 * k);
        c.drawLine(a, b, p);
      }
    }
  }

  void earPair(double spread, double lift, double ew, double eh, Color outer, Color inner, {double tiltOut = 0.35, bool pointy = false, bool floppy = false}) {
    for (final sgn in [-1.0, 1.0]) {
      final base = forehead + right * (sgn * spread) + up * lift;
      c.save();
      c.translate(base.dx, base.dy);
      c.rotate(roll + sgn * tiltOut + (floppy ? sgn * math.sin(t * 3) * 0.05 : 0));
      if (pointy) {
        final p = Path()
          ..moveTo(-ew / 2, eh * 0.3)
          ..lineTo(0, -eh * 0.7)
          ..lineTo(ew / 2, eh * 0.3)
          ..close();
        c.drawPath(p.shift(const Offset(2, 4)), Paint()..color = Colors.black26);
        c.drawPath(p, Paint()..color = outer);
        final q = Path()
          ..moveTo(-ew * 0.28, eh * 0.2)
          ..lineTo(0, -eh * 0.42)
          ..lineTo(ew * 0.28, eh * 0.2)
          ..close();
        c.drawPath(q, Paint()..color = inner);
      } else {
        final r = Rect.fromCenter(center: Offset(0, -eh * 0.3), width: ew, height: eh);
        c.drawOval(r.shift(const Offset(2, 4)), Paint()..color = Colors.black26);
        c.drawOval(r, Paint()..shader = ui.Gradient.linear(r.topLeft, r.bottomRight, [Color.lerp(outer, Colors.white, 0.2)!, outer]));
        c.drawOval(Rect.fromCenter(center: r.center + Offset(0, eh * 0.06), width: ew * 0.52, height: eh * 0.72), Paint()..color = inner);
      }
      c.restore();
    }
  }

  void blobNose(Color col, double s) {
    final r = Rect.fromCenter(center: no, width: eyeD * 0.55 * s, height: eyeD * 0.38 * s);
    inFrame(no, () {
      final rr = Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height);
      c.drawOval(rr, Paint()..color = col);
      c.drawOval(Rect.fromCenter(center: Offset(-rr.width * 0.18, -rr.height * 0.18), width: rr.width * 0.35, height: rr.height * 0.25), Paint()..color = Colors.white.withValues(alpha: 0.6));
    });
  }

  switch (l.id) {
    case 'puppy':
      earPair(fw * 0.5, -fh * 0.02, fw * 0.36, fh * 0.55, const Color(0xFF8D5A3B), const Color(0xFFD9A07A), tiltOut: 0.55, floppy: true);
      blobNose(const Color(0xFF2B1B14), 1.0);
      cheeks(const Color(0x44FF7FA0));
      if (open > 0.25) {
        final len = eyeD * (0.45 + open * 0.9);
        inFrame(mo, () {
          final wig = math.sin(t * 9) * 0.08;
          c.rotate(wig);
          final r = RRect.fromRectAndCorners(Rect.fromLTWH(-eyeD * 0.24, -eyeD * 0.05, eyeD * 0.48, len), bottomLeft: Radius.circular(eyeD * 0.24), bottomRight: Radius.circular(eyeD * 0.24));
          c.drawRRect(r, Paint()..color = const Color(0xFFFF6F91));
          c.drawLine(Offset(0, eyeD * 0.04), Offset(0, len * 0.7), Paint()
            ..color = const Color(0xFFD94A6E)
            ..strokeWidth = eyeD * 0.03);
        });
      }
      break;
    case 'bunny':
      earPair(fw * 0.2, fh * 0.05, fw * 0.24, fh * 0.85, Colors.white, const Color(0xFFFFB6C9), tiltOut: 0.12, floppy: true);
      inFrame(no, () {
        final p = Path()
          ..moveTo(-eyeD * 0.12, -eyeD * 0.06)
          ..lineTo(eyeD * 0.12, -eyeD * 0.06)
          ..lineTo(0, eyeD * 0.1)
          ..close();
        c.drawPath(p, Paint()..color = const Color(0xFFFF7FA8));
      });
      whiskers(Colors.white70);
      inFrame(mo - up * (eyeD * 0.02), () {
        for (final sx in [-1.0, 1.0]) {
          final r = RRect.fromRectAndRadius(Rect.fromLTWH(sx < 0 ? -eyeD * 0.13 : eyeD * 0.005, -eyeD * 0.06, eyeD * 0.125, eyeD * 0.2), Radius.circular(eyeD * 0.03));
          c.drawRRect(r, Paint()..color = Colors.white);
          c.drawRRect(r, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.black26);
        }
      });
      cheeks(const Color(0x55FF7FA0));
      break;
    case 'cat':
      earPair(fw * 0.32, fh * 0.02, fw * 0.32, fh * 0.42, const Color(0xFFF2994A), const Color(0xFFFFC2D1), tiltOut: 0.3, pointy: true);
      inFrame(no, () {
        final p = Path()
          ..moveTo(-eyeD * 0.11, -eyeD * 0.05)
          ..lineTo(eyeD * 0.11, -eyeD * 0.05)
          ..lineTo(0, eyeD * 0.08)
          ..close();
        c.drawPath(p, Paint()..color = const Color(0xFFFF6F91));
      });
      whiskers(Colors.black87);
      cheeks(const Color(0x44FF7FA0));
      break;
    case 'flowers':
      const fl = ['🌸', '🌼', '🌺', '🌷', '🌸', '🌼', '🌺', '🌷', '🌸'];
      for (var k = 0; k < fl.length; k++) {
        final x = (k - 4) / 4.0; // -1..1
        final p = forehead + right * (x * fw * 0.55) + up * (fh * 0.12 - x * x * fh * 0.14);
        _emoji(c, fl[k], p, fw * (k.isEven ? 0.21 : 0.17), roll + x * 0.6);
      }
      _emoji(c, '🍃', forehead + right * (-fw * 0.66) + up * (-fh * 0.04), fw * 0.15, roll - 0.9);
      _emoji(c, '🍃', forehead + right * (fw * 0.66) + up * (-fh * 0.04), fw * 0.15, roll + 0.9);
      cheeks(const Color(0x55FF7FA0));
      for (var k = 0; k < 5; k++) {
        final a = t * 0.8 + k * 1.3;
        if (math.sin(a * 2) > 0.3) _emoji(c, '✨', forehead + right * (math.cos(a) * fw * 0.7) + up * (math.sin(a) * fh * 0.25 + fh * 0.1), fw * 0.08);
      }
      break;
    case 'butterfly':
      for (var k = 0; k < 4; k++) {
        final a = t * 0.9 + k * math.pi / 2;
        final p = eyeMid + right * (math.cos(a) * fw * 0.75) + up * (fh * 0.45 + math.sin(a) * fh * 0.22);
        c.save();
        c.translate(p.dx, p.dy);
        c.scale(0.55 + 0.45 * math.sin(t * 14 + k).abs(), 1);
        _emoji(c, '🦋', Offset.zero, fw * 0.2, math.sin(a) * 0.3);
        c.restore();
      }
      for (var k = 0; k < 5; k++) {
        final x = (k - 2) / 2.0;
        _emoji(c, k.isEven ? '💜' : '💙', forehead + right * (x * fw * 0.4) + up * (fh * 0.08 - x * x * fh * 0.08), fw * 0.09, roll);
      }
      cheeks(const Color(0x44B388FF));
      break;
    case 'hearts':
      for (final e in [le, re]) {
        _emoji(c, '❤️', e, eyeD * (0.62 + 0.08 * math.sin(t * 8)), roll);
      }
      for (var k = 0; k < 6; k++) {
        final ph = (t * 0.35 + k / 6) % 1.0;
        final side = k.isEven ? -1.0 : 1.0;
        final p = eyeMid + right * (side * fw * (0.6 + 0.1 * math.sin(k + t))) + up * (fh * (-0.2 + ph * 1.0));
        _emoji(c, k % 3 == 0 ? '💕' : '💖', p, fw * (0.1 + 0.04 * (k % 2)), math.sin(t + k) * 0.3);
      }
      cheeks(const Color(0x66FF4F8B));
      break;
    case 'rainbow':
      if (open > 0.25) {
        const cols = [Color(0xFFFF3B30), Color(0xFFFF9500), Color(0xFFFFCC00), Color(0xFF34C759), Color(0xFF007AFF), Color(0xFFAF52DE)];
        final bw = eyeD * (0.08 + 0.06 * open);
        final down = -up;
        for (var i = 0; i < cols.length; i++) {
          final off = right * ((i - 2.5) * bw);
          final path = Path();
          final start = mo + off;
          path.moveTo(start.dx, start.dy);
          for (var s = 1; s <= 12; s++) {
            final q = mo + off + down * (s * h / 12) + right * (math.sin(s * 0.7 - t * 6) * bw * 1.2 * s / 6);
            path.lineTo(q.dx, q.dy);
          }
          c.drawPath(path, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = bw * 1.05
            ..color = cols[i].withValues(alpha: 0.9));
        }
        for (var k = 0; k < 6; k++) {
          final ph = (t * 0.8 + k / 6) % 1.0;
          _emoji(c, '✨', mo + down * (ph * h * 0.6) + right * ((k - 2.5) * bw * 2.5), fw * 0.07);
        }
      }
      for (final e in [le, re]) {
        if (math.sin(t * 3 + e.dx) > 0) _emoji(c, '✨', e + right * (eyeD * 0.25) + up * (eyeD * 0.25), eyeD * 0.25);
      }
      break;
    case 'thug':
      final drop = (since / 1.2).clamp(0.0, 1.0);
      final eased = 1 - math.pow(1 - drop, 3).toDouble();
      final target = eyeMid;
      final at = Offset.lerp(target - up * (-h) , target, eased)!;
      inFrame(at, () {
        final u = eyeD * 0.115; // one pixel block
        final black = Paint()..color = Colors.black;
        final white = Paint()..color = Colors.white;
        // top bar
        c.drawRect(Rect.fromLTWH(-u * 10, -u * 2, u * 20, u), black);
        for (final sx in [-1.0, 1.0]) {
          final x0 = sx < 0 ? -u * 9 : u * 1;
          c.drawRect(Rect.fromLTWH(x0, -u, u * 8, u), black);
          c.drawRect(Rect.fromLTWH(x0 + u, 0, u * 6, u), black);
          c.drawRect(Rect.fromLTWH(x0 + u * 2, u, u * 4, u), black);
          c.drawRect(Rect.fromLTWH(x0 + u, -u, u, u), white);
          c.drawRect(Rect.fromLTWH(x0 + u * 2, 0, u, u), white);
        }
      });
      if (drop >= 1) {
        final tp = TextPainter(
          text: TextSpan(text: 'THUG LIFE', style: TextStyle(fontSize: fw * 0.2, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2, shadows: const [Shadow(color: Colors.black, blurRadius: 0, offset: Offset(3, 3))])),
          textDirection: TextDirection.ltr,
        )..layout();
        final p = mo - up * (fh * 0.42);
        c.save();
        c.translate(p.dx, p.dy);
        c.rotate(roll);
        tp.paint(c, Offset(-tp.width / 2, 0));
        c.restore();
      }
      break;
    case 'crown':
      _emoji(c, '👑', forehead + up * (fh * 0.12), fw * 0.62, roll);
      for (var k = 0; k < 7; k++) {
        final a = k * 0.9 + t * 0.4;
        if (math.sin(t * 4 + k * 2) > 0.2) _emoji(c, '✨', eyeMid + right * (math.cos(a) * fw * 0.75) + up * (math.sin(a) * fh * 0.55 + fh * 0.1), fw * 0.08);
      }
      cheeks(const Color(0x44FF7FA0));
      break;
    case 'devil':
      for (final sgn in [-1.0, 1.0]) {
        final base = forehead + right * (sgn * fw * 0.28);
        c.save();
        c.translate(base.dx, base.dy);
        c.rotate(roll);
        final hw = fw * 0.12, hh = fh * 0.32;
        final p = Path()
          ..moveTo(-hw, 0)
          ..quadraticBezierTo(-hw * 0.4, -hh * 0.6, sgn * hw * 1.6, -hh)
          ..quadraticBezierTo(hw * 0.2 * sgn, -hh * 0.4, hw, 0)
          ..close();
        c.drawPath(p, Paint()..shader = ui.Gradient.linear(Offset(0, -hh), Offset.zero, [const Color(0xFFFF3B30), const Color(0xFF8B0000)]));
        c.restore();
      }
      for (final e in [le, re]) {
        c.drawCircle(e, eyeD * 0.2, Paint()
          ..color = const Color(0xCCFF1A00)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, eyeD * 0.1));
        c.drawCircle(e, eyeD * 0.06, Paint()..color = const Color(0xFFFFE680));
      }
      for (var k = 0; k < 5; k++) {
        final x = (k - 2) / 2.0;
        final flick = 1 + 0.15 * math.sin(t * 12 + k * 2);
        _emoji(c, '🔥', forehead + right * (x * fw * 0.42) + up * (fh * 0.2 - x * x * fh * 0.1), fw * 0.15 * flick, roll);
      }
      break;
    case 'clown':
      blobNose(const Color(0xFFE5202E), 1.15);
      cheeks(const Color(0x88FF3B30));
      const hair = [Color(0xFFFF3B30), Color(0xFFFF9500), Color(0xFFFFCC00), Color(0xFF34C759), Color(0xFF007AFF), Color(0xFFAF52DE)];
      for (final sgn in [-1.0, 1.0]) {
        for (var k = 0; k < 6; k++) {
          final p = eyeMid + right * (sgn * (fw * 0.55 + (k % 2) * fw * 0.1)) + up * (fh * (0.45 - k * 0.12));
          c.drawCircle(p, fw * 0.11, Paint()..color = hair[(k + (sgn > 0 ? 3 : 0)) % hair.length]);
        }
      }
      inFrame(mo, () {
        final r = Rect.fromCenter(center: Offset(0, -eyeD * 0.05), width: eyeD * 1.3, height: eyeD * 0.7);
        c.drawArc(r, 0.15, math.pi - 0.3, false, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = eyeD * 0.1
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xCCE5202E));
      });
      for (final e in [le, re]) {
        inFrame(e, () {
          final p = Path()
            ..moveTo(0, -eyeD * 0.35)
            ..lineTo(eyeD * 0.1, 0)
            ..lineTo(0, eyeD * 0.35)
            ..lineTo(-eyeD * 0.1, 0)
            ..close();
          c.drawPath(p, Paint()..color = const Color(0x882F7DE1));
        });
      }
      break;
    case 'baby':
      cheeks(const Color(0x88FF7FA0));
      _emoji(c, '🎀', forehead + right * (fw * 0.25) + up * (fh * 0.05), fw * 0.3, roll + 0.3);
      inFrame(mo, () {
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: eyeD * 0.95, height: eyeD * 0.5), Paint()..color = const Color(0xFF8EC5FF));
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: eyeD * 0.95, height: eyeD * 0.5), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = eyeD * 0.04
          ..color = const Color(0xFF4B8FE0));
        c.drawCircle(Offset(0, eyeD * 0.02), eyeD * 0.14, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = eyeD * 0.06
          ..color = const Color(0xFFFF8FB8));
        c.drawCircle(Offset(-eyeD * 0.25, -eyeD * 0.08), eyeD * 0.05, Paint()..color = Colors.white70);
      });
      break;
    case 'crying':
      drawFaceOverlay(c, size, 2, f, t);
      for (final sgn in [-1.0, 1.0]) {
        final e = sgn < 0 ? le : re;
        final a = e + up * (eyeD * 0.38) + right * (sgn * eyeD * 0.22);
        final b = e + up * (eyeD * 0.5) - right * (sgn * eyeD * 0.18);
        c.drawLine(a, b, Paint()
          ..color = const Color(0xFF3B2A20)
          ..strokeWidth = eyeD * 0.07
          ..strokeCap = StrokeCap.round);
      }
      break;
    case 'dayyam':
      c.drawRect(Offset.zero & size, Paint()..shader = ui.Gradient.radial(f.face.center.scale(w, h), math.max(w, h) * 0.75, [Colors.transparent, const Color(0xCC000000)], [0.35, 1]));
      drawFaceOverlay(c, size, 9, f, t);
      for (final e in [le, re]) {
        c.drawCircle(e, eyeD * 0.12, Paint()
          ..color = const Color(0xAAFF0000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, eyeD * 0.08));
      }
      break;
    case 'alien':
      c.drawOval(Rect.fromCenter(center: eyeMid - up * (fh * 0.12), width: fw * 1.05, height: fh * 1.15), Paint()
        ..color = const Color(0x5539FF14)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.08));
      drawFaceOverlay(c, size, 4, f, t);
      break;
    case 'mustache':
      inFrame(no + (mo - no) * 0.55, () {
        final m = eyeD;
        final p = Path()
          ..moveTo(0, -m * 0.05)
          ..cubicTo(-m * 0.3, -m * 0.25, -m * 0.65, -m * 0.1, -m * 0.75, -m * 0.3)
          ..cubicTo(-m * 0.7, m * 0.05, -m * 0.35, m * 0.15, 0, m * 0.05)
          ..cubicTo(m * 0.35, m * 0.15, m * 0.7, m * 0.05, m * 0.75, -m * 0.3)
          ..cubicTo(m * 0.65, -m * 0.1, m * 0.3, -m * 0.25, 0, -m * 0.05)
          ..close();
        c.drawPath(p, Paint()..color = const Color(0xFF2B1B14));
      });
      _emoji(c, '🎩', forehead + up * (fh * 0.2), fw * 0.6, roll);
      c.drawCircle(re, eyeD * 0.28, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = eyeD * 0.05
        ..color = const Color(0xFFD4AF37));
      break;
    case 'party':
      inFrame(forehead + up * (fh * 0.05) + right * (fw * 0.12), () {
        c.rotate(0.25);
        final hw = fw * 0.22, hh = fh * 0.55;
        final p = Path()
          ..moveTo(-hw, 0)
          ..lineTo(0, -hh)
          ..lineTo(hw, 0)
          ..close();
        c.drawPath(p, Paint()..color = const Color(0xFF7C4DFF));
        c.save();
        c.clipPath(p);
        for (var k = 0; k < 5; k++) {
          c.drawRect(Rect.fromLTWH(-hw, -hh + k * hh / 4.5, hw * 2, hh / 10), Paint()..color = const Color(0xFFFFD54F));
        }
        c.restore();
        c.drawCircle(Offset(0, -hh), hw * 0.28, Paint()..color = const Color(0xFFFF4081));
      });
      final rnd = math.Random(7);
      const conf = [Color(0xFFFF3B30), Color(0xFFFFCC00), Color(0xFF34C759), Color(0xFF007AFF), Color(0xFFAF52DE), Color(0xFFFF4081)];
      for (var k = 0; k < 40; k++) {
        final x = rnd.nextDouble() * w;
        final sp = 0.15 + rnd.nextDouble() * 0.25;
        final y = ((rnd.nextDouble() + t * sp) % 1.0) * h;
        c.save();
        c.translate(x + math.sin(t * 2 + k) * 10, y);
        c.rotate(t * 3 + k);
        c.drawRect(Rect.fromCenter(center: Offset.zero, width: w * 0.018, height: w * 0.008), Paint()..color = conf[k % conf.length]);
        c.restore();
      }
      break;
  }
}

class LensPainter extends CustomPainter {
  final Lens lens;
  final FaceState? f;
  final double t, since;
  LensPainter(this.lens, this.f, this.t, this.since);
  @override
  void paint(Canvas c, Size s) => drawLens(c, s, lens, f, t, since: since);
  @override
  bool shouldRepaint(LensPainter o) => true;
}
