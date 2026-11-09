// The shared make-up of the bars docked above the composer (todo, goal),
// sized to stack with the activity strip.

import 'package:flutter/material.dart';

import '../../common/expand_reveal.dart';
import '../../pets/pet_perch.dart';
import '../../theme/theme.dart';

///
/// ```

/// ```
///

abstract final class DockMetrics {

  static const height = 36.0;

  static const radius = height / 2;

  static const glyph = 20.0;

  static const edge = (height - glyph) / 2;

  static const textStart = 40.0;

  static const glyphGap = textStart - edge - glyph;

  static const trailingGap = 10.0;

  static const gap = 6.0;

  static const shape = BorderRadius.all(Radius.circular(radius));
}

class DockGlyph extends StatelessWidget {
  const DockGlyph({super.key, required this.child});

  DockGlyph.icon(IconData icon, {Key? key, required Color color})
    : this(
        key: key,
        child: Icon(icon, size: iconSize, color: color),
      );

  static const iconSize = 18.0;

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: DockMetrics.glyph,
    child: Center(child: child),
  );
}

class DockRow extends StatelessWidget {
  const DockRow({super.key, required this.leading, required this.content, this.accessory, this.trailing});

  final Widget leading;
  final Widget content;

  final Widget? accessory;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: DockMetrics.height),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DockMetrics.edge),
        child: Row(
          children: [
            leading,
            const SizedBox(width: DockMetrics.glyphGap),
            Expanded(child: content),
            if (accessory != null) ...[const SizedBox(width: DockMetrics.trailingGap), accessory!],
            if (trailing != null) ...[
              const SizedBox(width: DockMetrics.trailingGap),
              trailing!,
            ] else
              // Text ends where a trailing glyph's slot would start.
              const SizedBox(width: DockMetrics.edge),
          ],
        ),
      ),
    );
  }
}

abstract final class DockText {
  static TextStyle title(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    return theme.textTheme.labelMedium!.copyWith(color: color ?? theme.colorScheme.onSurface, height: 1.3);
  }

  static TextStyle detail(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall!.copyWith(color: color ?? theme.colorScheme.onSurfaceVariant, height: 1.3);
  }
}

class DockProgressLine extends StatelessWidget {
  const DockProgressLine({super.key, required this.fraction, this.width = 28});

  final double fraction;
  final double width;

  static const thickness = 3.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dsh = DshColors.of(context);
    final target = fraction.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: AppMotion.of(context, AppMotion.standard),
      curve: AppMotion.std,
      builder: (context, value, _) => Container(
        width: width,
        height: thickness,
        alignment: Alignment.centerLeft,
        decoration: ShapeDecoration(color: colors.onSurface.withValues(alpha: 0.10), shape: const StadiumBorder()),
        child: FractionallySizedBox(
          widthFactor: value,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: target >= 1 ? dsh.success : colors.primary,
              shape: const StadiumBorder(),
            ),
            child: const SizedBox(height: thickness),
          ),
        ),
      ),
    );
  }
}

/// ([AppMotion.standard] / [AppMotion.std])。
class DockSlot extends StatefulWidget {
  const DockSlot({super.key, this.child});

  /// Null: nothing to show.
  final Widget? child;

  @override
  State<DockSlot> createState() => _DockSlotState();
}

class _DockSlotState extends State<DockSlot> {
  Widget? _last;

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (child != null) _last = child;
    final last = _last;
    if (last == null) return const SizedBox(width: double.infinity);
    return ExpandReveal(
      open: child != null,
      duration: AppMotion.standard,
      curve: AppMotion.std,
      child: Padding(
        padding: const EdgeInsets.only(bottom: DockMetrics.gap),
        // The chat page's pet may stand on the bar (not while it folds away).
        child: PetPerch(kind: PerchKind.dock, active: child != null, child: last),
      ),
    );
  }
}
