/// Cross-repository contract test for DSH-go-rewrite's native HTTP/WebSocket
/// server. It is skipped during the ordinary package suite and enabled by the
/// cloud workflow that starts the real Go server with a temporary home.
@Tags(['live', 'native-go'])
library;

import 'dart:async';
import 'dart:convert';
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

    test('native workspace list, stat, text, bytes, and confinement', () async {
      final sessionId = (await client.createSession(cwd: '/root/workspace')).sessionId;
      final listing = await client.listWorkspace(sessionId, '');
      expect(listing.entries.map((entry) => entry.name), contains('contract.txt'));

      final stat = await client.statFile(sessionId, 'contract.txt');
      expect(stat.absolutePath, endsWith('/workspace/contract.txt'));
      expect(stat.version, isNotEmpty);
      expect(stat.bytes, greaterThan(0));

      final text = await client.readWorkspaceText(sessionId, 'contract.txt', offset: 2, limit: 1);
      expect(text.text, 'hello from native workspace');
      expect(text.lines, 1);
      expect(text.eof, isTrue);

      final bytes = await client.readWorkspaceWindow(sessionId, 'contract.txt', length: 5);
      expect(String.fromCharCodes(bytes.data), 'first');
      expect(bytes.eof, isFalse);

      await expectLater(
        client.statFile(sessionId, '../outside'),
        throwsA(isA<DshRemoteException>().having((e) => e.code, 'code', 'workspace-file/not-allowed')),
      );
    });

    test('streaming upload is durable and readable by attachment id', () async {
      final sessionId = (await client.createSession()).sessionId;
      final receipt = await client.uploadFile(sessionId, utf8.encode('native attachment'), name: 'native.txt');
      expect(receipt.receiptId, isNotEmpty);
      expect(receipt.attachment.name, 'native.txt');
      expect(receipt.attachment.bytes, utf8.encode('native attachment').length);
      final attachmentId = receipt.attachment.attachmentId;
      expect(attachmentId, isNotEmpty);

      final value = await client.rpc.call('session/attachment', {
        'request': {'sessionId': sessionId, 'attachmentId': attachmentId},
      }) as Map;
      expect(utf8.decode(base64Decode(value['data']! as String)), 'native attachment');
    });

    test('goal lifecycle and live session-control projection', () async {
      final sessionId = (await client.createSession()).sessionId;
      final baseline = Completer<SessionControlBaseline>();
      final goalProjection = Completer<SessionControlProjection>();
      final control = client.watchSessionControl().listen((update) {
        if (update is SessionControlBaseline && !baseline.isCompleted) baseline.complete(update);
        if (update is SessionControlProjection && update.sessionId == sessionId && update.key == 'goal') {
          final value = update.value;
          if (value is Map && value['goal'] is Map && !goalProjection.isCompleted) goalProjection.complete(update);
        }
      });
      addTearDown(control.cancel);
      expect((await baseline.future.timeout(const Duration(seconds: 10))).projections, contains(sessionId));

      var ref = await client.createGoal(sessionId, 'Finish native DSH', maxGoalRounds: 6);
      expect(ref.id, isNotEmpty);
      final current = await client.goal(sessionId);
      expect(current?.goal.objective, 'Finish native DSH');
      expect(current?.activation, GoalActivation.armed);
      await goalProjection.future.timeout(const Duration(seconds: 10));

      final edited = await client.editGoal(sessionId, ref, objective: 'Finish standalone native DSH');
      ref = edited.ref;
      expect(edited.goal.objective, 'Finish standalone native DSH');
      final paused = await client.pauseGoal(sessionId, ref);
      ref = paused.ref;
      expect(paused.goal.phase, GoalPhase.paused);
      final resumed = await client.resumeGoal(sessionId, ref);
      ref = resumed.ref;
      expect(resumed.activation, GoalActivation.armed);
      await client.clearGoal(sessionId, ref);
      expect(await client.goal(sessionId), isNull);
    });

    test('native terminal attach, input, output, rename, resize, and close', () async {
      final sessionId = (await client.createSession()).sessionId;
      final environment = await client.terminalEnvironment(sessionId);
      expect(environment.cwd, isNotEmpty);
      final shells = await client.terminalShells(sessionId);
      expect(shells, isNotEmpty);
      final id = newTerminalId();
      final created = await client.createTerminal(sessionId, id: id, cols: 80, rows: 24);
      expect(created.running, isTrue);

      final attachment = client.attachTerminal(sessionId, id, environment: environment);
      final snapshot = Completer<TerminalSnapshot>();
      final output = Completer<TerminalOutput>();
      final frames = attachment.frames.listen((frame) {
        if (frame is TerminalSnapshot && !snapshot.isCompleted) snapshot.complete(frame);
        if (frame is TerminalOutput && frame.data.contains('DART_NATIVE_TERMINAL') && !output.isCompleted) {
          output.complete(frame);
        }
      });
      addTearDown(frames.cancel);
      addTearDown(attachment.close);
      expect((await snapshot.future.timeout(const Duration(seconds: 10))).writable, isTrue);
      expect(attachment.write('echo DART_NATIVE_TERMINAL\n'), isTrue);
      expect((await output.future.timeout(const Duration(seconds: 10))).data, contains('DART_NATIVE_TERMINAL'));
      expect(attachment.resize(100, 30), isTrue);
      await client.renameTerminal(sessionId, id, 'Native shell');
      expect((await client.listTerminals(sessionId)).single.title, 'Native shell');
      await client.closeTerminal(sessionId, id);
    });

    test('native workspace registry, directory picker, pins, and grouping', () async {
      final home = await client.browseDirectory();
      expect(home.path, isNotEmpty);
      final path = await client.createDirectory(home.path, 'contract-project');
      final created = await client.createWorkspace(path);
      expect(created.created, isTrue);
      expect(created.workspace.path, path);
      final renamed = await client.renameWorkspace(created.workspace.workspaceId, 'Contract Project');
      expect(renamed.title, 'Contract Project');

      final sessionId = (await client.createSession(workspaceId: renamed.workspaceId)).sessionId;
      final summary = (await client.listSessions()).firstWhere((item) => item.sessionId == sessionId);
      expect(summary.cwd, path);
      expect(await client.pinSession(sessionId), contains(sessionId));
      expect(await client.archiveSession(sessionId), contains(sessionId));
      expect(await client.unarchiveSession(sessionId), isNot(contains(sessionId)));
      expect(await client.unpinSession(sessionId), isNot(contains(sessionId)));
      expect(await client.moveWorkspace(renamed.workspaceId), contains(renamed.workspaceId));
      await client.deleteWorkspace(renamed.workspaceId);
      expect(await Directory(path).exists(), isTrue, reason: 'workspace deletion must preserve the folder');
    });

    test('native skills and built-in agent preset', () async {
      final sessionId = (await client.createSession()).sessionId;
      final environment = await client.terminalEnvironment(sessionId);
      final terminalId = newTerminalId();
      await client.createTerminal(sessionId, id: terminalId, cols: 80, rows: 24);
      final attachment = client.attachTerminal(sessionId, terminalId, environment: environment);
      final snapshot = Completer<void>();
      final ready = Completer<void>();
      final frames = attachment.frames.listen((frame) {
        if (frame is TerminalSnapshot && !snapshot.isCompleted) snapshot.complete();
        if (frame is TerminalOutput && frame.data.contains('SKILL_READY') && !ready.isCompleted) ready.complete();
      });
      addTearDown(frames.cancel);
      addTearDown(attachment.close);
      await snapshot.future.timeout(const Duration(seconds: 10));
      expect(
        attachment.write(
          "mkdir -p .dsh/skills/cloud-native && printf '%s\\n' '---' 'name: cloud-native' "
          "'description: Cloud native contract skill' '---' 'Use native tools only.' "
          "> .dsh/skills/cloud-native/SKILL.md && echo SKILL_READY\n",
        ),
        isTrue,
      );
      await ready.future.timeout(const Duration(seconds: 10));
      final skills = await client.listSkills(sessionId);
      final skill = skills.firstWhere((item) => item.name == 'cloud-native');
      expect(skill.description, 'Cloud native contract skill');
      expect(skill.modelInvocable, isTrue);
      await client.closeTerminal(sessionId, terminalId);

      final presets = await client.listAgentPresets();
      expect(presets.map((preset) => preset.id), contains('native'));
      final document = await client.readAgentPreset('native');
      expect(document.content, contains('id: native'));
      expect(await client.selectAgentPreset(sessionId, 'native'), 'native');
    });

    test('native file and session reference discovery', () async {
      final sourceId = (await client.createSession()).sessionId;
      final files = await client.fileReferences(sourceId, 'contract');
      expect(files.map((file) => file.path), contains('contract.txt'));

      final targetId = (await client.createSession()).sessionId;
      await client.renameSession(targetId, 'Reference target');
      final sessions = await client.sessionReferences(sourceId, 'Reference target');
      final target = sessions.singleWhere((candidate) => candidate.sessionId == targetId);
      expect(target.label, 'Reference target');
      expect(decodeSessionReferenceUri(target.mention.substring(target.mention.indexOf('dsh-session:'), target.mention.length - 1)), targetId);
      expect(target.sameWorkspace, isTrue);
    });

    test('native settings revisions and command catalogue', () async {
      final description = await client.describeSettings();
      expect(description.writable, isTrue);
      expect(description.namespaces, contains('native-engine'));
      final before = description.namespaces['native-engine']!;
      final changed = await client.setSetting(
        'native-engine',
        ['defaultPermission'],
        'read-only',
        expectedRevision: before.revision,
      );
      expect(changed.value['defaultPermission'], 'read-only');
      await expectLater(
        client.setSetting('native-engine', ['defaultPermission'], 'auto', expectedRevision: before.revision),
        throwsA(isA<DshRemoteException>().having((e) => e.code, 'code', 'settings/conflict')),
      );
      final restored = await client.setSetting(
        'native-engine',
        ['defaultPermission'],
        'auto',
        expectedRevision: changed.revision,
      );
      expect(restored.value['defaultPermission'], 'auto');
      await client.setDefaultAgentPreset('native');

      final commands = await client.rpc.call('commands/list', {'agentId': (await client.createSession()).sessionId});
      expect(commands, isA<List>());
      expect((commands! as List).whereType<Map>().map((command) => command['name']), contains('permission'));
    });

    test('native account, app-auth, and plugin capability states', () async {
      final account = await client.rpc.call('account/getState') as Map;
      expect(account['status'], 'signed-out');
      expect((account['links'] as Map)['usageUrl'], isNotEmpty);
      expect(await client.rpc.call('account/getProfile'), isNull);
      expect(await client.rpc.call('account/hasRunningAccountTasks'), isFalse);
      final subscriptions = await client.rpc.call('appAuth/list') as Map;
      expect((subscriptions['providers'] as List).map((provider) => (provider as Map)['id']), containsAll(['openai-codex', 'anthropic']));
      final inventory = await client.rpc.call('dynamicCordisRunner/inventory');
      expect(inventory, isEmpty);
      final install = await client.rpc.call('pluginManager/installBundle', {
        'request': {'bundleId': 'missing-native-bundle'},
      }) as Map;
      expect(install['application'], 'failed');
      expect((install['error'] as Map)['code'], 'operation-error');
    });

    test('native custom provider settings, discovery, and routing', () async {
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => upstream.close(force: true));
      upstream.listen((request) async {
        final response = request.response;
        if (request.uri.path == '/v1/models') {
          response.headers.contentType = ContentType.json;
          response.write('{"data":[{"id":"native-model","name":"Native Model","context_window":32000}]}');
        } else if (request.uri.path == '/v1/chat/completions') {
          response.headers.contentType = ContentType('text', 'event-stream');
          response.write('data: {"choices":[{"delta":{"content":"custom reply"}}]}\n\n');
          response.write('data: [DONE]\n\n');
        } else {
          response.statusCode = HttpStatus.notFound;
        }
        await response.close();
      });
      const keyRef = 'CUSTOM_NATIVE_API_KEY';
      await client.setProviderKey('custom-key', ref: keyRef);
      final saved = await client.saveProvider(
        ProviderProfile(
          route: 'native-gateway',
          displayName: 'Native Gateway',
          api: ProviderApi.openaiCompletions.wire,
          baseUrl: 'http://127.0.0.1:${upstream.port}/v1',
          apiKeyEnv: keyRef,
          models: const [ProviderModelSpec(id: 'native-model', name: 'Native Model')],
        ),
      );
      expect(saved.byRoute('native-gateway')?.displayName, 'Native Gateway');
      final providers = await client.listConfigurableProviders();
      expect(providers.map((provider) => provider.provider), contains('native-gateway'));
      final discovered = await client.discoverModels(
        baseUrl: 'http://127.0.0.1:${upstream.port}/v1',
        api: ProviderApi.openaiCompletions,
        apiKey: 'custom-key',
      );
      expect(discovered.single.id, 'native-model');
      final catalog = await client.listModels();
      expect(catalog.groups.map((group) => group.id), contains('native-gateway'));
      final sessionId = (await client.createSession()).sessionId;
      final selection = await client.setModel(sessionId, provider: 'native-gateway', model: 'native-model');
      expect(selection.provider, 'native-gateway');
      expect(selection.model, 'native-model');
      await client.clearProviderKey(ref: keyRef);
    });

    test('native queue errors and default model initialization', () async {
      final sessionId = (await client.createSession()).sessionId;
      await expectLater(
        client.updateQueue(sessionId, 'missing-queue-item', remove: true),
        throwsA(isA<DshRemoteException>().having((e) => e.code, 'code', 'session/queue-item-not-found')),
      );
      await client.rpc.call('session/initializeDefaultModel');
    });

    test('native schedule catalogue and missing-task errors', () async {
      expect(await client.scheduleCatalog(), isEmpty);
      const missing = ScheduleTask(
        id: 'missing-native-schedule',
        sessionId: null,
        kind: 'every',
        title: 'Missing',
        prompt: 'Missing',
        active: true,
        record: {},
        target: {'kind': 'new_once'},
        updatedAt: '2026-11-10T00:00:00Z',
      );
      final history = await client.scheduleHistory(missing);
      expect(history.missing, 'schedule_not_found');
      expect(await client.deleteSchedule(missing), isFalse);
      await expectLater(
        client.runScheduledTask(missing),
        throwsA(isA<DshRemoteException>().having((e) => e.code, 'code', 'schedule_not_found')),
      );
    });

    test('native background job stream and missing-job error', () async {
      final sessionId = (await client.createSession()).sessionId;
      final jobs = await client.watchJobs(sessionId).first.timeout(const Duration(seconds: 10));
      expect(jobs, isEmpty);
      await expectLater(
        client.killJob(sessionId, 'missing-native-job'),
        throwsA(isA<DshRemoteException>().having((e) => e.code, 'code', 'job/not-found')),
      );
    });

    test('native message feedback lifecycle', () async {
      final sessionId = (await client.createSession()).sessionId;
      final events = <DshEvent>[];
      final ended = Completer<TurnEndedEvent>();
      final watch = client.watch(sessionId).listen((event) {
        events.add(event);
        if (event is TurnEndedEvent && !ended.isCompleted) ended.complete(event);
      });
      addTearDown(watch.cancel);
      await client.prompt(sessionId, 'rate this native reply');
      await ended.future.timeout(const Duration(seconds: 10));
      final reply = events.whereType<AssistantMessageEvent>().single;
      final messageId = reply.message.id;
      expect(messageId, isNotEmpty);

      final created = await client.putMessageFeedback(
        sessionId,
        messageId,
        FeedbackRating.positive,
        ifVersion: null,
        note: 'Useful native reply',
        category: FeedbackCategory.taskResult,
      );
      expect(created.messageId, messageId);
      expect(created.rating, FeedbackRating.positive);
      expect(created.note, 'Useful native reply');
      expect(created.category, FeedbackCategory.taskResult);

      await expectLater(
        client.putMessageFeedback(
          sessionId,
          messageId,
          FeedbackRating.negative,
          ifVersion: 'stale-version',
        ),
        throwsA(isA<MessageFeedbackException>().having((e) => e.code, 'code', 'version-conflict')),
      );
      final listed = await client.listMessageFeedback(sessionId);
      expect(listed.single.version, created.version);
      await client.deleteMessageFeedback(sessionId, messageId, ifVersion: created.version);
      expect(await client.listMessageFeedback(sessionId), isEmpty);
    });

    test('session fork persists a closed history prefix', () async {
      final sourceId = (await client.createSession()).sessionId;
      final ended = Completer<TurnEndedEvent>();
      final watch = client.watch(sourceId).listen((event) {
        if (event is TurnEndedEvent && !ended.isCompleted) ended.complete(event);
      });
      addTearDown(watch.cancel);
      await client.prompt(sourceId, 'fork this native session');
      await ended.future.timeout(const Duration(seconds: 10));
      final childId = await client.forkSession(sourceId);
      expect(childId, isNotEmpty);
      expect(childId, isNot(sourceId));
      final child = await client.projections(childId);
      expect(child, isNotNull);
      final history = await client.history(childId, throughSeq: child!.asOfSeq);
      expect(history.events.map((event) => event.type), contains('session/end-seed'));
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
