import 'package:flutter/widgets.dart';

///

///

///

class FrameClock {
  FrameClock({this.maxStep = const Duration(milliseconds: 34)});

  static final instance = FrameClock();

  final Duration maxStep;

  bool enabled = false;

  Duration? _last;
  Duration _skipped = Duration.zero;

  Duration adjust(Duration raw) {
    final last = _last;
    _last = raw;
    if (enabled && last != null) {
      final step = raw - last;
      if (step > maxStep) _skipped += step - maxStep;
    }
    return raw - _skipped;
  }

  @visibleForTesting
  void reset() {
    _last = null;
    _skipped = Duration.zero;
    enabled = false;
  }
}

class SteadyFrameBinding extends WidgetsFlutterBinding {
  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    super.handleBeginFrame(rawTimeStamp == null ? null : FrameClock.instance.adjust(rawTimeStamp));
  }
}
