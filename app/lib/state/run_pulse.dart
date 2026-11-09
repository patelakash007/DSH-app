// What the live stream says about a running turn that the transcript does not
// keep, i.e. how fast tokens are flowing right now (for the whale-tail
// indicator) and whether the context is being compacted. The token estimate
// follows DeepSeek's published rule of thumb (1 Chinese character ≈ 0.6
// token, 1 English character ≈ 0.3 token).

import 'dart:async';
import 'dart:math' as math;

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notify_state.dart' show appForegroundProvider;

///

double estimateTokens(String text) {
  var cjk = 0;
  var other = 0;
  for (final rune in text.runes) {
    if (rune <= 0x20 || rune == 0x3000) continue;
    if ((rune >= 0x3400 && rune <= 0x9FFF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        (rune >= 0x3040 && rune <= 0x30FF) ||
        (rune >= 0xAC00 && rune <= 0xD7A3) ||
        (rune >= 0x20000 && rune <= 0x3FFFF)) {
      cjk++;
    } else {
      other++;
    }
  }
  return cjk * 0.6 + other * 0.3;
}

///

class TokenRateMeter {
  TokenRateMeter({
    this.window = const Duration(milliseconds: 2500),
    this.minSpan = const Duration(milliseconds: 500),
    this.stallAfter = const Duration(milliseconds: 1200),
  });

  final Duration window;
  final Duration minSpan;
  final Duration stallAfter;

  final _samples = <({DateTime at, double tokens})>[];

  DateTime? _burstStart;

  DateTime? get lastAt => _samples.isEmpty ? null : _samples.last.at;

  void add(DateTime at, double tokens) {
    if (tokens <= 0) return;
    final last = lastAt;
    if (last == null || at.difference(last) > stallAfter) _burstStart = at;
    // Out-of-order times (clock estimate moved) keep the list sorted enough:
    // a sample is never placed before the newest one.
    final when = last != null && at.isBefore(last) ? last : at;
    _samples.add((at: when, tokens: tokens));
  }

  void clear() {
    _samples.clear();
    _burstStart = null;
  }

  double rateAt(DateTime now) {
    final last = lastAt;
    if (last == null || now.difference(last) > stallAfter) return 0;
    final from = now.subtract(window);
    _samples.removeWhere((s) => s.at.isBefore(from));
    if (_samples.isEmpty) return 0;
    final start = _burstStart != null && _burstStart!.isAfter(from) ? _burstStart! : from;
    final span = now.difference(start);
    final seconds = (span < minSpan ? minSpan : span).inMicroseconds / 1e6;
    final tokens = _samples.fold<double>(0, (sum, s) => sum + s.tokens);
    return tokens / seconds;
  }
}

///

/// |---|---|---|---|

///

class SpeedGauge {
  SpeedGauge({this.minDwell = const Duration(milliseconds: 900)});

  final Duration minDwell;

  static const enterAt = <int, double>{3: 30, 4: 75};
  static const exitRatio = 0.8;

  int _level = 1;
  DateTime? _changedAt;

  int get level => _level;

  int update(double tps, DateTime now) {
    final target = targetFor(tps, _level);
    if (target == _level) return _level;
    final changed = _changedAt;
    if (changed != null && now.difference(changed) < minDwell) return _level;
    _level = target;
    _changedAt = now;
    return _level;
  }

  void reset() {
    _level = 1;
    _changedAt = null;
  }

  static int targetFor(double tps, int current) {
    if (tps <= 0) return 1;
    var level = math.max(current, 2);
    while (level < 4 && tps >= enterAt[level + 1]!) {
      level++;
    }
    while (level > 2 && tps < enterAt[level]! * exitRatio) {
      level--;
    }
    return level;
  }
}

///

class RunPulse extends ChangeNotifier {
  RunPulse({
    DateTime Function()? clock,
    this.tick = const Duration(milliseconds: 250),
    TokenRateMeter? meter,
    SpeedGauge? gauge,
  }) : _clock = clock ?? DateTime.now,
       meter = meter ?? TokenRateMeter(),
       gauge = gauge ?? SpeedGauge();

  final DateTime Function() _clock;
  final Duration tick;
  final TokenRateMeter meter;
  final SpeedGauge gauge;

  Timer? _timer;
  bool _disposed = false;
  bool _samplingEnabled = true;

  final _nextIndex = <String, int>{};

  final _attemptEstimate = <String, double>{};

  double _scale = 1;

  double _tps = 0;
  DateTime? _compactingSince;

  int get level => gauge.level;

  double get tokensPerSecond => _tps;

  DateTime? get compactingSince => _compactingSince;

  void observe(DshEvent event, {Duration? skew}) {
    switch (event) {
      case AssistantChunkEvent(:final attemptId, :final index, :final chunk):
        final next = _nextIndex[attemptId] ?? 0;
        if (index < next) return;
        _nextIndex[attemptId] = index + 1;
        _chunk(attemptId, chunk, event.time, skew);
      case AssistantStreamEnded(:final attemptId):
        _nextIndex.remove(attemptId);
        _attemptEstimate.remove(attemptId);
      case SessionSnapshotEvent(:final events, :final isResync):
        if (!isResync) {
          _nextIndex.clear();
          _attemptEstimate.clear();
        }
        _setCompacting(compactingAfter(events, _compactingSince, isResync));
      case SessionLogEvent():
        _setCompacting(compactingAfter([event], _compactingSince, true));
      default:
        break;
    }
  }

  void _chunk(String attempt, StreamChunk chunk, DateTime time, Duration? skew) {
    final text = switch (chunk) {
      TextDeltaChunk(:final text) => text,
      ReasoningDeltaChunk(:final text) => text,
      ToolCallDeltaChunk(:final argumentsDelta) => argumentsDelta,
      _ => null,
    };
    if (chunk is UsageChunk) {
      _calibrate(_attemptEstimate[attempt], chunk.usage.outputTokens);
      return;
    }
    if (text == null || text.isEmpty) return;
    final tokens = estimateTokens(text);
    if (tokens <= 0) return;
    _attemptEstimate[attempt] = (_attemptEstimate[attempt] ?? 0) + tokens;
    final now = _clock();
    final local = skew == null ? now : time.add(skew);
    meter.add(local.isAfter(now) ? now : local, tokens);
    _update();
    _ensureTimer();
  }

  void _calibrate(double? estimated, int actual) {
    if (estimated == null || estimated < 40 || actual <= 0) return;
    final ratio = (actual / estimated).clamp(0.4, 2.5);
    _scale = _scale * 0.5 + ratio * 0.5;
  }

  void _update() {
    final now = _clock();
    _tps = meter.rateAt(now) * _scale;
    final before = gauge.level;
    if (gauge.update(_tps, now) != before) _notify();
    if (gauge.level == 1 && meter.lastAt == null) _stopTimer();
  }

  @visibleForTesting
  void tickNow() {
    _update();
    final last = meter.lastAt;
    final idle = gauge.level == 1 && (last == null || _clock().difference(last) > meter.stallAfter);
    if (idle) {
      meter.clear();
      _stopTimer();
    }
  }

  /// Pause only the display clock; event ingestion and usage calibration remain
  /// live. On resume, discard a stale rate before scheduling another tick.
  void setSamplingEnabled(bool enabled) {
    if (_disposed || enabled == _samplingEnabled) return;
    _samplingEnabled = enabled;
    if (!enabled) {
      _stopTimer();
      return;
    }
    tickNow();
    if (meter.lastAt != null) _ensureTimer();
  }

  void _ensureTimer() {
    if (_timer != null || _disposed || !_samplingEnabled) return;
    _timer = Timer.periodic(tick, (_) => tickNow());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _setCompacting(DateTime? since) {
    if (since == _compactingSince) return;
    _compactingSince = since;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    super.dispose();
  }
}

@visibleForTesting
DateTime? compactingAfter(Iterable<SessionLogEvent> events, DateTime? current, bool merge) {
  var since = merge ? current : null;
  for (final event in events) {
    switch (event.type) {
      case 'compaction/start':
        since = event.time;
      case 'compaction/end' || 'turn/end':
        since = null;
    }
  }
  return since;
}

final runPulseProvider = Provider.autoDispose.family<RunPulse, String>((ref, sessionId) {
  final pulse = RunPulse();
  ref.listen(appForegroundProvider, (_, foreground) {
    pulse.setSamplingEnabled(foreground);
  }, fireImmediately: true);
  ref.onDispose(pulse.dispose);
  return pulse;
});
