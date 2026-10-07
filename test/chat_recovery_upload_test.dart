import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/screen_context.dart';
import 'package:presencekit_mobile/models/session_scope.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Settings extends AppSettingsStore {
  List<PendingMobileEnvelope> pending = const [];
  List<String> seen = const [];
  Object? pendingError;
  int consumeCalls = 0;

  @override
  Future<bool> isBackgroundNotificationServiceRunning() async => false;
  @override
  Future<List<String>> loadSeenMobileMessageIds() async => seen;

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
  Completer<void>? pollGate;
  bool pollFailure = false;
  String? replyDisplayText;
  int sessionMisses = 0;
  bool dropCompletedResponse = false;
  int chatExecutions = 0;
  bool omitTurnId = false;
  bool networkDown = false;
  List<MobilePollMessage> pollMessages = const [];
  int uploadExecutions = 0;
  final uploadedRequestIds = <String?>[];
  final _completedChats = <String, BackendChatResponse>{};
  final _completedUploads = <String, BackendChatResponse>{};
  int historySessionMisses = 0;
  final sentSessionIds = <String?>[];
  final sentRequestIds = <String?>[];
  final sentReplyTargets = <ReplyTarget?>[];
  final historySessionIds = <String?>[];
  Uint8List? mediaBytes;
  int mediaDownloads = 0;
  Completer<void>? mediaGate;
  @override
  Future<ChatLogDates> loadChatLogDates({
    required String token,
    String? sessionId,
    String? characterId,
  }) async {
    historyReads++;
    historySessionIds.add(sessionId);
    if (historySessionMisses > 0) {
      historySessionMisses -= 1;
      throw const BackendException('session_not_found', statusCode: 404);
    }
    if (offline) throw const BackendException('offline');
    return ChatLogDates.fromJson({
      'dates': day == null ? [] : [day!.date],
    });
  }

  @override
  Future<ChatLogDay> loadChatLogDay(
    String date, {
    required String token,
    String? sessionId,
    String? characterId,
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
    final fail = pollFailure;
    await pollGate?.future;
    if (fail) throw const BackendException('old poll failure');
    return MobilePollResult(ok: true, active: true, messages: pollMessages);
  }

  @override
  Future<BackendChatResponse> sendChat(
    String message, {
    required String token,
    ReplyTarget? replyTo,
    String? sessionId,
    String? requestId,
  }) async {
    chats++;
    sentReplyTargets.add(replyTo);
    sentSessionIds.add(sessionId);
    sentRequestIds.add(requestId);
    await sendGate?.future;
    if (sessionMisses > 0) {
      sessionMisses -= 1;
      throw const BackendException('session_not_found', statusCode: 404);
    }
    final key = requestId?.trim();
    if (key != null && key.isNotEmpty && _completedChats.containsKey(key)) {
      return _completedChats[key]!;
    }
    if (networkDown) throw const BackendException('timeout');
    if (offline) throw const BackendException('offline', statusCode: 500);
    chatExecutions++;
    final response = BackendChatResponse(
      reply: 'echo:$message',
      emotion: 'neutral',
      displayText: replyDisplayText,
      msgId: 'msg-$chatExecutions',
      turnId: omitTurnId ? null : 'turn-$chatExecutions',
    );
    if (key != null && key.isNotEmpty) {
      _completedChats[key] = response;
    }
    if (dropCompletedResponse) {
      dropCompletedResponse = false;
      throw const BackendException('offline');
    }
    return response;
  }

  @override
  Future<BackendChatResponse> uploadFiles({
    required List<PickedUploadFile> files,
    required String token,
    String message = '',
    String channel = 'mobile',
    String? sessionId,
    String? requestId,
  }) async {
    uploads++;
    uploaded = files;
    caption = message;
    uploadedRequestIds.add(requestId);
    final key = requestId?.trim();
    if (key != null && key.isNotEmpty && _completedUploads.containsKey(key)) {
      return _completedUploads[key]!;
    }
    if (offline) throw const BackendException('offline', statusCode: 500);
    uploadExecutions++;
    const response = BackendChatResponse(reply: '', emotion: 'neutral');
    if (key != null && key.isNotEmpty) {
      _completedUploads[key] = response;
    }
    if (dropCompletedResponse) {
      dropCompletedResponse = false;
      throw const BackendException('offline');
    }
    return response;
  }

  @override
  Future<Uint8List> downloadChatMedia(
    String sha256, {
    required String token,
    Duration timeout = const Duration(seconds: 30),
    String? sessionId,
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
      resolvePresenceSession: ({required String charId, bool force = false}) async =>
          PresenceSessionGrant(
            sessionId: 'sess-$charId',
            charId: charId,
            ownerId: 'owner',
            domain: 'reality',
          ),
    );
  });
  tearDown(() => controller.dispose());

  test('old epoch poll failure cannot clear a new successful poll state', () async {
    backend.pollGate = Completer<void>();
    final oldGate = backend.pollGate!;
    backend.pollFailure = true;
    final oldPoll = controller.pollMobile();
    await Future<void>.delayed(Duration.zero);
    await controller.resetForConnectionChange(restart: false);
    backend.pollGate = null;
    backend.pollFailure = false;
    await controller.pollMobile();
    expect(controller.mobileActive, isTrue);
    oldGate.complete();
    await oldPoll;
    expect(controller.mobileActive, isTrue);
    expect(controller.mobileError, isNull);
  });

  testWidgets('unknown outcome expires to retry without any successful poll', (tester) async {
    backend.networkDown = true;
    controller.uncertainWindow = const Duration(seconds: 1);
    var now = DateTime(2026, 10, 7);
    controller.clock = () => now;
    controller.send('offline');
    await tester.pump();
    expect(controller.sent.singleWhere((m) => m.role == 'you').uncertain, isTrue);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.sent.singleWhere((m) => m.role == 'you').failed, isTrue);
  });
  Future<void> settle() async {
    for (var i = 0; i < 20 && controller.sending; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'native seen notification still replays its pending paragraphs exactly once',
    () async {
      backend.offline = false;
      settings.seen = ['background'];
      await controller.pollMobile();
      settings.pending = [
        const PendingMobileEnvelope(
          content: 'first\nsecond',
          displayText: '<hl>first</hl>\n<big>second</big>',
          id: 'background',
          turnId: 'background',
          replayable: true,
          origin: 'http://127.0.0.1:8080',
          owner: 'owner',
          charId: 'char-a',
        ),
      ];
      await controller.catchUpFromNotification();
      await controller.catchUpFromNotification();
      final rows = [
        ...controller.history,
        ...controller.sent,
      ].where((m) => m.role == 'him').toList();
      expect(rows.map((m) => m.text), ['first', 'second']);
      expect(rows.map((m) => m.displayText), [
        '<hl>first</hl>',
        '<big>second</big>',
      ]);
    },
  );

  test(
    'server epochs place user then tool then assistant within one minute',
    () async {
      backend.offline = false;
      final epoch = DateTime(2026, 9, 13, 12).millisecondsSinceEpoch / 1000;
      backend.day = ChatLogDay.fromJson({
        'date': '2026-09-13',
        'entries': [
          {
            'time': '12:00',
            'ts': epoch + 10,
            'tool_activity': {
              'source': 'reality',
              'event_id': 'e1',
              'chain_id': 'c1',
              'char_id': 'char-a',
              'tool_name': 'get_time',
              'status': 'success',
            },
          },
          {
            'time': '12:00',
            'ts': epoch + 40,
            'user_ts': epoch + 1,
            'user': 'question',
            'assistant': 'answer',
            'turn_id': 't1',
          },
        ],
      });
      await controller.loadHistory();
      expect(controller.history.map((m) => m.role), [
        'you',
        'tool',
        'reasoning',
        'him',
      ]);
      expect(controller.history.last.text, 'answer');
    },
  );

  test(
    'retry preserves the exact quoted wire payload and request identity',
    () async {
      final quote = ReplyTarget(
        text: 'quoted',
        timestamp: DateTime(2026, 9, 13, 12),
      );
      controller.send('hello', replyToOverride: quote);
      await settle();
      controller.uncertainWindow = Duration.zero;
      controller.expireUncertain();
      final failed = controller.sent.singleWhere((m) => m.role == 'you');
      backend.offline = false;
      controller.retryMessage(failed);
      await settle();
      expect(backend.sentReplyTargets.map((r) => r?.toJson()), [
        quote.toJson(),
        quote.toJson(),
      ]);
      expect(backend.sentRequestIds, [failed.requestId, failed.requestId]);
    },
  );

  test(
    'HTTP replay cannot append a turn already restored from history',
    () async {
      backend.offline = false;
      backend.replyDisplayText = '<hl>echo:hello</hl>';
      backend.sendGate = Completer<void>();
      controller.send('hello');
      await Future<void>.delayed(Duration.zero);
      final user = controller.sent.singleWhere((m) => m.role == 'you');
      backend.day = ChatLogDay.fromJson({
        'date': '2026-09-13',
        'entries': [
          {
            'time': '12:00',
            'user': 'hello',
            'assistant': 'echo:hello',
            'turn_id': 'turn-1',
            'request_id': user.requestId,
          },
        ],
      });
      await controller.loadHistory(reconcileLocal: true);
      backend.sendGate!.complete();
      await settle();
      final all = [...controller.history, ...controller.sent];
      expect(
        all.where((m) => m.role == 'him' && m.text == 'echo:hello'),
        hasLength(1),
      );
      expect(all.singleWhere((m) => m.role == 'him').displayText, '<hl>echo:hello</hl>');
      expect(all.singleWhere((m) => m.role == 'you').turnId, 'turn-1');
      expect(all.singleWhere((m) => m.role == 'you').requestId, user.requestId);
    },
  );

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
  test('failed history does not complete initial sync so start can retry', () async {
    await controller.start();
    expect(controller.historyError, 'offline');
    expect(controller.historyLoaded, isFalse);
    expect(controller.mobileActive, isFalse);
    backend.offline = false;
    backend.day = ChatLogDay.fromJson({
      'date': '2026-09-12',
      'entries': [
        {'time': '12:00', 'assistant': 'recovered'},
      ],
    });
    await controller.start();
    expect(controller.historyLoaded, isTrue);
    expect(controller.historyError, isNull);
    expect(controller.history.last.text, 'recovered');
    expect(controller.mobileActive, isTrue);
  },
  );

  test('missing session character is unavailable, not unsupported', () async {
    final unbound = ChatController(
      backend: () => backend,
      token: () => 'test-token',
      settings: SettingsStore(settings),
      relay: RelayStatusService(settings),
      deliveryOrigin: () => 'http://127.0.0.1:8080',
      deliveryOwner: () => 'owner',
      deliveryCharId: () => null,
      resolvePresenceSession: ({required String charId, bool force = false}) async =>
          PresenceSessionGrant(
            sessionId: 'sess-$charId',
            charId: charId,
            ownerId: 'owner',
            domain: 'reality',
          ),
    );
    addTearDown(unbound.dispose);
    await unbound.start();
    expect(unbound.historyError, 'character_unavailable');
    expect(unbound.historyLoaded, isFalse);
  });

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

  test(
    'history session_not_found rebinds the original character',
    () async {
      backend.offline = false;
      backend.historySessionMisses = 1;
      backend.day = ChatLogDay.fromJson({
        'date': '2026-09-12',
        'entries': [
          {'time': '12:00', 'assistant': 'rebound'},
        ],
      });
      var binds = 0;
      var invalidated = 0;
      PresenceSessionGrant grantFor(String charId, {bool force = false}) =>
          PresenceSessionGrant(
            sessionId: force ? 'sess-rebound' : 'sess-$charId',
            charId: charId,
            ownerId: 'owner',
            domain: 'reality',
          );
      final scoped = ChatController(
        backend: () => backend,
        token: () => 'test-token',
        settings: SettingsStore(settings),
        relay: RelayStatusService(settings),
        deliveryOrigin: () => 'http://127.0.0.1:8080',
        deliveryOwner: () => 'owner',
        deliveryCharId: () => 'char-a',
        resolvePresenceSession: ({required String charId, bool force = false}) async {
          binds += 1;
          return grantFor(charId, force: force);
        },
        onPresenceSessionInvalid: () => invalidated += 1,
      );
      addTearDown(scoped.dispose);
      await scoped.start();
      expect(scoped.history.last.text, 'rebound');
      expect(scoped.historyError, isNull);
      expect(backend.historySessionIds, ['sess-char-a', 'sess-rebound']);
      expect(binds, greaterThanOrEqualTo(2));
      expect(invalidated, 1);
    });

  test(
    'session_not_found rebinds and retries the same request_id',
    () async {
      backend.offline = false;
      backend.sessionMisses = 1;
      var binds = 0;
      var invalidated = 0;
      final scoped = ChatController(
        backend: () => backend,
        token: () => 'test-token',
        settings: SettingsStore(settings),
        relay: RelayStatusService(settings),
        deliveryOrigin: () => 'http://127.0.0.1:8080',
        deliveryOwner: () => 'owner',
        deliveryCharId: () => 'char-a',
        resolvePresenceSession: ({required String charId, bool force = false}) async {
          binds += 1;
          return PresenceSessionGrant(
            sessionId: force ? 'sess-rebound' : 'sess-$charId',
            charId: charId,
            ownerId: 'owner',
            domain: 'reality',
          );
        },
        onPresenceSessionInvalid: () => invalidated += 1,
      );
      addTearDown(scoped.dispose);
      scoped.send('ping');
      for (var i = 0; i < 20 && (scoped.sending || backend.chats < 2); i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(backend.chats, 2);
      expect(backend.sentSessionIds, ['sess-char-a', 'sess-rebound']);
      expect(backend.sentRequestIds, hasLength(2));
      expect(backend.sentRequestIds[0], backend.sentRequestIds[1]);
      expect(backend.sentRequestIds.first, startsWith('req_'));
      expect(binds, greaterThanOrEqualTo(2));
      expect(invalidated, 1);
      expect(scoped.backendError, isNull);
      expect(scoped.sent.where((m) => m.role == 'him').single.text, 'echo:ping');
    });

  test('manual retry reuses the failed bubble request_id', () async {
    controller.send('hello');
    for (var i = 0; i < 20 && controller.sending; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    final failed = controller.sent.singleWhere((item) => item.role == 'you');
    expect(failed.failed, isTrue);
    expect(failed.requestId, startsWith('req_'));
    backend.offline = false;
    controller.retryMessage(failed);
    for (var i = 0; i < 20 && controller.sending; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(backend.sentRequestIds, [failed.requestId, failed.requestId]);
    expect(
      controller.sent.singleWhere((item) => item.role == 'you').requestId,
      failed.requestId,
    );
  });

  test(
    'retry after a lost completed response does not execute a second turn',
    () async {
      backend.offline = false;
      backend.dropCompletedResponse = true;
      controller.send('hello');
      for (var i = 0; i < 20 && controller.sending; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final failed = controller.sent.singleWhere((item) => item.role == 'you');
      expect(failed.uncertain, isTrue);
      expect(failed.failed, isFalse);
      expect(backend.chatExecutions, 1);
      controller.clock = () => DateTime.now().add(const Duration(minutes: 6));
      controller.expireUncertain();
      expect(controller.sent.singleWhere((m) => m.role == 'you').failed, isTrue,
      );
      controller.retryMessage(controller.sent.singleWhere((m) => m.role == 'you'),
      );
      for (var i = 0; i < 20 && controller.sending; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(backend.chatExecutions, 1);
      expect(backend.sentRequestIds, [failed.requestId, failed.requestId]);
      expect(
        controller.sent.where((item) => item.role == 'him').single.text,
        'echo:hello',
      );
    },
  );

  test('upload retry reuses request_id and does not re-ingest', () async {
    final file = PickedUploadFile(
      name: 'photo.png',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    backend.offline = false;
    backend.dropCompletedResponse = true;
    await controller.uploadFiles(
      [file],
      preview: '📎 photo.png',
      failureLabel: 'image',
      message: 'caption',
    );
    final failed = controller.sent.singleWhere((item) => item.role == 'you');
    expect(failed.uncertain, isTrue);
    expect(failed.requestId, startsWith('req_'));
    expect(backend.uploadExecutions, 1);
    controller.clock = () => DateTime.now().add(const Duration(minutes: 6));
    controller.expireUncertain();
    controller.retryMessage(
      controller.sent.singleWhere((item) => item.role == 'you'),
    );
    for (var i = 0; i < 20 && controller.sending; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(backend.uploads, 2);
    expect(backend.uploadExecutions, 1);
    expect(backend.uploadedRequestIds, [failed.requestId, failed.requestId]);
    expect(
      controller.sent.singleWhere((item) => item.role == 'you').id,
      failed.id,
    );
  });
  MobilePollMessage pollReply(String requestId) => MobilePollMessage.fromJson({
    'id': 'poll-1',
    'seq': 1,
    'content': 'late reply',
    'user_id': 'owner',
    'char_id': 'char-a',
    'request_id': requestId,
  });

  test('timeout marks the send uncertain, not failed, and poll request_id clears it', () async {
    backend.networkDown = true; // BackendException without HTTP status
    controller.send('hello');
    await settle();
    final unsure = controller.sent.singleWhere((m) => m.role == 'you');
    expect(unsure.uncertain, isTrue);
    expect(unsure.failed, isFalse);
    expect(controller.backendError, isNull);
    backend.pollMessages = [pollReply('req_other')];
    await controller.pollMobile();
    expect(controller.sent.singleWhere((m) => m.role == 'you').uncertain, isTrue,
      );
    backend.pollMessages = [pollReply(unsure.requestId!)];
    await controller.pollMobile();
    final cleared = controller.sent.singleWhere((m) => m.role == 'you');
    expect(cleared.uncertain, isFalse);
    expect(cleared.failed, isFalse);
  },
  );

  test('history refresh carrying the request_id clears an uncertain send', () async {
    backend.networkDown = true;
    controller.send('hello');
    await settle();
    final unsure = controller.sent.singleWhere((m) => m.role == 'you');
    expect(unsure.uncertain, isTrue);
    backend.networkDown = false;
    backend.offline = false;
    backend.day = ChatLogDay.fromJson({
      'date': '2026-09-13',
      'entries': [
        {
          'time': '12:00',
          'user': 'hello',
          'assistant': 'echo:hello',
          'turn_id': 't9',
          'request_id': unsure.requestId,
        },
      ],
    });
    await controller.loadHistory(reconcileLocal: true);
    final all = [...controller.history, ...controller.sent];
    expect(all.where((m) => m.role == 'you' && (m.uncertain || m.failed)), isEmpty,
      );
    expect(all.where((m) => m.role == 'you' && m.text == 'hello'), hasLength(1),
      );
  },
  );

  test('uncertain turns failed only after the window and then offers retry', () async {
    backend.networkDown = true;
    controller.send('hello');
    await settle();
    expect(controller.expireUncertain(), isFalse);
    controller.clock = () => DateTime.now().add(const Duration(minutes: 6));
    expect(controller.expireUncertain(), isTrue);
    final failed = controller.sent.singleWhere((m) => m.role == 'you');
    expect(failed.failed, isTrue);
    expect(failed.uncertain, isFalse);
  },
  );

  test('a failure never falls back to marking the latest other message', () async {
    backend.offline = false;
    controller.send('first');
    await settle();
    backend.networkDown = true;
    controller.send('second');
    await settle();
    final users = controller.sent.where((m) => m.role == 'you').toList();
    expect(users.firstWhere((m) => m.text == 'first').uncertain, isFalse);
    expect(users.firstWhere((m) => m.text == 'first').failed, isFalse);
    expect(users.firstWhere((m) => m.text == 'second').uncertain, isTrue);
  },
  );

  test('an HTTP error status is a definite failure with retry', () async {
    backend.offline = true; // harness answers HTTP 500
    controller.send('hello');
    await settle();
    final m = controller.sent.singleWhere((x) => x.role == 'you');
    expect(m.failed, isTrue);
    expect(m.uncertain, isFalse);
    expect(controller.backendError, isNotNull);
  });

  test('a response without turn_id is not a send failure', () async {
    backend.offline = false;
    backend.omitTurnId = true;
    controller.send('hello');
    await settle();
    final me = controller.sent.singleWhere((m) => m.role == 'you');
    expect(me.failed, isFalse);
    expect(me.uncertain, isFalse);
    expect(controller.sent.where((m) => m.role == 'reasoning' && m.failed), isEmpty,
    );
  });
}
