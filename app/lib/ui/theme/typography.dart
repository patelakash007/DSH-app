// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

///

///

///

///

///

///

///

///

abstract final class AppType {

  static const String? sansFamily = null;

  static const monoFamily = 'JetBrainsMono';

  /// Source operators remain separate glyphs (<=, !=, ->), not programming
  /// ligatures. This changes shaping only, never the text copied or selected.
  static const monoFeatures = [FontFeature.disable('calt'), FontFeature.disable('liga')];

  static const monoFallback = <String>['monospace', 'Noto Sans Mono CJK SC', 'Noto Sans CJK SC'];

  /// [t] with every style's glyph locale set to [locale] (null: unchanged).
  /// The English UI passes zh_CN so Chinese content keeps Chinese shapes.
  static TextTheme withGlyphLocale(TextTheme t, Locale? locale) {
    if (locale == null) return t;
    final s = TextStyle(locale: locale);
    return t.merge(
      TextTheme(
        displayLarge: s,
        displayMedium: s,
        displaySmall: s,
        headlineLarge: s,
        headlineMedium: s,
        headlineSmall: s,
        titleLarge: s,
        titleMedium: s,
        titleSmall: s,
        bodyLarge: s,
        bodyMedium: s,
        bodySmall: s,
        labelLarge: s,
        labelMedium: s,
        labelSmall: s,
      ),
    );
  }

  static TextStyle mono({double size = 13, FontWeight? weight, Color? color, double height = 1.55}) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFeatures: monoFeatures,
      fontFamilyFallback: monoFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  static TextStyle monoSmall({Color? color}) => mono(size: 12, color: color, height: 1.5);

  static TextStyle monoLabel({Color? color, FontWeight? weight}) =>
      mono(size: 12, color: color, weight: weight, height: 1.35);

  ///

  static TextStyle chatBody(BuildContext context, {double scale = 1, double? height, Color? color}) {
    final base = Theme.of(context).textTheme.bodyLarge ?? textTheme.bodyLarge!;
    return base.copyWith(fontSize: (base.fontSize ?? 16) * scale, height: height ?? base.height, color: color);
  }

  static TextStyle display({double size = 28, Color? color}) => TextStyle(
    fontFamily: sansFamily,
    fontSize: size,
    fontWeight: FontWeight.w300,
    height: 1.25,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextStyle wordmark({double size = 18, Color? color}) => TextStyle(
    fontFamily: sansFamily,
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    height: 1.2,
    color: color,
  );

  static TextStyle eyebrow({Color? color}) => TextStyle(
    fontFamily: sansFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.35,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextStyle tabular(TextStyle style) => style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static const _even = TextLeadingDistribution.even;

  ///

  /// |---|---|---|

  static const textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w300, height: 1.2, leadingDistribution: _even),
    displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, height: 1.2, leadingDistribution: _even),
    displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, height: 1.25, leadingDistribution: _even),
    headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.3, leadingDistribution: _even),
    headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3, leadingDistribution: _even),
    headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.35, leadingDistribution: _even),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, leadingDistribution: _even),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.45, leadingDistribution: _even),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.45, leadingDistribution: _even),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.65, leadingDistribution: _even),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.55, leadingDistribution: _even),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5, leadingDistribution: _even),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0.1,
      leadingDistribution: _even,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.35,
      letterSpacing: 0.2,
      leadingDistribution: _even,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.35,
      letterSpacing: 0.2,
      leadingDistribution: _even,
    ),
  );
}
