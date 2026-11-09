// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:async';
import 'dart:math' as math;

import 'package:dsh_client/dsh_client.dart' show CotTranslationLimits;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/cot_translation_state.dart';
import '../../../state/sessions_state.dart';
import '../../common/expand_reveal.dart';
import '../../common/pressable.dart';
import '../../common/smooth_size.dart';
import '../../common/think_glyph.dart';
import '../../engine_settings/engine_settings_page.dart' show openSettingsPage;
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../render/markdown_body.dart';
import 'stream_pacer.dart';
import 'stream_row.dart';

///
/// ```

/// ```
///

///

///

///

///

const _brandBlue = Color(0xFF4D6BFE);

class ThinkingPill extends StatefulWidget {
  const ThinkingPill({
    super.key,
    required this.reasoning,
    this.active = false,
    this.streaming = false,
    this.growIn = false,
  });

  final String reasoning;

  final bool active;

  final bool streaming;

  final bool growIn;

  @override
  State<ThinkingPill> createState() => _ThinkingPillState();
}

String thinkingPreview(String text) => _firstLine(text).replaceAll('**', '').trim();

String _firstLine(String text) {
  final trimmed = text.trimLeft();
  final newline = trimmed.indexOf('\n');
  return newline == -1 ? trimmed : trimmed.substring(0, newline);
}

class _ThinkingPillState extends State<ThinkingPill> {
  bool _expanded = false;

  Widget? _body;

  final _translation = _TranslationHolder();

  late bool _windowHeld = widget.growIn;

  @override
  void initState() {
    super.initState();
    if (!_windowHeld) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _windowHeld = false);
    });
  }

  @override
  void didUpdateWidget(ThinkingPill oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.streaming && !widget.streaming) _expanded = false;
  }

  @override
  void dispose() {
    _translation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    final brand = dark ? Color.lerp(_brandBlue, Colors.white, 0.3)! : _brandBlue;
    final active = widget.active;

    final open = active || _expanded;
    final preview = open ? '' : thinkingPreview(widget.reasoning);
    final detail = StreamRow.detail(context);

    final header = Row(
      children: [
        SizedBox.square(
          dimension: StreamRow.lead,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: brand.withValues(alpha: dark ? 0.18 : 0.10),
              shape: Squircle.border(StreamRow.lead * 0.32),
            ),
            child: Center(

              child: RepaintBoundary(
                child: ThinkGlyph(size: 15, color: brand, spinning: active),
              ),
            ),
          ),
        ),
        const SizedBox(width: StreamRow.gap),

        ThinkingLabel(active ? l10n.chatThinkingActive : l10n.chatThinking, active: active),
        if (preview.isNotEmpty) ...[
          const StreamDot(),
          Expanded(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => LinearGradient(
                colors: const [Colors.black, Colors.transparent],
                stops: [((rect.width - 40) / rect.width).clamp(0.0, 1.0), 1],
              ).createShader(rect),
              child: Text(preview, maxLines: 1, softWrap: false, overflow: TextOverflow.clip, style: detail),
            ),
          ),
        ] else
          const Spacer(),
        const SizedBox(width: 4),
        StreamChevron(open: _expanded),
      ],
    );

    Widget reasoningBody() {
      if (!_expanded) return ThinkingTicker(text: widget.reasoning);

      void collapse() => setState(() => _expanded = false);
      return _hasProviderScope(context)
          ? _TranslatableReasoning(
              text: widget.reasoning.trim(),
              active: active,
              holder: _translation,
              onBodyTap: collapse,
            )
          : _CollapsibleReasoningBody(
              onCollapse: collapse,
              child: MarkdownBody(text: widget.reasoning.trim(), streaming: active, secondary: true, selectable: false),
            );
    }

    if (open) {
      _body = SmoothSize(

        duration: active && !_expanded ? Duration.zero : AppMotion.of(context, AppMotion.quick),
        alignment: AlignmentDirectional.topCenter,
        child: StreamThread(
          child: Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: reasoningBody()),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          child: StreamRowFrame(onTap: () => setState(() => _expanded = !_expanded), child: header),
        ),

        ExpandReveal(open: open && !_windowHeld, child: _body ?? const SizedBox.shrink()),
      ],
    );
  }
}

///

///

class ThinkingLabel extends StatefulWidget {
  const ThinkingLabel(this.text, {super.key, this.active = false});

  final String text;
  final bool active;

  static const lead = Duration(milliseconds: 600);
  static const sweep = Duration(seconds: 1);
  static const period = Duration(seconds: 4);

  @override
  State<ThinkingLabel> createState() => _ThinkingLabelState();
}

class _ThinkingLabelState extends State<ThinkingLabel> with SingleTickerProviderStateMixin {

  static _ThinkingLabelState? _owner;

  AnimationController? _sweep;
  Timer? _timer;

  void _sync() {
    final run = widget.active && !AppMotion.reduced(context);
    if (run == (_timer != null)) return;
    if (run) {
      _sweep ??= AnimationController(vsync: this, duration: ThinkingLabel.sweep);
      _timer = Timer(ThinkingLabel.lead, () {
        _timer = Timer.periodic(ThinkingLabel.period, (_) => _play());

        _owner?._sweep?.reset();
        _owner = this;
        _play();
      });
    } else {
      _timer?.cancel();
      _timer = null;
      _sweep?.reset();
      _release();
    }
  }

  void _play() {

    _owner ??= this;
    if (identical(_owner, this)) _sweep!.forward(from: 0);
  }

  void _release() {
    if (identical(_owner, this)) _owner = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ThinkingLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sweep?.dispose();
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = StreamRow.label(context);
    final label = Text(widget.text, style: style);
    final sweep = _sweep;
    if (sweep == null || _timer == null) return label;
    final muted = style?.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final bright = Theme.of(context).colorScheme.onSurface;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: sweep,
        child: label,
        builder: (context, child) {
          if (!sweep.isAnimating) return child!;
          return ShaderMask(
            blendMode: BlendMode.srcIn,

            shaderCallback: (rect) =>
                LinearGradient(colors: [muted, bright, muted])
                    .createShader(Rect.fromLTWH((2 * sweep.value - 1) * rect.width, 0, rect.width, rect.height)),
            child: child,
          );
        },
      ),
    );
  }
}

///

class _CollapsibleReasoningBody extends StatelessWidget {
  const _CollapsibleReasoningBody({required this.onCollapse, required this.child});

  final VoidCallback onCollapse;
  final Widget child;

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: Semantics(
      button: true,
      hint: context.l10n.commonCollapse,
      onTap: onCollapse,
      child: GestureDetector(

        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onCollapse,
        child: child,
      ),
    ),
  );
}

///

class ThinkingTicker extends StatelessWidget {
  const ThinkingTicker({super.key, required this.text});

  final String text;

  static const rows = 3;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.fluid(context)) return _FluidTicker(text: text);
    final style = StreamRow.detail(context);
    final scaler = MediaQuery.textScalerOf(context);
    final lineHeight = scaler.scale(style?.fontSize ?? 13) * (style?.height ?? 1.3);
    final shown = thinkingTickerText(text);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final painter = TextPainter(
          text: TextSpan(text: shown, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout(maxWidth: width);
        final textHeight = painter.height;

        painter.dispose();
        final window = lineHeight * ThinkingTicker.rows;

        final height = window;

        final shift = (textHeight - window).clamp(0.0, double.infinity);
        return SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.quick),

              curve: Curves.linear,
              transform: Matrix4.translationValues(0, -shift, 0),
              child: OverflowBox(
                alignment: AlignmentDirectional.topStart,
                minHeight: 0,
                maxHeight: double.infinity,
                child: SizedBox(
                  width: width,
                  child: Text(shown, style: style),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

///

String thinkingTickerText(String text) {
  var tail = text.trimRight();
  if (tail.length > _tickerChars) tail = tail.substring(tail.length - _tickerChars);
  return tail.replaceAll('**', '').replaceAll(_blankRun, '\n').trimLeft();
}

const _tickerChars = 2000;

/// The fluid window's text. [thinkingTickerText] drops a character off the front for
/// every new one, and past [_tickerChars] that rewraps everything on every update. Here
/// the cut stands still for [_fluidCutStep] characters, and lands on a line break when
/// there is one, so the last lines keep their wrapping.
@visibleForTesting
String fluidTickerText(String text) {
  var tail = text.trimRight();
  if (tail.length > _tickerChars) {
    var cut = ((tail.length - _tickerChars) ~/ _fluidCutStep + 1) * _fluidCutStep;
    cut = math.min(cut, tail.length);
    final breakAt = tail.indexOf('\n', cut);
    if (breakAt >= 0 && breakAt - cut < _fluidCutStep) cut = breakAt + 1;
    tail = tail.substring(cut);
  }
  return tail.replaceAll('**', '').replaceAll(_blankRun, '\n').trimLeft();
}

const _fluidCutStep = 600;

/// [ThinkingTicker] on the fluid tier: the same three-line window, in continuous
/// motion. What made the plain one stutter: text arrives in lumps, each new line starts
/// its own 160ms move and then stops dead, and a long thought rewraps on every update.
///
/// Here the text is paced ([StreamPacer]), and the window holds the text by its bottom
/// edge: a new line only adds to how far the text still has to rise, and that distance
/// is worked off at a speed matched to how fast lines are coming. Between updates only
/// a transform changes; the text isn't laid out again. Lines leave through a soft edge.
class _FluidTicker extends StatefulWidget {
  const _FluidTicker({required this.text});

  final String text;

  @override
  State<_FluidTicker> createState() => _FluidTickerState();
}

class _FluidTickerState extends State<_FluidTicker> with SingleTickerProviderStateMixin {
  /// Text to show at most this often; the motion in between runs every frame.
  static const _publishEvery = 1 / 30;
  static const _minSettle = 0.09;
  static const _maxSettle = 0.45;

  late final Ticker _ticker = createTicker(_tick);
  // Not lazily: made at the first growth, it would take that growth as already shown.
  late final StreamPacer _pacer;

  /// How far the text still has to rise. Only ever a transform.
  final _behind = ValueNotifier(0.0);
  late String _shown = fluidTickerText(widget.text);

  Duration _last = Duration.zero;
  double _sincePublish = 0;
  double _height = -1;
  double _width = -1;
  double _lineHeight = -1;
  double _sinceLine = 1;

  /// How long the last lines took to come: what the rise is paced by.
  double _settle = 0.2;

  @override
  void initState() {
    super.initState();
    _pacer = StreamPacer(shown: widget.text.length);
  }

  @override
  void didUpdateWidget(_FluidTicker old) {
    super.didUpdateWidget(old);
    if (!widget.text.startsWith(old.text)) {
      _pacer.reset(widget.text.length);
      _shown = fluidTickerText(widget.text);
      // Different text, not more of it: nothing to rise.
      _height = -1;
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      unawaited(_ticker.start());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _behind.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final seconds = (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    _sinceLine += seconds;
    _pacer.advance(seconds, widget.text.length);
    _sincePublish += seconds;
    final behind = _behind.value;
    if (behind > 0.1) {
      _behind.value = behind * math.exp(-seconds / _settle);
    } else if (behind != 0) {
      _behind.value = 0;
    }
    // The last of it goes out at once: the ticker is about to stop.
    if (_sincePublish >= _publishEvery || _pacer.caughtUp(widget.text.length)) {
      _sincePublish = 0;
      final next = fluidTickerText(widget.text.substring(0, _pacer.shown));
      if (next != _shown) setState(() => _shown = next);
    }
    if (_pacer.caughtUp(widget.text.length) && _behind.value == 0) _ticker.stop();
  }

  /// Text height at [width], with what growing by a line means for the motion.
  double _measure(TextStyle? style, TextScaler scaler, double width, double lineHeight, double window, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    // Only what goes past the window has to rise: below that the text grows into the
    // space it has, and any distance saved up would jump when the window fills.
    final past = math.max(_height, window);
    // A wider line or larger type grows the text too, but that isn't a new line.
    if (_width == width && _lineHeight == lineHeight && _height >= 0 && height > past) {
      final added = height - past;
      if (added < lineHeight * 3) {
        _settle = (0.5 * _settle + 0.5 * _sinceLine * 0.5).clamp(_minSettle, _maxSettle);
        _sinceLine = 0;
      }
      // Set during build for the transform below it: nothing has painted yet. A big lump
      // rises too, from no further down than the window is tall.
      _behind.value = math.min(_behind.value + added, window);
    }
    _height = height;
    _width = width;
    _lineHeight = lineHeight;
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final style = StreamRow.detail(context);
    final scaler = MediaQuery.textScalerOf(context);
    final lineHeight = scaler.scale(style?.fontSize ?? 13) * (style?.height ?? 1.3);
    final window = lineHeight * ThinkingTicker.rows;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = _measure(style, scaler, width, lineHeight, window, _shown);
        final overflows = height > window;
        final text = OverflowBox(
          // Short of a full window it starts at the top; past that, by the bottom edge.
          alignment: overflows ? AlignmentDirectional.bottomStart : AlignmentDirectional.topStart,
          minHeight: 0,
          maxHeight: double.infinity,
          child: SizedBox(
            width: width,
            child: Text(_shown, style: style),
          ),
        );
        return SizedBox(
          width: width,
          height: window,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) {
              final soft = overflows ? (lineHeight * 0.7 / rect.height).clamp(0.0, 0.5) : 0.0;
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Color(0x00000000), Color(0xFF000000)],
                stops: [0, soft == 0 ? 0.001 : soft],
              ).createShader(rect);
            },
            child: ClipRect(
              child: ValueListenableBuilder<double>(
                valueListenable: _behind,
                child: text,
                // Under a full window the text is just growing downward: nothing to rise.
                builder: (context, behind, child) =>
                    Transform.translate(offset: Offset(0, overflows ? behind : 0), child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

final _blankRun = RegExp(r'\n[ \t]*(\n[ \t]*)+');

/// Golden and geometry tests pump the pill without a ProviderScope; there is
/// no engine to ask then, so the plain text shows.
bool _hasProviderScope(BuildContext context) {
  try {
    ProviderScope.containerOf(context, listen: false);
    return true;
  } on StateError {
    return false;
  }
}

class _TranslationHolder {
  ReasoningTranslation? controller;

  String? language;

  bool showTranslation = false;

  void reset() {
    controller?.dispose();
    controller = null;
    showTranslation = false;
  }

  void dispose() => controller?.dispose();
}

class _TranslatableReasoning extends ConsumerStatefulWidget {
  const _TranslatableReasoning({
    required this.text,
    required this.active,
    required this.holder,
    required this.onBodyTap,
  });

  final String text;
  final bool active;
  final _TranslationHolder holder;

  final VoidCallback onBodyTap;

  @override
  ConsumerState<_TranslatableReasoning> createState() => _TranslatableReasoningState();
}

class _TranslatableReasoningState extends ConsumerState<_TranslatableReasoning> {
  ReasoningTranslation? _listening;

  @override
  void initState() {
    super.initState();
    _listen(widget.holder.controller);
  }

  @override
  void didUpdateWidget(_TranslatableReasoning old) {
    super.didUpdateWidget(old);
    _listen(widget.holder.controller);
    if (old.text != widget.text || old.active != widget.active) {
      widget.holder.controller?.update(widget.text, running: widget.active);
    }
  }

  @override
  void dispose() {
    _listening?.removeListener(_changed);
    super.dispose();
  }

  void _listen(ReasoningTranslation? controller) {
    if (identical(controller, _listening)) return;
    _listening?.removeListener(_changed);
    _listening = controller?..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _start(CotTranslationLimits limits, ReasoningTranslator translator) {
    final holder = widget.holder;
    final sessionId = ref.read(currentSessionProvider);
    holder.language = reasoningUiLanguage;
    final controller = holder.controller ??= ReasoningTranslation(
      maxTextChars: limits.maxTextChars,
      translate: (text) => translator(text, limits: limits, sessionId: sessionId),
    );
    _listen(controller);
    setState(() => holder.showTranslation = true);
    controller.update(widget.text, running: widget.active);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final holder = widget.holder;
    if (holder.controller != null && holder.language != reasoningUiLanguage) holder.reset();
    final controller = holder.controller;
    final limits = ref.watch(cotTranslationProvider).value;
    final translator = ref.watch(reasoningTranslatorProvider);
    final offered =
        limits != null &&
        translator != null &&
        reasoningNeedsTranslation(widget.text, limits.targetFor(reasoningUiLanguage));
    final failed = controller?.failed ?? false;
    final showing = holder.showTranslation && controller != null && !failed;
    final body = _CollapsibleReasoningBody(
      onCollapse: widget.onBodyTap,
      child: MarkdownBody(
        text: showing ? controller.text.trim() : widget.text,
        streaming: widget.active,
        secondary: true,

        selectable: false,
      ),
    );
    if (controller == null && !offered) return body;

    final tools = <Widget>[
      if (controller == null)
        _TranslateChip(icon: AppIcons.translate, label: l10n.chatTranslate, onTap: () => _start(limits!, translator!))
      else if (failed) ...[
        Text(
          l10n.chatTranslationUnavailable,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: DshColors.of(context).textTertiary),
        ),
        const SizedBox(width: 8),
        _TranslateChip(icon: AppIcons.retry, label: l10n.commonRetry, onTap: controller.retry),
      ] else
        _TranslateChip(
          icon: AppIcons.translate,
          label: showing ? l10n.chatViewOriginal : l10n.chatViewTranslation,
          onTap: () => setState(() => holder.showTranslation = !holder.showTranslation),
        ),
      if (controller != null && controller.pending && !failed) ...[
        const SizedBox(width: 10),
        Semantics(
          label: l10n.chatTranslating,
          child: SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: DshColors.of(context).textTertiary),
          ),
        ),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: tools),
        ),
        body,
      ],
    );
  }
}

class _TranslateChip extends StatelessWidget {
  const _TranslateChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  void _settings(BuildContext context) => unawaited(openSettingsPage(context, 'cot-translation'));

  static const height = 26.0;
  static const padding = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurfaceVariant;
    return Pressable(
      onTap: onTap,
      onLongPress: () => _settings(context),
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: padding),
        decoration: ShapeDecoration(
          color: dark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.onSurface.withValues(alpha: 0.06),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.labelMedium?.copyWith(fontSize: 12.5, height: 1.2, color: fg)),
          ],
        ),
      ),
    );
  }
}
