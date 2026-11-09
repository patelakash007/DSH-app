// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

import 'squircle.dart';

///

///

/// |---|---|---|

///

abstract final class AppShape {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;

  static const radiusXs = BorderRadius.all(Radius.circular(xs));
  static const radiusSm = BorderRadius.all(Radius.circular(sm));
  static const radiusMd = BorderRadius.all(Radius.circular(md));
  static const radiusLg = BorderRadius.all(Radius.circular(lg));
  static const radiusXl = BorderRadius.all(Radius.circular(xl));

  static const card = SquircleBorder(borderRadius: radiusMd);

  static const bubble = SquircleBorder(borderRadius: radiusLg);

  static const dialog = SquircleBorder(borderRadius: radiusXl);

  static const sheet = SquircleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(xl)));

  static const pill = StadiumBorder();

  static SquircleBorder outlined(Color color, {double radius = md, double width = 1}) => SquircleBorder(
    borderRadius: BorderRadius.all(Radius.circular(radius)),
    side: BorderSide(color: color, width: width),
  );
}

///

abstract final class AppSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  static const gutter = 16.0;

  static const inTurn = 8.0;

  static const betweenTurns = 24.0;

  static const readingWidth = 720.0;

  static const floatInset = 12.0;

  static const floatingWidth = readingWidth - 2 * floatInset;
}
