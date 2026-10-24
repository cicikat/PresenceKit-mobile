import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/session_scope.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Store extends AppSettingsStore {
  int? cursor;
  final seen = <String>[];
  final inbox = <PendingMobileEnvelope>[];
  final events = <String>[];
  bool failStash = false;
  Completer<List<PendingMobileEnvelope>>? peekGate;
  @override
  Future<List<PendingMobileEnvelope>> peekPendingMobileEnvelopes({
    String? origin,
    String? owner,
    String? charId,
  }) async => await peekGate?.future ?? List.of(inbox);
  @override
  Future<void> stashPendingMobileEnvelopes(
    List<Map<String, dynamic>> items, {
    String? origin,
    String? owner,
  }) async {
    if (failStash) throw PlatformException(code: 'inbox_full');
    for (final item in items) {
      if (inbox.any((row) => row.id == item['id'])) continue;
      inbox.add(
        PendingMobileEnvelope.fromJson({
          ...item,
          'origin': origin,
          'owner': owner,
          'replayable': true,
        }),
      );
    }
    events.add('persist');
  }

  @override
  Future<void> ackPendingMobileEnvelopes(
    List<PendingMobileEnvelope> items, {
    String? origin,
    String? owner,
    String? charId,
  }) async {
    if (items.isNotEmpty) events.add('confirm');
    inbox.removeWhere(
      (row) => items.any((item) => item.id == row.id && item.seq == row.seq),
    );
  }

  @override
  Future<int?> loadLastAckedMobileSeq() async => cursor;
  @override
  Future<void> saveLastAckedMobileSeq(
    int value, {
    String? origin,
    String? owner,
  }) async {
    cursor = value;
  }

  @override
  Future<List<String>> loadSeenMobileMessageIds() async => seen;
  @override
  Future<void> saveSeenMobileMessageIds(
    List<String> ids, {
    String? origin,
    String? owner,
  }) async {
    seen
      ..clear()
      ..addAll(ids);
  }
}

class _Backend extends BackendClient {
  _Backend(this.store)
    : super(baseUrl: 'http://localhost:8080', settingsStore: store);
  final _Store store;
  final polls = <Completer<MobilePollResult>>[];
  final waits = <int>[];
  final limits = <int>[];
  final afters = <int?>[];
  final acks = <int>[];
  Completer<ChatLogDates>? historyGate;
  int cancellations = 0;
  @override
  void cancelMobileReceive() {
    cancellations++;
  }

  @override
  Future<MobileActivationResult> activateMobile({
    required String token,
  }) async => const MobileActivationResult(ok: true, active: true);
  @override
  Future<MobileActivationResult> deactivateMobile({
    required String token,
  }) async => const MobileActivationResult(ok: true, active: false);
  @override
  Future<ChatLogDates> loadChatLogDates({
    required String token,
    String? sessionId,
    String? characterId,
  }) async => await historyGate?.future ?? ChatLogDates.fromJson(const {});
  @override
  Future<MobilePollResult> pollMobile({
    required String token,
    int limit = 20,
    int? after,
    int waitSeconds = 0,
  }) {
    limits.add(limit);
    afters.add(after);
    waits.add(waitSeconds);
    final work = Completer<MobilePollResult>();
    polls.add(work);
    return work.future;
  }

  @override
  Future<void> ackMobile({required String token, required int ackSeq}) async {
    store.events.add('server-ack');
    acks.add(ackSeq);
  }
}

MobilePollResult _batch(int start, int count) => MobilePollResult(
  ok: true,
  active: true,
  messages: [
    for (var i = start; i < start + count; i++)
      MobilePollMessage.fromJson({
        'id': 'fixture-$i',
        'seq': i,
        'content': 'item $i',
        'char_id': 'char-a',
        'timestamp': 1,
      }),
  ],
);

ChatController _controller(
  _Store store,
  _Backend backend, {
  Stream<void>? changes,
}) => ChatController(
  backend: () => backend,
  token: () => 'fixture',
  settings: SettingsStore(store),
  relay: RelayStatusService(store),
  networkChanges: changes,
  deliveryOrigin: () => backend.baseUrl,
  deliveryOwner: () => 'owner',
  deliveryCharId: () => 'char-a',
  resolvePresenceSession:
      ({required String charId, bool force = false}) async =>
          PresenceSessionGrant(
            sessionId: 'fixture-session',
            charId: charId,
            ownerId: 'owner',
            domain: 'reality',
          ),
);

void main() {
  testWidgets(
    'inbox persistence failure refuses UI and server acknowledgement, then recovers',
    (tester) async {
      final store = _Store()..failStash = true;
      final backend = _Backend(store);
      final chat = _controller(store, backend);
      final first = chat.pollIfBackgroundUnavailable();
      await tester.pump();
      backend.polls.last.complete(_batch(1, 1));
      await tester.pump();
      await first;
      expect(backend.acks, isEmpty);
      expect(chat.sent, isEmpty);
      expect(store.seen, isEmpty);
      store.failStash = false;
      final retry = chat.pollIfBackgroundUnavailable();
      await tester.pump();
      backend.polls.last.complete(_batch(1, 1));
      await tester.pump();
      await retry;
      expect(backend.acks, [1]);
      expect(
        store.events.indexOf('persist'),
        lessThan(store.events.indexOf('server-ack')),
      );
      expect(chat.sent.where((row) => row.text == 'item 1'), hasLength(1));
      expect(store.inbox.single.id, 'fixture-1');
      chat.dispose();
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'a stale peek is never confirmed and can be replayed by a new epoch',
    (tester) async {
      final store = _Store();
      final backend = _Backend(store);
      final chat = _controller(store, backend);
      store.inbox.add(
        PendingMobileEnvelope.fromJson({
          'id': 'pending',
          'seq': 9,
          'content': 'kept',
          'replayable': true,
          'origin': backend.baseUrl,
          'owner': 'owner',
          'char_id': 'char-a',
        }),
      );
      store.peekGate = Completer<List<PendingMobileEnvelope>>();
      final stale = chat.pollIfBackgroundUnavailable();
      await tester.pump();
      await chat.resetForConnectionChange(restart: false);
      store.peekGate!.complete(List.of(store.inbox));
      await tester.pump();
      await stale;
      expect(store.inbox, hasLength(1));
      expect(store.events, isNot(contains('confirm')));
      expect(chat.sent, isEmpty);
      store.peekGate = null;
      final recovered = chat.pollIfBackgroundUnavailable();
      await tester.pump();
      expect(chat.sent.single.text, 'kept');
      expect(store.events, contains('confirm'));
      backend.polls.last.complete(_batch(10, 0));
      await tester.pump();
      await recovered;
      chat.dispose();
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'network change replaces a held poll and ignores its late result/finally',
    (tester) async {
      final store = _Store();
      final backend = _Backend(store);
      final network = StreamController<void>.broadcast(sync: true);
      final chat = _controller(store, backend, changes: network.stream);
      final old = chat.pollIfBackgroundUnavailable();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        backend.polls,
        hasLength(1),
        reason:
            'error=${chat.mobileError} handoff=${chat.pendingHandoffError} busy=${chat.pollingMobile}',
      );
      network.add(null);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(backend.polls, hasLength(2));
      expect(backend.cancellations, greaterThan(0));
      backend.polls.first.complete(_batch(1, 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await old;
      expect(chat.sent, isEmpty);
      expect(chat.pollingMobile, isTrue);
      backend.polls.last.complete(_batch(2, 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(chat.sent.any((m) => m.text == 'item 2'), isTrue);
      expect(backend.acks, [2]);
      chat.dispose();
      await tester.pump(const Duration(milliseconds: 500));
      await network.close();
    },
  );

  testWidgets(
    'backlog drains without the old five second gap and history cannot block reception',
    (tester) async {
      final store = _Store();
      final backend = _Backend(store)..historyGate = Completer<ChatLogDates>();
      final chat = _controller(store, backend);
      final start = chat.start();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        backend.polls,
        hasLength(1),
        reason:
            'error=${chat.mobileError} handoff=${chat.pendingHandoffError} busy=${chat.pollingMobile}',
      );
      backend.polls.first.complete(_batch(1, 50));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(backend.polls, hasLength(2));
      expect(backend.afters.last, 50);
      expect(backend.waits.last, 25);
      expect(backend.limits.last, 50);
      backend.polls.last.complete(_batch(51, 50));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(backend.acks, [50, 100]);
      backend.historyGate!.complete(ChatLogDates.fromJson(const {}));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await start;
      chat.dispose();
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets('pause stops reception and makes an in-flight result stale', (
    tester,
  ) async {
    final store = _Store();
    final backend = _Backend(store);
    final network = StreamController<void>.broadcast(sync: true);
    final chat = _controller(store, backend, changes: network.stream);
    final old = chat.pollIfBackgroundUnavailable();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    chat.pausePolling();
    network.add(null);
    backend.polls.first.complete(_batch(1, 1));
    await tester.pump(const Duration(seconds: 1));
    await old;
    expect(chat.sent, isEmpty);
    expect(backend.acks, isEmpty);
    expect(
      backend.polls,
      hasLength(1),
      reason:
          'error=${chat.mobileError} handoff=${chat.pendingHandoffError} busy=${chat.pollingMobile}',
    );
    chat.dispose();
    await tester.pump(const Duration(milliseconds: 500));
    await network.close();
  });
}
