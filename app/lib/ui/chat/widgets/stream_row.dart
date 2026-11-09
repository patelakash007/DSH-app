// The one anatomy every "process" row of a turn shares (thinking, tool calls,
// tool groups, the folded turn, slash commands, notices), so they line up on
// the same two columns as the answer text.

import 'package:flutter/material.dart';

import '../../common/bleed.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';

///
/// ```

/// ```
///

abstract final class StreamRow {

  static const lead = 24.0;

  static const gap = 8.0;

  static const indent = lead + gap;

  static const minHeight = 32.0;

  static const bleed = 8.0;

  static TextStyle? label(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3);

  static TextStyle? detail(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall
          ?.copyWith(fontSize: 13, color: DshColors.of(context).textTertiary, height: 1.3);
}

class StreamRowFrame extends StatelessWidget {
  const StreamRowFrame({super.key, required this.child, this.onTap, this.onLongPress});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: StreamRow.minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: StreamRow.bleed, vertical: 4),
        child: child,
      ),
    );
    return Bleed(
      horizontal: StreamRow.bleed,
      child: onTap == null && onLongPress == null
          ? content
          : InkWell(onTap: onTap, onLongPress: onLongPress, customBorder: Squircle.border(AppShape.sm), child: content),
    );
  }
}

class StreamLead extends StatelessWidget {
  const StreamLead({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: StreamRow.lead,
    child: Center(child: child),
  );
}

class StreamChevron extends StatelessWidget {
  const StreamChevron({super.key, required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: open ? 0.5 : 0,
    duration: AppMotion.of(context, AppMotion.collapse),
    curve: AppMotion.collapseCurve,
    child: Icon(AppIcons.expand, size: 16, color: DshColors.of(context).textTertiary),
  );
}

///

class StreamThread extends StatelessWidget {
  const StreamThread({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return CustomPaint(
      painter: _RailPainter(color.withValues(alpha: 0.8)),
      child: Padding(
        padding: const EdgeInsets.only(left: StreamRow.indent),
        child: child,
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 8) return;
    const x = StreamRow.lead / 2;
    canvas.drawLine(
      const Offset(x, 4),
      Offset(x, size.height - 4),
      Paint()
        ..color = color
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RailPainter old) => old.color != color;
}

class StreamDot extends StatelessWidget {
  const StreamDot({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: SizedBox.square(
      dimension: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(color: DshColors.of(context).textTertiary, shape: BoxShape.circle),
      ),
    ),
  );
}
