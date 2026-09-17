import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_session_coordinator.dart';

void main() {
  test('send, poll, and user history refresh may overlap', () {
    final session = ChatSessionCoordinator()
      ..sending = true
      ..generation = 1;
    expect(
      session.shouldHoldHistoryRead(
        backgroundRefresh: true,
        loadingMoreHistory: false,
      ),
      isTrue,
    );
    expect(
      session.shouldHoldHistoryRead(
        backgroundRefresh: false,
        loadingMoreHistory: false,
      ),
      isFalse,
    );
    session.deferHistoryRefresh();
    expect(
      session.takeDeferredHistoryFlush(loadingMoreHistory: false),
      isFalse,
    );
    session.sending = false;
    expect(session.takeDeferredHistoryFlush(loadingMoreHistory: false), isTrue);
    expect(session.historyRefreshPending, isFalse);
  });

  test('reveal holds silent history and serializes extra segments', () {
    final session = ChatSessionCoordinator()..playingSegments = true;
    expect(
      session.shouldHoldHistoryRead(
        backgroundRefresh: true,
        loadingMoreHistory: false,
      ),
      isTrue,
    );
    expect(
      session.shouldAbandonHistoryApply(
        backgroundRefresh: false,
        localMutated: false,
      ),
      isTrue,
    );
    session.deferHistoryRefresh();
    expect(
      session.takeDeferredHistoryFlush(loadingMoreHistory: false),
      isFalse,
    );
  });

  test('generation bump discards in-flight work and keeps later sends', () {
    final session = ChatSessionCoordinator()
      ..sending = true
      ..himTyping = true
      ..playingSegments = true
      ..historyRefreshPending = true
      ..initialSyncComplete = true;
    final captured = session.generation;
    final next = session.beginEpoch();
    expect(next, captured + 1);
    expect(session.isStale(captured), isTrue);
    expect(session.isCurrent(next), isTrue);
    session.clearLiveWork();
    expect(session.sending, isFalse);
    expect(session.playingSegments, isFalse);
    expect(session.historyRefreshPending, isFalse);
    expect(session.initialSyncComplete, isFalse);
  });

  test('dispose freezes every in-flight apply', () {
    final session = ChatSessionCoordinator()..generation = 4;
    session.markDisposed();
    expect(session.isCurrent(4), isFalse);
    expect(session.isStale(4), isTrue);
    session.deferHistoryRefresh();
    expect(
      session.takeDeferredHistoryFlush(loadingMoreHistory: false),
      isFalse,
    );
  });
}
