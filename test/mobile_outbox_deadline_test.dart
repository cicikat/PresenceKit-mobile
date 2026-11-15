import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/models/screen_context.dart';
import 'package:presencekit_mobile/services/mobile_outbox_store.dart';

void main() {
  late MobileOutboxStore store;
  String? snapshot;
  final now = DateTime.utc(2026, 11, 15);
  setUp(() {
    snapshot = null;
    store = MobileOutboxStore(() async => snapshot, (s) async => snapshot = s);
  });
  Future<OutboxEntry> enqueue(String id) => store.enqueue(
    (seq) => OutboxEntry(
      requestId: id,
      scope: 'scope',
      sequence: seq,
      createdAt: now,
      text: id,
      files: [
        PickedUploadFile(name: 'a.png', bytes: Uint8List.fromList([1, 2, 3])),
      ],
    ),
  );

  test(
    '55: expired/cancelled records preserve payload but release all 100 queue slots',
    () async {
      for (var i = 0; i < MobileOutboxStore.maxEntries; i++) {
        final row = await enqueue('old-$i');
        await store.setState(
          row,
          i.isEven ? OutboxState.expired : OutboxState.cancelled,
        );
      }
      for (var i = 0; i < MobileOutboxStore.maxEntries; i++) {
        await enqueue('new-$i');
      }
      await expectLater(enqueue('overflow'), throwsStateError);
      final rows = await store.readScope('scope');
      expect(rows.length, 200);
      expect(rows.first.files.single.bytes, [1, 2, 3]);
      expect(rows.where((r) => r.state == OutboxState.queued).length, 100);
      await expectLater(
        store.setState(
          rows.first,
          OutboxState.queued,
          queuedAt: now.add(const Duration(minutes: 2)),
        ),
        throwsStateError,
      );
    },
  );

  test(
    '55: cancel and dispatch atomically compete; only one can win',
    () async {
      for (final cancelFirst in [true, false]) {
        final row = await enqueue('race-$cancelFirst');
        final states = cancelFirst
            ? [OutboxState.cancelled, OutboxState.sending]
            : [OutboxState.sending, OutboxState.cancelled];
        final outcomes = await Future.wait(
          states.map((state) => store.setState(row, state)),
        );
        expect(outcomes, [true, false]);
        expect((await store.readScope('scope')).last.state, states.first);
      }
    },
  );

  test(
    '55: retry refreshes deadline; stale preparation cannot claim the retry',
    () async {
      final row = await enqueue('retry');
      await store.setState(row, OutboxState.expired);
      final stopped = (await store.readScope('scope')).single;
      final retryAt = now.add(const Duration(minutes: 2));
      await store.setState(stopped, OutboxState.queued, queuedAt: retryAt);
      expect(await store.setState(row, OutboxState.sending), isFalse);
      final reloaded = MobileOutboxStore(
        () async => snapshot,
        (s) async => snapshot = s,
      );
      final retry = (await reloaded.readScope('scope')).single;
      expect(retry.queuedAt, retryAt);
      expect(retry.createdAt, now);
      expect(retry.files.single.bytes, [1, 2, 3]);
    },
  );

  test(
    '55: legacy snapshot defaults queue time to creation and sent remains unknown',
    () async {
      final row = await enqueue('legacy');
      await store.setState(row, OutboxState.sending);
      final old = jsonDecode(snapshot!) as Map<String, dynamic>;
      (old['entries'] as List).first.remove('queued_at');
      snapshot = jsonEncode(old);
      final reloaded = MobileOutboxStore(
        () async => snapshot,
        (s) async => snapshot = s,
      );
      final loaded = (await reloaded.readScope('scope')).single;
      expect(loaded.queuedAt, now);
      expect(loaded.state, OutboxState.outcomeUnknown);
    },
  );
}
