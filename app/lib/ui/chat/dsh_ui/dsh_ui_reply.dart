// Portions derived from DS Bot (https://github.com/Fei2411/DeepSeek-Bot), Apache-2.0, Copyright 2026 Fei2411 and the DS Bot contributors. See THIRD_PARTY_NOTICES.md.
// Modified: the `validateOptions` selection rules translated to Dart; the
// answer travels as a readable user message built only from visible labels

// message order instead of being stored.

import 'package:dsh_client/dsh_client.dart';

import '../../../l10n/l10n.dart';
import 'dsh_ui_model.dart';

const dshUiReplyMarker = '[dsh-ui reply]';

enum DshUiReplyKind {

  choice,

  confirm,

  cancel,

  other,
}

final class DshUiReply {
  const DshUiReply({required this.kind, this.title, this.value, this.freetext});

  factory DshUiReply.choice(List<String> labels, {String? title, String? freetext}) {
    final chosen = labels.map(_flat).whereType<String>().join(_join);
    return DshUiReply(
      kind: DshUiReplyKind.choice,
      title: _flat(title),
      value: chosen.isEmpty ? null : chosen,
      freetext: _flat(freetext),
    );
  }

  factory DshUiReply.confirm(bool confirmed, {String? label, String? title}) {
    final kind = confirmed ? DshUiReplyKind.confirm : DshUiReplyKind.cancel;
    final fallback = confirmed ? DshUiConfirm.defaultConfirm : DshUiConfirm.defaultCancel;
    final flat = _flat(label);
    return DshUiReply(kind: kind, title: _flat(title), value: flat == null || flat == fallback ? null : flat);
  }

  final DshUiReplyKind kind;

  final String? title;

  final String? value;

  final String? freetext;

  String get text {
    final head = title == null ? dshUiReplyMarker : '$dshUiReplyMarker $title';
    final body = switch (kind) {
      DshUiReplyKind.choice => [
        if (value != null && value!.isNotEmpty) appL10n.viewUiReplyChoice(value!),
        if (freetext != null && freetext!.isNotEmpty) appL10n.viewUiReplyOther(freetext!),
      ].join('\n'),
      DshUiReplyKind.confirm => value == null ? appL10n.commonConfirm : appL10n.viewUiReplyConfirm(value!),
      DshUiReplyKind.cancel => value == null ? appL10n.commonCancel : appL10n.viewUiReplyCancel(value!),
      DshUiReplyKind.other => value ?? '',
    };
    return body.isEmpty ? head : '$head\n$body';
  }

  String get chipLabel => switch (kind) {
    DshUiReplyKind.choice => switch ((value, freetext)) {
      (final chosen?, final typed?) when chosen.isNotEmpty && typed.isNotEmpty =>
        '${appL10n.viewUiChosen(chosen)} · ${appL10n.viewUiChosenOther(typed)}',
      (_, final typed?) when typed.isNotEmpty => appL10n.viewUiChosenOther(typed),
      _ => appL10n.viewUiChosen(value ?? ''),
    },
    DshUiReplyKind.confirm => value == null ? appL10n.viewUiConfirmed : appL10n.viewUiConfirmedValue(value!),
    DshUiReplyKind.cancel => value == null ? appL10n.commonCancelled : appL10n.viewUiCancelledValue(value!),
    DshUiReplyKind.other => value == null || value!.isEmpty ? appL10n.viewUiReplied : value!,
  };

  List<String> get choices => kind == DshUiReplyKind.choice && value != null
      ? [
          for (final part in value!.split(_join))
            if (part.trim().isNotEmpty) part.trim(),
        ]
      : const [];

  List<String> selectedIn(List<String> labels) {
    if (kind != DshUiReplyKind.choice || value == null) return const [];
    final padded = '$_join$value$_join';
    return [
      for (final label in labels)
        if (padded.contains('$_join$label$_join')) label,
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is DshUiReply &&
      other.kind == kind &&
      other.title == title &&
      other.value == value &&
      other.freetext == freetext;

  @override
  int get hashCode => Object.hash(kind, title, value, freetext);

  @override
  String toString() => text;
}

const _join = '、'; // l10n:keep reply selection protocol delimiter

final _otherLine = RegExp(r'^(其他|Other)\s*[：:]\s*(.*)$');

String? _flat(String? text) {
  final flat = text?.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();
  return flat == null || flat.isEmpty ? null : flat;
}

DshUiReply? parseDshUiReply(String text) {
  final lines = text.trimLeft().split(RegExp(r'\r?\n'));
  final head = lines.first.trim();
  if (!head.startsWith(dshUiReplyMarker)) return null;
  final title = _flat(head.substring(dshUiReplyMarker.length));
  final body = [
    for (final line in lines.skip(1))
      if (line.trim().isNotEmpty) line.trim(),
  ];
  if (body.isEmpty) return DshUiReply(kind: DshUiReplyKind.other, title: title);
  final first = body.first;

  if (_otherLine.firstMatch(first) case final other?) {
    return DshUiReply(kind: DshUiReplyKind.choice, title: title, freetext: _flat(other.group(2)));
  }
  // l10n:keep legacy reply protocol parser
  final colon = RegExp(r'^(选择|确认|取消|Select|Confirm|Cancel)\s*(?:[：:]\s*(.*))?$').firstMatch(first);
  if (colon == null) {
    return DshUiReply(kind: DshUiReplyKind.other, title: title, value: first);
  }
  final value = _flat(colon.group(2));
  final kind = switch (colon.group(1)) {
    // l10n:keep legacy reply protocol value
    '选择' || 'Select' => DshUiReplyKind.choice,
    // l10n:keep legacy reply protocol value
    '确认' || 'Confirm' => DshUiReplyKind.confirm,
    _ => DshUiReplyKind.cancel,
  };

  final freetext = kind == DshUiReplyKind.choice && body.length > 1
      ? _flat(_otherLine.firstMatch(body[1])?.group(2))
      : null;
  return DshUiReply(kind: kind, title: title, value: value, freetext: freetext);
}

enum DshUiInteraction {

  live,

  running,

  answered,

  expired,
}

final class DshUiState {
  const DshUiState(this.interaction, {this.reply});

  static const live = DshUiState(DshUiInteraction.live);
  static const running = DshUiState(DshUiInteraction.running);
  static const expired = DshUiState(DshUiInteraction.expired);

  final DshUiInteraction interaction;

  final DshUiReply? reply;

  bool get canAnswer => interaction == DshUiInteraction.live;

  @override
  bool operator ==(Object other) => other is DshUiState && other.interaction == interaction && other.reply == reply;

  @override
  int get hashCode => Object.hash(interaction, reply);

  @override
  String toString() => 'DshUiState(${interaction.name}, $reply)';
}

///

DshUiState dshUiStateFor({
  required List<ChatItem> items,
  required String messageId,
  required bool running,
  List<String> pending = const [],
}) {
  final index = items.indexWhere((item) => item is AssistantChatItem && item.id == messageId);
  if (index < 0) return DshUiState.expired;
  var laterReply = false;
  for (var i = index + 1; i < items.length; i++) {
    final item = items[i];
    if (item is UserChatItem) return _after(item.text);
    if (item is AssistantChatItem && item.text.trim().isNotEmpty) {
      laterReply = true;
    }
  }
  if (pending.isNotEmpty) return _after(pending.first);
  if (laterReply) return DshUiState.expired;
  final message = items[index] as AssistantChatItem;
  if (running || message.streaming) return DshUiState.running;
  return DshUiState.live;
}

DshUiState _after(String userText) {
  final reply = parseDshUiReply(userText);
  return reply == null ? DshUiState.expired : DshUiState(DshUiInteraction.answered, reply: reply);
}

DshUiAnswer? dshUiAnswerFor(DshUiView view, DshUiReply reply) {
  final title = reply.title;
  if (title != null && view.title != null && title != view.title) return null;
  switch (reply.kind) {
    case DshUiReplyKind.choice:
      for (final node in view.answerNodes) {
        if (node is! DshUiOptions) continue;
        final picked = reply.selectedIn(node.labels);

        final typed = node.freetext ? reply.freetext : null;
        if (picked.isEmpty && (typed == null || typed.isEmpty)) continue;

        return DshUiAnswer(
          nodePath: node.path,
          selected: node.multi ? picked : picked.take(1).toList(),
          freetext: typed,
        );
      }
      return null;
    case DshUiReplyKind.confirm:
    case DshUiReplyKind.cancel:
      for (final node in view.answerNodes) {
        if (node is DshUiConfirm) {
          return DshUiAnswer(nodePath: node.path, confirmed: reply.kind == DshUiReplyKind.confirm);
        }
      }
      return null;
    case DshUiReplyKind.other:
      return null;
  }
}

final class DshUiAnswer {
  const DshUiAnswer({required this.nodePath, this.selected = const [], this.freetext, this.confirmed});

  final String nodePath;

  final List<String> selected;

  final String? freetext;

  final bool? confirmed;
}
