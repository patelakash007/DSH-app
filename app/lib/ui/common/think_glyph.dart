// Portions derived from DeepSeek Harness (https://github.com/deepseek-ai/deepseek-harness), MIT, Copyright (c) 2026 DeepSeek. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

///

class ThinkGlyph extends StatefulWidget {
  const ThinkGlyph({super.key, this.size = 16, this.color, this.spinning = false, this.strokeWidth = 1.25});

  final double size;

  final Color? color;
  final bool spinning;

  final double strokeWidth;

  @override
  State<ThinkGlyph> createState() => _ThinkGlyphState();
}

class _ThinkGlyphState extends State<ThinkGlyph> with SingleTickerProviderStateMixin {
  AnimationController? _spin;

  void _sync(bool animate) {
    if (animate) {
      (_spin ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 7200))).repeat();
    } else {
      _spin?.stop();
      _spin?.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(widget.spinning && !MediaQuery.disableAnimationsOf(context));
  }

  @override
  void didUpdateWidget(ThinkGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spinning != widget.spinning) {
      _sync(widget.spinning && !MediaQuery.disableAnimationsOf(context));
    }
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? IconTheme.of(context).color ?? Colors.black;
    Widget glyph = CustomPaint(size: Size.square(widget.size), painter: _ThinkPainter(color, widget.strokeWidth));
    final spin = _spin;
    if (spin != null) glyph = RotationTransition(turns: spin, child: glyph);
    return Semantics(
      excludeSemantics: true,
      child: SizedBox.square(dimension: widget.size, child: glyph),
    );
  }
}

class _ThinkPainter extends CustomPainter {
  _ThinkPainter(this.color, this.strokeWidth);

  final Color color;
  final double strokeWidth;

  // viewBox 0 0 16 16。
  static const _orbitA =
      'M10.2854 5.71481C12.9673 8.39663 14.1182 11.5938 12.8562 12.8559'
      'C11.5942 14.1179 8.39706 12.9669 5.71518 10.2851'
      'C3.03333 7.60323 1.88236 4.40608 3.14441 3.14403'
      'C4.40644 1.882 7.6036 3.03297 10.2854 5.71481Z';
  static const _orbitB =
      'M10.2854 10.2851C7.6036 12.9669 4.40644 14.1179 3.14441 12.8559'
      'C1.88236 11.5938 3.03333 8.39663 5.71518 5.71481'
      'C8.39706 3.03297 11.5942 1.882 12.8562 3.14403'
      'C14.1182 4.40608 12.9673 7.60323 10.2854 10.2851Z';

  static final _orbits = Path()
    ..addPath(_parse(_orbitA), Offset.zero)
    ..addPath(_parse(_orbitB), Offset.zero);

  static Path _parse(String d) {
    final path = Path();
    final tokens = RegExp(r'[MCZ]|-?\d*\.?\d+').allMatches(d).map((m) => m[0]!);
    final it = tokens.iterator;
    double next() {
      it.moveNext();
      return double.parse(it.current);
    }

    while (it.moveNext()) {
      switch (it.current) {
        case 'M':
          path.moveTo(next(), next());
        case 'C':
          path.cubicTo(next(), next(), next(), next(), next(), next());
        case 'Z':
          path.close();
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 16, size.height / 16);
    canvas.drawPath(
      _orbits,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color
        ..isAntiAlias = true,
    );

    canvas.drawCircle(const Offset(8.0022, 8.0002), 0.8607, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ThinkPainter old) => old.color != color || old.strokeWidth != strokeWidth;
}
