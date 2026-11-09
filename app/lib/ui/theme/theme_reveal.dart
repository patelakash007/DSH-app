import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'motion.dart';

///

class ThemeRevealHost extends StatefulWidget {
  const ThemeRevealHost({super.key, required this.child});

  final Widget child;

  static bool get active => _ThemeRevealHostState._active;

  static Future<void> run(BuildContext context, Future<void> Function() change) async {
    final host = context.findAncestorStateOfType<_ThemeRevealHostState>();
    if (host == null || !AppMotion.fluid(context)) {
      await change();
      return;
    }
    await host._reveal(change);
  }

  @override
  State<ThemeRevealHost> createState() => _ThemeRevealHostState();
}

class _ThemeRevealHostState extends State<ThemeRevealHost> with SingleTickerProviderStateMixin {
  static bool _active = false;
  static const _duration = Duration(milliseconds: 560);
  static const _curve = Cubic(0.4, 0, 0.2, 1);

  static const _maxWaitFrames = 8;

  final _boundary = GlobalKey();
  late final AnimationController _progress = AnimationController(vsync: this, duration: _duration);
  late final Animation<double> _hole = CurvedAnimation(parent: _progress, curve: _curve);

  ui.Image? _image;
  double _pixelRatio = 1;
  Offset? _lastDown;

  int _run = 0;

  @override
  void dispose() {
    _active = false;
    _image?.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _reveal(Future<void> Function() change) async {
    final run = ++_run;
    final before = Theme.of(context).brightness;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final ui.Image image;
    try {

      image = (_boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImageSync(pixelRatio: ratio);
    } catch (_) {

      await change();
      return;
    }
    final replaced = _image;
    _active = true;
    _pixelRatio = ratio;

    _progress.value = 0;
    setState(() => _image = image);
    WidgetsBinding.instance.addPostFrameCallback((_) => replaced?.dispose());
    try {
      await change();
    } catch (_) {
      // Nothing to reveal, and the screenshot must not stay over the app.
      if (mounted && run == _run) {
        _active = false;
        setState(() => _image = null);
        WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
      }
      rethrow;
    }

    var frames = 0;
    while (mounted && run == _run && Theme.of(context).brightness == before && frames++ < _maxWaitFrames) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || run != _run) return;

    if (Theme.of(context).brightness != before) {

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || run != _run) return;
      try {
        await _progress.forward(from: 0).orCancel;
      } on TickerCanceled {

      }
    }
    if (!mounted || run != _run) return;
    _active = false;
    setState(() => _image = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _lastDown = event.position,
      child: RepaintBoundary(
        key: _boundary,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (image != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _RevealPainter(image: image, pixelRatio: _pixelRatio, center: _lastDown, progress: _hole),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RevealPainter extends CustomPainter {
  _RevealPainter({required this.image, required this.pixelRatio, required this.center, required this.progress})
    : super(repaint: progress);

  final ui.Image image;
  final double pixelRatio;
  final Offset? center;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final origin = center ?? rect.center;
    final reach = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ].map((corner) => (corner - origin).distance).reduce(math.max);
    final hole = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addOval(Rect.fromCircle(center: origin, radius: reach * progress.value));
    canvas
      ..save()
      ..clipPath(hole)
      ..scale(1 / pixelRatio)
      ..drawImage(image, Offset.zero, Paint())
      ..restore();
  }

  @override
  bool shouldRepaint(_RevealPainter old) => old.image != image || old.center != center;
}
