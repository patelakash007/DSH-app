import 'package:flutter/widgets.dart';

import 'dsh_ui_reply.dart';

typedef DshUiSend = Future<bool> Function(String text);

///

class DshUiScope extends InheritedWidget {
  const DshUiScope({
    super.key,
    required this.sessionId,
    required this.messageId,
    required this.state,
    this.onReply,
    this.onAskResend,
    required super.child,
  });

  final String sessionId;

  final String messageId;

  final DshUiState state;

  final DshUiSend? onReply;

  final DshUiSend? onAskResend;

  static DshUiScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DshUiScope>();

  @override
  bool updateShouldNotify(DshUiScope old) =>
      old.sessionId != sessionId ||
      old.messageId != messageId ||
      old.state != state ||
      old.onReply != onReply ||
      old.onAskResend != onAskResend;
}
