import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'accent.dart';
import 'palette.dart';

///

/// |---|---|---|

///

enum GlassTier { chrome, sheet, card, pill }

@immutable
class GlassStyle {
  const GlassStyle({
    required this.fill,
    required this.fallbackFill,
    required this.hairline,
    required this.rim,
    this.blurSigma = 0,
    this.saturation = 1,
    this.hairlineWidth = 0.5,
    this.shadows = const [],
  });

  final Color fill;

  final Color fallbackFill;

  final Color hairline;
  final double hairlineWidth;

  final Color rim;

  final double blurSigma;

  final double saturation;

  final List<BoxShadow> shadows;

  bool get blurs => blurSigma > 0;

  GlassStyle copyWith({
    Color? fill,
    Color? fallbackFill,
    Color? hairline,
    Color? rim,
    double? blurSigma,
    double? saturation,
    double? hairlineWidth,
    List<BoxShadow>? shadows,
  }) {
    return GlassStyle(
      fill: fill ?? this.fill,
      fallbackFill: fallbackFill ?? this.fallbackFill,
      hairline: hairline ?? this.hairline,
      rim: rim ?? this.rim,
      blurSigma: blurSigma ?? this.blurSigma,
      saturation: saturation ?? this.saturation,
      hairlineWidth: hairlineWidth ?? this.hairlineWidth,
      shadows: shadows ?? this.shadows,
    );
  }

  static GlassStyle lerp(GlassStyle a, GlassStyle b, double t) {
    return GlassStyle(
      fill: Color.lerp(a.fill, b.fill, t)!,
      fallbackFill: Color.lerp(a.fallbackFill, b.fallbackFill, t)!,
      hairline: Color.lerp(a.hairline, b.hairline, t)!,
      rim: Color.lerp(a.rim, b.rim, t)!,
      blurSigma: lerpDouble(a.blurSigma, b.blurSigma, t)!,
      saturation: lerpDouble(a.saturation, b.saturation, t)!,
      hairlineWidth: lerpDouble(a.hairlineWidth, b.hairlineWidth, t)!,
      shadows: BoxShadow.lerpList(a.shadows, b.shadows, t) ?? const [],
    );
  }
}

///

class DshSurfaces extends ThemeExtension<DshSurfaces> {
  const DshSurfaces({
    required this.backdropTop,
    required this.backdropBottom,
    required this.glowPrimary,
    required this.glowSecondary,
    required this.userBubble,
    required this.onUserBubble,
    required this.scrim,
    required this.chrome,
    required this.sheet,
    required this.card,
    required this.pill,
    this.accent = AppAccent.mist,
    this.blurEnabled = true,
  });

  final Color backdropTop;
  final Color backdropBottom;

  final Color glowPrimary;

  final Color glowSecondary;

  final Color userBubble;
  final Color onUserBubble;

  final Color scrim;

  final GlassStyle chrome;
  final GlassStyle sheet;
  final GlassStyle card;
  final GlassStyle pill;

  final AppAccent accent;

  final bool blurEnabled;

  static DshSurfaces of(BuildContext context) => Theme.of(context).extension<DshSurfaces>()!;

  GlassStyle glass(GlassTier tier) => switch (tier) {
    GlassTier.chrome => chrome,
    GlassTier.sheet => sheet,
    GlassTier.card => card,
    GlassTier.pill => pill,
  };

  factory DshSurfaces.light(AppAccent accent, {bool blurEnabled = true}) {
    final n = NeutralTones.forAccent(accent);
    final ink = n.shadowInk;
    const white = Color(0xFFFFFFFF);
    return DshSurfaces(
      backdropTop: n.mistTop,
      backdropBottom: n.mistBottom,
      glowPrimary: accent.glow.withValues(alpha: 0.42),
      glowSecondary: accent.haze.withValues(alpha: 0.38),
      userBubble: accent.bubble,
      onUserBubble: n.ink,
      scrim: n.scrim.withValues(alpha: 0.32),
      accent: accent,
      blurEnabled: blurEnabled,
      chrome: GlassStyle(
        fill: white.withValues(alpha: 0.70),
        fallbackFill: n.mistLowest.withValues(alpha: 0.96),
        hairline: ink.withValues(alpha: 0.08),
        rim: white.withValues(alpha: 0.85),
        blurSigma: 18,
        saturation: 1.3,
        shadows: [
          BoxShadow(color: ink.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: ink.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      sheet: GlassStyle(
        fill: n.mistLow.withValues(alpha: 0.82),
        fallbackFill: n.mistLow,
        hairline: ink.withValues(alpha: 0.07),
        rim: white.withValues(alpha: 0.90),
        blurSigma: 24,
        saturation: 1.4,
        shadows: [BoxShadow(color: ink.withValues(alpha: 0.10), blurRadius: 32, offset: const Offset(0, 8))],
      ),
      card: GlassStyle(
        fill: white.withValues(alpha: 0.62),
        fallbackFill: white.withValues(alpha: 0.72),
        hairline: ink.withValues(alpha: 0.06),
        rim: white.withValues(alpha: 0.70),
      ),
      pill: GlassStyle(
        fill: white.withValues(alpha: 0.55),
        fallbackFill: white.withValues(alpha: 0.66),
        hairline: ink.withValues(alpha: 0.07),
        rim: white.withValues(alpha: 0.75),
      ),
    );
  }

  factory DshSurfaces.dark(AppAccent accent, {bool blurEnabled = true}) {
    final n = NeutralTones.forAccent(accent);
    const white = Color(0xFFFFFFFF);
    const black = Color(0xFF000000);

    final smoke = n.smoke;
    return DshSurfaces(
      backdropTop: n.nightTop,
      backdropBottom: n.nightBottom,
      glowPrimary: accent.glowDark.withValues(alpha: 0.28),
      glowSecondary: accent.hazeDark.withValues(alpha: 0.24),
      userBubble: accent.bubbleDark,
      onUserBubble: n.paper,
      scrim: black.withValues(alpha: 0.48),
      accent: accent,
      blurEnabled: blurEnabled,
      chrome: GlassStyle(
        fill: smoke.withValues(alpha: 0.72),
        fallbackFill: smoke.withValues(alpha: 0.97),
        hairline: white.withValues(alpha: 0.09),
        rim: white.withValues(alpha: 0.12),
        blurSigma: 18,
        saturation: 1.2,
        shadows: [
          BoxShadow(color: black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: black.withValues(alpha: 0.25), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      sheet: GlassStyle(
        fill: n.sheetDark.withValues(alpha: 0.86),
        fallbackFill: n.sheetDark,
        hairline: white.withValues(alpha: 0.08),
        rim: white.withValues(alpha: 0.10),
        blurSigma: 24,
        saturation: 1.2,
        shadows: [BoxShadow(color: black.withValues(alpha: 0.40), blurRadius: 32, offset: const Offset(0, 8))],
      ),
      card: GlassStyle(
        fill: white.withValues(alpha: 0.05),
        fallbackFill: white.withValues(alpha: 0.06),
        hairline: white.withValues(alpha: 0.07),
        rim: white.withValues(alpha: 0.06),
      ),
      pill: GlassStyle(
        fill: white.withValues(alpha: 0.06),
        fallbackFill: white.withValues(alpha: 0.07),
        hairline: white.withValues(alpha: 0.08),
        rim: white.withValues(alpha: 0.08),
      ),
    );
  }

  @override
  DshSurfaces copyWith({
    Color? backdropTop,
    Color? backdropBottom,
    Color? glowPrimary,
    Color? glowSecondary,
    Color? userBubble,
    Color? onUserBubble,
    Color? scrim,
    GlassStyle? chrome,
    GlassStyle? sheet,
    GlassStyle? card,
    GlassStyle? pill,
    AppAccent? accent,
    bool? blurEnabled,
  }) {
    return DshSurfaces(
      backdropTop: backdropTop ?? this.backdropTop,
      backdropBottom: backdropBottom ?? this.backdropBottom,
      glowPrimary: glowPrimary ?? this.glowPrimary,
      glowSecondary: glowSecondary ?? this.glowSecondary,
      userBubble: userBubble ?? this.userBubble,
      onUserBubble: onUserBubble ?? this.onUserBubble,
      scrim: scrim ?? this.scrim,
      chrome: chrome ?? this.chrome,
      sheet: sheet ?? this.sheet,
      card: card ?? this.card,
      pill: pill ?? this.pill,
      accent: accent ?? this.accent,
      blurEnabled: blurEnabled ?? this.blurEnabled,
    );
  }

  @override
  DshSurfaces lerp(DshSurfaces? other, double t) {
    if (other is! DshSurfaces) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return DshSurfaces(
      backdropTop: mix(backdropTop, other.backdropTop),
      backdropBottom: mix(backdropBottom, other.backdropBottom),
      glowPrimary: mix(glowPrimary, other.glowPrimary),
      glowSecondary: mix(glowSecondary, other.glowSecondary),
      userBubble: mix(userBubble, other.userBubble),
      onUserBubble: mix(onUserBubble, other.onUserBubble),
      scrim: mix(scrim, other.scrim),
      chrome: GlassStyle.lerp(chrome, other.chrome, t),
      sheet: GlassStyle.lerp(sheet, other.sheet, t),
      card: GlassStyle.lerp(card, other.card, t),
      pill: GlassStyle.lerp(pill, other.pill, t),
      accent: t < 0.5 ? accent : other.accent,
      blurEnabled: t < 0.5 ? blurEnabled : other.blurEnabled,
    );
  }
}
