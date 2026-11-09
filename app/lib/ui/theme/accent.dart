// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'oklch.dart';
import 'palette.dart';

///

///

///

/// |---|---|---|
/// | seed / pressed | 0.53 / 0.47 | 1 / 0.95 |
/// | container / onContainer | 0.93 / 0.33 | 0.26 / 0.70 |
/// | bubble / glow | 0.918 / 0.819 | 0.29 / 0.68 |
/// | seedDark / pressedDark | 0.764 / 0.704 | 0.76 |
/// | onSeedDark | 0.231 | 0.39 |
/// | containerDark / onContainerDark | 0.361 / 0.909 | 0.51 / 0.24 |
/// | bubbleDark / glowDark | 0.314 / 0.52 | 0.29 / 0.72 |
///

///

@immutable
class AppAccent {
  const AppAccent({
    required this.id,
    this._label,
    required this.seed,
    required this.pressed,
    required this.container,
    required this.onContainer,
    required this.bubble,
    required this.glow,
    required this.seedDark,
    required this.pressedDark,
    required this.onSeedDark,
    required this.containerDark,
    required this.onContainerDark,
    required this.bubbleDark,
    required this.glowDark,
    required this.tintHue,
    required this.tintChroma,
    required this.haze,
    required this.hazeDark,
  });

  final String id;

  final String? _label;

  String get label =>
      _label ??
      switch (id) {
        'mist' => appL10n.phoneAccentMist,
        'daiqing' => appL10n.phoneAccentDaiqing,
        'dusk' => appL10n.phoneAccentDusk,
        'turquoise' => appL10n.phoneAccentTurquoise,
        'amber' => appL10n.phoneAccentAmber,
        'graphite' => appL10n.phoneAccentGraphite,
        _ => appL10n.phoneAccentCustom,
      };

  final Color seed;

  final Color pressed;

  final Color container;
  final Color onContainer;

  final Color bubble;

  final Color glow;

  final Color seedDark;
  final Color pressedDark;
  final Color onSeedDark;
  final Color containerDark;
  final Color onContainerDark;
  final Color bubbleDark;
  final Color glowDark;

  final double tintHue;

  final double tintChroma;

  final Color haze;
  final Color hazeDark;

  Color get onSeed => const Color(0xFFFFFFFF);

  Color seedFor(Brightness brightness) => brightness == Brightness.dark ? seedDark : seed;

  static const mist = AppAccent(
    id: 'mist',
    seed: Color(0xFF4B67B4),
    pressed: Color(0xFF3D569D),
    container: Color(0xFFDEE8FF),
    onContainer: Color(0xFF213262),
    bubble: Color(0xFFD9E4FD),
    glow: Color(0xFFABC3FC),
    seedDark: Color(0xFF97B1F0),
    pressedDark: Color(0xFF859EDC),
    onSeedDark: Color(0xFF121C34),
    containerDark: Color(0xFF2E3C5F),
    onContainerDark: Color(0xFFD8E1F6),
    bubbleDark: Color(0xFF293144),
    glowDark: Color(0xFF51679D),
    tintHue: NeutralTones.baseHue,
    tintChroma: 1,
    haze: Color(0xFFD5CBEB),
    hazeDark: Color(0xFF514765),
  );

  static const daiqing = AppAccent(
    id: 'daiqing',
    seed: Color(0xFF236185),
    pressed: Color(0xFF145071),
    container: Color(0xFFDBEAF5),
    onContainer: Color(0xFF123950),
    bubble: Color(0xFFD6E7F3),
    glow: Color(0xFFA2CAE5),
    seedDark: Color(0xFF8CB9D7),
    pressedDark: Color(0xFF79A6C4),
    onSeedDark: Color(0xFF0D1F2B),
    containerDark: Color(0xFF274152),
    onContainerDark: Color(0xFFD5E3ED),
    bubbleDark: Color(0xFF26333C),
    glowDark: Color(0xFF466E88),
    tintHue: 238,
    tintChroma: 0.9,
    haze: Color(0xFFC7D0EC),
    hazeDark: Color(0xFF444C66),
  );

  static const dusk = AppAccent(
    id: 'dusk',
    seed: Color(0xFF726291),
    pressed: Color(0xFF61517D),
    container: Color(0xFFEAE5F4),
    onContainer: Color(0xFF392F4C),
    bubble: Color(0xFFE6E1F1),
    glow: Color(0xFFC8BDE1),
    seedDark: Color(0xFFB8ABD2),
    pressedDark: Color(0xFFA598BF),
    onSeedDark: Color(0xFF1F1A29),
    containerDark: Color(0xFF40394F),
    onContainerDark: Color(0xFFE2DEEC),
    bubbleDark: Color(0xFF332F3B),
    glowDark: Color(0xFF6D6284),
    tintHue: 295,
    tintChroma: 0.85,
    haze: Color(0xFFE6C7D7),
    hazeDark: Color(0xFF5F4353),
  );

  static const turquoise = AppAccent(
    id: 'turquoise',
    seed: Color(0xFF34766F),
    pressed: Color(0xFF296760),
    container: Color(0xFFDBECE9),
    onContainer: Color(0xFF123D39),
    bubble: Color(0xFFD6E8E6),
    glow: Color(0xFFA3CEC8),
    seedDark: Color(0xFF8DBEB7),
    pressedDark: Color(0xFF7BABA4),
    onSeedDark: Color(0xFF0D211F),
    containerDark: Color(0xFF274340),
    onContainerDark: Color(0xFFD6E5E2),
    bubbleDark: Color(0xFF263533),
    glowDark: Color(0xFF47726D),
    tintHue: 190,
    tintChroma: 0.7,
    haze: Color(0xFFB9D7E3),
    hazeDark: Color(0xFF34525E),
  );

  static const amber = AppAccent(
    id: 'amber',
    seed: Color(0xFF8D6636),
    pressed: Color(0xFF7A5528),
    container: Color(0xFFF2E6D9),
    onContainer: Color(0xFF483011),
    bubble: Color(0xFFEEE2D3),
    glow: Color(0xFFDCBE9D),
    seedDark: Color(0xFFCCAC87),
    pressedDark: Color(0xFFB99975),
    onSeedDark: Color(0xFF271A0C),
    containerDark: Color(0xFF4C3A25),
    onContainerDark: Color(0xFFEADFD3),
    bubbleDark: Color(0xFF392F24),
    glowDark: Color(0xFF7F6343),
    tintHue: 75,
    tintChroma: 0.75,
    haze: Color(0xFFEAC8C1),
    hazeDark: Color(0xFF64443D),
  );

  static const graphite = AppAccent(
    id: 'graphite',
    seed: Color(0xFF2C2E32),
    pressed: Color(0xFF1D1F23),
    container: Color(0xFFE3E6EC),
    onContainer: Color(0xFF2C2E32),
    bubble: Color(0xFFE0E3E8),
    glow: Color(0xFFBBBEC3),
    seedDark: Color(0xFFE5E8ED),
    pressedDark: Color(0xFFCED1D6),
    onSeedDark: Color(0xFF191B1E),
    containerDark: Color(0xFF3B3D41),
    onContainerDark: Color(0xFFDEE1E7),
    bubbleDark: Color(0xFF2E3034),
    glowDark: Color(0xFF616368),
    tintHue: 262,
    tintChroma: 0.25,
    haze: Color(0xFFCED1D6),
    hazeDark: Color(0xFF4A4D52),
  );

  static const presets = [mist, daiqing, dusk, turquoise, amber, graphite];

  static const customId = 'custom';
  static const wallpaperId = 'wallpaper';

  static AppAccent preset(String? id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return mist;
  }

  static const maxChroma = 0.13;

  static const lightSeedL = 0.53;

  static const darkLift = 0.234;

  ///

  factory AppAccent.derive(Color pick, {String id = customId, String? label}) {
    final key = (pick.toARGB32(), id, label);
    final hit = _derived[key];
    if (hit != null) return hit;
    if (_derived.length > 64) _derived.clear();
    return _derived[key] = AppAccent._derive(pick, id: id, label: label);
  }

  static final _derived = <(int, String, String?), AppAccent>{};

  factory AppAccent._derive(Color pick, {required String id, required String? label}) {
    final o = Oklch.fromColor(pick);
    final c = math.min(o.c, maxChroma);
    final h = o.h;
    final k = math.min(1.0, c / 0.1255);
    final tintChroma = 0.8 * k;
    final neutrals = NeutralTones.of(tintHue: h, tintChroma: tintChroma);
    Color tone(double l, double ratio) => Oklch(l, c * ratio, h).toColor();

    final onSeedDark = tone(0.231, 0.39);
    final lightL = o.l.clamp(0.30, 0.60);
    final seed = guard(
      Oklch(lightL, c, h),
      brightness: Brightness.light,
      surface: neutrals.mistHighest,
      onAccent: const Color(0xFFFFFFFF),
    );
    final seedDark = guard(
      Oklch(math.min(0.93, lightL + darkLift), c * 0.76, h),
      brightness: Brightness.dark,
      surface: neutrals.nightHighest,
      onAccent: onSeedDark,
    );
    final sl = Oklch.fromColor(seed).l;
    final sdl = Oklch.fromColor(seedDark).l;
    return AppAccent(
      id: id,
      label: label,
      seed: seed,
      pressed: tone(sl - 0.06, 0.95),
      container: tone(0.93, 0.26),
      onContainer: tone(0.33, 0.70),
      bubble: tone(0.918, 0.29),
      glow: tone(0.819, 0.68),
      seedDark: seedDark,
      pressedDark: tone(sdl - 0.06, 0.76),
      onSeedDark: onSeedDark,
      containerDark: tone(0.361, 0.51),
      onContainerDark: tone(0.909, 0.24),
      bubbleDark: tone(0.314, 0.29),
      glowDark: tone(0.52, 0.72),
      tintHue: h,
      tintChroma: tintChroma,
      haze: Oklch(0.86, 0.045 * k, h + 33).toColor(),
      hazeDark: Oklch(0.42, 0.05 * k, h + 33).toColor(),
    );
  }

  static const minOnSurface = 3.0;

  static const minText = 4.5;

  ///

  ///

  static Color guard(Oklch start, {required Brightness brightness, required Color surface, required Color onAccent}) {
    bool ok(Color c) => contrastRatio(c, surface) >= minOnSurface && contrastRatio(onAccent, c) >= minText;
    final first = start.toColor();
    if (ok(first)) return first;
    final dark = brightness == Brightness.dark;

    var pass = dark ? 1.0 : 0.0;
    var fail = start.l;
    for (var i = 0; i < 24; i++) {
      final mid = (pass + fail) / 2;
      if (ok(start.copyWith(l: mid).toColor())) {
        pass = mid;
      } else {
        fail = mid;
      }
    }
    return start.copyWith(l: pass).toColor();
  }

  static Color guardedSeed(Color pick, Brightness brightness) => AppAccent.derive(pick).seedFor(brightness);

  static Color hueColor(double hue, {double chroma = 0.11}) => Oklch(lightSeedL, chroma, hue).toColor();

  @override
  bool operator ==(Object other) =>
      other is AppAccent &&
      other.id == id &&
      other.seed == seed &&
      other.seedDark == seedDark &&
      other.tintHue == tintHue &&
      other.tintChroma == tintChroma;

  @override
  int get hashCode => Object.hash(id, seed, seedDark, tintHue, tintChroma);

  @override
  String toString() => 'AppAccent($id)';
}
