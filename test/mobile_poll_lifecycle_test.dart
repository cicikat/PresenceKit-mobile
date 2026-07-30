// Fills the two gaps the foreground delivery contract test does not cover
// (see docs/quality/testing-and-dev.md):
//   1. the mobile-poll ack *cursor persistence* failing (as opposed to the
//      network ack call itself failing, which foreground_mobile_delivery_
//      contract_test.dart already covers) must not advance the cursor used
//      for the next poll's `after` param;
//   2. a message re-delivered in a later poll batch (same id/seq) must not
//      be shown twice.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/main.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';

class _LifecycleSettingsStore extends AppSettingsStore {
  _LifecycleSettingsStore({this.cursorPersistThrows = false});

  final bool cursorPersistThrows;
  final List<String> events = [];
  int cursorPersistAttempts = 0;
  int? lastAckedSeq;
  List<String> seenIds = [];

  @override
  Future<String?> loadBackendBaseUrl() async => 'http://127.0.0.1:8080';

  @override
  Future<String?> loadAdminToken() async => 'test-token';

  @override
  Future<bool> loadBackgroundNotificationsEnabled() async => true;

  @override
  Future<bool> isAllowedBaseUrl(String raw) async => true;

  @override
  Future<String?> normalizeOrigin(String raw) async => raw;

  @override
  Future<bool> isBackgroundNotificationServiceRunning() async => false;

  @override
  Future<int?> loadLastAckedMobileSeq() async => lastAckedSeq;

  @override
  Future<void> saveLastAckedMobileSeq(int value) async {
    cursorPersistAttempts += 1;
    if (cursorPersistThrows) {
      throw Exception('local storage write failed');
    }
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
  Future<void> startBackgroundNotifications() async {}
}

class _LifecycleBackendClient extends BackendClient {
  _LifecycleBackendClient(this._settings, {required this.pollBatches})
    : super(baseUrl: 'http://127.0.0.1:8080', settingsStore: _settings);

  final _LifecycleSettingsStore _settings;
  final List<List<MobilePollMessage>> pollBatches;
  final List<int?> pollAfters = [];
  final List<int> ackSeqs = [];
  int _pollBatchIndex = 0;

  @override
  Future<MobileActivationResult> activateMobile({
    required String token,
  }) async => const MobileActivationResult(ok: true, active: true);

  @override
  Future<MobileActivationResult> deactivateMobile({
    required String token,
  }) async => const MobileActivationResult(ok: true, active: false);

  @override
  Future<ChatLogDates> loadChatLogDates({required String token}) async {
    return ChatLogDates.fromJson(const {});
  }

  @override
  Future<GardenState> loadGardenState({required String token}) async {
    return GardenState.fromJson(const {});
  }

  @override
  Future<MobilePollResult> pollMobile({
    required String token,
    int limit = 20,
    int? after,
    int waitSeconds = 0,
  }) async {
    pollAfters.add(after);
    if (_pollBatchIndex >= pollBatches.length) {
      return const MobilePollResult(ok: true, active: true, messages: []);
    }
    return MobilePollResult(
      ok: true,
      active: true,
      messages: pollBatches[_pollBatchIndex++],
    );
  }

  @override
  Future<void> ackMobile({required String token, required int ackSeq}) async {
    _settings.events.add('ack:$ackSeq');
    ackSeqs.add(ackSeq);
  }
}

void main() {
  testWidgets(
    'ack cursor persistence failure leaves the poll cursor unchanged',
    (tester) async {
      final settings = _LifecycleSettingsStore(cursorPersistThrows: true);
      final message = MobilePollMessage.fromJson({
        'id': 'lifecycle-cursor-1',
        'seq': 5,
        'content': '游标持久化失败测试',
        'user_id': '10001',
        'timestamp': 1781280000,
      });
      final backend = _LifecycleBackendClient(
        settings,
        pollBatches: [
          [message],
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CompanionApp(settingsStore: settings, backendClient: backend),
        ),
      );
      for (var i = 0; i < 20; i += 1) {
        await tester.pump(const Duration(milliseconds: 100));
        if (backend.ackSeqs.isNotEmpty) break;
      }
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('游标持久化失败测试'), findsOneWidget);
      // The network ack still fired (it succeeded)...
      expect(backend.ackSeqs, [5]);
      // ...but persisting the cursor failed, so it must not have advanced.
      expect(settings.cursorPersistAttempts, 1);
      expect(settings.lastAckedSeq, isNull);

      // The next poll cycle must therefore still request messages after the
      // old (null) cursor, not seq 5 — otherwise a retry after a transient
      // storage failure would silently skip messages.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 100));
      expect(backend.pollAfters, [null, null]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'a message re-delivered in a later poll batch is deduped, not shown twice',
    (tester) async {
      final settings = _LifecycleSettingsStore();
      final message = MobilePollMessage.fromJson({
        'id': 'lifecycle-dup-1',
        'seq': 5,
        'content': '重复投递测试',
        'user_id': '10001',
        'timestamp': 1781280000,
      });
      final backend = _LifecycleBackendClient(
        settings,
        // The backend echoes the exact same message (same id + seq) again in
        // the second poll batch, e.g. because the client's ack didn't land
        // before the backend's own retry window elapsed.
        pollBatches: [
          [message],
          [message],
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CompanionApp(settingsStore: settings, backendClient: backend),
        ),
      );
      for (var i = 0; i < 20; i += 1) {
        await tester.pump(const Duration(milliseconds: 100));
        if (backend.ackSeqs.isNotEmpty) break;
      }
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('重复投递测试'), findsOneWidget);
      expect(settings.lastAckedSeq, 5);

      // Trigger the next poll cycle, which replays the same message.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 100));

      expect(backend.pollAfters, [null, 5]);
      // Still only one bubble: the duplicate id must be filtered out.
      expect(find.text('重复投递测试'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );
}
