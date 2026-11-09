// The two-column feature tiles of the hub pages.

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'pressable.dart';

class TileGrid extends StatelessWidget {
  const TileGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  }) : assert(columns > 0);

  final List<Widget> children;
  final int columns;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      final cells = <Widget>[];
      for (var c = 0; c < columns; c++) {
        if (c > 0) cells.add(SizedBox(width: spacing));
        final i = start + c;
        cells.add(Expanded(child: i < children.length ? children[i] : const SizedBox()));
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      rows.add(
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

///
/// ```
/// ╭──────────────────────╮

/// │                      │

/// ╰──────────────────────╯
/// ```
///

///

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    this.icon,
    this.art,
    required this.title,
    this.subtitle,
    this.tint,
    this.badge,
    this.corner,
    this.onTap,
    this.enabled = true,
  }) : assert(icon != null || art != null);

  final IconData? icon;

  /// A [glyph]-sized graphic in place of the circle and [icon].
  final Widget? art;
  final String title;
  final String? subtitle;

  /// One of the 8 identity hues (`DshColors.identity`) for the circle; null
  /// follows the accent.
  final int? tint;

  final String? badge;

  /// A 36 × 36 widget in the top-right corner instead of [badge] (a second
  /// way in, e.g. an icon button).
  final Widget? corner;
  final VoidCallback? onTap;
  final bool enabled;

  static const padding = 14.0;
  static const glyph = 36.0;
  static const cornerIcon = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    final scheme = theme.colorScheme;
    final (Color fill, Color ink) = switch (tint) {
      final tint? => (
        colors.identity[tint % colors.identity.length],
        colors.onIdentity[tint % colors.onIdentity.length],
      ),
      null => (scheme.primaryContainer, scheme.primary),
    };

    final top = Row(
      children: [
        SizedBox.square(
          dimension: FeatureCard.glyph,
          child:
              art ??
              DecoratedBox(
                decoration: ShapeDecoration(color: fill, shape: const CircleBorder()),
                child: Icon(icon, size: 19, color: ink),
              ),
        ),
        const Spacer(),
        if (corner case final corner?)
          Transform.translate(
            offset: const Offset((FeatureCard.glyph - FeatureCard.cornerIcon) / 2, 0),
            child: SizedBox.square(dimension: FeatureCard.glyph, child: corner),
          )
        else if (badge case final badge?)
          _CornerBadge(badge),
      ],
    );

    final body = Padding(
      padding: const EdgeInsets.all(FeatureCard.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          top,
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  // Two lines on narrow phones / large text, never cut.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 15, height: 1.35),
                ),
                if (subtitle case final subtitle?) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: Pressable(
        // Feedback only: the InkWell below owns the tap.
        enabled: enabled,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: AppMotion.of(context, AppMotion.quick),
          child: GlassSurface(
            tier: GlassTier.card,
            borderRadius: AppShape.radiusLg,
            child: Material(
              type: MaterialType.transparency,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedSuperellipseBorder(borderRadius: AppShape.radiusLg),
              child: InkWell(
                onTap: enabled && onTap != null
                    ? () {
                        CardOrigin.remember(context);
                        onTap!();
                      }
                    : null,
                child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 112), child: body),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerBadge extends StatelessWidget {
  const _CornerBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.onSurface.withValues(alpha: 0.06),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
