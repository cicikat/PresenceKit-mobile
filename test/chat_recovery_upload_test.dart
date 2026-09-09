import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/screen_context.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Settings extends AppSettingsStore {
  @override
  Future<bool> isBackgroundNotificationServiceRunning() async => false;
}

class _Backend extends BackendClient {
  _Backend(superStore)
    : super(baseUrl: 'http://localhost:8080', settingsStore: superStore);
  bool offline = true;
  int activations = 0;
  int historyReads = 0;
  int uploads = 0;
  int chats = 0;
  int? wait;
  String? caption;
  List<PickedUploadFile>? uploaded;
  Completer<void>? gate;
  @override
  Future<ChatLogDates> loadChatLogDates({required String token}) async {
    historyReads++;
    if (offline) throw const BackendException('offline');
    return ChatLogDates.fromJson({});
  }

  @override
  Future<MobileActivationResult> activateMobile({required String token}) async {
    activations++;
    await gate?.future;
    if (offline) throw const BackendException('offline');
    return const MobileActivationResult(ok: true, active: true);
  }

  @override
  Future<MobileActivationResult> deactivateMobile({
    required String token,
  }) async => const MobileActivationResult(ok: true, active: false);
  @override
  Future<MobilePollResult> pollMobile({
    required String token,
    int limit = 20,
    int? after,
    int waitSeconds = 0,
  }) async {
    wait = waitSeconds;
    return const MobilePollResult(ok: true, active: true, messages: []);
  }

  @override
  Future<BackendChatResponse> uploadFiles({
    required List<PickedUploadFile> files,
    required String token,
    String message = '',
    String channel = 'mobile',
  }) async {
    uploads++;
    uploaded = files;
    caption = message;
    if (offline) throw const BackendException('offline');
    return const BackendChatResponse(reply: '', emotion: 'neutral');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Settings settings;
  late _Backend backend;
  late ChatController controller;
  setUp(() {
    settings = _Settings();
    backend = _Backend(settings);
    controller = ChatController(
      backend: () => backend,
      token: () => 'test-token',
      settings: SettingsStore(settings),
      relay: RelayStatusService(settings),
    );
  });
  tearDown(() => controller.dispose());

  test(
    'manual refresh recovers failed startup and coalesces repeated refreshes',
    () async {
      await controller.start();
      expect(controller.historyError, 'offline');
      expect(controller.mobileActive, isFalse);
      backend.offline = false;
      backend.gate = Completer<void>();
      final a = controller.refreshConnection();
      final b = controller.refreshConnection();
      expect(identical(a, b), isTrue);
      backend.gate!.complete();
      await a;
      expect(controller.historyLoaded, isTrue);
      expect(controller.historyError, isNull);
      expect(controller.mobileActive, isTrue);
      expect(controller.mobileError, isNull);
      expect(backend.activations, 2);
      expect(backend.wait, 0);
      final reads = backend.historyReads;
      await controller.refreshConnection();
      expect(
        backend.historyReads,
        reads,
        reason:
            'A healthy refresh must not reload and duplicate locally sent messages',
      );
    },
  );

  test(
    'image bytes and caption survive failure and multipart retry without duplicating bubble',
    () async {
      final file = PickedUploadFile(
        name: 'photo.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      await controller.uploadFiles(
        [file],
        preview: '📎 photo.png',
        failureLabel: 'image',
        message: 'caption',
      );
      final failed = controller.sent.single;
      expect(failed.failed, isTrue);
      expect(failed.attachments.single.bytes, same(file.bytes));
      expect(failed.copyWith().attachments.single, same(file));
      expect(failed.settled().uploadNote, 'caption');
      backend.offline = false;
      controller.retryMessage(failed);
      await Future<void>.delayed(Duration.zero);
      expect(backend.uploads, 2);
      expect(backend.caption, 'caption');
      expect(backend.uploaded!.single.bytes, same(file.bytes));
      final userMessages = controller.sent.where((item) => item.role == 'you');
      expect(userMessages, hasLength(1));
      expect(userMessages.single.id, failed.id);
      expect(userMessages.single.failed, isFalse);
    },
  );
}
