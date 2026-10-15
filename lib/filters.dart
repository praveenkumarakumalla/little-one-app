import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'face_fx.dart';
import 'store.dart';

// ───────────────────────── colour matrices ─────────────────────────
typedef M = List<double>;
const M ident = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];

M _mul(M a, M b) {
  // (a ∘ b): apply b first, then a. Both are 4x5 colour matrices.
  final r = List<double>.filled(20, 0);
  for (var i = 0; i < 4; i++) {
    for (var j = 0; j < 5; j++) {
      var s = j == 4 ? a[i * 5 + 4] : 0.0;
      for (var k = 0; k < 4; k++) {
        s += a[i * 5 + k] * b[k * 5 + j];
      }
      r[i * 5 + j] = s;
    }
  }
  return r;
}

M chain(List<M> ms) => ms.fold(ident, (acc, m) => _mul(m, acc));

M sat(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
  return [sr + s, sg, sb, 0, 0, sr, sg + s, sb, 0, 0, sr, sg, sb + s, 0, 0, 0, 0, 0, 1, 0];
}

M contrast(double c, [double bright = 0]) {
  final o = 128 * (1 - c) + bright;
  return [c, 0, 0, 0, o, 0, c, 0, 0, o, 0, 0, c, 0, o, 0, 0, 0, 1, 0];
}

M rgb(double r, double g, double b, [double ro = 0, double go = 0, double bo = 0]) => [r, 0, 0, 0, ro, 0, g, 0, 0, go, 0, 0, b, 0, bo, 0, 0, 0, 1, 0];

const M sepiaM = [0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, 0.272, 0.534, 0.131, 0, 0, 0, 0, 0, 1, 0];

// ───────────────────────── filters ─────────────────────────
class PhotoFilter {
  final String id, name, emoji, group;
  final M m;
  final bool grain, vignette, scan, rec, polaroid, fire, softGlow;
  final String? stamp; // 'film' (orange '98 date) or 'vhs'
  final String? autoSticker;
  const PhotoFilter(this.id, this.name, this.emoji, this.group, this.m,
      {this.grain = false, this.vignette = false, this.scan = false, this.rec = false, this.polaroid = false, this.fire = false, this.softGlow = false, this.stamp, this.autoSticker});
}

final List<PhotoFilter> filters = [
  const PhotoFilter('none', 'Normal', '⚪', 'Basic', ident),
  // 90's
  PhotoFilter('kodak', "Kodak '98", '📼', "90's", chain([sat(0.82), contrast(0.9, 10), rgb(1.08, 1.02, 0.88, 14, 6, 0)]), grain: true, vignette: true, stamp: 'film'),
  PhotoFilter('polaroid', 'Polaroid', '🖼️', "90's", chain([sat(0.78), contrast(0.86, 14), rgb(1.02, 1.0, 1.06, 8, 6, 16)]), grain: true, polaroid: true),
  PhotoFilter('vhs', 'VHS Camcorder', '📹', "90's", chain([sat(0.72), contrast(1.1, -4), rgb(0.98, 1.02, 1.1, 0, 4, 10)]), scan: true, rec: true, stamp: 'vhs', grain: true),
  PhotoFilter('fuji', 'Fuji Film', '🎞️', "90's", chain([sat(1.04), contrast(1.08), rgb(0.96, 1.05, 1.02, 0, 4, 6)]), grain: true, vignette: true, stamp: 'film'),
  PhotoFilter('bw', 'Classic B&W', '⚫', "90's", chain([sat(0), contrast(1.18)]), grain: true, vignette: true),
  PhotoFilter('sepia', 'Old Sepia', '🟤', "90's", chain([sepiaM, contrast(0.95, 6)]), grain: true, vignette: true),
  // modern
  PhotoFilter('vivid', 'Vivid', '🌈', 'Modern', chain([sat(1.35), contrast(1.1)])),
  PhotoFilter('pink', 'Baby Pink', '🌸', 'Modern', chain([sat(0.95), contrast(0.9, 8), rgb(1.05, 1.0, 1.03, 16, 6, 14)]), softGlow: true),
  PhotoFilter('golden', 'Golden Hour', '🌅', 'Modern', chain([sat(1.1), rgb(1.1, 1.03, 0.84, 18, 8, 0)]), vignette: true),
  PhotoFilter('cool', 'Cool Breeze', '🧊', 'Modern', chain([rgb(0.92, 1.0, 1.1, 0, 4, 16), contrast(1.04)])),
  PhotoFilter('dreamy', 'Dreamy', '☁️', 'Modern', chain([sat(0.88), contrast(0.8, 20), rgb(1.02, 1.0, 1.04, 6, 4, 10)]), softGlow: true),
  PhotoFilter('clarendon', 'Pop', '✨', 'Modern', chain([sat(1.2), contrast(1.2), rgb(0.98, 1.0, 1.06, 0, 0, 6)])),
  // fun
  PhotoFilter('devil', 'Devil', '😈', 'Fun', chain([sat(0.55), contrast(1.25), rgb(1.35, 0.62, 0.58, 22, 0, 0)]), vignette: true, fire: true, autoSticker: 'horns'),
  PhotoFilter('ghost', 'Ghost', '👻', 'Fun', chain([sat(0.15), contrast(1.35), rgb(0.85, 1.12, 1.05, 0, 14, 10)]), vignette: true, scan: true),
  PhotoFilter('angel', 'Angel', '😇', 'Fun', chain([contrast(0.85, 22), rgb(1.03, 1.02, 0.98, 8, 8, 4)]), softGlow: true, autoSticker: 'halo'),
];

PhotoFilter filterById(String? id) => filters.firstWhere((f) => f.id == id, orElse: () => filters.first);

// ───────────────────────── face stickers ─────────────────────────
class Sticker {
  final String id, label, emoji;
  final String kind; // face | top | eyes | nose | horns | halo
  final double scale, dy;
  const Sticker(this.id, this.label, this.emoji, this.kind, {this.scale = 1, this.dy = 0});
}

const stickers = [
  Sticker('none', 'None', '🚫', 'none'),
  Sticker('horns', 'Devil horns', '😈', 'horns'),
  Sticker('halo', 'Angel halo', '😇', 'halo'),
  Sticker('crown', 'Princess', '👑', 'top', scale: 0.75, dy: -0.38),
  Sticker('hat', 'Party hat', '🥳', 'top', scale: 0.7, dy: -0.45),
  Sticker('glasses', 'Cool shades', '🕶️', 'eyes', scale: 1.0),
  Sticker('clown', 'Clown face', '🤡', 'face', scale: 1.45),
  Sticker('monkey', 'Monkey face', '🐵', 'face', scale: 1.5),
  Sticker('alien', 'Alien face', '👽', 'face', scale: 1.4),
  Sticker('pig', 'Piggy face', '🐷', 'face', scale: 1.45),
  Sticker('cat', 'Kitty face', '🐱', 'face', scale: 1.45),
  Sticker('disguise', 'Disguise', '🥸', 'face', scale: 1.4),
  Sticker('nose', 'Clown nose', '🔴', 'nose', scale: 0.25),
  Sticker('love', 'Heart eyes', '😍', 'face', scale: 1.4),
];

Sticker stickerById(String? id) => stickers.firstWhere((s) => s.id == id, orElse: () => stickers.first);

/// A face in canvas coordinates.
class FaceBox {
  final Rect box;
  final Offset? lEye, rEye, nose, mouthL, mouthR, mouthB;
  const FaceBox(this.box, {this.lEye, this.rEye, this.nose, this.mouthL, this.mouthR, this.mouthB});
  FaceBox map(Offset Function(Offset) f) {
    final a = f(box.topLeft), b = f(box.bottomRight);
    Offset? m(Offset? o) => o == null ? null : f(o);
    return FaceBox(Rect.fromPoints(a, b), lEye: m(lEye), rEye: m(rEye), nose: m(nose), mouthL: m(mouthL), mouthR: m(mouthR), mouthB: m(mouthB));
  }

  FaceState? state(Size size) => FaceState.fromPoints(box: box, lEye: lEye, rEye: rEye, mouthL: mouthL, mouthR: mouthR, mouthB: mouthB, nose: nose, size: size);
}

void _emoji(Canvas c, String e, Offset center, double size) {
  final tp = TextPainter(text: TextSpan(text: e, style: TextStyle(fontSize: size)), textDirection: TextDirection.ltr)..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

void drawSticker(Canvas c, FaceBox f, Sticker s) {
  final b = f.box, w = b.width, h = b.height;
  switch (s.kind) {
    case 'face':
      _emoji(c, s.emoji, b.center, w * s.scale);
      break;
    case 'top':
      _emoji(c, s.emoji, Offset(b.center.dx, b.top + h * s.dy), w * s.scale);
      break;
    case 'eyes':
      final mid = (f.lEye != null && f.rEye != null) ? Offset((f.lEye!.dx + f.rEye!.dx) / 2, (f.lEye!.dy + f.rEye!.dy) / 2) : Offset(b.center.dx, b.top + h * 0.4);
      _emoji(c, s.emoji, mid, w * s.scale);
      break;
    case 'nose':
      final n = f.nose ?? Offset(b.center.dx, b.top + h * 0.6);
      c.drawCircle(n, w * 0.09, Paint()..color = const Color(0xFFE5202E));
      c.drawCircle(n - Offset(w * 0.03, w * 0.03), w * 0.025, Paint()..color = Colors.white.withValues(alpha: 0.7));
      break;
    case 'horns':
      final red = Paint()
        ..shader = ui.Gradient.linear(Offset(0, b.top - h * 0.5), Offset(0, b.top + h * 0.1), [const Color(0xFFFF3B30), const Color(0xFF8B0000)]);
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015
        ..color = const Color(0xFF3A0000);
      for (final side in [-1.0, 1.0]) {
        final base = Offset(b.center.dx + side * w * 0.28, b.top + h * 0.08);
        final p = Path()
          ..moveTo(base.dx - side * w * 0.13, base.dy)
          ..quadraticBezierTo(base.dx + side * w * 0.02, base.dy - h * 0.25, base.dx + side * w * 0.2, base.dy - h * 0.5)
          ..quadraticBezierTo(base.dx + side * w * 0.04, base.dy - h * 0.15, base.dx + side * w * 0.11, base.dy)
          ..close();
        c.drawPath(p, red);
        c.drawPath(p, edge);
      }
      break;
    case 'halo':
      final r = Rect.fromCenter(center: Offset(b.center.dx, b.top - h * 0.18), width: w * 0.8, height: w * 0.2);
      c.drawOval(r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.07
        ..color = const Color(0x66FFE57A)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04));
      c.drawOval(r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..color = const Color(0xFFFFD447));
      break;
  }
}

// ───────────────────────── overlay effects ─────────────────────────
String stampText(DateTime d) => "${d.month.toString().padLeft(2, ' ')} ${d.day.toString().padLeft(2, '0')} '${(d.year % 100).toString().padLeft(2, '0')}";

void drawEffects(Canvas c, Size s, PhotoFilter f, {DateTime? when, int seed = 1, bool live = false}) {
  final w = s.width, h = s.height;
  final d = when ?? DateTime.now();
  if (f.softGlow) {
    c.drawRect(Offset.zero & s, Paint()
      ..shader = ui.Gradient.radial(s.center(Offset.zero), math.max(w, h) * 0.7, [const Color(0x00FFFFFF), const Color(0x33FFE4EE)], [0.55, 1]));
  }
  if (f.vignette) {
    c.drawRect(Offset.zero & s, Paint()
      ..shader = ui.Gradient.radial(s.center(Offset.zero), math.max(w, h) * 0.75, [const Color(0x00000000), const Color(0x8C000000)], [0.5, 1]));
  }
  if (f.scan) {
    final p = Paint()..color = const Color(0x1A000000);
    final gap = math.max(3.0, h / 260);
    for (var y = 0.0; y < h; y += gap) {
      c.drawRect(Rect.fromLTWH(0, y, w, gap / 2.5), p);
    }
  }
  if (f.grain) {
    final r = math.Random(seed);
    final n = live ? 1400 : (w * h / 260).clamp(2000, 60000).toInt();
    final light = <Offset>[], dark = <Offset>[];
    for (var i = 0; i < n; i++) {
      (i.isEven ? light : dark).add(Offset(r.nextDouble() * w, r.nextDouble() * h));
    }
    final sw = math.max(1.0, w / 900);
    c.drawPoints(ui.PointMode.points, light, Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = sw);
    c.drawPoints(ui.PointMode.points, dark, Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = sw);
  }
  if (f.fire) {
    final size = w / 7;
    for (var i = 0; i < 8; i++) {
      _emoji(c, '🔥', Offset(w * (i / 7), h - size * 0.35 + (i.isEven ? 0 : size * 0.12)), size);
    }
  }
  if (f.stamp == 'film') {
    final tp = TextPainter(
      text: TextSpan(text: stampText(d), style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: w * 0.055, color: const Color(0xFFFF9A2E), shadows: [Shadow(color: const Color(0xCCFF5A00), blurRadius: w * 0.012)])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(w - tp.width - w * 0.05, h - tp.height - h * 0.04));
  }
  if (f.stamp == 'vhs') {
    final st = TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: w * 0.05, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: w * 0.006, offset: Offset(w * 0.003, w * 0.003))]);
    final tl = TextPainter(text: TextSpan(text: 'PLAY ▶', style: st), textDirection: TextDirection.ltr)..layout();
    tl.paint(c, Offset(w * 0.05, h * 0.04));
    final hh = '${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
    final br = TextPainter(text: TextSpan(text: '$hh\n${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}', style: st), textDirection: TextDirection.ltr, textAlign: TextAlign.right)..layout();
    br.paint(c, Offset(w - br.width - w * 0.05, h - br.height - h * 0.04));
  }
  if (f.rec) {
    c.drawCircle(Offset(w - w * 0.13, h * 0.065), w * 0.022, Paint()..color = const Color(0xFFFF2D2D));
    final tp = TextPainter(text: TextSpan(text: 'REC', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: w * 0.045, color: Colors.white)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(w - w * 0.1, h * 0.065 - tp.height / 2));
  }
}

/// Live overlay over the camera preview: effects + stickers.
class LiveOverlayPainter extends CustomPainter {
  final PhotoFilter f;
  final Sticker s;
  final List<FaceBox> faces;
  LiveOverlayPainter(this.f, this.s, this.faces);
  @override
  void paint(Canvas c, Size size) {
    drawEffects(c, size, f, live: true);
    if (f.polaroid) {
      final b = size.width * 0.05;
      final p = Paint()..color = const Color(0xFFF8F5EE);
      c.drawRect(Rect.fromLTWH(0, 0, size.width, b), p);
      c.drawRect(Rect.fromLTWH(0, 0, b, size.height), p);
      c.drawRect(Rect.fromLTWH(size.width - b, 0, b, size.height), p);
      c.drawRect(Rect.fromLTWH(0, size.height - b * 4, size.width, b * 4), p);
    }
    if (s.kind != 'none') {
      for (final fb in faces) {
        drawSticker(c, fb, s);
      }
    }
  }

  @override
  bool shouldRepaint(LiveOverlayPainter o) => o.f != f || o.s != s || o.faces != faces;
}

// ───────────────────────── final photo ─────────────────────────
/// Applies the filter, face changer, effects and stickers to a captured photo and saves a JPEG.
/// [faces] are in the photo's own pixel coordinates (un-mirrored).
Future<String> renderPhoto(String srcPath, PhotoFilter f, Sticker s, List<FaceBox> faces, {bool mirror = false, String caption = '', int fxMode = 0}) async {
  final bytes = await File(srcPath).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final src = (await codec.getNextFrame()).image;
  final sw = src.width.toDouble(), sh = src.height.toDouble();
  final k = math.min(1.0, 2400 / math.max(sw, sh));
  final w = (sw * k).roundToDouble(), h = (sh * k).roundToDouble();
  final border = f.polaroid ? w * 0.05 : 0.0;
  final bottom = f.polaroid ? w * 0.2 : 0.0;
  final tw = w + border * 2, th = h + border + bottom;

  // 1) colour filter (+ mirror for selfies)
  final r1 = ui.PictureRecorder();
  final c1 = Canvas(r1);
  if (mirror) {
    c1.translate(w, 0);
    c1.scale(-1, 1);
  }
  c1.drawImageRect(src, Rect.fromLTWH(0, 0, sw, sh), Rect.fromLTWH(0, 0, w, h), Paint()
    ..colorFilter = ColorFilter.matrix(f.m)
    ..filterQuality = FilterQuality.high);
  var base = await r1.endRecording().toImage(w.round(), h.round());

  // 2) face changer warp on the biggest face
  FaceState? fs;
  if (fxMode != 0 && faces.isNotEmpty) {
    final big = faces.reduce((a, b) => a.box.width * a.box.height >= b.box.width * b.box.height ? a : b);
    fs = big.state(Size(sw, sh));
    if (fs != null && mirror) fs = fs.mirrored();
    if (fs != null) base = await FaceShader.warp(base, fxMode, fs);
  }

  // 3) frame, effects, stickers, overlays
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  if (f.polaroid) c.drawRect(Rect.fromLTWH(0, 0, tw, th), Paint()..color = const Color(0xFFF8F5EE));
  c.save();
  c.translate(border, border);
  c.clipRect(Rect.fromLTWH(0, 0, w, h));
  c.drawImage(base, Offset.zero, Paint()..filterQuality = FilterQuality.high);
  drawEffects(c, Size(w, h), f, seed: DateTime.now().millisecond);
  if (s.kind != 'none') {
    for (final fb in faces) {
      drawSticker(c, fb.map((o) => Offset(mirror ? w - o.dx * k : o.dx * k, o.dy * k)), s);
    }
  }
  drawFaceOverlay(c, Size(w, h), fxMode, fs, 0.6);
  c.restore();
  if (f.polaroid) {
    final tp = TextPainter(
      text: TextSpan(text: caption, style: TextStyle(fontSize: w * 0.05, color: const Color(0xFF4A4A4A), fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: tw - border * 2);
    tp.paint(c, Offset((tw - tp.width) / 2, h + border + (bottom - tp.height) / 2));
  }
  final out = await rec.endRecording().toImage(tw.round(), th.round());
  final bd = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  final im = img.Image.fromBytes(width: out.width, height: out.height, bytes: bd!.buffer, numChannels: 4, order: img.ChannelOrder.rgba);
  final jpg = img.encodeJpg(im, quality: 90);
  final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/memories');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final file = File('${dir.path}/${Store.newId()}_${f.id}.jpg');
  await file.writeAsBytes(jpg, flush: true);
  src.dispose();
  base.dispose();
  out.dispose();
  return file.path;
}
