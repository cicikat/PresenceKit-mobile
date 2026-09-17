/// Independent ChatController session dimensions.
///
/// These flags are allowed to overlap. They are not a single enum and must
/// not be collapsed into hydrating/sending/revealing states.
///
/// Allowed in parallel:
/// - user send or upload with live poll and canonical-media download
/// - user-initiated history refresh while a send is in flight
/// - reveal with poll (new segments enqueue behind the current batch)
/// - older-history pagination with send or poll
///
/// Forbidden:
/// - applying send, upload, poll, or history results after dispose or a
///   connection-generation bump
/// - applying a silent/background history read while sending or revealing
/// - flushing a deferred history refresh while sending, revealing, paging,
///   or another history read is in flight
/// - two concurrent history reads, initial syncs, connection refreshes,
///   sends, or polls
/// - dropping a queued user send or a failed bubble across generation reset
///   until [resetForConnectionChange] explicitly clears live queues
class ChatSessionCoordinator {
  int generation = 0;
  bool disposed = false;
  bool sending = false;
  bool himTyping = false;
  bool playingSegments = false;
  bool historyRefreshPending = false;
  bool initialSyncComplete = false;
  Future<void>? initialSync;
  Future<void>? refresh;
  Future<void>? historyRead;

  int beginEpoch() {
    generation += 1;
    historyRefreshPending = false;
    return generation;
  }

  void markDisposed() => disposed = true;

  bool isCurrent(int captured) => !disposed && captured == generation;

  bool isStale(int captured) => !isCurrent(captured);

  bool shouldHoldHistoryRead({
    required bool backgroundRefresh,
    required bool loadingMoreHistory,
  }) => playingSegments || loadingMoreHistory || (backgroundRefresh && sending);

  bool shouldAbandonHistoryApply({
    required bool backgroundRefresh,
    required bool localMutated,
  }) => playingSegments || (backgroundRefresh && sending) || localMutated;

  void deferHistoryRefresh() => historyRefreshPending = true;

  bool takeDeferredHistoryFlush({required bool loadingMoreHistory}) {
    if (!historyRefreshPending ||
        disposed ||
        sending ||
        playingSegments ||
        loadingMoreHistory ||
        historyRead != null) {
      return false;
    }
    historyRefreshPending = false;
    return true;
  }

  void clearLiveWork() {
    sending = false;
    himTyping = false;
    playingSegments = false;
    historyRefreshPending = false;
    initialSyncComplete = false;
  }
}
