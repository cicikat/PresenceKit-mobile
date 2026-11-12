import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/controllers/mobile_realtime_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/session_scope.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

const grant = PresenceSessionGrant(
  sessionId: 'session-a',
  charId: 'character_a',
  ownerId: 'owner',
  domain: 'reality',
);

class _Store extends AppSettingsStore {
  @override
  Future<bool> isAllowedBaseUrl(String baseUrl) async => true;
}

class _RealHttp extends HttpOverrides {}

HttpClient _realClient() =>
    HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttp());

class _Backend extends BackendClient {
  _Backend(AppSettingsStore store, String address)
    : super(
        baseUrl: address,
        settingsStore: store,
        httpClientFactory: _realClient,
      );
  bool enabled = true;
  @override
  Future<void> reportMobileRealtimeMetric(
    String kind,
    int value, {
    required String token,
  }) async {}
  int opens = 0;
  int historyReads = 0;
  int sends = 0;
  String? request;
  Completer<BackendChatResponse>? response;
  List<Map<String, dynamic>> messages = [];
  @override
  Future<Map<String, dynamic>> mobileRealtimeCapability({
    required String token,
  }) async => {'enabled': enabled, 'protocol': 'mobile-final-v1'};
  @override
  Future<Map<String, dynamic>> mobileFinalHistory({
    required String token,
    required String sessionId,
    int? before,
  }) async {
    historyReads++;
    final remaining =
        messages
            .where(
              (m) => before == null || (m['history_index'] as int) < before,
            )
            .toList()
          ..sort(
            (a, b) => (b['history_index'] as int).compareTo(
              a['history_index'] as int,
            ),
          );
    final page = remaining.take(2).toList();
    return {
      'messages': page,
      'next_before': remaining.length > 2 ? page.last['history_index'] : null,
    };
  }

  @override
  Future<BackendChatResponse> sendChat(
    String message, {
    required String token,
    ReplyTarget? replyTo,
    String? sessionId,
    String? voiceReceipt,
    String? requestId,
  }) {
    sends++;
    request = requestId;
    return response!.future;
  }

  @override
  Future<ChatLogDates> loadChatLogDates({
    required String token,
    String? sessionId,
    String? characterId,
  }) async => const ChatLogDates(dates: [], count: 0);
  @override
  Future<MobileActivationResult> deactivateMobile({
    required String token,
  }) async => const MobileActivationResult(ok: true, active: false);
}

Map<String, dynamic> message(
  int index, {
  String charId = 'character_a',
  String? request,
}) => {
  'id': 'turn-$index',
  'msg_id': 'turn-$index',
  'turn_id': 'turn-$index',
  'user_id': 'owner',
  'char_id': charId,
  'domain': 'reality',
  'critical_written': true,
  'history_index': index,
  'content': 'Hello\nHello',
  'display_text': '<hl>Hello</hl>\nHello',
  'timestamp': 1700000000 + index * 86400,
  if (request != null) 'request_id': request,
};

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition timed out');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  late _Backend backend;
  late _Store store;
  final sockets = <WebSocket>[];
  setUp(() async {
    sockets.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    store = _Store();
    backend = _Backend(store, 'http://127.0.0.1:${server.port}');
    server.listen((request) async {
      expect(request.uri.path, '/ws/mobile');
      expect(request.headers.value('authorization'), 'Bearer fixture');
      expect(request.headers.value('x-presence-session'), 'session-a');
      expect(request.headers.value('x-presence-client'), isNotEmpty);
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.add(
        jsonEncode({
          'type': 'ready',
          'generation': 'generation-${sockets.length}',
          'char_id': 'character_a',
          'domain': 'reality',
          'client_type': 'mobile',
          'session_id': 'session-a',
          'mode': 'final_only',
        }),
      );
    });
  });
  tearDown(() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  });

  MobileRealtimeController receiver(List<Map<String, dynamic>> applied) =>
      MobileRealtimeController(
        backend: () => backend,
        token: () => 'fixture',
        grant: () async => grant,
        apply: applied.add,
        isLive: () => true,
      );

  test(
    'cross-day pages recover while WS is disabled and never open a socket',
    () async {
      backend.enabled = false;
      backend.messages = [message(1)];
      final applied = <Map<String, dynamic>>[];
      final realtime = receiver(applied)..start();
      addTearDown(realtime.stop);
      await until(() => applied.length == 1);
      realtime.stop();
      backend.messages = [for (var i = 1; i <= 5; i++) message(i)];
      realtime.start();
      await until(() => applied.length == 5);
      expect(applied.map((m) => m['id']), [
        'turn-1',
        'turn-2',
        'turn-3',
        'turn-4',
        'turn-5',
      ]);
      expect(backend.historyReads, 4);
      expect(sockets, isEmpty);
      expect(backend.sends, 0);
    },
  );

  test(
    'ready boundary recovers a final missed between history and upgrade',
    () async {
      final applied = <Map<String, dynamic>>[];
      final realtime = receiver(applied)..start();
      addTearDown(realtime.stop);
      await until(() => realtime.state == 'final_only');
      expect(backend.historyReads, 2);
      expect(backend.sends, 0);
    },
  );

  test('wrong-scope final is rejected and pause rejects late frames', () async {
    final applied = <Map<String, dynamic>>[];
    final realtime = receiver(applied)..start();
    await until(() => realtime.state == 'final_only');
    sockets.single.add(
      jsonEncode({
        'type': 'final',
        'generation': 'generation-1',
        'char_id': 'character_a',
        'domain': 'reality',
        'client_type': 'mobile',
        'message': message(1, charId: 'character_b'),
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(applied, isEmpty);
    realtime.stop();
    expect(realtime.state, 'http');
    expect(backend.sends, 0);
  });

  test(
    'duplicate WS and HTTP final merge repeated paragraphs by occurrence',
    () async {
      final chat = ChatController(
        backend: () => backend,
        token: () => 'fixture',
        settings: SettingsStore(store),
        relay: RelayStatusService(store),
        networkChanges: const Stream.empty(),
        deliveryOwner: () => 'owner',
        deliveryCharId: () => 'character_a',
        resolvePresenceSession:
            ({required String charId, bool force = false}) async => grant,
      );
      addTearDown(chat.dispose);
      chat.realtime.start();
      await until(() => chat.realtime.state == 'final_only');
      backend.response = Completer<BackendChatResponse>();
      chat.send('test');
      await until(() => backend.request != null);
      final payload = message(1, request: backend.request);
      final frame = jsonEncode({
        'type': 'final',
        'generation': 'generation-1',
        'char_id': 'character_a',
        'domain': 'reality',
        'client_type': 'mobile',
        'message': payload,
      });
      sockets.single.add(frame);
      sockets.single.add(frame);
      await until(() => chat.realtime.finalFrames == 2);
      expect(chat.himTyping, false);
      expect(
        chat.sent.where((m) => m.role == 'reasoning').single.text,
        'turn-1',
      );
      expect(chat.sent.where((m) => m.role == 'him').length, 2);
      backend.response!.complete(
        const BackendChatResponse(
          reply: 'Hello\nHello',
          displayText: '<hl>Hello</hl>\nHello',
          emotion: 'neutral',
          turnId: 'turn-1',
          msgId: 'turn-1',
        ),
      );
      await until(() => !chat.sending);
      expect(
        [
          ...chat.history,
          ...chat.sent,
        ].where((m) => m.role == 'him' && m.turnId == 'turn-1').length,
        2,
      );
      expect(backend.sends, 1);
      expect(chat.lastAckedMobileSeq, isNull);
    },
  );

  test(
    'late HTTP failure cannot downgrade an already persisted WS reply',
    () async {
      final chat = ChatController(
        backend: () => backend,
        token: () => 'fixture',
        settings: SettingsStore(store),
        relay: RelayStatusService(store),
        networkChanges: const Stream.empty(),
        deliveryOwner: () => 'owner',
        deliveryCharId: () => 'character_a',
        resolvePresenceSession:
            ({required String charId, bool force = false}) async => grant,
      );
      addTearDown(chat.dispose);
      chat.realtime.start();
      await until(() => chat.realtime.state == 'final_only');
      backend.response = Completer<BackendChatResponse>();
      chat.send('test');
      await until(() => backend.request != null);
      sockets.single.add(
        jsonEncode({
          'type': 'final',
          'generation': 'generation-1',
          'char_id': 'character_a',
          'domain': 'reality',
          'client_type': 'mobile',
          'message': message(1, request: backend.request),
        }),
      );
      await until(() => chat.realtime.finalFrames == 1);
      backend.response!.completeError(
        const BackendException('execution_outcome_unknown', statusCode: 503),
      );
      await until(() => !chat.sending);
      expect(chat.himTyping, false);
      expect(
        [...chat.sent, ...chat.history].where((m) => m.role == 'him'),
        hasLength(2),
      );
      expect(
        [
          ...chat.sent,
          ...chat.history,
        ].where((m) => m.role == 'you').every((m) => !m.failed),
        true,
      );
    },
  );

  test(
    'persistence failure stops typing and cannot display a successful reply',
    () async {
      final chat = ChatController(
        backend: () => backend,
        token: () => 'fixture',
        settings: SettingsStore(store),
        relay: RelayStatusService(store),
        networkChanges: const Stream.empty(),
        deliveryOwner: () => 'owner',
        deliveryCharId: () => 'character_a',
        resolvePresenceSession:
            ({required String charId, bool force = false}) async => grant,
      );
      addTearDown(chat.dispose);
      backend.response = Completer<BackendChatResponse>();
      chat.send('test');
      await until(() => backend.request != null);
      backend.response!.complete(
        const BackendChatResponse(
          reply: 'half sentence',
          emotion: 'neutral',
          turnId: 'failed',
          msgId: 'failed',
          criticalWritten: false,
        ),
      );
      await until(() => !chat.sending);
      expect(chat.himTyping, false);
      expect(
        [...chat.sent, ...chat.history].where((m) => m.role == 'him'),
        isEmpty,
      );
      expect(backend.sends, 1);
    },
  );

  test('cancel closes an upgrade whose peer never responds', () async {
    final blackhole = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<void>();
    final closed = Completer<void>();
    Socket? peer;
    blackhole.listen((socket) {
      peer = socket;
      socket.listen(
        (bytes) {
          if (!received.isCompleted) received.complete();
        },
        onDone: () {
          if (!closed.isCompleted) closed.complete();
        },
      );
    });
    final transport = BackendClient(
      baseUrl: 'http://127.0.0.1:${blackhole.port}',
      settingsStore: store,
      httpClientFactory: _realClient,
    );
    final attempt = transport.openMobileRealtime(
      token: 'fixture',
      sessionId: 'session-a',
      clientId: 'client-a',
    );
    final outcome = expectLater(attempt, throwsA(isA<Exception>()));
    await received.future.timeout(const Duration(seconds: 2));
    transport.cancelMobileRealtime();
    await outcome.timeout(const Duration(seconds: 2));
    await closed.future.timeout(const Duration(seconds: 2));
    peer?.destroy();
    await blackhole.close();
  });
}
