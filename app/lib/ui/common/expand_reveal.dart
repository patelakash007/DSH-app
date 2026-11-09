import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

///

///

class ExpandReveal extends StatefulWidget {
  const ExpandReveal({
    super.key,
    required this.open,
    required this.child,
    this.duration = AppMotion.collapse,
    this.curve = AppMotion.collapseCurve,
  });

  final bool open;
  final Widget child;
  final Duration duration;

  final Curve curve;

  @override
  State<ExpandReveal> createState() => _ExpandRevealState();
}

class _ExpandRevealState extends State<ExpandReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration, value: widget.open ? 1 : 0)
        ..addStatusListener((status) {
          if (status == AnimationStatus.dismissed && mounted) setState(() {});
        });

  late final Animation<double> _size = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
    reverseCurve: widget.curve.flipped,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = AppMotion.of(context, widget.duration);
  }

  @override
  void didUpdateWidget(ExpandReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = AppMotion.of(context, widget.duration);
    if (widget.open != oldWidget.open) {
      if (widget.open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open && _controller.isDismissed) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget child = FadeTransition(opacity: _fade, child: widget.child);
        if (constraints.hasBoundedWidth) {
          child = SizedBox(width: constraints.maxWidth, child: child);
        }
        return SizeTransition(sizeFactor: _size, alignment: AlignmentDirectional.topStart, child: child);
      },
    );
  }
}
