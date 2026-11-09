// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

import 'accent.dart';
import 'oklch.dart';
import 'surfaces.dart';

///

///

///

///

///

///

///

abstract final class DshPalette {

  static const mistTop = Color(0xFFEBF1FE);

  static const mistBottom = Color(0xFFF6F7FC);

  static const mist = Color(0xFFF0F4FD);

  static const mistLowest = Color(0xFFFBFCFF);
  static const mistLow = Color(0xFFF6F9FE);
  static const mistContainer = Color(0xFFEEF1F9);
  static const mistHigh = Color(0xFFE7EBF4);
  static const mistHighest = Color(0xFFDFE4EE);

  static const ink = Color(0xFF1E232E);

  static const inkMuted = Color(0xFF4F5562);

  static const inkFaint = Color(0xFF646974);

  static const inkGhost = Color(0xFFA1A5AC);

  static const outlineLight = Color(0xFF7E838D);

  static const ruleLight = Color(0xFFDCE0E8);

  static const shadowInk = Color(0xFF0B152D);

  static const nightTop = Color(0xFF1D222C);
  static const nightBottom = Color(0xFF1B1C23);
  static const night = Color(0xFF1C1F28);
  static const nightLowest = Color(0xFF14171E);
  static const nightLow = Color(0xFF232730);
  static const nightContainer = Color(0xFF272C36);
  static const nightHigh = Color(0xFF2D323C);
  static const nightHighest = Color(0xFF343944);

  static const paper = Color(0xFFE6E9F0);
  static const paperMuted = Color(0xFFB6BBC5);
  static const paperFaint = Color(0xFF9A9EA9);
  static const paperGhost = Color(0xFF656971);
  static const outlineDark = Color(0xFF737781);
  static const ruleDark = Color(0xFF343841);
  static const shadowNight = Color(0xFF03060D);

  static const slate = Color(0xFF545E6F);
  static const slateContainer = Color(0xFFE2E6F0);

  static const slateLift = Color(0xFFB3BED2);
  static const onSlateLift = Color(0xFF1A2230);
  static const slateContainerDark = Color(0x17FFFFFF);

  static const dusk = Color(0xFF6B578F);
  static const duskContainer = Color(0xFFECE5FB);
  static const onDuskContainer = Color(0xFF3B2C54);
  static const duskLift = Color(0xFFBEAEDE);
  static const onDuskLift = Color(0xFF251C36);
  static const duskContainerDark = Color(0xFF3E3451);
  static const onDuskContainerDark = Color(0xFFE4DDF3);

  static const danger = Color(0xFFA54743);
  static const onDanger = Color(0xFFFDF9F8);
  static const dangerContainer = Color(0xFFFFE2E0);
  static const onDangerContainer = Color(0xFF642724);
  static const dangerLift = Color(0xFFE69089);
  static const onDangerLift = Color(0xFF331513);
  static const dangerContainerDark = Color(0xFF542C29);
  static const onDangerContainerDark = Color(0xFFF8D9D7);

  static const scrim = Color(0xFF0B111F);

  ///

  static ColorScheme lightScheme(AppAccent accent) {
    final n = NeutralTones.forAccent(accent);
    return ColorScheme(
      brightness: Brightness.light,
      primary: accent.seed,
      onPrimary: accent.onSeed,
      primaryContainer: accent.container,
      onPrimaryContainer: accent.onContainer,
      secondary: n.slate,
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: n.slateContainer,
      onSecondaryContainer: n.ink,

      tertiary: dusk,
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: duskContainer,
      onTertiaryContainer: onDuskContainer,
      error: danger,
      onError: onDanger,
      errorContainer: dangerContainer,
      onErrorContainer: onDangerContainer,
      surface: n.mist,
      onSurface: n.ink,
      onSurfaceVariant: n.inkMuted,
      surfaceDim: n.mistHighest,
      surfaceBright: n.mistLowest,
      surfaceContainerLowest: n.mistLowest,
      surfaceContainerLow: n.mistLow,
      surfaceContainer: n.mistContainer,
      surfaceContainerHigh: n.mistHigh,
      surfaceContainerHighest: n.mistHighest,

      surfaceTint: Colors.transparent,
      inverseSurface: n.inverseSurface,
      onInverseSurface: n.onInverseSurface,
      inversePrimary: accent.seedDark,
      outline: n.outlineLight,
      outlineVariant: n.ruleLight,
      shadow: n.shadowInk,
      scrim: n.scrim,
    );
  }

  static ColorScheme darkScheme(AppAccent accent) {
    final n = NeutralTones.forAccent(accent);
    return ColorScheme(
      brightness: Brightness.dark,
      primary: accent.seedDark,
      onPrimary: accent.onSeedDark,
      primaryContainer: accent.containerDark,
      onPrimaryContainer: accent.onContainerDark,
      secondary: n.slateLift,
      onSecondary: n.onSlateLift,
      secondaryContainer: slateContainerDark,
      onSecondaryContainer: n.paper,
      tertiary: duskLift,
      onTertiary: onDuskLift,
      tertiaryContainer: duskContainerDark,
      onTertiaryContainer: onDuskContainerDark,
      error: dangerLift,
      onError: onDangerLift,
      errorContainer: dangerContainerDark,
      onErrorContainer: onDangerContainerDark,
      surface: n.night,
      onSurface: n.paper,
      onSurfaceVariant: n.paperMuted,
      surfaceDim: n.nightLowest,
      surfaceBright: n.nightHighest,
      surfaceContainerLowest: n.nightLowest,
      surfaceContainerLow: n.nightLow,
      surfaceContainer: n.nightContainer,
      surfaceContainerHigh: n.nightHigh,
      surfaceContainerHighest: n.nightHighest,
      surfaceTint: Colors.transparent,
      inverseSurface: n.paper,
      onInverseSurface: n.ink,
      inversePrimary: accent.seed,
      outline: n.outlineDark,
      outlineVariant: n.ruleDark,
      shadow: n.shadowNight,
      scrim: const Color(0xFF000000),
    );
  }
}

///

@immutable
class NeutralTones {
  const NeutralTones({
    required this.mistTop,
    required this.mistBottom,
    required this.mist,
    required this.mistLowest,
    required this.mistLow,
    required this.mistContainer,
    required this.mistHigh,
    required this.mistHighest,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.inkGhost,
    required this.outlineLight,
    required this.ruleLight,
    required this.shadowInk,
    required this.slate,
    required this.slateContainer,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.scrim,
    required this.codeWell,
    required this.codeWellHeader,
    required this.codeWellBorder,
    required this.lineNumber,
    required this.comment,
    required this.nightTop,
    required this.nightBottom,
    required this.night,
    required this.nightLowest,
    required this.nightLow,
    required this.nightContainer,
    required this.nightHigh,
    required this.nightHighest,
    required this.paper,
    required this.paperMuted,
    required this.paperFaint,
    required this.paperGhost,
    required this.outlineDark,
    required this.ruleDark,
    required this.shadowNight,
    required this.slateLift,
    required this.onSlateLift,
    required this.smoke,
    required this.sheetDark,
    required this.codeWellDark,
    required this.codeWellHeaderDark,
    required this.codeWellBorderDark,
    required this.lineNumberDark,
    required this.commentDark,
    required this.terminal,
    required this.terminalKey,
  });

  final Color mistTop, mistBottom, mist, mistLowest, mistLow, mistContainer, mistHigh, mistHighest;
  final Color ink, inkMuted, inkFaint, inkGhost, outlineLight, ruleLight, shadowInk;
  final Color slate, slateContainer, inverseSurface, onInverseSurface, scrim;

  final Color codeWell, codeWellHeader, codeWellBorder, lineNumber, comment;

  final Color nightTop, nightBottom, night, nightLowest, nightLow, nightContainer, nightHigh, nightHighest;
  final Color paper, paperMuted, paperFaint, paperGhost, outlineDark, ruleDark, shadowNight;
  final Color slateLift, onSlateLift;

  final Color smoke, sheetDark;

  final Color codeWellDark, codeWellHeaderDark, codeWellBorderDark, lineNumberDark, commentDark;

  final Color terminal, terminalKey;

  static const baseHue = 266.0;

  static const defaults = NeutralTones(
    mistTop: DshPalette.mistTop,
    mistBottom: DshPalette.mistBottom,
    mist: DshPalette.mist,
    mistLowest: DshPalette.mistLowest,
    mistLow: DshPalette.mistLow,
    mistContainer: DshPalette.mistContainer,
    mistHigh: DshPalette.mistHigh,
    mistHighest: DshPalette.mistHighest,
    ink: DshPalette.ink,
    inkMuted: DshPalette.inkMuted,
    inkFaint: DshPalette.inkFaint,
    inkGhost: DshPalette.inkGhost,
    outlineLight: DshPalette.outlineLight,
    ruleLight: DshPalette.ruleLight,
    shadowInk: DshPalette.shadowInk,
    slate: DshPalette.slate,
    slateContainer: DshPalette.slateContainer,
    inverseSurface: Color(0xFF252A35),
    onInverseSurface: Color(0xFFECEEF4),
    scrim: DshPalette.scrim,
    codeWell: Color(0xFFEDF0F6),
    codeWellHeader: Color(0xFFE7EBF3),
    codeWellBorder: Color(0xFFDBDEE5),
    lineNumber: Color(0xFF7D8088),
    comment: Color(0xFF636975),
    nightTop: DshPalette.nightTop,
    nightBottom: DshPalette.nightBottom,
    night: DshPalette.night,
    nightLowest: DshPalette.nightLowest,
    nightLow: DshPalette.nightLow,
    nightContainer: DshPalette.nightContainer,
    nightHigh: DshPalette.nightHigh,
    nightHighest: DshPalette.nightHighest,
    paper: DshPalette.paper,
    paperMuted: DshPalette.paperMuted,
    paperFaint: DshPalette.paperFaint,
    paperGhost: DshPalette.paperGhost,
    outlineDark: DshPalette.outlineDark,
    ruleDark: DshPalette.ruleDark,
    shadowNight: DshPalette.shadowNight,
    slateLift: DshPalette.slateLift,
    onSlateLift: DshPalette.onSlateLift,
    smoke: Color(0xFF292E39),
    sheetDark: Color(0xFF232832),
    codeWellDark: Color(0xFF14171E),
    codeWellHeaderDark: Color(0xFF1A1E26),
    codeWellBorderDark: Color(0xFF2F333A),
    lineNumberDark: Color(0xFF71747D),
    commentDark: Color(0xFF868C97),
    terminal: Color(0xFF12151C),
    terminalKey: Color(0xFF262A33),
  );

  static final _cache = <(double, double), NeutralTones>{};

  static NeutralTones forAccent(AppAccent accent) => of(tintHue: accent.tintHue, tintChroma: accent.tintChroma);

  static NeutralTones current(BuildContext context) =>
      forAccent(Theme.of(context).extension<DshSurfaces>()?.accent ?? AppAccent.mist);

  static Color tint(Color mistNeutral, AppAccent accent) =>
      retint(mistNeutral, hueShift: accent.tintHue - baseHue, chromaScale: accent.tintChroma);

  static NeutralTones of({required double tintHue, required double tintChroma}) {
    if (tintHue == baseHue && tintChroma == 1) return defaults;
    return _cache.putIfAbsent((tintHue, tintChroma), () {
      if (_cache.length > 32) _cache.clear();
      final shift = tintHue - baseHue;
      Color t(Color c) => retint(c, hueShift: shift, chromaScale: tintChroma);
      const m = defaults;
      return NeutralTones(
        mistTop: t(m.mistTop),
        mistBottom: t(m.mistBottom),
        mist: t(m.mist),
        mistLowest: t(m.mistLowest),
        mistLow: t(m.mistLow),
        mistContainer: t(m.mistContainer),
        mistHigh: t(m.mistHigh),
        mistHighest: t(m.mistHighest),
        ink: t(m.ink),
        inkMuted: t(m.inkMuted),
        inkFaint: t(m.inkFaint),
        inkGhost: t(m.inkGhost),
        outlineLight: t(m.outlineLight),
        ruleLight: t(m.ruleLight),
        shadowInk: t(m.shadowInk),
        slate: t(m.slate),
        slateContainer: t(m.slateContainer),
        inverseSurface: t(m.inverseSurface),
        onInverseSurface: t(m.onInverseSurface),
        scrim: t(m.scrim),
        codeWell: t(m.codeWell),
        codeWellHeader: t(m.codeWellHeader),
        codeWellBorder: t(m.codeWellBorder),
        lineNumber: t(m.lineNumber),
        comment: t(m.comment),
        nightTop: t(m.nightTop),
        nightBottom: t(m.nightBottom),
        night: t(m.night),
        nightLowest: t(m.nightLowest),
        nightLow: t(m.nightLow),
        nightContainer: t(m.nightContainer),
        nightHigh: t(m.nightHigh),
        nightHighest: t(m.nightHighest),
        paper: t(m.paper),
        paperMuted: t(m.paperMuted),
        paperFaint: t(m.paperFaint),
        paperGhost: t(m.paperGhost),
        outlineDark: t(m.outlineDark),
        ruleDark: t(m.ruleDark),
        shadowNight: t(m.shadowNight),
        slateLift: t(m.slateLift),
        onSlateLift: t(m.onSlateLift),
        smoke: t(m.smoke),
        sheetDark: t(m.sheetDark),
        codeWellDark: t(m.codeWellDark),
        codeWellHeaderDark: t(m.codeWellHeaderDark),
        codeWellBorderDark: t(m.codeWellBorderDark),
        lineNumberDark: t(m.lineNumberDark),
        commentDark: t(m.commentDark),
        terminal: t(m.terminal),
        terminalKey: t(m.terminalKey),
      );
    });
  }
}

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
