// The measurements, colors and small motions the dsh-ui components share
// (docs/design/page-design.md §4–§5).

import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'dsh_ui_plugin_styles.dart';

abstract final class DshUiMetrics {

  static const cardRadius = AppShape.lg;
  static const cardPadding = 16.0;

  static const wellRadius = 12.0;

  static const tagRadius = 8.0;

  static const gap = 16.0;

  static const rowGap = 12.0;

  static const control = 48.0;

  static const chartHeight = 196.0;

  static const hbarRow = 32.0;

  static const donut = 148.0;
}

///

abstract final class DshUiPalette {
  static const light = [
    Color(0xFF3D6FD6),
    Color(0xFFDC6530),
    Color(0xFF169470),
    Color(0xFFB88000),
    Color(0xFFD0628F),
    Color(0xFF6B58D0),
  ];

  static const dark = [
    Color(0xFF5B8EE6),
    Color(0xFFD9692F),
    Color(0xFF1F9E76),
    Color(0xFFB88510),
    Color(0xFFD6649A),
    Color(0xFF8A7DE0),
  ];

  static const otherLight = Color(0xFF9AA0AA);
  static const otherDark = Color(0xFF6B707A);

  static List<Color> of(BuildContext context) {
    final style = DshUiPluginStyles.styleOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (style != null && style.chartColors.isNotEmpty) {
      return [for (final pair in style.chartColors) Color(0xFF000000 | pair.at(isDark))];
    }
    return isDark ? dark : light;
  }

  static Color other(BuildContext context) {
    final adjusted = DshUiPluginStyles.styleOf(context)?.chartOther;
    if (adjusted != null) return Color(0xFF000000 | adjusted.at(Theme.of(context).brightness == Brightness.dark));
    return NeutralTones.tint(
      Theme.of(context).brightness == Brightness.dark ? otherDark : otherLight,
      DshSurfaces.of(context).accent,
    );
  }
}

extension DshUiColors on BuildContext {

  Color get dshUiWell {
    final style = DshUiPluginStyles.styleOf(this);
    if (style != null) return Theme.of(this).colorScheme.surface;
    return Theme.of(this).brightness == Brightness.dark
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.05)
        : NeutralTones.current(this).shadowInk.withValues(alpha: 0.04);
  }

  Color get dshUiCardSurface {
    if (DshUiPluginStyles.viewOf(this) != null) return Theme.of(this).colorScheme.surface;
    final surfaces = DshSurfaces.of(this);
    final page = Color.lerp(surfaces.backdropTop, surfaces.backdropBottom, 0.5)!;
    return Color.alphaBlend(surfaces.card.fill, page);
  }
}

class DshUiAppear extends StatefulWidget {
  const DshUiAppear({super.key, required this.child, this.enabled = true, this.index = 0});

  final Widget child;
  final bool enabled;

  final int index;

  @override
  State<DshUiAppear> createState() => _DshUiAppearState();
}

class _DshUiAppearState extends State<DshUiAppear> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || !widget.enabled || AppMotion.reduced(context)) {
      return;
    }
    final delay = Duration(milliseconds: 30 * widget.index.clamp(0, 7));
    final total = delay + AppMotion.standard;
    final controller = AnimationController(vsync: this, duration: total);
    _controller = controller;
    _t = CurvedAnimation(
      parent: controller,
      curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: AppMotion.enter),
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
        final v = t.value;
        if (v >= 1) return child!;
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child),
        );
      },
    );
  }
}

TextSpan dshUiNumberSpan(String text, {required TextStyle number, required TextStyle unit}) {
  final match = _numberPattern.firstMatch(text);
  if (match == null) return TextSpan(text: text, style: number);
  final before = text.substring(0, match.start);
  final digits = match.group(0)!;
  final after = text.substring(match.end);

  if (_digit.hasMatch(before) || _digit.hasMatch(after)) {
    return TextSpan(text: text, style: AppType.tabular(number));
  }
  return TextSpan(
    children: [
      if (before.isNotEmpty) TextSpan(text: before, style: unit),
      TextSpan(text: digits, style: AppType.tabular(number)),
      if (after.isNotEmpty) TextSpan(text: after, style: unit),
    ],
  );
}

final _numberPattern = RegExp(r'[-+−]?\d[\d,]*(?:\.\d+)?');
final _digit = RegExp(r'\d');
