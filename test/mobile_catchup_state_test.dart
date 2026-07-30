import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Settings extends AppSettingsStore {
  _Settings({this.failSeenPersistence = false});

  final bool failSeenPersistence;
  final List<String> seenIds = [];
  int? lastAckedSeq;

  @override
  Future<List<String>> loadSeenMobileMessageIds() async => seenIds;

  @override
  Future<void> saveSeenMobileMessageIds(List<String> ids) async {
    if (failSeenPersistence) throw Exception('seen persistence failed');
    seenIds
      ..clear()
      ..addAll(ids);
  }

  @override
  Future<int?> loadLastAckedMobileSeq() async => lastAckedSeq;

  @override
  Future<void> saveLastAckedMobileSeq(int value) async {
    lastAckedSeq = value;
  }

  @override
  Future<bool> isBackgroundNotificationServiceRunning() async => false;
}

class _Backend extends BackendClient {
  _Backend(
    this.settings, {
    required this.activation,
    required this.pollResults,
    this.historyGate,
  }) : super(baseUrl: 'http://127.0.0.1:8080', settingsStore: settings);

  final _Settings settings;
  final MobileActivationResult activation;
  final List<MobilePollResult> pollResults;
  final Completer<void>? historyGate;
  int pollCalls = 0;
  int ackCalls = 0;

  @override
  Future<MobileActivationResult> activateMobile({
    required String token,
  }) async => activation;

  @override
  Future<MobileActivationResult> deactivateMobile({
    required String token,
  }) async => const MobileActivationResult(ok: true, active: false);

  @override
  Future<ChatLogDates> loadChatLogDates({required String token}) async {
    await historyGate?.future;
    return ChatLogDates.fromJson(const {});
  }

  @override
  Future<MobilePollResult> pollMobile({
    required String token,
    int limit = 20,
    int? after,
    int waitSeconds = 0,
  }) async {
    final index = pollCalls++;
    return index < pollResults.length
        ? pollResults[index]
        : const MobilePollResult(ok: true, active: true, messages: []);
  }

  @override
  Future<void> ackMobile({required String token, required int ackSeq}) async {
    ackCalls += 1;
  }
}

ChatController _controller(_Backend backend, _Settings settings) =>
    ChatController(
      backend: () => backend,
      token: () => 'test-token',
      settings: SettingsStore(settings),
      relay: RelayStatusService(settings),
    );

MobilePollMessage _message(int index) => MobilePollMessage(
  id: 'message-$index',
  seq: index,
  content: 'message $index',
  userId: 'owner',
  timestamp: null,
  behaviorKind: '',
  behaviorDelivery: '',
  behaviorLevel: '',
  behaviorId: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('activate business failure never marks mobile active', () async {
    final settings = _Settings();
    final backend = _Backend(
      settings,
      activation: const MobileActivationResult(
        ok: false,
        active: false,
        error: 'mobile channel is not registered',
      ),
      pollResults: const [],
    );
    final controller = _controller(backend, settings);

    await controller.activateMobile();

    expect(controller.mobileActive, isFalse);
    expect(controller.mobileError, 'mobile channel is not registered');
    expect(backend.pollCalls, 0);
    controller.dispose();
  });

  test('poll active false never marks mobile active', () async {
    final settings = _Settings();
    final backend = _Backend(
      settings,
      activation: const MobileActivationResult(ok: true, active: true),
      pollResults: const [
        MobilePollResult(
          ok: false,
          active: false,
          messages: [],
          error: 'mobile channel is not registered',
        ),
      ],
    );
    final controller = _controller(backend, settings);

    await controller.pollMobile();

    expect(controller.mobileActive, isFalse);
    expect(controller.mobileError, 'mobile channel is not registered');
    controller.dispose();
  });

  test(
    'initial catch-up waits for history and appends backlog without reveal',
    () async {
      final gate = Completer<void>();
      final settings = _Settings();
      final backend = _Backend(
        settings,
        activation: const MobileActivationResult(ok: true, active: true),
        pollResults: [
          MobilePollResult(
            ok: true,
            active: true,
            messages: List.generate(20, (index) => _message(index + 1)),
          ),
        ],
        historyGate: gate,
      );
      final controller = _controller(backend, settings);

      final start = controller.start();
      await Future<void>.delayed(Duration.zero);
      expect(backend.pollCalls, 0);

      gate.complete();
      await start;

      expect(backend.pollCalls, 1);
      expect(controller.sent, hasLength(20));
      expect(controller.sent.every((message) => !message.animate), isTrue);
      expect(controller.himTyping, isFalse);
      controller.dispose();
    },
  );

  test('real-time poll keeps the reveal animation path', () async {
    final settings = _Settings();
    final backend = _Backend(
      settings,
      activation: const MobileActivationResult(ok: true, active: true),
      pollResults: [
        const MobilePollResult(ok: true, active: true, messages: []),
        MobilePollResult(ok: true, active: true, messages: [_message(1)]),
      ],
    );
    final controller = _controller(backend, settings);

    await controller.start();
    await controller.pollMobile();
    await Future<void>.delayed(Duration.zero);

    expect(controller.sent.single.animate, isTrue);
    controller.dispose();
  });

  test('seen persistence failure prevents acknowledgement', () async {
    final settings = _Settings(failSeenPersistence: true);
    final backend = _Backend(
      settings,
      activation: const MobileActivationResult(ok: true, active: true),
      pollResults: [
        MobilePollResult(ok: true, active: true, messages: [_message(1)]),
      ],
    );
    final controller = _controller(backend, settings);

    await controller.pollMobile(animate: false);

    expect(backend.ackCalls, 0);
    expect(controller.lastAckedMobileSeq, isNull);
    controller.dispose();
  });
}
