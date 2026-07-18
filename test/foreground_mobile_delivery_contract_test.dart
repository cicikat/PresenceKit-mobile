import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/main.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';

class _ForegroundSettingsStore extends AppSettingsStore {
  _ForegroundSettingsStore(this.baseUrl);

  final String baseUrl;
  final List<String> events = [];
  int backgroundServiceStartRequests = 0;
  int? lastAckedSeq;
  List<String> seenIds = [];

  @override
  Future<String?> loadBackendBaseUrl() async => baseUrl;

  @override
  Future<String?> loadAdminToken() async => 'test-token';

  @override
  Future<bool> loadBackgroundNotificationsEnabled() async => true;

  @override
  Future<bool> isAllowedBaseUrl(String raw) async => raw == baseUrl;

  @override
  Future<String?> normalizeOrigin(String raw) async => baseUrl;

  @override
  Future<bool> isBackgroundNotificationServiceRunning() async => false;

  @override
  Future<int?> loadLastAckedMobileSeq() async => lastAckedSeq;

  @override
  Future<void> saveLastAckedMobileSeq(int value) async {
    events.add('cursor:$value');
    lastAckedSeq = value;
  }

  @override
  Future<void> saveSeenMobileMessageIds(List<String> ids) async {
    events.add('persist:${ids.join(',')}');
    seenIds = List<String>.of(ids);
  }

  @override
  Future<List<String>> loadSeenMobileMessageIds() async => seenIds;

  @override
  Future<void> startBackgroundNotifications() async {
    backgroundServiceStartRequests += 1;
  }
}

class _ForegroundBackendClient extends BackendClient {
  _ForegroundBackendClient(
    this.foregroundSettings, {
    this.failAck = false,
    this.chatResponse,
    this.pollBatches,
  }) : super(
         baseUrl: 'http://127.0.0.1:8080',
         settingsStore: foregroundSettings,
       );

  final _ForegroundSettingsStore foregroundSettings;
  final bool failAck;
  final BackendChatResponse? chatResponse;
  final List<List<MobilePollMessage>>? pollBatches;
  final List<int?> pollAfters = [];
  final List<int> ackSeqs = [];
  int _pollBatchIndex = 0;

  @override
  Future<void> activateMobile({required String token}) async {}

  @override
  Future<void> deactivateMobile({required String token}) async {}

  @override
  Future<ChatLogDates> loadChatLogDates({required String token}) async {
    return ChatLogDates.fromJson(const {});
  }

  @override
  Future<GardenState> loadGardenState({required String token}) async {
    return GardenState.fromJson(const {});
  }

  @override
  Future<List<MobilePollMessage>> pollMobile({
    required String token,
    int limit = 20,
    int? after,
    int waitSeconds = 0,
  }) async {
    pollAfters.add(after);
    final batches = pollBatches;
    if (batches != null) {
      if (_pollBatchIndex >= batches.length) return const [];
      return batches[_pollBatchIndex++];
    }
    if (after != null) return const [];
    return [
      MobilePollMessage.fromJson({
        'id': 'relay-foreground-contract-1',
        'seq': 7,
        'content': '前台契约消息一',
        'user_id': '10001',
        'timestamp': 1781280000,
        'behavior': {
          'behavior_id': 'presence_ping',
          'kind': 'overlay_message',
          'delivery': 'overlay',
          'level': 'attention_grab',
        },
      }),
      MobilePollMessage.fromJson({
        'id': 'relay-foreground-contract-2',
        'seq': 12,
        'content': '前台契约消息二',
        'user_id': '10001',
        'timestamp': 1781280001,
      }),
    ];
  }

  @override
  Future<void> ackMobile({required String token, required int ackSeq}) async {
    foregroundSettings.events.add('ack:$ackSeq');
    ackSeqs.add(ackSeq);
    if (failAck) throw const BackendException('ack failed');
  }

  @override
  Future<BackendChatResponse> sendChat(
    String message, {
    required String token,
  }) async {
    return chatResponse ?? super.sendChat(message, token: token);
  }
}

void main() {
  test('BackendChatResponse parses msg_id with turn_id fallback', () {
    expect(
      BackendChatResponse.fromJson(const {
        'reply': 'msg id',
        'msg_id': 'msg-1',
        'turn_id': 'turn-ignored',
      }).msgId,
      'msg-1',
    );
    expect(
      BackendChatResponse.fromJson(const {
        'reply': 'turn id',
        'turn_id': 'turn-1',
      }).msgId,
      'turn-1',
    );
    expect(
      BackendChatResponse.fromJson(const {'reply': 'legacy'}).msgId,
      isNull,
    );
  });

  testWidgets(
    'foreground persists messages before max-seq ack and reuses cursor',
    (tester) async {
      final settings = _ForegroundSettingsStore('http://127.0.0.1:8080');
      final backend = _ForegroundBackendClient(settings);

      await tester.pumpWidget(
        MaterialApp(
          home: CompanionApp(
            settingsStore: settings,
            backendClient: backend,
          ),
        ),
      );
      for (var i = 0; i < 20; i += 1) {
        await tester.pump(const Duration(milliseconds: 100));
        if (settings.lastAckedSeq == 12) break;
      }

      expect(find.text('前台契约消息一'), findsOneWidget);
      expect(find.text('前台契约消息二'), findsOneWidget);
      expect(settings.backgroundServiceStartRequests, 0);
      expect(backend.ackSeqs, [12]);
      expect(settings.lastAckedSeq, 12);
      expect(
        settings.events.indexWhere((event) => event.startsWith('persist:')),
        lessThan(settings.events.indexOf('ack:12')),
      );
      expect(
        settings.events.indexOf('ack:12'),
        lessThan(settings.events.indexOf('cursor:12')),
      );

      await tester.pump(const Duration(seconds: 5));
      expect(backend.pollAfters, contains(12));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'ack failure leaves message visible and cursor unchanged on retry',
    (tester) async {
      final settings = _ForegroundSettingsStore('http://127.0.0.1:8080');
      final backend = _ForegroundBackendClient(settings, failAck: true);

      await tester.pumpWidget(
        MaterialApp(
          home: CompanionApp(
            settingsStore: settings,
            backendClient: backend,
          ),
        ),
      );
      for (var i = 0; i < 20; i += 1) {
        await tester.pump(const Duration(milliseconds: 100));
        if (backend.ackSeqs.isNotEmpty) break;
      }

      expect(find.text('前台契约消息一'), findsOneWidget);
      expect(find.text('前台契约消息二'), findsOneWidget);
      expect(settings.lastAckedSeq, isNull);
      expect(backend.pollAfters.first, isNull);
      expect(
        settings.events.indexWhere((event) => event.startsWith('persist:')),
        lessThan(settings.events.indexOf('ack:12')),
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        backend.pollAfters.where((after) => after == null).length,
        greaterThan(1),
      );
      expect(find.text('前台契约消息一'), findsOneWidget);
      expect(find.text('前台契约消息二'), findsOneWidget);
      expect(settings.lastAckedSeq, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets('sync reply msgId reconciles matching poll reply by id', (
    tester,
  ) async {
    final settings = _ForegroundSettingsStore('http://127.0.0.1:8080');
    const reply = '同一条同步与 poll 回复';
    final backend = _ForegroundBackendClient(
      settings,
      chatResponse: BackendChatResponse.fromJson(const {
        'reply': reply,
        'msg_id': 'turn-x',
      }),
      pollBatches: [
        const [],
        [
          MobilePollMessage(
            id: 'turn-x',
            seq: 21,
            content: reply,
            userId: '10001',
            timestamp: null,
            behaviorKind: '',
            behaviorDelivery: '',
            behaviorLevel: '',
            behaviorId: '',
          ),
        ],
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CompanionApp(
          settingsStore: settings,
          backendClient: backend,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField).last, '测试 id 对账');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(reply), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(reply), findsOneWidget);
    expect(settings.seenIds, contains('turn-x'));
    expect(backend.ackSeqs, contains(21));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets(
    'id-bearing poll reply does not use content fingerprint fallback',
    (tester) async {
      final settings = _ForegroundSettingsStore('http://127.0.0.1:8080');
      const reply = '相同正文但不同消息';
      final backend = _ForegroundBackendClient(
        settings,
        chatResponse: BackendChatResponse.fromJson(const {
          'reply': reply,
          'turn_id': 'turn-sync',
        }),
        pollBatches: [
          const [],
          [
            MobilePollMessage(
              id: 'turn-other',
              seq: 22,
              content: reply,
              userId: '10001',
              timestamp: null,
              behaviorKind: '',
              behaviorDelivery: '',
              behaviorLevel: '',
              behaviorId: '',
            ),
          ],
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CompanionApp(
            settingsStore: settings,
            backendClient: backend,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).last, '测试不同 id');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(reply), findsNWidgets(2));
      expect(settings.seenIds, contains('turn-other'));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );
}
