// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, this.color});

  final Color? color;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller
        ..stop()
        ..value = 0.25;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _scaleFor(int index) {
    final phase = (_controller.value + index / 3) % 1.0;
    return 0.55 + 0.45 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            SizedBox.square(
              dimension: 8,
              child: Center(
                child: Container(
                  width: 8 * _scaleFor(i),
                  height: 8 * _scaleFor(i),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.35 + 0.65 * _scaleFor(i)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
