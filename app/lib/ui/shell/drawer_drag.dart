// Ported from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.
//
// There is no PageView behind the chat here, so a leftward swipe while the
// drawer is closed is simply rejected and left to whatever else wants it: a

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

///

///

///

///

///

class DrawerDragRecognizer extends OneSequenceGestureRecognizer {
  DrawerDragRecognizer({
    required this.isOpen,
    required this.onStart,
    required this.onDelta,
    required this.onEnd,
    super.debugOwner,
  });

  ///

  final ValueGetter<bool> isOpen;

  final VoidCallback onStart;

  final ValueChanged<double> onDelta;

  final ValueChanged<double> onEnd;

  ///

  ///

  static const double _slop = 8.0;

  static const double _verticalSlop = kTouchSlop;

  @protected
  double get openingSign => 1;

  @protected
  bool opensAfter(double distance, PointerDeviceKind kind) => true;

  @protected
  double endVelocity(PointerEvent event) => _velocity?.getVelocity().pixelsPerSecond.dx ?? 0;

  Offset _accum = Offset.zero;
  bool _accepted = false;
  VelocityTracker? _velocity;

  @override
  String get debugDescription => 'drawer drag';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _accum = Offset.zero;
    _accepted = false;
    _velocity = VelocityTracker.withKind(event.kind);
    startTrackingPointer(event.pointer, event.transform);

  }

  @override
  void handleEvent(PointerEvent event) {
    _velocity?.addPosition(event.timeStamp, event.localPosition);

    if (event is PointerMoveEvent) {
      if (_accepted) {
        onDelta(event.delta.dx);
        return;
      }
      _accum += event.delta;

      if (_accum.dy.abs() > _verticalSlop && _accum.dy.abs() > _accum.dx.abs()) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
        return;
      }
      if (_accum.dx.abs() < _slop) return;

      final open = isOpen();
      final towards = _accum.dx * openingSign;
      if (open || towards > 0) {
        if (!open && !opensAfter(towards, event.kind)) return;
        _accepted = true;
        onStart();
        resolve(GestureDisposition.accepted);

        onDelta(_accum.dx);
      } else {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
      }
      return;
    }

    if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_accepted) {
        onEnd(endVelocity(event));
      }
      stopTrackingPointer(event.pointer);
      _accepted = false;
    }
  }

  ///

  ///

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
    _accepted = false;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
}

///

///

class QuickPanelDragRecognizer extends DrawerDragRecognizer {
  QuickPanelDragRecognizer({
    required super.isOpen,
    required super.onStart,
    required super.onDelta,
    required super.onEnd,
    super.debugOwner,
  });

  @override
  double get openingSign => -1;

  @override
  bool opensAfter(double distance, PointerDeviceKind kind) => distance > computeHitSlop(kind, gestureSettings);

  @override
  double endVelocity(PointerEvent event) => event is PointerCancelEvent ? 0 : super.endVelocity(event);

  @override
  String get debugDescription => 'quick panel drag';
}
