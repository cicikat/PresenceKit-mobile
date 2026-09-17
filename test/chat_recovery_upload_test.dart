import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/screen_context.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Settings extends AppSettingsStore {
  List<PendingMobileEnvelope> pending = const [];
  Object? pendingError;
  int consumeCalls = 0;

  @override
  Future<bool> isBackgroundNotificationServiceRunning() async => false;

  @override
  Future<List<PendingMobileEnvelope>> consumePendingMobileEnvelopes({
    String? origin,
    String? owner,
    String? charId,
  }) async {
    consumeCalls += 1;
    final error = pendingError;
    if (error != null) throw error;
    return pending;
  }
}

class _Backend extends BackendClient {
  _Backend(superStore)
    : super(baseUrl: 'http://localhost:8080', settingsStore: superStore);
  bool offline = true;
  ChatLogDay? day;
  int activations = 0;
  int historyReads = 0;
  int uploads = 0;
  int chats = 0;
  int? wait;
  String? caption;
  List<PickedUploadFile>? uploaded;
  Completer<void>? gate;
  Completer<void>? sendGate;
  Uint8List? mediaBytes;
  int mediaDownloads = 0;
  Completer<void>? mediaGate;
  @override
  Future<ChatLogDates> loadChatLogDates({required String token}) async {
    historyReads++;
    if (offline) throw const BackendException('offline');
    return ChatLogDates.fromJson({
      'dates': day == null ? [] : [day!.date],
    });
  }

  @override
  Future<ChatLogDay> loadChatLogDay(
    String date, {
    required String token,
  }) async => day!;

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
  Future<BackendChatResponse> sendChat(
    String message, {
    required String token,
    ReplyTarget? replyTo,
  }) async {
    chats++;
    await sendGate?.future;
    if (offline) throw const BackendException('offline');
    return BackendChatResponse(
      reply: 'echo:$message',
      emotion: 'neutral',
      msgId: 'msg-$chats',
      turnId: 'turn-$chats',
    );
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

  @override
  Future<Uint8List> downloadChatMedia(
    String sha256, {
    required String token,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    mediaDownloads += 1;
    await mediaGate?.future;
    final bytes = mediaBytes;
    if (bytes == null) {
      throw const BackendException('媒体文件已不可恢复', statusCode: 410);
    }
    return bytes;
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
      deliveryOrigin: () => 'http://127.0.0.1:8080',
      deliveryOwner: () => 'owner',
      deliveryCharId: () => 'char-a',
    );
  });
  tearDown(() => controller.dispose());

  test(
    'canonical media caches bytes and coalesces inflight downloads',
    () async {
      const digest =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      backend.mediaBytes = Uint8List.fromList([1, 2, 3]);
      backend.mediaGate = Completer<void>();
      const ref = ChatMediaRef(
        kind: 'image',
        filename: 'scene.png',
        sha256: digest,
      );
      final first = controller.loadCanonicalMedia(ref);
      final second = controller.loadCanonicalMedia(ref);
      backend.mediaGate!.complete();
      expect(await first, backend.mediaBytes);
      expect(await second, backend.mediaBytes);
      expect(backend.mediaDownloads, 1);
      expect(await controller.loadCanonicalMedia(ref), backend.mediaBytes);
      expect(backend.mediaDownloads, 1);
    },
  );

  test('canonical media skips unavailable and invalid fingerprints', () async {
    expect(
      await controller.loadCanonicalMedia(
        const ChatMediaRef(
          kind: 'image',
          filename: 'gone.png',
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          availability: 'unavailable',
        ),
      ),
      isNull,
    );
    expect(
      await controller.loadCanonicalMedia(
        const ChatMediaRef(kind: 'image', filename: 'gone.png', sha256: 'bad'),
      ),
      isNull,
    );
    expect(backend.mediaDownloads, 0);
  });

  test('canonical media treats download failure as a missing image', () async {
    expect(
      await controller.loadCanonicalMedia(
        const ChatMediaRef(
          kind: 'image',
          filename: 'gone.png',
          sha256:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
      ),
      isNull,
    );
    expect(backend.mediaDownloads, 1);
  });

  test(
    'history keeps tool receipts out of bubbles and gives each turn one reasoning anchor',
    () async {
      backend.offline = false;
      final receipt = {
        'source': 'reality',
        'event_id': 'event-1',
        'chain_id': 'chain-1',
        'char_id': 'char',
        'tool_name': 'read_document',
        'status': 'success',
      };
      backend.day = ChatLogDay.fromJson({
        'date': '2026-09-13',
        'entries': [
          {
            'time': '12:00',
            'user': 'question',
            'assistant': 'first',
            'turn_id': 't1',
          },
          {'time': '12:00', 'assistant': 'second', 'turn_id': 't1'},
          {
            'time': '12:01',
            'assistant': 'legacy action',
            'turn_id': 'old-action',
            'entry_kind': 'narration',
          },
          {'time': '12:02', 'tool_activity': receipt},
          {'time': '12:02', 'tool_activity': receipt},
        ],
      });
      await controller.loadHistory();
      expect(controller.history.map((m) => m.role), [
        'you',
        'reasoning',
        'him',
        'him',
        'narration',
        'tool',
      ]);
      expect(controller.history.last.toolActivity!.status, 'success');
      final anchor = controller.history[1].id;
      await controller.loadHistory(reconcileLocal: true);
      expect(controller.history[1].id, anchor);
      expect(controller.history.where((m) => m.role == 'tool'), hasLength(1));
    },
  );

  test(
    'notification opens reread history after native ack and preserve inline display',
    () async {
      backend.offline = false;
      backend.day = ChatLogDay.fromJson({
        'date': '2026-09-12',
        'entries': [
          {'time': '12:00', 'user': 'hi', 'assistant': 'old'},
        ],
      });
      await controller.start();
      backend.day = ChatLogDay.fromJson({
        'date': '2026-09-12',
        'entries': [
          {
            'time': '12:01',
            'user': 'hi',
            'assistant': 'new message',
            'turn_id': 't1',
            'assistant_display_text': '<hl>new</hl> message',
          },
        ],
      });
      await controller.catchUpFromNotification();
      expect(controller.history.last.text, 'new message');
      expect(controller.history.last.displayText, '<hl>new</hl> message');
      expect(
        controller.history.where((m) => m.role == 'reasoning').single.dateKey,
        '2026-09-12',
      );
      expect(backend.historyReads, 2);
    },
  );

  test(
    'offline pending replay keeps identity and skips history duplicates',
    () async {
      backend.offline = false;
      backend.day = ChatLogDay.fromJson({
        'date': '2026-09-12',
        'entries': [
          {
            'time': '12:01',
            'assistant': 'already in history',
            'turn_id': 'dup',
          },
        ],
      });
      await controller.start();
      settings.pending = [
        const PendingMobileEnvelope(
          content: 'already in history',
          id: 'dup',
          turnId: 'dup',
          origin: 'http://127.0.0.1:8080',
          owner: 'owner',
          charId: 'char-a',
          replayable: true,
        ),
        const PendingMobileEnvelope(
          content: 'offline only',
          id: 'fresh',
          turnId: 'fresh',
          origin: 'http://127.0.0.1:8080',
          owner: 'owner',
          charId: 'char-a',
          replayable: true,
        ),
        const PendingMobileEnvelope(content: 'legacy body', replayable: false),
      ];
      await controller.catchUpFromNotification();
      expect(
        controller.sent.where((m) => m.text == 'offline only'),
        hasLength(1),
      );
      expect(
        controller.sent.where((m) => m.text == 'already in history'),
        isEmpty,
      );
      expect(controller.sent.where((m) => m.text == 'legacy body'), isEmpty);
      expect(controller.sent.single.turnId, 'fresh');
      await controller.catchUpFromNotification();
      expect(
        controller.sent.where((m) => m.text == 'offline only'),
        hasLength(1),
      );
    },
  );

  test(
    'missing plugin still refreshes history and keeps a diagnostic error',
    () async {
      backend.offline = false;
      backend.day = ChatLogDay.fromJson({
        'date': '2026-09-12',
        'entries': [
          {'time': '12:00', 'assistant': 'from history', 'turn_id': 'h1'},
        ],
      });
      settings.pendingError = MissingPluginException(
        'consumePendingMobileEnvelopes',
      );
      await controller.catchUpFromNotification();
      expect(controller.history.last.text, 'from history');
      expect(controller.pendingHandoffError, isNotNull);
      expect(backend.historyReads, 1);
    },
  );
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
        reads + 1,
        reason:
            'A healthy refresh must fetch the latest history as a delivery fallback',
      );
    },
  );

  test(
    'refresh adds missed history, reconciles occurrences and retains a pending send',
    () async {
      backend.offline = false;
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      backend.day = ChatLogDay.fromJson({
        'date': date,
        'entries': [
          {'time': '10:00', 'user': 'hello', 'assistant': 'reply'},
          {'time': '10:01', 'user': 'other device', 'assistant': 'missed'},
        ],
      });
      final reply = ChatMessage(role: 'him', text: 'reply', time: '10:00');
      final pending = ChatMessage(
        role: 'you',
        text: 'still sending',
        time: '10:02',
      );
      controller.sent.addAll([
        ChatMessage(role: 'you', text: 'hello', time: '10:00'),
        reply,
        pending,
      ]);
      controller.sending = true;
      await controller.refreshConnection();
      expect(controller.history.map((m) => m.text), [
        'hello',
        'reply',
        'other device',
        'missed',
      ]);
      expect(controller.history[1].id, reply.id);
      expect(controller.sent.single.id, pending.id);
      await controller.refreshConnection();
      expect(controller.history.where((m) => m.text == 'reply'), hasLength(1));
      expect(controller.sent.single.id, pending.id);
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

  test(
    'connection reset drops a late send and keeps later user input',
    () async {
      backend.offline = false;
      backend.day = ChatLogDay.fromJson({
        'date': '2026-09-12',
        'entries': [
          {'time': '12:00', 'assistant': 'ready'},
        ],
      });
      await controller.start();
      backend.sendGate = Completer<void>();
      controller.send('first');
      expect(controller.sending, isTrue);
      expect(controller.sent.where((m) => m.text == 'first'), hasLength(1));
      final reset = controller.resetForConnectionChange();
      await Future<void>.delayed(Duration.zero);
      controller.send('second');
      backend.sendGate!.complete();
      await reset;
      await Future<void>.delayed(Duration.zero);
      expect(controller.sent.where((m) => m.text == 'first'), isEmpty);
      expect(controller.sent.where((m) => m.text == 'second'), hasLength(1));
      expect(controller.sending, isFalse);
    },
  );
}
