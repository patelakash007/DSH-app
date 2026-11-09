// Ported from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/widgets.dart';

///

class OverscrollForwarder extends StatelessWidget {
  const OverscrollForwarder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {

    final outer = Scrollable.maybeOf(context);
    if (outer == null) return child;
    return NotificationListener<OverscrollNotification>(
      onNotification: (notification) {

        if (notification.metrics.axis != Axis.vertical) return false;
        final position = outer.position;
        final target = (position.pixels + notification.overscroll).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if (target != position.pixels) {
          position.jumpTo(target.toDouble());
        }
        return true;
      },
      child: child,
    );
  }
}
