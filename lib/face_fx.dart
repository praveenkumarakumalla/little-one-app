import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Snapchat-style face changers. The warping is done on the GPU by shaders/face_warp.frag.
class FaceFx {
  final int mode;
  final String emoji, name;
  const FaceFx(this.mode, this.emoji, this.name);
}

const faceFx = [
  FaceFx(0, '🚫', 'None'),
  FaceFx(1, '😮', 'Big Mouth'),
  FaceFx(2, '😭', 'Crying Baby'),
  FaceFx(9, '👻', 'Dayyam'),
  FaceFx(3, '👀', 'Bug Eyes'),
  FaceFx(4, '👽', 'Alien'),
  FaceFx(5, '🤏', 'Tiny Face'),
  FaceFx(6, '🐴', 'Long Face'),
  FaceFx(7, '🍔', 'Fat Face'),
  FaceFx(10, '👃', 'Big Nose'),
  FaceFx(11, '🐹', 'Chipmunk'),
  FaceFx(13, '💋', 'Kissy Lips'),
  FaceFx(8, '🌀', 'Swirl'),
  FaceFx(12, '🪞', 'Mirror Twin'),
];

/// Where the face is, as fractions (0..1) of the picture.
class FaceState {
  final Rect face; // x, y, w, h fractions
  final Offset lEye, rEye, mouth, nose;
  final double mouthW;
  final double open; // 0 closed … 1 wide open
  final double roll; // head tilt in radians (screen space)
  const FaceState(this.face, this.lEye, this.rEye, this.mouth, this.nose, this.mouthW, {this.open = 0, this.roll = 0});

  static FaceState? fromPoints({required Rect box, Offset? lEye, Offset? rEye, Offset? mouthL, Offset? mouthR, Offset? mouthB, Offset? nose, double? open, required Size size}) {
    if (size.width <= 0 || size.height <= 0) return null;
    Offset n(Offset o) => Offset(o.dx / size.width, o.dy / size.height);
    final b = Rect.fromLTRB(box.left / size.width, box.top / size.height, box.right / size.width, box.bottom / size.height);
    // fall back to typical face proportions when a landmark is missing
    final le = lEye != null ? n(lEye) : Offset(b.left + b.width * 0.32, b.top + b.height * 0.4);
    final re = rEye != null ? n(rEye) : Offset(b.left + b.width * 0.68, b.top + b.height * 0.4);
    Offset mouth;
    double mw;
    if (mouthL != null && mouthR != null) {
      final ml = n(mouthL), mr = n(mouthR);
      mouth = Offset((ml.dx + mr.dx) / 2, (ml.dy + mr.dy) / 2);
      if (mouthB != null) mouth = Offset(mouth.dx, (mouth.dy * 2 + n(mouthB).dy) / 3);
      mw = (mr.dx - ml.dx).abs();
    } else {
      mouth = Offset(b.center.dx, b.top + b.height * 0.75);
      mw = b.width * 0.4;
    }
    final no = nose != null ? n(nose) : Offset(b.center.dx, b.top + b.height * 0.6);
    // keep left/right in screen order
    final l = le.dx <= re.dx ? le : re, r = le.dx <= re.dx ? re : le;
    final roll = math.atan2((r.dy - l.dy) * size.height, (r.dx - l.dx) * size.width);
    var op = open;
    if (op == null && mouthL != null && mouthR != null && mouthB != null) {
      final d = (mouthB.dy - (mouthL.dy + mouthR.dy) / 2).abs() / box.height;
      op = ((d - 0.07) / 0.09).clamp(0.0, 1.0);
    }
    return FaceState(b, l, r, mouth, no, mw, open: op ?? 0, roll: roll);
  }

  FaceState lerp(FaceState? o, double t) {
    if (o == null) return this;
    Offset lo(Offset a, Offset b) => Offset.lerp(b, a, t)!;
    return FaceState(Rect.lerp(o.face, face, t)!, lo(lEye, o.lEye), lo(rEye, o.rEye), lo(mouth, o.mouth), lo(nose, o.nose), o.mouthW + (mouthW - o.mouthW) * t, open: o.open + (open - o.open) * t, roll: o.roll + (roll - o.roll) * t);
  }

  FaceState mirrored() => FaceState(Rect.fromLTRB(1 - face.right, face.top, 1 - face.left, face.bottom), Offset(1 - rEye.dx, rEye.dy), Offset(1 - lEye.dx, lEye.dy), Offset(1 - mouth.dx, mouth.dy), Offset(1 - nose.dx, nose.dy), mouthW, open: open, roll: -roll);
}

class FaceShader {
  static ui.FragmentProgram? _p;
  static bool failed = false;
  static Future<ui.FragmentProgram?> program() async {
    if (_p != null || failed) return _p;
    try {
      _p = await ui.FragmentProgram.fromAsset('shaders/face_warp.frag');
    } catch (_) {
      failed = true;
    }
    return _p;
  }

  /// Fill uniforms 2.. (0,1 = size; set by the engine for live preview).
  static void setUniforms(ui.FragmentShader s, int mode, double time, FaceState? f) {
    var i = 2;
    void set(double v) => s.setFloat(i++, v);
    set(mode.toDouble());
    set(time);
    if (f == null) {
      for (var k = 0; k < 16; k++) {
        set(0);
      }
      return;
    }
    set(f.face.left);
    set(f.face.top);
    set(f.face.width);
    set(f.face.height);
    set(f.lEye.dx);
    set(f.lEye.dy);
    set(f.rEye.dx);
    set(f.rEye.dy);
    set(f.mouth.dx);
    set(f.mouth.dy);
    set(f.mouthW);
    set(0);
    set(f.nose.dx);
    set(f.nose.dy);
    set(0);
    set(0);
  }

  /// Warp a finished photo the same way as the live preview.
  static Future<ui.Image> warp(ui.Image src, int mode, FaceState f) async {
    final p = await program();
    if (p == null || mode == 0) return src;
    final s = p.fragmentShader();
    s.setFloat(0, src.width.toDouble());
    s.setFloat(1, src.height.toDouble());
    setUniforms(s, mode, 0.6, f);
    s.setImageSampler(0, src);
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()), Paint()..shader = s);
    return rec.endRecording().toImage(src.width, src.height);
  }
}

/// Extra drawings on top: tears, the dayyam ghost, alien antennae, big-mouth teeth glint.
void drawFaceOverlay(Canvas c, Size size, int mode, FaceState? f, double t) {
  if (f == null || mode == 0) return;
  final w = size.width, h = size.height;
  Offset px(Offset o) => Offset(o.dx * w, o.dy * h);
  final fw = f.face.width * w, fh = f.face.height * h;
  if (mode == 2) {
    // streams of tears from both eyes
    final p = Paint()..color = const Color(0xCC4FC3F7);
    final edge = Paint()
      ..color = const Color(0xFF0288D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, fw * 0.008);
    for (final eye in [f.lEye, f.rEye]) {
      final e = px(eye);
      for (var k = 0; k < 5; k++) {
        final ph = (t * 0.9 + k / 5) % 1.0;
        final y = e.dy + fw * 0.06 + ph * fh * 0.9;
        final x = e.dx + math.sin((ph + k) * 6) * fw * 0.02;
        final r = fw * (0.035 + 0.01 * (k % 2));
        final drop = Path()
          ..moveTo(x, y - r * 1.8)
          ..quadraticBezierTo(x + r, y - r * 0.2, x, y + r)
          ..quadraticBezierTo(x - r, y - r * 0.2, x, y - r * 1.8)
          ..close();
        c.drawPath(drop, p..color = Color.fromRGBO(79, 195, 247, 0.85 * (1 - ph * 0.6)));
        c.drawPath(drop, edge);
      }
    }
  } else if (mode == 9) {
    // the dayyam: a ghost rising behind the shoulder, flickering
    final appear = (math.sin(t * 1.3) + 1) / 2; // slowly comes and goes
    final side = (t ~/ 6) % 2 == 0 ? 1.0 : -1.0;
    final gx = f.face.center.dx * w + side * fw * 1.1;
    final gy = f.face.top * h + fh * 0.2 - appear * fh * 0.25 + math.sin(t * 3) * fh * 0.03;
    final gw = fw * 1.1, gh = fh * 1.5;
    final flick = (math.sin(t * 37) > 0.85) ? 0.35 : 1.0;
    final body = Path()
      ..moveTo(gx - gw / 2, gy + gh * 0.45)
      ..quadraticBezierTo(gx - gw / 2, gy - gh * 0.5, gx, gy - gh * 0.5)
      ..quadraticBezierTo(gx + gw / 2, gy - gh * 0.5, gx + gw / 2, gy + gh * 0.45);
    for (var k = 0; k < 4; k++) {
      final x0 = gx + gw / 2 - gw * (k + 0.5) / 4;
      body.quadraticBezierTo(x0 + gw / 16, gy + gh * 0.6 + math.sin(t * 4 + k) * gh * 0.03, x0 - gw / 8 + gw / 16, gy + gh * 0.45);
    }
    body.close();
    final alpha = (0.25 + 0.55 * appear) * flick;
    c.drawPath(body, Paint()
      ..color = Color.fromRGBO(235, 240, 255, alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.03));
    final eyeP = Paint()..color = Color.fromRGBO(10, 0, 0, alpha + 0.2);
    c.drawOval(Rect.fromCenter(center: Offset(gx - gw * 0.18, gy - gh * 0.18), width: gw * 0.16, height: gh * 0.14), eyeP);
    c.drawOval(Rect.fromCenter(center: Offset(gx + gw * 0.18, gy - gh * 0.18), width: gw * 0.16, height: gh * 0.14), eyeP);
    c.drawOval(Rect.fromCenter(center: Offset(gx, gy + gh * 0.08), width: gw * 0.2, height: gh * 0.2 * (0.6 + 0.4 * appear)), eyeP);
    final glow = Paint()
      ..color = const Color(0xFFFF1E00)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.02);
    c.drawCircle(Offset(gx - gw * 0.18, gy - gh * 0.17), gw * 0.025, glow);
    c.drawCircle(Offset(gx + gw * 0.18, gy - gh * 0.17), gw * 0.025, glow);
  } else if (mode == 4) {
    // alien antennae
    final top = f.face.top * h - fh * 0.15;
    final paint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..strokeWidth = fw * 0.025
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in [-1.0, 1.0]) {
      final base = Offset(f.face.center.dx * w + s * fw * 0.18, top + fh * 0.12);
      final tip = Offset(base.dx + s * fw * 0.2 + math.sin(t * 3 + s) * fw * 0.03, top - fh * 0.32);
      c.drawLine(base, tip, paint);
      c.drawCircle(tip, fw * 0.06, Paint()..color = const Color(0xFFB2FF59));
    }
  }
}

class FaceOverlayPainter extends CustomPainter {
  final int mode;
  final FaceState? f;
  final double t;
  FaceOverlayPainter(this.mode, this.f, this.t);
  @override
  void paint(Canvas c, Size s) => drawFaceOverlay(c, s, mode, f, t);
  @override
  bool shouldRepaint(FaceOverlayPainter o) => true;
}
