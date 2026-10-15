import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../data.dart';
import '../face_fx.dart';
import '../filters.dart';
import '../lenses.dart';
import '../store.dart';
import '../watch.dart';
import 'memories.dart';

/// Our own camera: live 90's / modern / fun filters, face stickers, photo + video.
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<CameraDescription> cams = [];
  CameraController? c;
  int camIdx = 0;
  bool video = false, recording = false, busy = false, flashWhite = false;
  FlashMode flash = FlashMode.off;
  int timer = 0, countdown = 0;
  String tab = 'face';
  PhotoFilter f = filters.first;
  Sticker s = stickers.first;
  List<FaceBox> faces = const [];
  String? error;
  Map<String, dynamic>? lastMemory;
  DateTime? recStart;
  Timer? recTick;
  bool _watchWasOn = false;
  Lens lens = lenses[1];
  FaceState? fstate;
  DateTime? foundAt, lensOn;
  String? detErr;
  int _miss = 0;
  ui.FragmentShader? shader;
  bool shaderOk = true;
  late final AnimationController anim = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  final _det = FaceDetector(options: FaceDetectorOptions(enableLandmarks: true, enableContours: true, performanceMode: FaceDetectorMode.fast, minFaceSize: 0.1));
  bool _detBusy = false;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    FaceShader.program().then((p) {
      if (p == null || !mounted) {
        shaderOk = false;
        return;
      }
      final sh = p.fragmentShader();
      try {
        ui.ImageFilter.shader(sh); // throws on phones without the new graphics engine
      } catch (_) {
        shaderOk = false;
      }
      if (mounted) setState(() => shader = sh);
    });
    lensOn = DateTime.now();
    _boot();
  }

  Future<void> _boot() async {
    // The mic can only be used by one thing at a time.
    if (SleepWatch.i.on) {
      _watchWasOn = true;
      await SleepWatch.i.stop(remember: false);
    }
    try {
      cams = await availableCameras();
      if (cams.isEmpty) throw 'No camera found';
      camIdx = cams.indexWhere((x) => x.lensDirection == CameraLensDirection.back);
      if (camIdx < 0) camIdx = 0;
      await _open();
    } catch (e) {
      setState(() => error = 'Camera could not start. Allow the camera permission and try again.\n$e');
    }
  }

  Future<void> _open() async {
    final old = c;
    c = null;
    if (mounted) setState(() {});
    await old?.dispose();
    final ctl = CameraController(cams[camIdx], ResolutionPreset.high, enableAudio: true, imageFormatGroup: ImageFormatGroup.nv21);
    await ctl.initialize();
    try {
      await ctl.setFlashMode(flash);
    } catch (_) {}
    c = ctl;
    faces = const [];
    if (mounted) setState(() {});
    await _streamOn();
  }

  bool get front => cams.isNotEmpty && cams[camIdx].lensDirection == CameraLensDirection.front;
  Sticker get activeSticker => s.kind != 'none' ? s : stickerById(f.autoSticker);

  Future<void> _streamOn() async {
    final ctl = c;
    if (ctl == null || _snap || ctl.value.isStreamingImages || recording || (activeSticker.kind == 'none' && lens.none)) return;
    try {
      await ctl.startImageStream(_onFrame);
    } catch (_) {}
  }

  Future<void> _streamOff() async {
    final ctl = c;
    if (ctl == null || !ctl.value.isStreamingImages) return;
    try {
      await ctl.stopImageStream();
    } catch (_) {}
  }

  static Uint8List _nv21(CameraImage im) {
    if (im.planes.length == 1) {
      final pl = im.planes.first;
      final w = im.width, h = im.height, size = w * h * 3 ~/ 2;
      // the detector needs exactly width × height × 1.5 bytes – some phones send extra padding
      if (pl.bytesPerRow == w) return pl.bytes.length == size ? pl.bytes : Uint8List.fromList(pl.bytes.length > size ? pl.bytes.sublist(0, size) : (Uint8List(size)..setRange(0, pl.bytes.length, pl.bytes)));
      final out = Uint8List(size);
      var i = 0;
      for (var row = 0; row < h + h ~/ 2; row++) {
        final st = row * pl.bytesPerRow;
        if (st + w > pl.bytes.length) break;
        out.setRange(i, i + w, pl.bytes, st);
        i += w;
      }
      return out;
    }
    final w = im.width, h = im.height;
    final y = im.planes[0], u = im.planes[1], v = im.planes[2];
    final out = Uint8List(w * h + 2 * (w ~/ 2) * (h ~/ 2));
    var i = 0;
    for (var row = 0; row < h; row++) {
      out.setRange(i, i + w, y.bytes, row * y.bytesPerRow);
      i += w;
    }
    final up = u.bytesPerPixel ?? 1, vp = v.bytesPerPixel ?? 1;
    for (var row = 0; row < h ~/ 2; row++) {
      for (var col = 0; col < w ~/ 2; col++) {
        out[i++] = v.bytes[row * v.bytesPerRow + col * vp];
        out[i++] = u.bytes[row * u.bytesPerRow + col * up];
      }
    }
    return out;
  }

  Future<void> _onFrame(CameraImage im) async {
    if (_detBusy || ++_frame % 3 != 0 || !mounted) return;
    _detBusy = true;
    try {
      final ctl = c!;
      final so = ctl.description.sensorOrientation;
      final rot = InputImageRotationValue.fromRawValue(so) ?? InputImageRotation.rotation0deg;
      final input = InputImage.fromBytes(bytes: _nv21(im), metadata: InputImageMetadata(size: Size(im.width.toDouble(), im.height.toDouble()), rotation: rot, format: InputImageFormat.nv21, bytesPerRow: im.width));
      final res = await _det.processImage(input);
      final upW = (so == 90 || so == 270) ? im.height.toDouble() : im.width.toDouble();
      final upH = (so == 90 || so == 270) ? im.width.toDouble() : im.height.toDouble();
      final ps = ctl.value.previewSize!;
      final pw = ps.height, ph = ps.width; // portrait
      // the preview shows the centre of the analysed picture (same zoom both ways)
      final k = math.max(pw / upW, ph / upH);
      final ox = (pw - upW * k) / 2, oy = (ph - upH * k) / 2;
      Offset map(Offset o) {
        final x = o.dx * k + ox;
        return Offset(front ? pw - x : x, o.dy * k + oy);
      }
      Offset? lm(Face fc, FaceLandmarkType t) {
        final p = fc.landmarks[t]?.position;
        return p == null ? null : Offset(p.x.toDouble(), p.y.toDouble());
      }

      final out = res
          .map((fc) => FaceBox(fc.boundingBox, lEye: lm(fc, FaceLandmarkType.leftEye), rEye: lm(fc, FaceLandmarkType.rightEye), nose: lm(fc, FaceLandmarkType.noseBase), mouthL: lm(fc, FaceLandmarkType.leftMouth), mouthR: lm(fc, FaceLandmarkType.rightMouth), mouthB: lm(fc, FaceLandmarkType.bottomMouth), open: mouthOpen(fc)).map(map))
          .toList();
      final FaceState? st = out.isEmpty ? null : out.reduce((a, b) => a.box.width * a.box.height >= b.box.width * b.box.height ? a : b).state(Size(pw, ph));
      detErr = null;
      if (mounted) {
        setState(() {
          faces = out;
          if (st != null) {
            _miss = 0;
            if (fstate == null) foundAt = DateTime.now();
            fstate = st.lerp(fstate, 0.55);
          } else if (++_miss > 4) {
            fstate = null;
          }
        });
      }
      _errs = 0;
    } catch (e) {
      detErr = '$e';
      // this phone's live frames don't suit the face detector → switch to photo-based tracking
      if (++_errs >= 4 && !_snap) {
        _snap = true;
        _detBusy = false;
        unawaited(_streamOff().then((_) => _snapLoop()));
        return;
      }
      if (mounted) setState(() {});
    }
    _detBusy = false;
  }

  int _errs = 0;
  bool _snap = false, _snapping = false;

  /// Fallback tracking: grab a quick still every moment and find the face in it.
  Future<void> _snapLoop() async {
    final det = FaceDetector(options: FaceDetectorOptions(enableLandmarks: true, enableContours: true, performanceMode: FaceDetectorMode.fast));
    while (mounted && _snap) {
      final ctl = c;
      if (ctl == null || !ctl.value.isInitialized || recording || busy || (lens.none && activeSticker.kind == 'none')) {
        await Future.delayed(const Duration(milliseconds: 400));
        continue;
      }
      _snapping = true;
      try {
        final shot = await ctl.takePicture();
        final bytes = await File(shot.path).readAsBytes();
        final img = await decodeImageFromList(bytes);
        final iw = img.width.toDouble(), ih = img.height.toDouble();
        img.dispose();
        final res = await det.processImage(InputImage.fromFilePath(shot.path));
        try {
          File(shot.path).deleteSync();
        } catch (_) {}
        final ps = ctl.value.previewSize!;
        final pw = ps.height, ph = ps.width;
        final k = math.max(pw / iw, ph / ih);
        final ox = (pw - iw * k) / 2, oy = (ph - ih * k) / 2;
        Offset map(Offset o) {
          final x = o.dx * k + ox;
          return Offset(front ? pw - x : x, o.dy * k + oy);
        }
        Offset? lm(Face fc, FaceLandmarkType t) {
          final p = fc.landmarks[t]?.position;
          return p == null ? null : Offset(p.x.toDouble(), p.y.toDouble());
        }

        final out = res.map((fc) => FaceBox(fc.boundingBox, lEye: lm(fc, FaceLandmarkType.leftEye), rEye: lm(fc, FaceLandmarkType.rightEye), nose: lm(fc, FaceLandmarkType.noseBase), mouthL: lm(fc, FaceLandmarkType.leftMouth), mouthR: lm(fc, FaceLandmarkType.rightMouth), mouthB: lm(fc, FaceLandmarkType.bottomMouth), open: mouthOpen(fc)).map(map)).toList();
        final FaceState? st = out.isEmpty ? null : out.reduce((a, b) => a.box.width * a.box.height >= b.box.width * b.box.height ? a : b).state(Size(pw, ph));
        detErr = null;
        if (mounted) {
          setState(() {
            faces = out;
            if (st != null) {
              _miss = 0;
              if (fstate == null) foundAt = DateTime.now();
              fstate = st.lerp(fstate, 0.7);
            } else if (++_miss > 2) {
              fstate = null;
            }
          });
        }
      } catch (e) {
        detErr = '$e';
        if (mounted) setState(() {});
        await Future.delayed(const Duration(seconds: 1));
      }
      _snapping = false;
      await Future.delayed(const Duration(milliseconds: 120));
    }
    await det.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    final ctl = c;
    if (ctl == null || !ctl.value.isInitialized) return;
    if (st == AppLifecycleState.inactive) {
      c = null;
      ctl.dispose();
      if (mounted) setState(() {});
    } else if (st == AppLifecycleState.resumed && cams.isNotEmpty) {
      _open();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    recTick?.cancel();
    anim.dispose();
    c?.dispose();
    _det.close();
    SystemChrome.setPreferredOrientations([]);
    if (_watchWasOn) SleepWatch.i.start();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));

  Future<void> _shutter() async {
    final ctl = c;
    if (ctl == null || busy) return;
    if (video) {
      recording ? await _stopVideo() : await _startVideo();
      return;
    }
    if (timer > 0) {
      for (var i = timer; i > 0; i--) {
        if (!mounted) return;
        setState(() => countdown = i);
        HapticFeedback.selectionClick();
        await Future.delayed(const Duration(seconds: 1));
      }
      if (mounted) setState(() => countdown = 0);
    }
    setState(() {
      busy = true;
      flashWhite = true;
    });
    while (_snapping) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => flashWhite = false);
    });
    try {
      await _streamOff();
      final shot = await ctl.takePicture();
      final st = activeSticker;
      var still = <FaceBox>[];
      if (st.kind != 'none' || !lens.none) {
        final det = FaceDetector(options: FaceDetectorOptions(enableLandmarks: true, enableContours: true, performanceMode: FaceDetectorMode.accurate));
        try {
          final fs = await det.processImage(InputImage.fromFilePath(shot.path));
          Offset? lm(Face fc, FaceLandmarkType t) {
            final p = fc.landmarks[t]?.position;
            return p == null ? null : Offset(p.x.toDouble(), p.y.toDouble());
          }

          still = fs.map((fc) => FaceBox(fc.boundingBox, lEye: lm(fc, FaceLandmarkType.leftEye), rEye: lm(fc, FaceLandmarkType.rightEye), nose: lm(fc, FaceLandmarkType.noseBase), mouthL: lm(fc, FaceLandmarkType.leftMouth), mouthR: lm(fc, FaceLandmarkType.rightMouth), mouthB: lm(fc, FaceLandmarkType.bottomMouth), open: mouthOpen(fc) ?? fstate?.open)).toList();
        } catch (_) {}
        await det.close();
      }
      final b = Store.i.birth;
      final cap = '${Store.i.babyName} · ${b == null ? dmy(DateTime.now()) : 'Day ${dayNumber(b)}'}';
      final path = await renderPhoto(shot.path, f, st, still, mirror: front, caption: cap, lens: lens, warpOk: shaderOk && shader != null, t: anim.value * 60);
      try {
        File(shot.path).deleteSync();
      } catch (_) {}
      final m = {'id': Store.newId(), 'path': path, 'video': false, 'caption': '${f.emoji} ${f.name}${!lens.none ? ' ${lens.emoji} ${lens.name}' : ''}${st.kind != 'none' ? ' ${st.emoji}' : ''}', 'tag': '', 'date': ymd(DateTime.now()), 'cam': true};
      await Store.i.addItem('memories', m);
      lastMemory = m;
      if (mounted) _snack('Saved to Memories 💖');
    } catch (e) {
      if (mounted) _snack('Could not take the photo: $e');
    }
    if (mounted) setState(() => busy = false);
    await _streamOn();
  }

  Future<void> _startVideo() async {
    final ctl = c!;
    await _streamOff();
    try {
      await ctl.startVideoRecording();
      HapticFeedback.heavyImpact();
      recStart = DateTime.now();
      recTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
        if (DateTime.now().difference(recStart!).inMinutes >= 5) _stopVideo();
      });
      setState(() {
        recording = true;
        faces = const [];
      });
    } catch (e) {
      _snack('Could not record: $e');
    }
  }

  Future<void> _stopVideo() async {
    final ctl = c;
    if (ctl == null || !recording) return;
    recTick?.cancel();
    setState(() {
      recording = false;
      busy = true;
    });
    try {
      final x = await ctl.stopVideoRecording();
      final path = await Store.keepFile(x.path, 'memories');
      try {
        File(x.path).deleteSync();
      } catch (_) {}
      final m = {'id': Store.newId(), 'path': path, 'video': true, 'caption': '🎬 ${f.emoji} ${f.name}', 'tag': '', 'date': ymd(DateTime.now()), 'filter': f.id, 'cam': true};
      await Store.i.addItem('memories', m);
      lastMemory = m;
      if (mounted) _snack('Video saved to Memories 🎬');
    } catch (e) {
      if (mounted) _snack('Could not save the video: $e');
    }
    if (mounted) setState(() => busy = false);
    await _streamOn();
  }

  Future<void> _flip() async {
    if (cams.length < 2 || recording) return;
    camIdx = (camIdx + 1) % cams.length;
    await _open();
  }

  Future<void> _toggleFlash() async {
    final ctl = c;
    if (ctl == null) return;
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always, FlashMode.torch];
    flash = order[(order.indexOf(flash) + 1) % order.length];
    try {
      await ctl.setFlashMode(flash);
    } catch (_) {}
    setState(() {});
  }

  IconData get _flashIcon => switch (flash) {
        FlashMode.off => Icons.flash_off,
        FlashMode.auto => Icons.flash_auto,
        FlashMode.always => Icons.flash_on,
        FlashMode.torch => Icons.highlight,
      };

  @override
  Widget build(BuildContext context) {
    final ctl = c;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (error != null)
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))))
        else if (ctl == null || !ctl.value.isInitialized)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else
          Positioned.fill(child: _preview(ctl)),
        if (flashWhite) Positioned.fill(child: Container(color: Colors.white)),
        if (countdown > 0) Center(child: Text('$countdown', style: const TextStyle(fontSize: 120, color: Colors.white, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 20)]))),
        SafeArea(child: Column(children: [_topBar(), if (!recording && !video && (!lens.none || activeSticker.kind != 'none')) _faceStatus(), const Spacer(), _bottom()])),
      ]),
    );
  }

  Widget _preview(CameraController ctl) {
    final ps = ctl.value.previewSize ?? const Size(1280, 720);
    final pw = ps.height, ph = ps.width;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: pw,
          height: ph,
          child: AnimatedBuilder(
            animation: anim,
            builder: (context, _) {
              final t = anim.value * 60;
              Widget pv = ColorFiltered(colorFilter: ColorFilter.matrix(f.m), child: CameraPreview(ctl));
              final warp = lens.warp != 0 && fstate != null && shader != null && shaderOk;
              if (warp) {
                try {
                  FaceShader.setUniforms(shader!, lens.warp, t, fstate);
                  pv = ImageFiltered(imageFilter: ui.ImageFilter.shader(shader!), child: pv);
                } catch (_) {
                  shaderOk = false;
                }
              }
              final size = Size(pw, ph);
              final mags = lensMags(lens, fstate, size);
              final since = foundAt == null ? 0.0 : DateTime.now().difference(foundAt!).inMilliseconds / 1000;
              return Stack(children: [
                Positioned.fill(child: pv),
                for (final m in mags) magLayer(pv, m, size),
                Positioned.fill(child: CustomPaint(painter: LiveOverlayPainter(f, activeSticker, faces))),
                if (!lens.none) Positioned.fill(child: CustomPaint(painter: LensPainter(lens, fstate, t, since))),
              ]);
            },
          ),
        ),
      ),
    );
  }

  /// Shows whether a face is being tracked, so the face changers never feel "broken".
  Widget _faceStatus() {
    final found = fstate != null;
    final waited = lensOn != null && DateTime.now().difference(lensOn!).inSeconds >= 3;
    String text;
    if (found) {
      text = '${lens.emoji} Face found!${lens.hint.isNotEmpty ? '  ${lens.hint}' : ''}';
    } else if (detErr != null && waited) {
      text = '⚠️ Face tracking problem: ${detErr!.length > 140 ? detErr!.substring(0, 140) : detErr}';
    } else if (!front && waited) {
      text = '🔍 Looking for a face… tap 🔄 for selfie';
    } else {
      text = '🔍 Looking for a face… hold the phone in front of a face';
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: found ? const Color(0xCC2EAE5A) : Colors.black54, borderRadius: BorderRadius.circular(20)),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }

  Widget _round(IconData i, VoidCallback? onTap, {String? label}) => Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.black38,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, color: Colors.white, size: 22), if (label != null) ...[const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]]),
            ),
          ),
        ),
      );

  Widget _topBar() {
    final el = recStart == null ? Duration.zero : DateTime.now().difference(recStart!);
    return Row(children: [
      _round(Icons.close, () => Navigator.pop(context)),
      const Spacer(),
      if (recording)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
          child: Text('● ${el.inMinutes}:${(el.inSeconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        )
      else ...[
        _round(_flashIcon, _toggleFlash),
        if (!video) _round(Icons.timer_outlined, () => setState(() => timer = timer == 0 ? 3 : timer == 3 ? 10 : 0), label: timer == 0 ? null : '${timer}s'),
      ],
      _round(Icons.flip_camera_android, recording ? null : _flip),
    ]);
  }

  Widget _bottom() {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
      child: Column(children: [
        if (!recording) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final t in [['face', '🤪 Face changer'], ['filters', '🎨 Filters'], ['stickers', '😈 Stickers']])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ChoiceChip(
                  label: Text(t[1]),
                  selected: tab == t[0],
                  onSelected: (_) => setState(() => tab = t[0]),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          SizedBox(height: 88, child: tab == 'filters' ? _filterStrip() : tab == 'face' ? _faceStrip() : _stickerStrip()),
        ],
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _thumb(),
          GestureDetector(
            onTap: busy ? null : _shutter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 82,
              height: 82,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)),
              padding: const EdgeInsets.all(5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(color: video ? Colors.red : Colors.white, shape: recording ? BoxShape.rectangle : BoxShape.circle, borderRadius: recording ? BorderRadius.circular(10) : null),
                child: busy ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(strokeWidth: 3)) : null,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: recording
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () async {
                      setState(() => video = !video);
                      if (video) faces = const [];
                    },
                    child: Text(video ? '📷\nPhoto' : '🎬\nVideo', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
          ),
        ]),
        if (video && !recording) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Video keeps the colour filter when played in Memories (face changers & stickers are for photos)', style: TextStyle(color: Colors.white70, fontSize: 11))),
      ]),
    );
  }

  Widget _thumb() {
    final m = lastMemory;
    return GestureDetector(
      onTap: m == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewerPage(m: m))),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white70, width: 2), color: Colors.white12),
        clipBehavior: Clip.antiAlias,
        child: m == null
            ? const Icon(Icons.photo_library_outlined, color: Colors.white70)
            : m['video'] == true
                ? const Icon(Icons.play_circle_fill, color: Colors.white)
                : Image.file(File(m['path'].toString()), fit: BoxFit.cover, cacheWidth: 160),
      ),
    );
  }

  Widget _chip(String emoji, String name, bool sel, VoidCallback onTap, {String? group}) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 72,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: sel ? 56 : 50,
              height: sel ? 56 : 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: sel ? 0.95 : 0.2), border: Border.all(color: sel ? const Color(0xFFFF6FA0) : Colors.transparent, width: 3)),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 4),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
          ]),
        ),
      );

  Widget _filterStrip() => ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final x in filters) ...[
            if (x == filters.first || filters[filters.indexOf(x) - 1].group != x.group)
              Center(child: RotatedBox(quarterTurns: 3, child: Text(x.group.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w800)))),
            _chip(x.emoji, x.name, f.id == x.id, () async {
              setState(() => f = x);
              await _streamOn();
            }),
          ],
        ],
      );

  Widget _faceStrip() => ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: lenses
            .where((x) => x.warp == 0 || (shaderOk && shader != null))
            .map((x) => _chip(x.emoji, x.name, lens.id == x.id, () async {
                  setState(() {
                    lens = x;
                    lensOn = DateTime.now();
                    foundAt = DateTime.now();
                  });
                  if (x.none && activeSticker.kind == 'none') {
                    await _streamOff();
                    setState(() {
                      faces = const [];
                      fstate = null;
                    });
                  } else {
                    if (video) setState(() => video = false);
                    await _streamOn();
                    if (x.hint.isNotEmpty && mounted) _snack(x.hint);
                  }
                }))
            .toList(),
      );

  Widget _stickerStrip() => ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: stickers
            .map((x) => _chip(x.emoji, x.label, s.id == x.id, () async {
                  setState(() => s = x);
                  if (x.kind == 'none' && f.autoSticker == null) {
                    await _streamOff();
                    setState(() => faces = const []);
                  } else {
                    if (video) setState(() => video = false);
                    await _streamOn();
                  }
                }))
            .toList(),
      );
}

/// How open the mouth is (0..1), from the lip outlines.
double? mouthOpen(Face fc) {
  final up = fc.contours[FaceContourType.upperLipBottom]?.points;
  final lo = fc.contours[FaceContourType.lowerLipTop]?.points;
  if (up == null || lo == null || up.isEmpty || lo.isEmpty) return null;
  final u = up[up.length ~/ 2], l = lo[lo.length ~/ 2];
  final gap = (l.y - u.y).abs() / fc.boundingBox.height;
  return ((gap - 0.02) / 0.12).clamp(0.0, 1.0);
}
