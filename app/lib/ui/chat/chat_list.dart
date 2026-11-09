// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.
// Local changes: rewritten around a centre-anchored CustomScrollView (see
// [ChatList]); the jump-to-bottom control is a chrome-glass circle.

import 'dart:async';
import 'dart:math' as math;

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../pets/pet_signals.dart' show petHeadroomProvider;
import '../../plugins/native/native_surface.dart' show nativeTurnNoteProvider;
import '../../state/agents_state.dart' show hostSessionsProvider, selectConversation;
import '../../state/artifacts.dart';
import '../../state/attachments.dart' show DraftAttachment;
import '../../state/chat_reveal.dart';
import '../../state/chat_state.dart';
import '../../state/connection_state.dart';
import '../../state/hosts_state.dart' show HostKind, activeHostProvider;
import '../../state/regenerate.dart';
import '../../state/sessions_state.dart';
import '../../state/settings_state.dart';
import '../common/app_dialog.dart';
import '../common/bleed.dart';
import '../common/ui_trace.dart';
import '../pets/pet_perch.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import '../update/update_sheet.dart' show checkForUpdates;
import 'chat_rows.dart';
import 'chat_rows_cache.dart';
import 'media/media_paths.dart';
import 'composer_toast.dart';
import 'dsh_ui/dsh_ui.dart';
import 'render/markdown_image.dart';
import 'trajectory_sheet.dart';
import 'widgets/approval_card.dart';
import 'widgets/artifact_card.dart';
import 'widgets/assistant_message.dart';
import 'widgets/attachments.dart';
import 'widgets/background_task_notice.dart';
import 'widgets/change_card.dart';
import 'widgets/command_row.dart';
import 'widgets/notice_row.dart';
import 'widgets/question_card.dart';
import 'widgets/stream_motion.dart';
import 'widgets/tool_row.dart';
import 'widgets/turn_failure_text.dart' show modelRefusalCodes;
import 'widgets/turn_footnote.dart';
import 'widgets/turn_process.dart';
import 'widgets/user_bubble.dart';

/// Sends [text] with [images] in conversation [sessionId] (a fork just made).
typedef ResendPrompt = Future<void> Function(String sessionId, String text, List<DraftAttachment> images);

///

///

///
/// ```

/// ```
///

class ChatList extends ConsumerStatefulWidget {
  const ChatList({
    super.key,
    required this.sessionId,
    required this.topInset,
    this.scrolledUnder,
    required this.bottomInset,
    this.onWithdraw,
    this.onSendNow,
    this.onEditPrompt,
    this.onResend,
    this.onQuote,
    this.onToast,
    this.onSwitchModel,
  });

  final String sessionId;

  final double topInset;

  /// How far the viewport extends below the composer's top edge. Overflowing
  /// content stops `bottomInset + 8` above the viewport bottom; short content
  /// stays aligned to the top instead.
  final double bottomInset;

  /// Set to how far content has scrolled under the top bar (0..1); the header
  /// fades in its backdrop by it.
  final ValueNotifier<double>? scrolledUnder;

  final ValueChanged<PendingPrompt>? onWithdraw;

  /// leaves it out.
  final ValueChanged<PendingPrompt>? onSendNow;

  /// ends just before it is open; the screen puts the text into the composer.
  /// Null leaves the action out.
  final ValueChanged<String>? onEditPrompt;

  /// is open and selected, with that prompt's text and images; the screen
  /// sends them there (and puts them back into the composer if that fails).
  /// Null leaves the action out.
  final ResendPrompt? onResend;

  /// screen puts it above the composer. Null leaves the action out.
  final ValueChanged<String>? onQuote;

  /// null: the plain SnackBar.
  final ComposerToast? onToast;

  /// the model sheet for this conversation. Null leaves the action out.
  final VoidCallback? onSwitchModel;

  @override
  ConsumerState<ChatList> createState() => _ChatListState();
}

class _ChatListState extends ConsumerState<ChatList> with SingleTickerProviderStateMixin {
  late final _scroll = _TopBoundedScrollController(_leadingBoundary);
  final _centerKey = UniqueKey();
  final _beforeKey = GlobalKey();
  final _historyKey = GlobalKey();
  double _anchorPixels = 0;

  // A centered viewport clamps its leading extent to <= 0. With a short
  // reverse segment that leaves empty space above the first row. Its actual
  // leading boundary can be positive. Read geometry during content-dimension
  // negotiation, after both sliver lists have been laid out; no frame callback
  // or change to the stable center coordinate is needed.
  double? _leadingBoundary() {
    final before = _beforeKey.currentContext?.findRenderObject();
    final header = _historyKey.currentContext?.findRenderObject();
    if (before is! RenderSliver || header is! RenderSliver) return null;
    final rows = before.geometry?.scrollExtent;
    final history = header.geometry?.scrollExtent;
    if (rows == null || history == null) return null;
    return _anchorPixels - rows - history - widget.topInset - AppSpace.sm;
  }

  bool _pinned = true;

  bool _held = false;

  late final _physics = _FollowPhysics(() => _pinned && !_held && _fingers == 0, glides: () => _glidable);

  /// Fingers on the list. Any `jumpTo` ends the drag under them for good (it goes idle,
  /// and the rest of that gesture moves nothing), so while one rests here or the list is
  /// moving on its own, following waits: the list is the user's.
  int _fingers = 0;

  bool get _userHasList => _fingers > 0 || (_scroll.hasClients && _scroll.position.isScrollingNotifier.value);

  /// Heading up, by finger or fling: however near the bottom, that is not "at the bottom".
  bool _goingUp = false;

  /// Following waited for the user; it picks up when they let go.
  bool _followWaiting = false;

  /// The next follow overrides the user: they asked for the bottom, or just sent something.
  bool _followNow = false;

  /// The fluid tier: following glides to a new line instead of snapping to it. Real
  /// scrolling, so everything else about the list is as it was; the new line only starts
  /// a little lower, behind the composer.
  bool _fluid = false;

  /// The glide is ours: its scroll updates say nothing about what the user wants.
  bool _gliding = false;
  bool _snapNext = false;
  late final Ticker _glide = createTicker(_onGlide);
  Duration _glideLast = Duration.zero;

  /// Time constant of the glide: a line (about 28) lands in some 150ms, and lines
  /// arriving faster than that blend into one steady motion.
  static const _glideSeconds = 0.07;

  /// Further than this is not a next line: a jump, as before.
  static const _glideReach = 240.0;

  bool get _glidable => _fluid && !_snapNext;

  void _startGlide() {
    _gliding = true;
    if (_glide.isActive) return;
    _glideLast = Duration.zero;
    _glide.start();
  }

  void _stopGlide() {
    _gliding = false;
    if (_glide.isActive) _glide.stop();
  }

  void _onGlide(Duration elapsed) {
    if (!mounted || !_scroll.hasClients || !_pinned || _held) return _stopGlide();
    if (_userHasList) {
      _followWaiting = true;
      return _stopGlide();
    }
    final seconds = (elapsed - _glideLast).inMicroseconds / Duration.microsecondsPerSecond;
    _glideLast = elapsed;
    final p = _scroll.position;
    final gap = p.maxScrollExtent - p.pixels;
    if (gap <= 0.5 || gap > _glideReach) {
      if (gap != 0) p.jumpTo(p.maxScrollExtent);
      return _stopGlide();
    }
    p.jumpTo(p.pixels + gap * (1 - math.exp(-seconds / _glideSeconds)));
  }

  final _showJump = ValueNotifier<bool>(false);
  final _hasNew = ValueNotifier<bool>(false);

  String? _splitKey;
  bool _splitChosen = false;

  List<ChatRow> _rows = const [];
  final _rowCache = ChatRowsCache();
  Map<String, int> _index = const {};
  Object? _rowsInputs;
  Set<String> _autoAnswered = const {};

  double? _lastViewport;
  int _lastPendingCount = 0;
  bool _followScheduled = false;

  /// The turn is running (queued bubbles can still be moved into it).
  bool _running = false;

  String? _forkingId;

  String? _regeneratingId;

  Set<int> _runningTurns = const {};

  final Set<String> _settling = {};

  final Map<String, int> _fresh = {};

  Future<void> _respond(ApprovalRequest request, ApprovalDecision decision) =>
      ref.read(chatProvider(widget.sessionId).notifier).respond(request, decision);

  Future<void> _allowAll(ApprovalRequest request) =>
      ref.read(chatProvider(widget.sessionId).notifier).allowAll(request);

  Future<void> _answer(UserQuestionRequest request, List<QuestionAnswer> answers) =>
      ref.read(chatProvider(widget.sessionId).notifier).answer(request, answers);

  Future<void> _rejectQuestion(UserQuestionRequest request) =>
      ref.read(chatProvider(widget.sessionId).notifier).rejectQuestion(request);

  @override
  void dispose() {
    _glide.dispose();
    _scroll.dispose();
    _showJump.dispose();
    _hasNew.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bottomInset != widget.bottomInset && _pinned) _follow();
  }

  // ---------------------------------------------------------------------------

  bool _atBottom([double slop = 24]) {
    if (!_scroll.hasClients) return true;
    final p = _scroll.position;
    return p.maxScrollExtent - p.pixels <= slop;
  }

  void _follow() {
    if (_followScheduled) return;
    _followScheduled = true;
    var attempts = 0;
    void step(Duration _) {
      if (!mounted || !_scroll.hasClients || !_pinned) {
        _followScheduled = false;
        return;
      }
      final p = _scroll.position;
      if (_followNow) {
        _followNow = false;
        // Ends a fling or a drag in progress.
        p.jumpTo(p.pixels);
      } else if (_userHasList) {
        _followScheduled = false;
        _followWaiting = true;
        return;
      }
      if (uiTraceEnabled && p.pixels != p.maxScrollExtent) {
        uiTrace('chat-list', 'follow', {'from': p.pixels, 'to': p.maxScrollExtent, 'held': _held, 'attempt': attempts});
      }
      final gap = p.maxScrollExtent - p.pixels;
      if (_glidable && gap > 0 && gap <= _glideReach) {
        _followScheduled = false;
        _startGlide();
        return;
      }
      _snapNext = false;
      if (p.pixels != p.maxScrollExtent) p.jumpTo(p.maxScrollExtent);
      attempts++;
      if (attempts < 4 && _scroll.position.pixels < p.maxScrollExtent - 0.5) {
        WidgetsBinding.instance.addPostFrameCallback(step);
      } else {
        _followScheduled = false;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback(step);
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _resumeFollow() {
    if (!_followWaiting || _userHasList) return;
    _followWaiting = false;
    if (!_pinned) return;
    _held = false;
    _follow();
  }

  void _onFingerUp() {
    if (_fingers > 0) _fingers--;
    _resumeFollow();
  }

  void jumpToBottom() {
    _pinned = true;
    _goingUp = false;
    _followNow = true;
    _snapNext = true;
    _stopGlide();
    _hasNew.value = false;
    _showJump.value = false;
    _follow();
  }

  void _reportScrolledUnder(ScrollMetrics m) {
    final target = widget.scrolledUnder;
    if (target == null) return;
    target.value = (m.extentBefore / 24).clamp(0.0, 1.0);
  }

  /// A dimension correction can end a ballistic activity during layout.
  /// Publish notifier/provider changes only after that frame, using the
  /// final geometry rather than a snapshot from an intermediate layout pass.
  void _consumeScrollMetrics(ScrollMetrics metrics, void Function(ScrollMetrics) consume) {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      final session = widget.sessionId;
      final position = _scroll.hasClients ? _scroll.position : null;
      _afterFrame(() {
        if (_scroll.hasClients && widget.sessionId == session && identical(_scroll.position, position)) {
          consume(_scroll.position);
        }
      });
    } else {
      consume(metrics);
    }
  }

  bool _onMetrics(ScrollMetricsNotification n) {
    if (n.depth != 0) return false;
    _consumeScrollMetrics(n.metrics, _applyMetrics);
    return false;
  }

  void _applyMetrics(ScrollMetrics metrics) {
    _reportScrolledUnder(metrics);
    // The reveal grows the reply between state updates.
    if (_glidable && _pinned && !_held && _scroll.hasClients && !_atBottom(0.5) && _atBottom(_glideReach)) {
      if (_userHasList) {
        _followWaiting = true;
      } else {
        _startGlide();
      }
    } else if (_glidable && _pinned && !_held && _scroll.hasClients && !_atBottom(_glideReach)) {
      // Too far to glide, with no new state to set off a follow: the jump it would do.
      if (_userHasList) {
        _followWaiting = true;
      } else {
        _follow();
      }
    }

    if (_held && _pinned && !_atBottom()) {
      _pinned = false;
      if (!_showJump.value && !_atBottom(160)) _showJump.value = true;
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    _consumeScrollMetrics(n.metrics, (metrics) => _applyScroll(n, metrics));
    return false;
  }

  void _applyScroll(ScrollNotification n, ScrollMetrics metrics) {
    _reportScrolledUnder(metrics);
    if (n is UserScrollNotification) _held = false;
    if (n is UserScrollNotification && n.direction == ScrollDirection.forward) {

      _pinned = false;
      _goingUp = true;
    } else if (n is UserScrollNotification && n.direction == ScrollDirection.reverse) {
      _goingUp = false;
    } else if (_gliding) {
      // Our own motion: still following, however far behind it is for now.
    } else if (n is ScrollEndNotification) {
      _goingUp = false;
      // Behind only because following waited: that isn't the user leaving.
      if (!_followWaiting || !_pinned) _pinned = _atBottom();
      // The activity that ended is still being replaced.
      scheduleMicrotask(() {
        if (mounted) _resumeFollow();
      });
    } else if (n is ScrollUpdateNotification && !_goingUp && !_followWaiting) {
      _pinned = _atBottom();
    }
    // Show only after leaving the bottom area; once shown, keep it until
    // the list is pinned again. A single threshold reverses the fade on
    // every tiny scroll/layout oscillation around 160.
    final far = !_atBottom(_showJump.value ? 24 : 160);
    if (_showJump.value != far) _showJump.value = far;
    if (!far) _hasNew.value = false;
    _maybeLoadOlder(metrics);
  }

  void _maybeLoadOlder(ScrollMetrics metrics) {
    if (metrics.pixels - metrics.minScrollExtent > 800) return;
    final state = ref.read(chatProvider(widget.sessionId));
    if (state.hasMoreHistory && !state.loadingOlder && !state.loading) {
      ref.read(chatProvider(widget.sessionId).notifier).loadOlder();
    }
  }

  // ---------------------------------------------------------------------------

  void _deriveRows(ChatState s, {required bool foldTurns, List<TurnArtifacts> artifacts = const []}) {
    if (s.loading || !foldTurns) {
      _settling.clear();
    } else {
      for (final turn in s.turns) {
        if (turn.running || !_runningTurns.contains(turn.startSeq) || !(turn.endReason?.isCompleted ?? false)) {
          continue;
        }

        if (_pinned) _settling.add('tp${turn.startSeq}');
      }
    }
    _runningTurns = {
      if (!s.loading)
        for (final turn in s.turns)
          if (turn.running) turn.startSeq,
    };
    final inputs = (
      foldTurns,
      artifacts,
      s.items,
      s.approvals,
      s.questions,
      s.pending,
      s.running,
      s.autoAnswered,
      s.commands,
      s.turns,
    );
    if (_rowsInputs == inputs) return;
    _rowsInputs = inputs;
    _held = false;
    final previousLength = _rows.length;
    final previousKeys = _index;
    final hadPending = _rows.any((r) => r is PendingRow);
    _rows = _rowCache.update(s, foldTurns: foldTurns, artifacts: artifacts);
    _index = _rowCache.index;

    for (final row in _rows) {
      if (row is TurnProcessRow &&
          row.cut != null &&
          _settling.contains('tp${row.trace.startSeq}') &&
          _settling.add(row.key)) {
        final key = row.key;
        _afterFrame(() => _settling.remove(key));
      }
    }
    _settling.removeWhere((key) => !_index.containsKey(key));
    _autoAnswered = s.autoAnswered;
    _markFresh(previousKeys, hadPending: hadPending, loading: s.loading);

    if (s.pending.length > _lastPendingCount) {

      _pinned = true;
      _goingUp = false;
      _followNow = true;
      _afterFrame(() => _hasNew.value = false);
    }
    _lastPendingCount = s.pending.length;

    if (s.loading) {

      _splitChosen = false;
      _splitKey = null;
    } else if (!_splitChosen) {
      _splitChosen = true;
      _splitKey = _lastStableKey();
    } else if (_splitKey != null && !_index.containsKey(_splitKey)) {

      final folded = _rows.whereType<TurnProcessRow>().where((row) => row.rows.any((child) => child.key == _splitKey));
      _splitKey = folded.isEmpty ? _lastStableKey() : folded.first.key;
    }

    if (uiTraceEnabled) {
      uiTrace('chat-list', 'rows', {
        'rows': _rows.length,
        'split': _split,
        'loading': s.loading,
        'pinned': _pinned,
        'held': _held,
      });
    }
    if (s.hasMoreHistory) {

      _afterFrame(() {
        if (_scroll.hasClients) _maybeLoadOlder(_scroll.position);
      });
    }

    if (_pinned) {
      _follow();
    } else if (_rows.length != previousLength || s.running) {
      _afterFrame(() => _hasNew.value = true);
    }
  }

  ///

  void _markFresh(Map<String, int> previous, {required bool hadPending, required bool loading}) {
    _fresh.removeWhere((key, _) => !_index.containsKey(key));
    if (!_splitChosen || loading) return;
    final split = _split;
    var order = 0;
    for (var i = split; i < _rows.length; i++) {
      final row = _rows[i];
      if (previous.containsKey(row.key)) continue;
      final animate = switch (row) {
        PendingRow() ||
        AssistantRow() ||
        ToolCallRow() ||
        NoticeRowData() ||
        ApprovalRow() ||
        QuestionRow() ||
        ChangeCardRow() ||
        ArtifactCardRow() ||
        CommandNoticeRow() ||
        TurnFootnoteRow() => true,
        UserRow() => !hadPending,
        _ => false,
      };
      if (animate) _fresh[row.key] = order++;
    }
  }

  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  String? _lastStableKey() {
    for (var i = _rows.length - 1; i >= 0; i--) {
      if (_rows[i].stable) return _rows[i].key;
    }
    return null;
  }

  int get _split {
    final key = _splitKey;
    if (key == null) return 0;
    final i = _index[key];
    return i == null ? 0 : i + 1;
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(chatProvider(widget.sessionId));
    _running = s.running;
    _deriveRows(
      s,
      foldTurns: ref.watch(settingsProvider.select((s) => s.foldCompletedTurns)),
      artifacts: ref.watch(sessionArtifactsProvider(widget.sessionId)),
    );
    final rows = _rows;
    final split = _split;
    _fluid = AppMotion.fluid(context);

    // Images in replies read this conversation's workspace.
    final headroom = ref.watch(petHeadroomProvider);
    ref.listen(petHeadroomProvider, (_, _) {
      if (_pinned) _follow();
    });
    // Back in the app to read a result (a finished phone task): the newest line.
    ref.listen(chatRevealProvider, (_, reveal) {
      if (reveal?.sessionId == widget.sessionId) jumpToBottom();
    });
    return MarkdownImageScope(
      sessionId: widget.sessionId,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.maxHeight;
          if (_lastViewport != null && _lastViewport != viewport && _pinned) {
            _follow();
          }
          _lastViewport = viewport;
          // The chat page's pet stands over the composer: the last line
          // stops clear of it (0 without a pet).
          final bottomPad = widget.bottomInset + AppSpace.sm + headroom;
          final anchor = viewport <= 0 ? 1.0 : ((viewport - bottomPad) / viewport).clamp(0.0, 1.0);
          _anchorPixels = viewport * anchor;

          return Stack(
            children: [
              Listener(
                onPointerDown: (_) {
                  _fingers++;
                  // The list stops where it is, under the finger.
                  if (_gliding) {
                    _stopGlide();
                    _followWaiting = true;
                  }
                  _held = true;
                },
                onPointerUp: (_) => _onFingerUp(),
                onPointerCancel: (_) => _onFingerUp(),
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: _onMetrics,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: CustomScrollView(
                      controller: _scroll,
                      physics: _physics,
                      // Material's stretch indicator moves the painted first
                      // row even while clamping physics holds its pixels.
                      scrollBehavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                      center: _centerKey,
                      anchor: anchor,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        SliverToBoxAdapter(child: SizedBox(height: widget.topInset + AppSpace.sm)),
                        SliverToBoxAdapter(
                          key: _historyKey,
                          child: _HistoryHeader(
                            loading: s.loadingOlder || (s.loading && rows.isEmpty),
                            hasMore: s.hasMoreHistory,
                          ),
                        ),
                        SliverList(
                          key: _beforeKey,
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _buildRow(split - 1 - i),
                            childCount: split,
                            findChildIndexCallback: (key) {
                              final i = key is ValueKey<String> ? _index[key.value] : null;
                              return i == null || i >= split ? null : split - 1 - i;
                            },
                          ),
                        ),
                        SliverList(
                          key: _centerKey,
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _buildRow(split + i),
                            childCount: rows.length - split,
                            findChildIndexCallback: (key) {
                              final i = key is ValueKey<String> ? _index[key.value] : null;
                              return i == null || i < split ? null : i - split;
                            },
                          ),
                        ),
                        SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                right: math.max(0.0, (constraints.maxWidth - AppSpace.readingWidth) / 2) + AppSpace.floatInset,
                bottom: widget.bottomInset + 12,
                // The pet keeps out of the key's way while it shows.
                child: ValueListenableBuilder<bool>(
                  valueListenable: _showJump,
                  builder: (context, visible, child) => PetAvoid(active: visible, child: child!),
                  child: _JumpToBottom(
                    visible: _showJump,
                    hasNew: _hasNew,
                    waiting: s.questions.length + s.approvals.where((a) => !s.autoAnswered.contains(a.eventId)).length,
                    onTap: jumpToBottom,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow(int index) {
    final row = _rows[index];
    final previous = index > 0 ? _rows[index - 1] : null;
    final fresh = _fresh.remove(row.key);
    final padding = EdgeInsets.fromLTRB(AppSpace.gutter, _gapBefore(row, previous), AppSpace.gutter, 0);
    final body = StreamFadeIn(
      enabled: fresh != null,
      index: fresh ?? 0,
      rise: row is UserRow || row is PendingRow,
      child: _rowWidget(row),
    );
    return KeyedSubtree(
      key: ValueKey<String>(row.key),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpace.readingWidth),

          child: row is AssistantRow

              ? AnimatedPadding(
                  duration: AppMotion.of(context, AppMotion.quick),
                  curve: AppMotion.std,
                  padding: padding,
                  child: SizedBox(width: double.infinity, child: body),
                )
              : Container(width: double.infinity, padding: padding, child: body),
        ),
      ),
    );
  }

  static bool _isProcess(ChatRow? row) => switch (row) {
    ToolCallRow() || ToolGroupRow() || CommandNoticeRow() => true,
    AssistantRow(:final item) => item.text.trim().isEmpty && (item.reasoning.trim().isNotEmpty || item.streaming),
    NoticeRowData(:final item) => item.kind != 'error',
    _ => false,
  };
  static bool _isUser(ChatRow? row) => switch (row) {
    UserRow() => true,
    PendingRow(:final prompt) => !prompt.isBackgroundTask,
    _ => false,
  };

  static double _gapBefore(ChatRow row, ChatRow? previous) {
    if (previous == null) return 0;
    if (_isUser(row)) return _isUser(previous) ? AppSpace.sm : AppSpace.xxl;
    if (_isProcess(row) && _isProcess(previous)) return 0;
    if (row is ApprovalRow || row is QuestionRow || row is ChangeCardRow || row is ArtifactCardRow) {
      return AppSpace.md;
    }
    if (row is TurnFootnoteRow) return AppSpace.xs;
    return AppSpace.sm;
  }

  Widget _pendingBubble(PendingPrompt prompt) {
    if (prompt.isBackgroundTask) {
      return BackgroundTaskNotice(key: ValueKey((widget.sessionId, prompt.requestId, prompt.inboxId)), prompt: prompt);
    }
    if (dshUiReplyChip(prompt.text) case final label? when !prompt.failed) {
      return DshUiReplyChip(label: label, pending: true);
    }
    final chat = ref.read(chatProvider(widget.sessionId).notifier);
    final (label, icon) = switch ((prompt.slot, prompt.mode)) {
      // In the inbox with no turn to take it: stopped elsewhere, or before
      // this app looked.
      (_?, _) when !_running => (appL10n.chatUnsent, AppIcons.paused),
      (InboxSlot.nextStep, _) => (appL10n.chatSteerNextStep, AppIcons.steer),
      (InboxSlot.nextTurn, _) => (appL10n.chatQueuedAfterTurn, AppIcons.queued),
      (null, SendMode.steer) => (appL10n.chatSteering, AppIcons.steer),
      (null, SendMode.queue) => (appL10n.chatQueued, AppIcons.queued),
      (null, SendMode.interrupt) => (appL10n.chatStoppingTurn, AppIcons.interrupt),
      (null, SendMode.now) => (appL10n.chatSending, AppIcons.queued),
    };
    final canAct = prompt.inboxId != null;
    return UserBubble(
      text: prompt.text,
      attachments: prompt.attachments.isEmpty ? null : SentAttachments.pending(prompt.attachments),
      pendingLabel: prompt.failed ? appL10n.chatFailedSubmission : label,
      pendingIcon: prompt.failed ? AppIcons.error : icon,
      pendingActions: [
        if (prompt.failed && prompt.resendable) (appL10n.chatEditFailedSubmission, () => _editFailedSubmission(prompt)),
        if (canAct && prompt.resendable && widget.onSendNow != null)
          (_running ? appL10n.chatSendNow : appL10n.commonSend, () => widget.onSendNow!(prompt)),
        if (canAct && _running && prompt.slot == InboxSlot.nextTurn)
          (appL10n.chatSwitchToSteer, () => chat.steerQueued(prompt)),
        if (canAct && widget.onWithdraw != null) (appL10n.chatWithdraw, () => widget.onWithdraw!(prompt)),
      ],
    );
  }

  Future<void> _editFailedSubmission(PendingPrompt prompt) async {
    final sessionId = widget.sessionId;
    final client = ref.read(activeConnectionProvider).value?.client;
    final generation = client?.mux.generation;
    final readyNumber = client?.mux.lastReadyGenerationNumber;
    var retired = false;
    final connection = ref.listenManual(activeConnectionProvider.select((c) => c.value?.client), (_, next) {
      if (!identical(next, client)) retired = true;
    });
    var text = prompt.text;
    try {
      final edited = await showAppDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(appL10n.chatEditFailedSubmission),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: prompt.text,
                  onChanged: (value) => text = value,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 8,
                ),
                if (prompt.attachments.isNotEmpty) SentAttachments.pending(prompt.attachments),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog), child: Text(appL10n.commonCancel)),
            TextButton(onPressed: () => Navigator.pop(dialog, text), child: Text(appL10n.commonSend)),
          ],
        ),
      );
      if (edited == null ||
          !mounted ||
          retired ||
          widget.sessionId != sessionId ||
          !identical(ref.read(activeConnectionProvider).value?.client, client) ||
          !identical(client?.mux.generation, generation) ||
          client?.mux.lastReadyGenerationNumber != readyNumber) {
        return;
      }
      await ref.read(chatProvider(sessionId).notifier).retryFailed(prompt, edited);
    } finally {
      connection.close();
    }
  }

  // ---------------------------------------------------------------------------

  Widget _reply(AssistantChatItem item, bool showActions, TurnTrace? footnote) {
    // A picture a media card shows is not drawn again in the reply.
    if (withoutShownImages(item.text, ref.read(sessionMediaPathsProvider(widget.sessionId))) case final text?) {
      item = replyWithText(item, text);
    }
    final chat = ref.read(chatProvider(widget.sessionId).notifier);
    final branchable = chat.branchPointAfter(item) != null;

    final prompt = branchable && widget.onResend != null
        ? regenerablePrompt(ref.read(chatProvider(widget.sessionId)), item)
        : null;
    final message = AssistantMessage(
      item: item,
      showActions: showActions,
      onBranch: branchable ? () => _branch(item) : null,
      branching: _forkingId == item.id,
      onRegenerate: prompt == null ? null : () => _regenerate(item, prompt),
      regenerating: _regeneratingId == item.id,
      onQuote: widget.onQuote,
      footnote: footnote == null ? null : _footnote(footnote),
    );
    // Always in a scope, so a reply that grows a visual block keeps its
    // State; only replies that carry one pay for working out whether it can
    // still be answered.
    final s = ref.read(chatProvider(widget.sessionId));
    return DshUiScope(
      sessionId: widget.sessionId,
      messageId: item.id,
      state: !item.text.contains('dsh-ui') && !item.text.contains('{')
          ? DshUiState.expired
          : dshUiStateFor(
              items: s.items,
              messageId: item.id,
              running: s.running,
              pending: [for (final p in s.pending) p.text],
            ),
      onReply: chat.send,
      onAskResend: chat.send,
      child: message,
    );
  }

  Widget _footnote(TurnTrace trace) => Consumer(
    builder: (context, ref, _) => TurnFootnote(
      trace: trace,
      notes: ref.watch(nativeTurnNoteProvider((widget.sessionId, trace.turn))),
      onTap: () => showTrajectorySheet(context, sessionId: widget.sessionId, turn: trace.turn),
    ),
  );

  Future<void> _branch(AssistantChatItem item) async {
    if (_forkingId != null || _regeneratingId != null) return;
    setState(() => _forkingId = item.id);
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      final outcome = await ref.read(chatProvider(widget.sessionId).notifier).branchAfter(item);
      if (outcome == null || !mounted) return;
      _openFork(outcome, messenger, appL10n.chatContinuedInNewChat);
    } finally {
      if (mounted) setState(() => _forkingId = null);
    }
  }

  /// the fork, and let the screen send the prompt there again. The source
  /// stays as it was. A failure before the fork stays here, in the banner.
  Future<void> _regenerate(AssistantChatItem item, UserChatItem prompt) async {
    final resend = widget.onResend;
    if (resend == null || _forkingId != null || _regeneratingId != null) {
      return;
    }
    // Image loading precedes the controller operation. Keep that preparation
    // attached to the connection on which the user chose to regenerate.
    final sessionId = widget.sessionId;
    final client = ref.read(activeConnectionProvider).value?.client;
    final generation = client?.mux.generation;
    final readyGeneration = client?.mux.lastReadyGenerationNumber;
    var retired = false;
    final connection = ref.listenManual(activeConnectionProvider.select((c) => c.value?.client), (_, next) {
      if (!identical(next, client)) retired = true;
    });
    bool current() =>
        mounted &&
        !retired &&
        widget.sessionId == sessionId &&
        identical(ref.read(activeConnectionProvider).value?.client, client) &&
        identical(client?.mux.generation, generation) &&
        client?.mux.lastReadyGenerationNumber == readyGeneration;
    setState(() => _regeneratingId = item.id);
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      final chat = ref.read(chatProvider(sessionId).notifier);
      final List<DraftAttachment> images;
      try {
        images = await resendImages(prompt, (image) => sessionImageBytes(ref, sessionId, image));
      } catch (_) {
        if (current()) chat.reportError(appL10n.chatReadOriginalImageFailed);
        return;
      }
      if (!current()) return;
      final outcome = await chat.forkBeforePrompt(prompt, action: appL10n.chatRegenerateFailed);
      if (outcome == null || !current()) return;
      _openFork(outcome, messenger, appL10n.chatRegeneratedInNewChat);
      // This list goes with the switch; the screen stays and sends.
      unawaited(resend(outcome.sessionId, prompt.text, images));
    } finally {
      connection.close();
      if (mounted) setState(() => _regeneratingId = null);
    }
  }

  Future<void> _editPrompt(UserChatItem item) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final compose = widget.onEditPrompt;
    final outcome = await ref.read(chatProvider(widget.sessionId).notifier).forkBeforePrompt(item);
    if (outcome == null || !mounted) return;
    final attached = item.images.isNotEmpty || item.files.isNotEmpty;
    _openFork(outcome, messenger, attached ? appL10n.chatOpenedInNewChatReattach : appL10n.chatOpenedInNewChat);
    compose?.call(item.text);
  }

  /// Switches to the fork; the toast offers the way back.
  void _openFork(ForkOutcome outcome, ScaffoldMessengerState? messenger, String message) {
    final source = widget.sessionId;
    final current = ref.read(currentSessionProvider.notifier);
    unawaited(ref.read(sessionsProvider.notifier).refresh());
    current.select(outcome.sessionId);
    final left = outcome.leftQueued;
    final text = left == 0 ? message : appL10n.chatForkQueuedLeft(message, left);
    void back() => current.select(source);
    if (widget.onToast case final toast?) {
      toast(text, actionLabel: appL10n.chatReturnToOriginal, onAction: back);
      return;
    }
    messenger?.showSnackBar(
      SnackBar(
        content: Text(text),
        persist: false,
        action: SnackBarAction(label: appL10n.chatReturnToOriginal, onPressed: back),
      ),
    );
  }

  bool _openSubagent(String id) {
    if (!ref.read(hostSessionsProvider).containsKey(id)) return false;
    selectConversation(ref, id);
    return true;
  }

  NoticeAction? _noticeAction(NoticeChatItem notice) {
    final s = ref.read(chatProvider(widget.sessionId));
    if (s.running) return null;
    final code = notice.failure?.code ?? '';
    final refused = notice.kind == 'error' && modelRefusalCodes.contains(code);
    final repeatable = switch (notice.kind) {

      'error' =>
        !refused && !const {'AUTH', 'INVALID_CREDENTIAL', 'QUOTA'}.contains(code) && !code.startsWith('ACCOUNT_'),
      'interrupted' || 'max-tokens' => true,
      _ => false,
    };
    if (!repeatable && !refused) return null;
    final at = s.items.lastIndexOf(notice);
    if (at < 0 || s.items.skip(at + 1).any((item) => item is! NoticeChatItem || item.kind != 'retry')) {
      return null;
    }
    if (refused) {
      if (code == 'CLIENT_UPGRADE_REQUIRED' && ref.read(activeHostProvider).kind == HostKind.local) {
        return (label: appL10n.updateCheck, onPressed: () => checkForUpdates(context, ref));
      }
      final switchModel = widget.onSwitchModel;
      return switchModel == null ? null : (label: appL10n.chatSwitchModel, onPressed: switchModel);
    }
    if (s.pending.isNotEmpty) return null;
    final turn = s.turns.where((turn) => turn.endSeq == notice.seq).firstOrNull;
    if (turn == null) return null;
    UserChatItem? prompt;
    var worked = false;
    for (var i = at - 1; i >= 0 && prompt == null; i--) {
      final item = s.items[i];
      if (item is NoticeChatItem && item.kind != 'retry') break;
      if (item is UserChatItem && item.seq < turn.startSeq) break;
      switch (item) {
        case final UserChatItem item:
          prompt = item;
        case ToolChatItem():
          worked = true;
        case AssistantChatItem(:final text) when text.trim().isNotEmpty:
          worked = true;
        default:
          break;
      }
    }
    if (prompt == null) return null;
    final chat = ref.read(chatProvider(widget.sessionId).notifier);
    if (notice.kind == 'error' &&
        !worked &&
        prompt.images.isEmpty &&
        prompt.files.isEmpty &&
        prompt.text.trim().isNotEmpty) {
      final text = prompt.text;
      return (label: appL10n.commonRetry, onPressed: () => chat.send(text));
    }
    return (label: appL10n.commonContinue, onPressed: () => chat.send(appL10n.commonContinue));
  }

  Widget _rowWidget(ChatRow row) {
    return switch (row) {
      UserRow(:final item) when dshUiReplyChip(item.text) != null => DshUiReplyChip(label: dshUiReplyChip(item.text)!),
      UserRow(:final item) => UserBubble(
        text: item.text,
        attachments: item.images.isEmpty && item.files.isEmpty
            ? null
            : SentAttachments.echoed(sessionId: widget.sessionId, images: item.images, files: item.files),
        onEdit: widget.onEditPrompt == null ? null : () => _editPrompt(item),
      ),
      PendingRow(:final prompt) => _pendingBubble(prompt),
      AssistantRow(:final item, :final showActions, :final footnote) => _reply(item, showActions, footnote),
      TurnFootnoteRow(:final trace) => Bleed(
        horizontal: 8,
        child: Align(alignment: Alignment.centerLeft, child: _footnote(trace)),
      ),
      ToolCallRow(:final item, :final card) => ToolRow(
        item: item,
        card: card,
        onRespond: _respond,
        onAllowAll: _allowAll,
        autoAnswered: _autoAnswered,
        onOpenSubagent: _openSubagent,
      ),
      ToolGroupRow(:final tools, :final live) => ToolGroup(
        tools: tools,
        live: live,
        onRespond: _respond,
        onAllowAll: _allowAll,
        autoAnswered: _autoAnswered,
        onOpenSubagent: _openSubagent,
      ),
      final TurnProcessRow row => TurnProcess(
        row: row,
        settle: _settling.remove(row.key),
        buildRow: _rowWidget,
        gapBefore: _gapBefore,
      ),
      NoticeRowData(:final item) => NoticeRow(item: item, action: _noticeAction(item)),
      ChangeCardRow(:final files) => ChangeCard(files: files),
      ArtifactCardRow(:final group) => ArtifactCard(sessionId: widget.sessionId, group: group),
      CommandNoticeRow(:final notice) => CommandRow(notice: notice),
      ApprovalRow(:final request) => ApprovalCard(request: request, onRespond: _respond, onAllowAll: _allowAll),
      QuestionRow(:final request) => QuestionCard(request: request, onAnswer: _answer, onReject: _rejectQuestion),
    };
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.loading, required this.hasMore});

  final bool loading;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (!loading && !hasMore) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: Center(
        child: loading
            ? SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 1.8, color: Theme.of(context).colorScheme.primary),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _JumpToBottom extends StatelessWidget {
  const _JumpToBottom({required this.visible, required this.hasNew, required this.waiting, required this.onTap});

  final ValueListenable<bool> visible;
  final ValueListenable<bool> hasNew;
  final int waiting;
  final VoidCallback onTap;

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    final quick = AppMotion.of(context, AppMotion.quick);
    final fluid = AppMotion.fluid(context);

    final pill = GlassSurface(
      key: const ValueKey('waiting'),
      tier: GlassTier.chrome,

      blur: false,
      stadium: true,
      onTap: onTap,
      child: SizedBox(
        height: _size,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.approval, size: 18, color: dsh.warning),
              const SizedBox(width: 8),
              Text(l10n.chatWaitingCount(waiting), style: AppType.tabular(theme.textTheme.labelLarge!)),
              const SizedBox(width: 4),
              Icon(AppIcons.scrollToBottom, size: 18, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );

    final circle = SizedBox.square(
      key: const ValueKey('jump'),
      dimension: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GlassSurface(
              tier: GlassTier.chrome,
              blur: false,
              circle: true,
              onTap: onTap,
              child: Center(child: Icon(AppIcons.scrollToBottom, size: 22, color: colors.onSurface)),
            ),
          ),

          Positioned(
            top: 2,
            right: 2,
            child: ValueListenableBuilder<bool>(
              valueListenable: hasNew,
              builder: (context, fresh, _) => AnimatedScale(
                scale: fresh ? 1 : 0,
                duration: fluid && fresh ? AppMotion.popCurve.duration : quick,
                curve: fluid && fresh ? AppMotion.popCurve : AppMotion.std,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, show, _) => IgnorePointer(
        ignoring: !show,
        child: AnimatedScale(
          scale: show ? 1 : (fluid ? 0.6 : 0.8),
          duration: fluid && show ? AppMotion.popCurve.duration : quick,
          curve: fluid && show ? AppMotion.popCurve : AppMotion.enter,
          child: AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: quick,
            child: Semantics(
              button: true,
              label: waiting > 0 ? l10n.chatWaitingBackToBottom(waiting) : l10n.chatBackToBottom,
              excludeSemantics: true,
              onTap: onTap,
              child: AnimatedSwitcher(
                duration: quick,
                layoutBuilder: (current, previous) =>
                    Stack(alignment: Alignment.centerRight, children: [...previous, ?current]),
                child: waiting > 0 ? pill : circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

///

class _FollowPhysics extends ScrollPhysics {
  const _FollowPhysics(this.follows, {required this.glides, super.parent});

  final bool Function() follows;

  /// A taller list is left for the glide to catch up with. Shorter still lands at once:
  /// a gap at the bottom can't wait.
  final bool Function() glides;

  @override
  _FollowPhysics applyTo(ScrollPhysics? ancestor) =>
      _FollowPhysics(follows, glides: glides, parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final adjusted = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
    if (isScrolling || velocity != 0 || !follows()) return adjusted;

    final at = newPosition.pixels > oldPosition.pixels ? newPosition.pixels : oldPosition.pixels;
    if (oldPosition.maxScrollExtent - at > 1 && !glides()) return adjusted;
    if (glides() && newPosition.maxScrollExtent >= at) return adjusted;
    return newPosition.maxScrollExtent;
  }
}

/// Keeps the center anchor while removing the viewport's artificial leading
/// gap using the same (possibly estimated) sliver geometry as the viewport.
/// Near the leading edge, a short reverse segment is fully laid out and its
/// extent is exact. Long reverse segments keep Flutter's original extent.
/// If all content fits, the bounds coincide and dragging cannot move it away
/// from the top.
class _TopBoundedScrollController extends ScrollController {
  _TopBoundedScrollController(this.leadingBoundary);

  final double? Function() leadingBoundary;

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) =>
      _TopBoundedScrollPosition(
        leadingBoundary: leadingBoundary,
        physics: physics,
        context: context,
        initialPixels: initialScrollOffset,
        keepScrollOffset: keepScrollOffset,
        oldPosition: oldPosition,
        debugLabel: debugLabel,
      );
}

class _TopBoundedScrollPosition extends ScrollPositionWithSingleContext {
  _TopBoundedScrollPosition({
    required this.leadingBoundary,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final double? Function() leadingBoundary;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (minScrollExtent == 0) {
      final leading = leadingBoundary();
      if (leading != null && leading.isFinite && leading > 0) {
        minScrollExtent = leading;
        maxScrollExtent = math.max(leading, maxScrollExtent);
      }
    }
    // ScrollPosition skips dimension correction on its first layout. Correct
    // that initial position here and ask the same viewport layout to retry;
    // otherwise a short chat would paint at the old anchor for one frame.
    // A collapsed range is also non-scrollable while a fling is active.
    // RangeMaintainingScrollPhysics otherwise retains an out-of-range offset
    // at nonzero velocity and springs a now-short chat back over later frames.
    if (!hasContentDimensions || minScrollExtent == maxScrollExtent) {
      final initial = pixels.clamp(minScrollExtent, maxScrollExtent);
      if (initial != pixels) {
        correctPixels(initial);
        return false;
      }
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
