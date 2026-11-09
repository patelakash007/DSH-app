// TODO: replace [StreamPress] / [StreamFadeIn] with the shared Pressable /
// FadeSlideIn (`ui/common/`) and delete this file.

import 'package:flutter/widgets.dart';

import '../../theme/motion.dart';

///

class StreamPress extends StatefulWidget {
  const StreamPress({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<StreamPress> createState() => _StreamPressState();
}

class _StreamPressState extends State<StreamPress> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Feedback only: the child owns the tap, also for screen readers.
      excludeFromSemantics: true,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: AppMotion.of(context, _down ? AppMotion.press : AppMotion.quick),
        curve: AppMotion.std,
        child: widget.child,
      ),
    );
  }
}

///

///

class StreamFadeIn extends StatefulWidget {
  const StreamFadeIn({super.key, required this.child, this.enabled = true, this.index = 0, this.rise = false});

  final Widget child;
  final bool enabled;
  final int index;
  final bool rise;

  @override
  State<StreamFadeIn> createState() => _StreamFadeInState();
}

class _StreamFadeInState extends State<StreamFadeIn> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _t;

  Animation<double>? _lift;

  static const _riseBy = 36.0;
  static const _riseScale = 0.94;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || !widget.enabled || AppMotion.reduced(context)) {
      return;
    }
    final delay = Duration(milliseconds: 30 * widget.index.clamp(0, 7));
    final rise = widget.rise && AppMotion.fluid(context);
    final total = delay + (rise ? AppMotion.riseCurve.duration : AppMotion.standard);
    final controller = AnimationController(vsync: this, duration: total);
    _controller = controller;
    final start = delay.inMicroseconds / total.inMicroseconds;
    if (rise) {
      _lift = CurvedAnimation(
        parent: controller,
        curve: Interval(start, 1, curve: AppMotion.riseCurve),
      );
    }
    _t = CurvedAnimation(
      parent: controller,
      curve: Interval(
        start,

        rise ? (delay + AppMotion.standard).inMicroseconds / total.inMicroseconds : 1,

        curve: AppMotion.std,
      ),
    );
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return widget.child;
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (context, child) {
        // Same wrappers before and after the end: swapping them for the bare
        // child would rebuild the row and lose its state (an open tool row,

        final v = t.value.clamp(0.0, 1.0);
        final lift = _lift?.value;
        return ClipRect(

          clipBehavior: v < 1 && lift == null ? Clip.hardEdge : Clip.none,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: v,
            // Align loosens the row's full width; give it back, or a narrow
            // row (the user bubble) drifts to the middle.
            child: SizedBox(
              width: double.infinity,
              child: Opacity(
                opacity: v,
                child: lift == null
                    ? Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child)
                    : Transform.translate(
                        offset: Offset(0, _riseBy * (1 - lift)),
                        child: Transform.scale(
                          scale: _riseScale + (1 - _riseScale) * lift,
                          alignment: AlignmentDirectional.bottomEnd,
                          child: child,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
