import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../render/code_block.dart';
import 'dsh_ui_dialect_card.dart';
import 'dsh_ui_model.dart';
import 'dsh_ui_reply.dart';
import 'dsh_ui_scope.dart';
import 'dsh_ui_skeleton.dart';
import 'dsh_ui_widgets.dart';
import '../../common/smooth_size.dart';

///

/// |---|---|

///

class DshUiBlock extends StatefulWidget {
  const DshUiBlock({super.key, required this.source, this.streaming = false, this.closed = true});

  final String source;

  final bool streaming;

  final bool closed;

  @override
  State<DshUiBlock> createState() => _DshUiBlockState();
}

class _DshUiBlockState extends State<DshUiBlock> {

  bool _sawStreaming = false;
  bool _resending = false;
  bool _resent = false;

  Future<void> _resend(DshUiSend send, String text) async {
    if (_resending || _resent) return;
    setState(() => _resending = true);
    var ok = false;
    try {
      ok = await send(text);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _resending = false;
      _resent = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final source = widget.source;
    final Widget child;
    final String key;
    if (!widget.closed && widget.streaming) {
      _sawStreaming = true;
      key = 'skeleton';
      child = DshUiSkeleton(shape: guessDshUiShape(source));
    } else if (!widget.closed) {
      key = 'interrupted';
      child = DshUiFallback(source: source, message: l10n.viewUiIncomplete);
    } else {
      switch (parseDshUi(source)) {
        case DshUiParsed(:final view) when view.dialect != null:
          key = 'view';
          child = DshUiDialectCard(key: ValueKey(source), view: view, animate: _sawStreaming);
        case DshUiParsed(:final view):
          key = 'view';
          child = DshUiCard(key: ValueKey(source), view: view, animate: _sawStreaming);
        case DshUiInvalid(dialect: _?):
          // Another plugin's format that maps to nothing here: fine where it
          // came from, so no resend.
          key = 'invalid';
          child = DshUiFallback(source: source, message: l10n.viewUiDialectInvalid);
        case DshUiInvalid(:final resendText):
          key = 'invalid';
          final scope = DshUiScope.maybeOf(context);
          final send = scope?.onAskResend;
          final canSend = send != null && scope!.state.canAnswer && !_resent;
          child = DshUiFallback(
            source: source,
            message: l10n.viewUiInvalid,
            busy: _resending,
            onResend: canSend ? () => _resend(send, resendText) : null,
          );
      }
    }
    final duration = AppMotion.of(context, AppMotion.standard);
    return SmoothSize(
      duration: duration,
      curve: AppMotion.std,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
        child: KeyedSubtree(key: ValueKey(key), child: child),
      ),
    );
  }
}

class DshUiFallback extends StatelessWidget {
  const DshUiFallback({super.key, required this.source, required this.message, this.onResend, this.busy = false});

  final String source;
  final String message;

  final VoidCallback? onResend;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              Icon(AppIcons.info, size: 16, color: dsh.textTertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: dsh.textTertiary)),
              ),
              if (onResend != null || busy)
                TextButton(
                  onPressed: busy ? null : onResend,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const StadiumBorder(),
                  ),
                  child: busy
                      ? SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                        )
                      : Text(l10n.viewUiResend),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CodeBlock(code: source.trim(), language: 'json'),
      ],
    );
  }
}

String? dshUiReplyChip(String text) => parseDshUiReply(text)?.chipLabel;
