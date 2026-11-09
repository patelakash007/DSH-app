// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

///

///

abstract final class AppMotion {

  static const press = Duration(milliseconds: 90);

  static const quick = Duration(milliseconds: 160);

  static const standard = Duration(milliseconds: 240);

  static const collapse = Duration(milliseconds: 280);

  static const emphasized = Duration(milliseconds: 340);

  static const sheetIn = Duration(milliseconds: 380);
  static const sheetOut = Duration(milliseconds: 260);

  static const glassIn = Duration(milliseconds: 120);

  static const slow = Duration(milliseconds: 480);

  static const breath = Duration(milliseconds: 2400);

  static const std = Easing.standard;

  static const enter = Easing.emphasizedDecelerate;

  static const exit = Easing.emphasizedAccelerate;

  static const collapseCurve = Curves.easeInOutCubic;

  static const glide = Cubic(0.32, 0.72, 0.0, 1.0);

  static final pressSpring = SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 150));

  static final layoutSpring = SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 350));

  static final sheetSpring = SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 500));

  static final flingSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 500),
    bounce: 0.15,
  );

  static final releaseSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 320),
    bounce: 0.45,
  );

  static final popSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 380),
    bounce: 0.2,
  );

  static final thumbSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 320),
    bounce: 0.15,
  );

  static final riseSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 420),
    bounce: 0.18,
  );

  ///

  static final popCurve = SpringCurve(popSpring, within: 0.01);
  static final thumbCurve = SpringCurve(thumbSpring);
  static final riseCurve = SpringCurve(riseSpring);

  ///

  ///

  static SpringSimulation settle(
    SpringDescription spring,
    double from,
    double to,
    double velocity, {
    bool landing = true,
    double extent = 1,
  }) {
    var start = velocity;
    if (landing) {
      final limit = (to - from) * spring.damping / (2 * spring.mass);
      start = limit > 0 ? math.min(velocity, limit) : math.max(velocity, limit);
    }
    return SpringSimulation(
      spring,
      from,
      to,
      start,
      snapToEnd: true,
      tolerance: Tolerance(distance: 0.001 * extent, velocity: double.infinity),
    );
  }

  static double rubberBand(double x, {double limit = 48}) => (1 - 1 / (x * 0.55 / limit + 1)) * limit;

  static const page = Duration(milliseconds: 300);

  static const push = Duration(milliseconds: 300);

  static const pushFluid = Duration(milliseconds: 360);

  static const stagger = Duration(milliseconds: 30);
  static const staggerLimit = 8;

  static const rise = 8.0;

  static const pressScale = 0.97;

  static const sheetRise = Cubic(0.2, 0.9, 0.25, 1.0);

  static const sheetFall = Curves.easeOutCubic;

  ///

  static bool fluid(BuildContext context) =>
      !reduced(context) && (context.dependOnInheritedWidgetOfExactType<AppMotionScope>()?.fluid ?? false);

  static ScrollPhysics? scrollPhysics(BuildContext context) =>
      fluid(context) ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()) : null;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration duration) => reduced(context) ? Duration.zero : duration;
}

class AppMotionScope extends InheritedWidget {
  const AppMotionScope({super.key, required this.fluid, required super.child});

  final bool fluid;

  @override
  bool updateShouldNotify(AppMotionScope oldWidget) => fluid != oldWidget.fluid;
}

///

class SpringCurve extends Curve {

  SpringCurve(SpringDescription spring, {double within = 0.002}) : this._(SpringSimulation(spring, 0, 1, 0), within);

  SpringCurve._(this._simulation, double within) : _seconds = _settleSeconds(_simulation, within);

  final SpringSimulation _simulation;
  final double _seconds;

  Duration get duration => Duration(microseconds: (_seconds * Duration.microsecondsPerSecond).round());

  static double _settleSeconds(SpringSimulation simulation, double within) {
    const step = 0.004;
    var last = step;
    for (var t = step; t < 4; t += step) {
      if ((simulation.x(t) - 1).abs() > within) last = t + step;
    }
    return last;
  }

  @override
  double transformInternal(double t) => _simulation.x(t * _seconds);
}
