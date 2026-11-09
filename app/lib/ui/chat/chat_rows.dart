// The row model between DSH ChatItems and the chat list.

import 'package:dsh_client/dsh_client.dart';

import '../../state/artifacts.dart';
import '../../state/chat_state.dart';
import 'tool_view.dart';
import 'turn_summary.dart';

sealed class ChatRow {
  const ChatRow();

  String get key;

  bool get stable => false;
}

final class UserRow extends ChatRow {
  const UserRow(this.item);
  final UserChatItem item;

  /// The optimistic bubble's key once echoed: the row keeps its element, so

  @override
  String get key => switch (item.requestId) {
    final id? => 'p$id',
    null => item.key,
  };
  @override
  bool get stable => true;
}

final class PendingRow extends ChatRow {
  const PendingRow(this.prompt);
  final PendingPrompt prompt;
  @override
  String get key => 'p${prompt.requestId}';
}

final class AssistantRow extends ChatRow {
  const AssistantRow(this.item, {this.showActions = false, this.footnote});
  final AssistantChatItem item;

  final bool showActions;

  final TurnTrace? footnote;
  @override
  String get key => item.key;
  @override
  bool get stable => !item.streaming && item.seq != null;
}

final class ToolCallRow extends ChatRow {
  const ToolCallRow(this.item, {this.card = ToolCardPlacement.inline});
  final ToolChatItem item;

  final ToolCardPlacement card;
  @override
  String get key => item.key;
}

final class ToolGroupRow extends ChatRow {
  const ToolGroupRow(this.tools, {this.live = false});
  final List<ToolChatItem> tools;
  final bool live;
  @override
  String get key => 'g${tools.first.key}';
}

final class NoticeRowData extends ChatRow {
  const NoticeRowData(this.item);
  final NoticeChatItem item;
  @override
  String get key => item.key;
  @override
  bool get stable => true;
}

final class ApprovalRow extends ChatRow {
  const ApprovalRow(this.request);
  final ApprovalRequest request;
  @override
  String get key => 'ap${request.eventId}';
}

final class QuestionRow extends ChatRow {
  const QuestionRow(this.request);
  final UserQuestionRequest request;
  @override
  String get key => 'q${request.eventId}';
}

final class ChangeCardRow extends ChatRow {
  const ChangeCardRow(this.files, {required this.anchor});
  final List<FileChange> files;

  final String anchor;
  @override
  String get key => 'chg$anchor';
}

final class ArtifactCardRow extends ChatRow {
  const ArtifactCardRow(this.group);
  final TurnArtifacts group;
  @override
  String get key => 'art${group.endSeq}';
}

///

final class TurnProcessRow extends ChatRow {
  const TurnProcessRow(this.trace, this.rows, {required this.toolCalls, required this.messages, this.cut});
  final TurnTrace trace;
  final List<ChatRow> rows;

  final int toolCalls;

  final int messages;

  final int? cut;

  @override
  String get key => switch (cut) {
    final seq? => 'tp${trace.startSeq}@$seq',
    null => 'tp${trace.startSeq}',
  };
  @override
  bool get stable => true;
}

final class TurnFootnoteRow extends ChatRow {
  const TurnFootnoteRow(this.trace);
  final TurnTrace trace;
  @override
  String get key => 'ft${trace.startSeq}';
  @override
  bool get stable => true;
}

final class CommandNoticeRow extends ChatRow {
  const CommandNoticeRow(this.notice);
  final CommandNotice notice;
  @override
  String get key => notice.key;
  @override
  bool get stable => notice.done && notice.seq != null;
}

const toolGroupThreshold = 3;

List<ChatRow> deriveRows({
  required List<ChatItem> items,
  List<ApprovalRequest> approvals = const [],
  List<UserQuestionRequest> questions = const [],
  List<PendingPrompt> pending = const [],
  bool running = false,
  Set<String> autoAnswered = const {},
  List<CommandNotice> commands = const [],
  List<TurnTrace> turns = const [],
  bool foldTurns = false,
  List<TurnArtifacts> artifacts = const [],
}) {
  final rows = <ChatRow>[];
  final attached = <String>{};
  var tools = <ToolChatItem>[];
  var nextCommand = 0;

  int? pieceStart;
  var pieceEnd = 0;
  int? lastText;

  TurnTrace? turn;
  var turnTools = <ToolChatItem>[];

  void flushTools({bool live = false}) {
    if (tools.isEmpty) return;
    pieceStart ??= rows.length;

    var run = <ToolChatItem>[];
    void flushRun({bool live = false}) {
      if (run.length >= toolGroupThreshold) {
        rows.add(ToolGroupRow(run, live: live));
      } else {
        for (final tool in run) {
          rows.add(ToolCallRow(tool));
        }
      }
      run = <ToolChatItem>[];
    }

    for (final tool in tools) {
      if (hasToolCard(tool)) {
        flushRun();
        rows.add(ToolCallRow(tool));
      } else {
        run.add(tool);
      }
    }
    flushRun(live: live);
    tools = <ToolChatItem>[];
    pieceEnd = rows.length;
  }

  var cursor = 0;
  TurnTrace? turnAt(int seq) {
    if (turns.isEmpty) return null;
    while (cursor + 1 < turns.length && turns[cursor + 1].startSeq <= seq) {
      cursor++;
    }
    while (cursor > 0 && turns[cursor].startSeq > seq) {
      cursor--;
    }
    final trace = turns[cursor];
    if (trace.startSeq > seq) return null;
    if (trace.endSeq case final end? when seq > end) return null;
    return trace;
  }

  var nextArtifacts = 0;
  List<TurnArtifacts> takeArtifacts(int? beforeSeq) {
    final start = nextArtifacts;
    while (nextArtifacts < artifacts.length && (beforeSeq == null || artifacts[nextArtifacts].endSeq < beforeSeq)) {
      nextArtifacts++;
    }
    return artifacts.sublist(start, nextArtifacts);
  }

  int? fold(TurnTrace trace, int? reply, {int? cut}) {
    final start = pieceStart!;
    // Prefer explicit final answers: a late subagent result can produce another
    // answer in the same turn. Older hosts/models keep the positional fallback.
    final hasFinalAnswer = rows
        .getRange(start, pieceEnd)
        .whereType<AssistantRow>()
        .any((row) => row.item.isFinalAnswer && row.item.text.trim().isNotEmpty);
    var answer = hasFinalAnswer ? null : reply;
    if (answer != null) {
      for (var i = answer + 1; i < pieceEnd; i++) {
        final row = rows[i];
        if (row is ToolCallRow || row is ToolGroupRow || row is AssistantRow) {
          answer = null;
          break;
        }
      }
    }
    final end = answer ?? pieceEnd;
    final process = <ChatRow>[];
    final kept = <ChatRow>[];
    int? keptAnswer;
    var toolCalls = 0;
    var messages = 0;
    for (var i = start; i < end; i++) {
      switch (rows[i]) {
        case final ToolCallRow row when hasToolCard(row.item):

          toolCalls++;
          process.add(ToolCallRow(row.item, card: ToolCardPlacement.rowOnly));
          kept.add(ToolCallRow(row.item, card: ToolCardPlacement.cardOnly));
        case final ToolCallRow row:
          toolCalls++;
          process.add(row);
        case final ToolGroupRow row:
          toolCalls += row.tools.length;
          process.add(row);
        case final AssistantRow row when row.item.isFinalAnswer && row.item.text.trim().isNotEmpty:
          var item = row.item;
          if (item.reasoning.trim().isNotEmpty) {
            final (thinking, reply) = _splitReasoning(item);
            process.add(AssistantRow(thinking));
            item = reply;
          }
          keptAnswer = kept.length;
          kept.add(AssistantRow(item));
        case final AssistantRow row:
          if (row.item.text.trim().isNotEmpty) messages++;
          process.add(AssistantRow(row.item));
        case final NoticeRowData row:
          process.add(row);
        case final row:
          kept.add(row);
      }
    }
    var answerRow = answer == null ? null : rows[answer] as AssistantRow;
    if (answerRow != null && answerRow.item.reasoning.trim().isNotEmpty) {
      final (thinking, reply) = _splitReasoning(answerRow.item);
      process.add(AssistantRow(thinking));
      answerRow = AssistantRow(reply);
    }

    if (toolCalls == 0 && messages == 0 && process.length <= 1) return reply;
    final replacement = [
      TurnProcessRow(trace, List.unmodifiable(process), toolCalls: toolCalls, messages: messages, cut: cut),
      ...kept,
      ?answerRow,
    ];
    final removed = (answer == null ? end : answer + 1) - start;
    rows.replaceRange(start, start + removed, replacement);
    pieceEnd += replacement.length - removed;
    if (answerRow != null) return start + replacement.length - 1;
    return keptAnswer == null ? null : start + 1 + keptAnswer;
  }

  void close({int? cut, int? artifactsBefore}) {
    flushTools();
    final last = cut == null;
    final trace = turn;
    final done = trace != null && !trace.running && trace.endSeq != null ? trace : null;
    var index = lastText;
    if (foldTurns && done != null && pieceStart != null && (done.endReason?.isCompleted ?? false)) {
      index = fold(done, index, cut: cut);
    }
    final footnote = last ? done : null;
    if (index != null) {
      final row = rows[index] as AssistantRow;
      rows[index] = AssistantRow(row.item, showActions: true, footnote: footnote);
    } else if (footnote != null && rows.isNotEmpty) {
      rows.insert(pieceEnd, TurnFootnoteRow(footnote));
      pieceEnd++;
    }
    lastText = null;
    pieceStart = null;
    if (!last) return;
    if (turnTools.isNotEmpty) {
      final files = fileChangesOf(turnTools);
      if (files.isNotEmpty) {
        final anchor = turnTools.firstWhere((t) => toolKindOf(t) == ToolKind.edit).callId;
        rows.insert(pieceEnd, ChangeCardRow(files, anchor: anchor));
      }
    }
    final groups = takeArtifacts(artifactsBefore);
    if (groups.isNotEmpty && rows.isNotEmpty) {
      var at = pieceEnd;
      if (at < rows.length && rows[at] is ChangeCardRow) at++;
      for (final group in groups) {
        rows.insert(at++, ArtifactCardRow(group));
      }
    }
    turnTools = <ToolChatItem>[];
    pieceEnd = rows.length;
  }

  void emitCommands(int? beforeSeq) {
    var flushed = false;
    while (nextCommand < commands.length) {
      final command = commands[nextCommand];
      final seq = command.seq;
      if (beforeSeq != null && (seq == null || seq >= beforeSeq)) break;
      if (!flushed) {
        flushTools();
        flushed = true;
      }
      rows.add(CommandNoticeRow(command));
      nextCommand++;
    }
  }

  int? seqOf(ChatItem item) => switch (item) {
    UserChatItem(:final seq) => seq,
    AssistantChatItem(:final seq) => seq,
    ToolChatItem(:final seq) => seq,
    NoticeChatItem(:final seq) => seq,
  };

  for (var i = 0; i < items.length; i++) {
    final item = items[i];

    if (seqOf(item) case final seq?) {
      final owner = turnAt(seq);
      if (!identical(owner, turn)) {

        close(artifactsBefore: (turn?.endSeq ?? seq - 1) + 1);
        turn = owner;
      }
      emitCommands(seq);
    }
    switch (item) {
      case ToolChatItem():
        if (item.pendingApproval case final request?) {
          attached.add(request.eventId);
        }
        tools.add(item);
        turnTools.add(item);
      case UserChatItem():

        close(cut: turn == null ? null : item.seq, artifactsBefore: item.seq);
        rows.add(UserRow(item));
        pieceEnd = rows.length;
      case AssistantChatItem():
        flushTools();
        pieceStart ??= rows.length;
        rows.add(AssistantRow(item));
        if (item.text.trim().isNotEmpty) lastText = rows.length - 1;
      case NoticeChatItem():
        flushTools();
        final previous = i > 0 ? items[i - 1] : null;
        if (item.kind == 'aborted' && previous is AssistantChatItem && previous.interrupted) {
          break;
        }
        pieceStart ??= rows.length;
        rows.add(NoticeRowData(item));
    }
    if (item is AssistantChatItem || item is NoticeChatItem) {
      pieceEnd = rows.length;
    }
  }
  if (running) {
    flushTools(live: true);
  } else {
    close();
  }
  emitCommands(null);

  final orphans = [
    for (final request in approvals)
      if (!attached.contains(request.eventId) && !autoAnswered.contains(request.eventId)) ApprovalRow(request),
  ];

  rows.addAll(orphans);
  for (final question in questions) {
    rows.add(QuestionRow(question));
  }
  for (final prompt in pending) {
    // DSH's own context for the model is nobody's message (the controller
    // leaves it out already).
    if (prompt.isEngineNote) continue;
    rows.add(PendingRow(prompt));
  }
  return rows;
}

(AssistantChatItem, AssistantChatItem) _splitReasoning(AssistantChatItem item) => (
  AssistantChatItem(
    id: '${item.id}#r',
    rowKey: '${item.key}#r',
    seq: item.seq,
    time: item.time,
    text: '',
    reasoning: item.reasoning,
    model: item.model,
  ),
  AssistantChatItem(
    id: item.id,
    rowKey: item.rowKey,
    seq: item.seq,
    time: item.time,
    text: item.text,
    reasoning: '',
    interrupted: item.interrupted,
    usage: item.usage,
    model: item.model,
    isFinalAnswer: item.isFinalAnswer,
  ),
);
