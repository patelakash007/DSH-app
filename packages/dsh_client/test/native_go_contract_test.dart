/// Cross-repository contract test for DSH-go-rewrite's native HTTP/WebSocket
/// server. It is skipped during the ordinary package suite and enabled by the
/// cloud workflow that starts the real Go server with a temporary home.
@Tags(['live', 'native-go'])
library;

import 'dart:async';
import 'dart:io';

import 'package:dsh_client/dsh_client.dart';
import 'package:test/test.dart';

void main() {
  final launchUrl = Platform.environment['DSH_NATIVE_GO_LIVE_URL'];
  final skip = launchUrl == null ? 'set DSH_NATIVE_GO_LIVE_URL to test the native Go server' : null;

  group('native Go server contract', skip: skip, () {
    late DshClient client;

    setUpAll(() async {
      client = await DshClient.connect(launchUrl: launchUrl);
    });

    tearDownAll(() => client.close());

    test('auth, mux generation, and core RPC errors', () async {
      expect(await client.connection.checkHealth(), DshHealth.ok);
      expect(client.mux.generation?.clientId, isNotEmpty);
      expect(await client.projections('missing-native-session'), isNull);
      await expectLater(
        client.rpc.call('nativeGo/notImplemented'),
        throwsA(isA<DshRemoteException>().having((e) => e.code, 'code', 'gateway/method-not-found')),
      );
    });

    test('session watch, prompt stream, durable reply, and history', () async {
      final created = await client.createSession(cwd: '/tmp/native-workspace');
      expect(created.sessionId, isNotEmpty);

      final events = <DshEvent>[];
      final snapshot = Completer<SessionSnapshotEvent>();
      final ended = Completer<TurnEndedEvent>();
      final subscription = client.watch(created.sessionId).listen((event) {
        events.add(event);
        if (event is SessionSnapshotEvent && !snapshot.isCompleted) snapshot.complete(event);
        if (event is TurnEndedEvent && !ended.isCompleted) ended.complete(event);
      });
      addTearDown(subscription.cancel);

      final initial = await snapshot.future.timeout(const Duration(seconds: 10));
      expect(initial.header.id, created.sessionId);

      final requestId = await client.prompt(created.sessionId, 'hello from the Dart native contract');
      final turn = await ended.future.timeout(const Duration(seconds: 10));
      expect(turn.reason.kind, 'completed');

      final user = events.whereType<UserMessageEvent>().single;
      expect(user.message.text, 'hello from the Dart native contract');
      expect(user.requestId, requestId);

      final assistant = events.whereType<AssistantMessageEvent>().single;
      expect(assistant.message.text, contains('Welcome to DSH Native'));
      expect(events.whereType<AssistantStreamStarted>(), isNotEmpty);
      expect(events.whereType<AssistantChunkEvent>(), isNotEmpty);
      expect(events.whereType<AssistantStreamEnded>().single.committed, isTrue);

      final history = await client.history(created.sessionId, throughSeq: turn.seq);
      expect(history.events.map((event) => event.type), containsAllInOrder([
        'turn/start',
        'user/message',
        'step/start',
        'assistant/message',
        'step/end',
        'turn/end',
      ]));
    });

    test('credential storage round trip', () async {
      const ref = 'DSH_NATIVE_CONTRACT_KEY';
      await client.setProviderKey('contract-value', ref: ref);
      expect((await client.describeCredentials([ref]))[ref]?.configured, isTrue);
      await client.clearProviderKey(ref: ref);
      expect((await client.describeCredentials([ref]))[ref]?.configured, isFalse);
    });

    test('workspace baseline and archive updates', () async {
      final sessionId = (await client.createSession(cwd: '/tmp/archive-workspace')).sessionId;
      final baseline = Completer<WorkspaceBaseline>();
      final archived = Completer<WorkspaceArchivedUpdate>();
      final subscription = client.watchWorkspaces().listen((update) {
        if (update is WorkspaceBaseline && !baseline.isCompleted) baseline.complete(update);
        if (update is WorkspaceArchivedUpdate && !archived.isCompleted) archived.complete(update);
      });
      addTearDown(subscription.cancel);

      expect((await baseline.future.timeout(const Duration(seconds: 10))).archivedSessionIds, isEmpty);
      expect(await client.archiveSession(sessionId), contains(sessionId));
      expect(
        (await archived.future.timeout(const Duration(seconds: 10))).archivedSessionIds,
        contains(sessionId),
      );
      expect(await client.unarchiveSession(sessionId), isNot(contains(sessionId)));
    });
  });
}
