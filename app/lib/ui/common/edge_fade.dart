// A paint-only fade on the edges of a horizontal scroll
// view, so wide tables, long code lines and formulas show there is more to
// swipe to. The child stays mounted (and keeps its scroll position) when the
// fade comes and goes; with nothing hidden it draws without a layer.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

///

class HorizontalEdgeFade extends StatefulWidget {
  const HorizontalEdgeFade({super.key, required this.child});

  final Widget child;

  @override
  State<HorizontalEdgeFade> createState() => _HorizontalEdgeFadeState();
}

class _HorizontalEdgeFadeState extends State<HorizontalEdgeFade> {
  double _start = 0;
  double _end = 0;

  static double _edge(double extent) => extent < 1 ? 0 : math.min(extent / 24, 1);

  bool _onMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return false;
    final start = _edge(metrics.extentBefore);
    final end = _edge(metrics.extentAfter);
    if (start != _start || end != _end) {
      setState(() {
        _start = start;
        _end = end;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollMetricsNotification>(
    onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
    child: NotificationListener<ScrollNotification>(
      onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
      child: _EdgeMask(start: _start, end: _end, child: widget.child),
    ),
  );
}

class EdgeFadeScrollBehavior extends MaterialScrollBehavior {
  const EdgeFadeScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    final result = super.buildScrollbar(context, child, details);
    if (axisDirectionToAxis(details.direction) != Axis.horizontal ||
        context.findAncestorWidgetOfExactType<HorizontalEdgeFade>() != null) {
      return result;
    }
    return HorizontalEdgeFade(child: result);
  }
}

class _EdgeMask extends SingleChildRenderObjectWidget {
  const _EdgeMask({required this.start, required this.end, super.child});

  final double start;
  final double end;

  @override
  RenderHorizontalEdgeFade createRenderObject(BuildContext context) => RenderHorizontalEdgeFade(start, end);

  @override
  void updateRenderObject(BuildContext context, RenderHorizontalEdgeFade renderObject) =>
      renderObject.update(start, end);
}

class RenderHorizontalEdgeFade extends RenderProxyBox {
  RenderHorizontalEdgeFade(this._start, this._end);

  double _start;
  double _end;
  double get start => _start;
  double get end => _end;
  final _mask = LayerHandle<ShaderMaskLayer>();

  @override
  bool get alwaysNeedsCompositing => _start > 0 || _end > 0;

  void update(double start, double end) {
    if (start == _start && end == _end) return;
    final composited = alwaysNeedsCompositing;
    _start = start;
    _end = end;
    if (composited != alwaysNeedsCompositing) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!alwaysNeedsCompositing || size.isEmpty) {
      _mask.layer = null;
      super.paint(context, offset);
      return;
    }
    final edge = math.min(24 / size.width, 0.5);
    _mask.layer = (_mask.layer ?? ShaderMaskLayer())
      ..shader = LinearGradient(
        colors: [
          Colors.black.withValues(alpha: 1 - _start),
          Colors.black,
          Colors.black,
          Colors.black.withValues(alpha: 1 - _end),
        ],
        stops: [0, edge, 1 - edge, 1],
      ).createShader(Offset.zero & size)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(_mask.layer!, super.paint, offset);
  }

  @override
  void dispose() {
    _mask.layer = null;
    super.dispose();
  }
}
