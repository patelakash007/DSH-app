// Concept derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/widgets.dart';

///

///

typedef SquircleBorder = RoundedSuperellipseBorder;

abstract final class Squircle {

  static RoundedSuperellipseBorder border(double radius, {BorderSide side = BorderSide.none}) =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(radius)), side: side);

  static Widget clip({required double radius, required Widget child, Clip clipBehavior = Clip.antiAlias}) =>
      ClipRSuperellipse(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        clipBehavior: clipBehavior,
        child: child,
      );
}
