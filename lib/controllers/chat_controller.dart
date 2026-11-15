import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import '../models/chat_artifact.dart';
import '../models/inline_display.dart';
import '../models/screen_context.dart';
import '../models/session_scope.dart';
import '../services/app_settings_store.dart';
import '../services/backend_client.dart';
import '../services/device_services.dart';
import '../services/network_status_service.dart';
import '../services/mobile_outbox_store.dart';
import 'chat_history_reconciliation.dart';
import '../models/chat_history_display.dart';
import 'chat_session_coordinator.dart';
import 'mobile_realtime_controller.dart';
import 'chat_scroll_controller.dart';

enum ChatDeliverySource { initialSync, catchUp, live }

class ChatController extends ChangeNotifier {
  ChatController({
    required BackendClient Function() backend,
    required String? Function() token,
    required SettingsStore settings,
    required RelayStatusService relay,
    VoiceService? voice,
    bool Function()? stickerEnabled,
    bool Function()? autoPlayVoice,
    String? Function()? deliveryOrigin,
    String? Function()? deliveryOwner,
    String? Function()? deliveryCharId,
    Future<PresenceSessionGrant?> Function({
      required String charId,
      bool force,
    })?
    resolvePresenceSession,
    void Function()? onPresenceSessionInvalid,
    String? Function()? presenceBindError,
    Stream<void>? networkChanges,
    this.localWaitTimeout = const Duration(seconds: 120),
    this.outgoingAttemptTimeout = const Duration(seconds: 120),
    this.queueWaitTimeout = const Duration(minutes: 1),
  }) : _backend = backend,
       _token = token,
       _settings = settings,
       _outbox = MobileOutboxStore(
         settings.loadChatOutbox,
         settings.saveChatOutbox,
       ),
       _relay = relay,
       _voice = voice ?? const VoiceService(AppSettingsStore()),
       _stickerEnabled = stickerEnabled ?? _alwaysEnabled,
       _autoPlayVoice = autoPlayVoice ?? _alwaysDisabled,
       _deliveryOrigin = deliveryOrigin ?? _alwaysNull,
       _deliveryOwner = deliveryOwner ?? _alwaysNull,
       _deliveryCharId = deliveryCharId ?? _alwaysNull,
       _resolvePresenceSession = resolvePresenceSession,
       _onPresenceSessionInvalid = onPresenceSessionInvalid,
       _presenceBindError = presenceBindError {
    scrollController.addListener(_handleScroll);
    _networkSubscription =
        (networkChanges ?? const NetworkStatusService().changes).listen(
          (_) => _handleNetworkChange(),
          onError: (Object _) {},
        );
  }

  static const initialVisibleMessageCount = 80;
  static const visibleMessageStep = 50;
  static const _staleDeliveryThreshold = Duration(seconds: 15);
  // Mirrors chat_widgets.dart AnimatedRevealText (kept in sync with
  // Emerald-client/src/windows/room/useVnPresenter.ts, 40 CPS).
  static const revealCps = 40.0;
  static bool _alwaysEnabled() => true;
  static bool _alwaysDisabled() => false;
  static String? _alwaysNull() => null;
  final BackendClient Function() _backend;
  final String? Function() _token;
  final SettingsStore _settings;
  final RelayStatusService _relay;
  final VoiceService _voice;
  final bool Function() _stickerEnabled;
  final bool Function() _autoPlayVoice;
  final String? Function() _deliveryOrigin;
  final String? Function() _deliveryOwner;
  final String? Function() _deliveryCharId;
  final Future<PresenceSessionGrant?> Function({
    required String charId,
    bool force,
  })?
  _resolvePresenceSession;
  final void Function()? _onPresenceSessionInvalid;
  final String? Function()? _presenceBindError;
  String? pendingHandoffError;
  String? _boundDeliveryOrigin;
  String? _boundDeliveryOwner;
  final ChatScrollController scrollController = ChatScrollController();

  @override
  void notifyListeners() {
    scrollController.preserveBeforeLayout();
    super.notifyListeners();
  }

  final List<ChatMessage> history = [];
  final List<ChatMessage> sent = [];
  final List<String> _availableDates = [];
  final List<String> _loadedDates = [];
  final List<String> _seenIds = [];
  final Set<String> _syncReplyIds = {};
  final Set<String> _acceptedRequestIds = {};
  final Map<String, Stopwatch> _replyClocks = {};

  void _observeReplyApply(String? requestId) {
    final clock = _replyClocks.remove(requestId);
    final access = _accessToken;
    if (clock == null || access == null) return;
    unawaited(
      _backend()
          .reportMobileRealtimeMetric(
            'reply_apply_ms',
            clock.elapsedMilliseconds.clamp(0, 600000),
            token: access,
          )
          .catchError((Object _) {}),
    );
  }

  final Map<String, DateTime> _recentReplies = {};
  final Map<String, String> _recentIdsByFingerprint = {};
  final MobileOutboxStore _outbox;
  final Map<String, OutboxState> _outboxStates = {};
  final Map<String, OutboxEntry> _outboxRows = {};
  final Map<String, Future<bool>> _enqueueEvents = {};
  List<OutboxEntry> get pendingOutgoing =>
      _outboxRows.values.toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
  int? _drainGeneration;
  bool _drainRequested = false;
  String? outboxError;

  OutboxState? deliveryState(ChatMessage message) =>
      _outboxStates[message.requestId];
  Timer? _pollTimer;
  StreamSubscription<void>? _networkSubscription;
  BackendClient? _receivingBackend;
  int _receiveEpoch = 0;
  int _receiveFailures = 0;
  bool _pollingEnabled = true;

  final List<List<ChatMessage>> _messageQueue = [];
  Completer<void>? _revealWake;
  final ChatSessionCoordinator _session = ChatSessionCoordinator();
  late final MobileRealtimeController realtime = MobileRealtimeController(
    backend: _backend,
    token: () => _accessToken,
    grant: () async {
      final charId = _deliveryCharId();
      if (charId == null || _resolvePresenceSession == null) return null;
      return _resolvePresenceSession(charId: charId, force: false);
    },
    isLive: () => _pollingEnabled && !_session.disposed,
    apply: _applyRealtimeFinal,
  );

  void _applyRealtimeFinal(Map<String, dynamic> message) {
    if (!_pollingEnabled || _session.disposed) return;
    final envelope = PendingMobileEnvelope.fromJson(message);
    if (envelope.charId != _deliveryCharId() ||
        message['user_id'] != _deliveryOwner()) {
      return;
    }
    if (envelope.requestId != null) {
      final matchesSend = [
        ...sent,
        ...history,
      ].any((row) => row.role == 'you' && row.requestId == envelope.requestId);
      _settleSend(requestId: envelope.requestId);
      if (matchesSend) {
        himTyping = false;
        for (final store in [sent, history]) {
          for (var i = 0; i < store.length; i++) {
            final row = store[i];
            if (row.requestId != envelope.requestId) continue;
            if (row.role == 'you') {
              store[i] = row.copyWith(turnId: envelope.identity);
            } else if (row.role == 'reasoning') {
              store[i] = ChatMessage(
                id: row.id,
                role: row.role,
                text: envelope.identity ?? '',
                time: row.time,
                timestamp: row.timestamp,
                dateKey: row.dateKey,
                turnId: envelope.identity,
                requestId: row.requestId,
              );
            }
          }
        }
      }
    }
    _observeReplyApply(envelope.requestId);
    final date = envelope.timestamp == null
        ? null
        : _dateKey(envelope.timestamp!);
    if (historyLoaded &&
        _loadedDates.isNotEmpty &&
        date != null &&
        date.compareTo(_loadedDates.first) < 0) {
      // Older pages remain available through the ordinary lazy day history.
      return;
    }
    final fresh = _mergeIncomingRows(_pendingRows(envelope));
    final key = date == null ? null : '$date ${envelope.toChatMessage().time}';
    final historyPosition = key == null
        ? -1
        : history.indexWhere(
            (row) =>
                row.dateKey != null &&
                '${row.dateKey} ${row.time}'.compareTo(key) > 0,
          );
    if (historyPosition >= 0) {
      history.insertAll(historyPosition, fresh);
    } else {
      final sentPosition = envelope.timestamp == null
          ? -1
          : sent.indexWhere(
              (row) => row.timestamp.isAfter(envelope.timestamp!),
            );
      sent.insertAll(sentPosition < 0 ? sent.length : sentPosition, fresh);
    }
    _rememberReply(envelope.content, msgId: envelope.identity);
    notifyListeners();
    if (fresh.isNotEmpty) _followIncoming(fresh.length);
  }

  bool get sending => _session.sending;
  set sending(bool value) => _session.sending = value;
  // Local bounded waiting is presentation, never evidence of remote running.
  Timer? _localWaitTimer;
  final Duration localWaitTimeout;
  final Duration outgoingAttemptTimeout;
  final Duration queueWaitTimeout;
  Timer? _queueExpiryTimer;
  final _preDispatchStops = <String, Completer<BackendChatResponse>>{};
  String? _localWaitRequest;
  bool get himTyping => _session.himTyping || _localWaitRequest != null;
  set himTyping(bool value) => _session.himTyping = value;

  void _endLocalWait({String? requestId, bool uncertain = false}) {
    final active = _localWaitRequest;
    if (active == null || (requestId != null && requestId != active)) return;
    _localWaitTimer?.cancel();
    _localWaitTimer = null;
    _localWaitRequest = null;
    if (uncertain) {
      for (final list in [sent, history]) {
        for (var i = 0; i < list.length; i++) {
          final message = list[i];
          if (message.role == 'you' && message.requestId == active) {
            list[i] = message.copyWith(uncertainSince: clock());
          }
        }
      }
    }
  }

  void _beginLocalWait(String requestId, int generation) {
    _endLocalWait();
    _localWaitRequest = requestId;
    _localWaitTimer = Timer(localWaitTimeout, () {
      if (!_session.isCurrent(generation) || _localWaitRequest != requestId) {
        return;
      }
      _endLocalWait(requestId: requestId, uncertain: true);
      notifyListeners();
    });
  }

  bool loadingHistory = false;
  bool loadingMoreHistory = false;
  bool noMoreHistory = false;
  bool historyLoaded = false;
  bool pollingMobile = false;
  bool mobileActive = false;
  bool showJumpToLatest = false;
  int visibleMessageLimit = initialVisibleMessageCount;
  int mobileReceivedCount = 0;
  int unreadHimCount = 0;
  int? lastAckedMobileSeq;
  String? backendError;
  String? historyError;
  String? mobileError;
  String? lastMobileContent;
  BackendChatResponse? lastBackendReply;
  ChatMessage? replyTarget;
  static const _canonicalMediaCacheLimit = 32;
  final Map<String, Uint8List> _canonicalMedia = {};
  final Map<String, Future<Uint8List?>> _canonicalMediaInflight = {};

  String? get _accessToken {
    final value = _token()?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> start() async {
    if (_accessToken == null) return;
    if (_session.disposed) return;
    _pollingEnabled = true;
    if (_session.initialSync != null) return _session.initialSync!;
    if (_session.initialSyncComplete) {
      realtime.start();
      _ensurePollTimer();
      await pollIfBackgroundUnavailable();
      return;
    }
    _pollTimer?.cancel();
    _pollTimer = null;
    final work = _startInitialSync();
    _session.initialSync = work;
    try {
      await work;
    } finally {
      if (identical(_session.initialSync, work)) {
        _session.initialSync = null;
        _requestOutboxDrain();
      }
    }
  }

  Future<void> _startInitialSync() async {
    final generation = _session.generation;
    await _restoreOutbox(generation);
    if (_session.isStale(generation)) return;
    final historyWork = loadHistory(reconcileLocal: true);
    await _replayPendingEnvelopes();
    if (_session.isStale(generation)) return;
    await activateMobile(source: ChatDeliverySource.initialSync);
    if (_session.isStale(generation)) return;
    _ensurePollTimer();
    await historyWork;
    if (_session.isStale(generation)) return;
    realtime.start();
    if (historyLoaded && historyError == null) {
      _session.initialSyncComplete = true;
    }
    _ensurePollTimer();
  }

  void _ensurePollTimer({Duration delay = Duration.zero}) {
    if (_pollTimer != null ||
        !_pollingEnabled ||
        _session.disposed ||
        _accessToken == null) {
      return;
    }
    final epoch = _receiveEpoch;
    _pollTimer = Timer(delay, () {
      _pollTimer = null;
      unawaited(_receiveCycle(epoch));
    });
  }

  Future<void> _receiveCycle(int epoch) async {
    try {
      await pollIfBackgroundUnavailable();
    } catch (error) {
      if (epoch == _receiveEpoch && !_session.disposed) {
        mobileError = error.toString();
        notifyListeners();
      }
    } finally {
      if (_pollingEnabled && !_session.disposed && epoch == _receiveEpoch) {
        _receiveFailures = mobileError == null
            ? 0
            : math.min(_receiveFailures + 1, 5);
        _ensurePollTimer(
          delay: mobileError == null
              ? const Duration(milliseconds: 100)
              : Duration(seconds: 1 << (_receiveFailures - 1)),
        );
      }
    }
  }

  void _cancelReceiveWork() {
    realtime.stop();
    _receiveEpoch++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _receivingBackend?.cancelMobileReceive();
    _backend().cancelMobileReceive();
    _foregroundDelivery = null;
    pollingMobile = false;
  }

  void _handleNetworkChange() {
    if (!_pollingEnabled || _session.disposed) return;
    _cancelReceiveWork();
    _receiveFailures = 0;
    realtime.start();
    _ensurePollTimer();
  }

  void pausePolling() {
    final waiting = _localWaitRequest != null || _session.himTyping;
    _endLocalWait(uncertain: true);
    himTyping = false;
    if (waiting && !_session.disposed) notifyListeners();
    _pollingEnabled = false;
    _cancelReceiveWork();
  }

  void resumePolling() {
    _pollingEnabled = true;
    _cancelReceiveWork();
    realtime.start();
    if (!_session.initialSyncComplete) {
      unawaited(start());
      return;
    }
    _ensurePollTimer();
    unawaited(refreshConnection());
  }

  Future<void> catchUpFromNotification() async {
    await refreshConnection();
    if (!_session.disposed && scrollController.following) {
      scrollController.followAfterLayout();
    }
  }

  Future<void> _replayPendingEnvelopes() async {
    final generation = _session.generation;
    final epoch = _receiveEpoch;
    final scope = _captureScope(generation);
    pendingHandoffError = null;
    try {
      final pending = await _settings.peekPendingMobileEnvelopes(
        origin: _deliveryOrigin(),
        owner: _deliveryOwner(),
        charId: _deliveryCharId(),
      );
      if (!_scopeStillLive(generation, scope) || epoch != _receiveEpoch) return;
      final fresh = <PendingMobileEnvelope>[];
      final replayed = <String>{};
      for (final envelope in pending) {
        if (envelope.identity != null && !replayed.add(envelope.identity!)) {
          continue;
        }
        if (envelope.requestId != null && envelope.charId == scope.charId) {
          _settleSend(requestId: envelope.requestId);
        }
        if (!_shouldReplayPending(envelope)) continue;
        fresh.add(envelope);
        final identity = envelope.identity;
        if (identity != null && !_seenIds.contains(identity)) {
          _seenIds.add(identity);
          while (_seenIds.length > 200) {
            _seenIds.removeAt(0);
          }
        }
      }
      if (fresh.isNotEmpty) {
        sent.addAll(
          _mergeIncomingRows([
            for (final envelope in fresh) ..._pendingRows(envelope),
          ]),
        );
        mobileReceivedCount += fresh.length;
        lastMobileContent = fresh.last.content;
        await _settings.saveSeenMobileMessageIds(
          List.unmodifiable(_seenIds),
          origin: _deliveryOrigin(),
          owner: _deliveryOwner(),
        );
        if (!_scopeStillLive(generation, scope) || epoch != _receiveEpoch) {
          return;
        }
        notifyListeners();
      }
      if (!_scopeStillLive(generation, scope) || epoch != _receiveEpoch) return;
      await _settings.ackPendingMobileEnvelopes(
        pending,
        origin: scope.origin,
        owner: scope.owner,
        charId: scope.charId,
      );
    } on MissingPluginException catch (e) {
      if (!_scopeStillLive(generation, scope) || epoch != _receiveEpoch) return;
      pendingHandoffError = e.message ?? e.toString();
    } on PlatformException catch (e) {
      if (!_scopeStillLive(generation, scope) || epoch != _receiveEpoch) return;
      pendingHandoffError = e.message ?? e.code;
    } catch (e) {
      if (!_scopeStillLive(generation, scope) || epoch != _receiveEpoch) return;
      pendingHandoffError = e.toString();
    }
    if (_scopeStillLive(generation, scope)) notifyListeners();
  }

  Future<void> refreshConnection() {
    final existing = _session.refresh;
    if (existing != null) return existing;
    late final Future<void> work;
    work = _refreshConnection().whenComplete(() {
      if (identical(_session.refresh, work)) {
        _session.refresh = null;
        _requestOutboxDrain();
      }
    });
    _session.refresh = work;
    return work;
  }

  Future<void> _refreshConnection() async {
    if (_accessToken == null) return;
    final generation = _session.generation;
    if (_session.initialSync != null) await _session.initialSync;
    if (_session.isStale(generation)) return;
    await _restoreOutbox(generation);
    if (_session.isStale(generation)) return;
    await _replayPendingEnvelopes();
    if (_session.isStale(generation)) return;
    final historyWork = loadHistory(reconcileLocal: true);
    await activateMobile(source: ChatDeliverySource.catchUp);
    if (_session.isStale(generation)) return;
    if (mobileActive && mobileError == null) backendError = null;
    _ensurePollTimer();
    notifyListeners();
    await historyWork;
  }

  Future<void> resetForConnectionChange({bool restart = true}) async {
    _session.beginEpoch();
    for (final stop in _preDispatchStops.values) {
      if (!stop.isCompleted) {
        stop.completeError(StateError('outbox_scope_changed'));
      }
    }
    _queueExpiryTimer?.cancel();
    pausePolling();
    realtime.stop(reset: true);
    _session.initialSync = null;
    _session.refresh = null;
    _foregroundDelivery = null;
    _acceptedRequestIds.clear();
    _replyClocks.clear();

    _messageQueue.clear();
    _outboxStates.clear();
    _outboxRows.clear();
    scrollController.reset();
    showJumpToLatest = false;
    unreadHimCount = 0;
    replyTarget = null;
    outboxError = null;
    if (_revealWake?.isCompleted == false) _revealWake!.complete();
    if (_session.historyRead != null) await _session.historyRead;
    _session.clearLiveWork();
    pollingMobile = false;
    pausePolling();
    history.clear();
    sent.clear();
    _availableDates.clear();
    _loadedDates.clear();
    historyLoaded = false;
    noMoreHistory = false;
    lastBackendReply = null;
    backendError = null;
    historyError = null;
    mobileError = null;
    notifyListeners();
    if (restart) await start();
  }

  Future<bool> send(String text, {ReplyTarget? replyToOverride}) async {
    final value = text.trim();
    final token = _accessToken;
    if (value.isEmpty || token == null) return false;
    final target = replyTarget;
    final replyTo =
        replyToOverride ??
        (replyTarget == null ? null : ReplyTarget.fromMessage(replyTarget!));
    final saved = await _enqueueOutgoing(
      value,
      replyTo: replyTo,
      voiceReceipt: _backend().takeVoiceReceipt(value, token),
    );
    if (saved &&
        !_session.disposed &&
        replyToOverride == null &&
        identical(replyTarget, target)) {
      clearReplyTarget();
    }
    return saved;
  }

  void setReplyTarget(ChatMessage message) {
    replyTarget = message;
    notifyListeners();
  }

  bool canRetryMessage(ChatMessage message) {
    final row = _outboxRows[message.requestId];
    return row != null &&
        (row.locallyStopped ||
            row.state == OutboxState.retryableFailed ||
            (row.state == OutboxState.blocked &&
                (row.statusCode == 401 || row.statusCode == 403)));
  }

  void retryMessage(ChatMessage message) {
    final requestId = message.requestId;
    if (message.role != 'you' || requestId == null) return;
    unawaited(_retryOutgoing(requestId));
  }

  Future<void> _retryOutgoing(String requestId) async {
    final scope = _captureScope(_session.generation);
    try {
      final rows = await _outbox.readScope(_outboxScope(scope));
      if (!_scopeStillLive(scope.generation, scope)) return;
      final row = rows.where((row) => row.requestId == requestId).firstOrNull;
      if (row == null) return;
      if (row.state == OutboxState.outcomeUnknown ||
          row.state == OutboxState.sending) {
        await refreshConnection();
        return;
      }
      if (!row.locallyStopped &&
          row.state != OutboxState.retryableFailed &&
          !(row.state == OutboxState.blocked &&
              (row.statusCode == 401 || row.statusCode == 403))) {
        return;
      }
      final queuedAt = clock();
      if (await _outbox.setState(row, OutboxState.queued, queuedAt: queuedAt) &&
          _scopeStillLive(scope.generation, scope)) {
        _renderOutgoing(row.withState(OutboxState.queued, queuedAt: queuedAt));
        notifyListeners();
        _requestOutboxDrain();
      }
    } catch (_) {
      _reportOutboxError(scope);
    }
  }

  Future<void> removeFromOutbox(ChatMessage message) async {
    final scope = _captureScope(_session.generation);
    try {
      final rows = await _outbox.readScope(_outboxScope(scope));
      if (!_scopeStillLive(scope.generation, scope)) return;
      final row = rows
          .where((row) => row.requestId == message.requestId)
          .firstOrNull;
      if (row == null || row.state == OutboxState.sending) return;
      if (!await _outbox.setState(row, null, requireCurrent: true) ||
          !_scopeStillLive(scope.generation, scope)) {
        return;
      }
      _preDispatchStops[row.requestId]?.completeError(
        StateError('outbox_stopped'),
      );
      _outboxStates.remove(row.requestId);
      _outboxRows.remove(row.requestId);
      _scheduleQueueExpiry();
      for (final list in [sent, history]) {
        list.removeWhere((item) => item.id == message.id);
      }
      notifyListeners();
      _requestOutboxDrain();
    } catch (_) {
      _reportOutboxError(scope);
    }
  }

  /// Explicit user decision; retain the request for later receipt reconciliation.
  Future<void> skipOutgoing(ChatMessage message) async {
    final scope = _captureScope(_session.generation);
    final row = _outboxRows[message.requestId];
    if (row == null || row.state == OutboxState.sending) return;
    try {
      if (await _outbox.setState(row, OutboxState.skipped) &&
          _scopeStillLive(scope.generation, scope)) {
        _preDispatchStops[row.requestId]?.completeError(
          StateError('outbox_stopped'),
        );
        _renderOutgoing(row.withState(OutboxState.skipped));
        notifyListeners();
        _requestOutboxDrain();
      }
    } catch (_) {
      _reportOutboxError(scope);
    }
  }

  void clearReplyTarget() {
    if (replyTarget == null) return;
    replyTarget = null;
    notifyListeners();
  }

  void markRevealStarted(ChatMessage message) {
    final index = sent.indexWhere((m) => m.id == message.id);
    if (index < 0 || !sent[index].animate) return;
    sent[index] = sent[index].settled();
  }

  Future<String> loadReasoning(String turnId) async {
    final generation = _session.generation;
    final scope = _captureScope(generation);
    return _withLiveGrant(
      scope: scope,
      generation: generation,
      call: (grant) => _backend().loadTurnReasoning(
        turnId,
        token: _accessToken!,
        sessionId: grant.sessionId,
      ),
    );
  }

  String _mediaCacheKey(String digest) {
    final scope = _captureScope(_session.generation);
    return '${scope.mediaCachePrefix}|$digest';
  }

  SessionScope _captureScope(int generation) => SessionScope(
    origin: _deliveryOrigin(),
    owner: _deliveryOwner(),
    charId: _deliveryCharId(),
    generation: generation,
  );

  Future<Uint8List?> loadCanonicalMedia(ChatMediaRef ref) {
    final digest = (ref.sha256 ?? '').trim().toLowerCase();
    if (digest.isEmpty ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
        ref.availability == 'unavailable') {
      return Future<Uint8List?>.value(null);
    }
    final key = _mediaCacheKey(digest);
    final cached = _canonicalMedia[key];
    if (cached != null) return Future<Uint8List?>.value(cached);
    final inflight = _canonicalMediaInflight[key];
    if (inflight != null) return inflight;
    final token = _accessToken;
    if (token == null) return Future<Uint8List?>.value(null);
    final scope = _captureScope(_session.generation);
    final pending = _downloadCanonicalMedia(digest, token, key, scope);
    _canonicalMediaInflight[key] = pending;
    return pending;
  }

  Future<Uint8List?> _downloadCanonicalMedia(
    String digest,
    String token,
    String key,
    SessionScope scope,
  ) async {
    try {
      final bytes = await _withLiveGrant(
        scope: scope,
        generation: scope.generation,
        call: (grant) => _backend().downloadChatMedia(
          digest,
          token: token,
          sessionId: grant.sessionId,
        ),
      );
      if (bytes.isEmpty) return null;
      if (!scope.matchesLive(
        generation: _session.generation,
        origin: _deliveryOrigin(),
        owner: _deliveryOwner(),
        charId: _deliveryCharId(),
      )) {
        return null;
      }
      if (_canonicalMedia.length >= _canonicalMediaCacheLimit) {
        _canonicalMedia.remove(_canonicalMedia.keys.first);
      }
      _canonicalMedia[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    } finally {
      _canonicalMediaInflight.remove(key);
    }
  }

  Future<Uint8List> fetchArtifactBytes(
    ChatArtifact artifact, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final token = _accessToken;
    if (token == null) throw const BackendException('尚未连接后端');
    final scope = _captureScope(_session.generation);
    return _withLiveGrant(
      scope: scope,
      generation: scope.generation,
      call: (grant) => _backend().downloadChatArtifact(
        artifact.downloadPath,
        maxBytes: artifact.isImage ? 25 * 1024 * 1024 : 2 * 1024 * 1024,
        token: token,
        sessionId: grant.sessionId,
        onProgress: onProgress,
      ),
    );
  }

  void _bindUserTurn(int id, String? turnId) {
    for (final list in [sent, history]) {
      final index = list.indexWhere((m) => m.id == id);
      if (index >= 0) list[index] = list[index].copyWith(turnId: turnId);
    }
  }

  bool _scopeStillLive(int generation, SessionScope scope) {
    return !_session.isStale(generation) &&
        scope.matchesLive(
          generation: _session.generation,
          origin: _deliveryOrigin(),
          owner: _deliveryOwner(),
          charId: _deliveryCharId(),
        );
  }

  Future<PresenceSessionGrant> _requirePresenceGrant({
    bool force = false,
  }) async {
    final charId = SessionScope.normalize(_deliveryCharId());
    if (charId == null) {
      throw const BackendException('character_unavailable');
    }
    final resolver = _resolvePresenceSession;
    if (resolver == null) {
      throw const SessionScopeUnsupportedException();
    }
    final grant = await resolver(charId: charId, force: force);
    if (grant != null) return grant;
    final bindError = SessionScope.normalize(_presenceBindError?.call());
    throw BackendException(bindError ?? 'session_scope_unsupported');
  }

  Future<T> _withLiveGrant<T>({
    required SessionScope scope,
    required int generation,
    required Future<T> Function(PresenceSessionGrant grant) call,
  }) async {
    Future<T> invoke(PresenceSessionGrant grant) {
      if (!_scopeStillLive(generation, scope)) {
        return Future<T>.error(const BackendException('session_scope_stale'));
      }
      return call(grant);
    }

    var grant = await _requirePresenceGrant();
    try {
      return await invoke(grant);
    } on BackendException catch (e) {
      if (!e.isSessionNotFound || !_scopeStillLive(generation, scope)) {
        rethrow;
      }
      _onPresenceSessionInvalid?.call();
      grant = await _requirePresenceGrant(force: true);
      return invoke(grant);
    }
  }

  Future<void> _applyChatResponse({
    required BackendChatResponse response,
    required int userId,
    required ChatMessage anchor,
  }) async {
    if (response.criticalWritten == false) {
      throw const BackendException(
        'execution_outcome_unknown',
        statusCode: 503,
      );
    }
    _bindUserTurn(userId, response.turnId);
    final anchorIndex = sent.indexWhere((m) => m.id == anchor.id);
    final restoredAnchor =
        response.turnId != null &&
        history.any(
          (m) =>
              m.role == 'reasoning' &&
              (m.turnId == response.turnId || m.text == response.turnId),
        );
    if (anchorIndex >= 0 && restoredAnchor) {
      sent.removeAt(anchorIndex);
    } else if (anchorIndex >= 0) {
      sent[anchorIndex] = ChatMessage(
        id: anchor.id,
        role: 'reasoning',
        text: response.turnId ?? '',
        time: anchor.time,
        // A missing turn_id is not a send failure: the server accepted it.
        turnId: response.turnId,
      );
    }
    _settleSend(userId: userId);
    notifyListeners();
    lastBackendReply = response;
    if (_shouldAppendSynchronousReply(response)) {
      await _appendReply(
        response.reply,
        displayText: response.displayText,
        turnId: response.turnId,
      );
      await _appendArtifacts(response.artifacts, turnId: response.turnId);
    }
  }

  String _outboxScope(SessionScope scope) => jsonEncode([
    scope.origin,
    scope.owner,
    scope.charId,
    'reality',
    'mobile',
  ]);

  void _reportOutboxError(SessionScope scope) {
    if (!_scopeStillLive(scope.generation, scope)) return;
    outboxError = 'storage';
    notifyListeners();
  }

  Future<bool> _enqueueOutgoing(
    String text, {
    ReplyTarget? replyTo,
    List<PickedUploadFile> files = const [],
    String caption = '',
    String? voiceReceipt,
  }) {
    // Coalesce only callbacks for the same in-flight durable UI event. Once
    // committed, deliberately sending the same content again remains possible.
    final key = jsonEncode([
      _outboxScope(_captureScope(_session.generation)),
      text,
      replyTo?.toJson(),
      caption,
      voiceReceipt,
      for (final file in files) [file.name, base64Encode(file.bytes)],
    ]);
    return _enqueueEvents.putIfAbsent(key, () {
      return _persistOutgoing(
        text,
        replyTo: replyTo,
        files: files,
        caption: caption,
        voiceReceipt: voiceReceipt,
      ).whenComplete(() {
        _enqueueEvents.remove(key);
      });
    });
  }

  Future<bool> _persistOutgoing(
    String text, {
    ReplyTarget? replyTo,
    List<PickedUploadFile> files = const [],
    String caption = '',
    String? voiceReceipt,
  }) async {
    final scope = _captureScope(_session.generation);
    final requestId = mintRequestId();
    final createdAt = clock();
    try {
      final row = await _outbox.enqueue(
        (sequence) => OutboxEntry(
          requestId: requestId,
          scope: _outboxScope(scope),
          sequence: sequence,
          createdAt: createdAt,
          text: text,
          replyTo: replyTo,
          files: files,
          caption: caption,
          voiceReceipt: voiceReceipt,
        ),
      );
      if (!_scopeStillLive(scope.generation, scope)) return true;
      outboxError = null;
      scrollController.follow();
      showJumpToLatest = false;
      unreadHimCount = 0;
      _renderOutgoing(row);
      if (_localWaitRequest == null) {
        _beginLocalWait(row.requestId, scope.generation);
      }
      notifyListeners();
      scrollController.followAfterLayout();
      _requestOutboxDrain();
      return true;
    } catch (_) {
      _reportOutboxError(scope);
      return false;
    }
  }

  bool canCancelMessage(ChatMessage message) =>
      deliveryState(message) == OutboxState.queued;

  Future<void> cancelQueuedMessage(ChatMessage message) async {
    final row = _outboxRows[message.requestId];
    if (row == null || row.state != OutboxState.queued) return;
    final scope = _captureScope(_session.generation);
    try {
      await _stopQueued(row, OutboxState.cancelled, scope);
    } catch (_) {
      _reportOutboxError(scope);
    }
  }

  Future<void> _stopQueued(
    OutboxEntry row,
    OutboxState state,
    SessionScope scope,
  ) async {
    if (!_scopeStillLive(scope.generation, scope)) return;
    if (await _outbox.setState(row, state)) {
      _preDispatchStops[row.requestId]?.completeError(
        StateError('outbox_stopped'),
      );
      if (_scopeStillLive(scope.generation, scope)) {
        _renderOutgoing(row.withState(state));
        if (_localWaitRequest == row.requestId) {
          _endLocalWait(requestId: row.requestId);
          _beginNextQueuedWait(scope);
        }
        notifyListeners();
        _requestOutboxDrain();
      }
    }
  }

  void _beginNextQueuedWait(SessionScope scope) {
    final next = _outboxRows.values
        .where(
          (row) =>
              row.scope == _outboxScope(scope) &&
              row.state == OutboxState.queued &&
              !_queueExpired(row),
        )
        .firstOrNull;
    if (next != null) _beginLocalWait(next.requestId, scope.generation);
  }

  bool _queueExpired(OutboxEntry row) =>
      !clock().isBefore(row.queuedAt.add(queueWaitTimeout));

  void _scheduleQueueExpiry({bool afterError = false}) {
    _queueExpiryTimer?.cancel();
    if (_session.disposed) return;
    final scope = _captureScope(_session.generation);
    final rows =
        _outboxRows.values
            .where(
              (row) =>
                  row.scope == _outboxScope(scope) &&
                  row.state == OutboxState.queued,
            )
            .toList()
          ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    if (rows.isEmpty) return;
    final delay = rows.first.queuedAt.add(queueWaitTimeout).difference(clock());
    _queueExpiryTimer = Timer(
      afterError
          ? const Duration(seconds: 5)
          : (delay.isNegative ? Duration.zero : delay),
      () async {
        var failed = false;
        try {
          for (final row in rows) {
            if (_queueExpired(row)) {
              await _stopQueued(row, OutboxState.expired, scope);
            }
          }
        } catch (_) {
          failed = true;
          if (!_session.disposed) _reportOutboxError(scope);
        } finally {
          _scheduleQueueExpiry(afterError: failed);
        }
      },
    );
  }

  Future<void> _restoreOutbox(int generation) async {
    final scope = _captureScope(generation);
    try {
      final rows = await _outbox.readScope(_outboxScope(scope));
      if (!_scopeStillLive(generation, scope)) return;
      for (var row in rows) {
        if (row.state == OutboxState.queued && _queueExpired(row)) {
          if (await _outbox.setState(row, OutboxState.expired)) {
            row = row.withState(OutboxState.expired);
          }
        }
        if (!_scopeStillLive(generation, scope)) return;
        if (_acceptedRequestIds.contains(row.requestId)) continue;
        if (row.hiddenOnRestore) {
          if (!_scopeStillLive(generation, scope)) return;
          // Retain the terminal identity for receipt reconciliation,
          // but never resurrect retired local bubbles on refresh or restart.
          _outboxRows[row.requestId] = row;
          _outboxStates[row.requestId] = row.state;
          for (final list in [sent, history]) {
            list.removeWhere(
              (m) =>
                  m.requestId == row.requestId &&
                  (m.role == 'you' || m.role == 'reasoning'),
            );
          }
          _endLocalWait(requestId: row.requestId);
          continue;
        }
        _renderOutgoing(
          row.state == OutboxState.sending && !sending
              ? row.withState(OutboxState.outcomeUnknown)
              : row,
        );
      }
      if (_outbox.corruptEntries > 0) outboxError = 'corrupt';
      notifyListeners();
    } catch (_) {
      _reportOutboxError(scope);
    }
  }

  ChatMessage _renderOutgoing(OutboxEntry row) {
    _outboxStates[row.requestId] = row.state;
    _outboxRows[row.requestId] = row;
    _scheduleQueueExpiry();
    final uncertain = row.state == OutboxState.outcomeUnknown;
    final failed =
        row.state == OutboxState.blocked ||
        row.state == OutboxState.retryableFailed ||
        row.locallyStopped;
    for (final list in [sent, history]) {
      final i = list.indexWhere(
        (message) =>
            message.role == 'you' && message.requestId == row.requestId,
      );
      if (i >= 0) {
        return list[i] = list[i].copyWith(
          failed: failed,
          uncertainSince: uncertain ? row.createdAt : null,
          clearUncertain: !uncertain,
        );
      }
    }
    final message = ChatMessage(
      id: -row.sequence,
      role: 'you',
      text: row.text,
      time: '现在',
      timestamp: row.createdAt,
      retainOnRefresh: true,
      requestId: row.requestId,
      quotedText: row.replyTo?.text,
      quotedLabel: row.replyTo == null ? null : 'reply',
      retryReplyTo: row.replyTo,
      attachments: row.files,
      uploadNote: row.caption,
      failed: failed,
      uncertainSince: uncertain ? row.createdAt : null,
    );
    sent.add(message);
    return message;
  }

  void _requestOutboxDrain() {
    if (_session.disposed || _accessToken == null) return;
    if (_session.initialSync != null || _session.refresh != null) {
      _drainRequested = true;
      return;
    }
    _drainRequested = true;
    if (_drainGeneration != null) return;
    unawaited(_drainOutbox(_captureScope(_session.generation)));
  }

  Future<void> _drainOutbox(SessionScope scope) async {
    final generation = scope.generation;
    _drainGeneration = generation;
    try {
      do {
        _drainRequested = false;
        while (_scopeStillLive(generation, scope) && _accessToken != null) {
          final rows = await _outbox.readScope(_outboxScope(scope));
          if (!_scopeStillLive(generation, scope) || rows.isEmpty) break;
          // Unresolved attempts retain their identity for reconciliation, but
          // must not hold unrelated, later input hostage. Never replay them.
          final row = rows
              .where((row) => row.state == OutboxState.queued)
              .firstOrNull;
          if (row == null) break;
          await _executeOutgoing(row, scope);
        }
      } while (_drainRequested && _scopeStillLive(generation, scope));
    } catch (_) {
      _reportOutboxError(scope);
    } finally {
      _drainGeneration = null;
      if (_drainRequested) _requestOutboxDrain();
    }
  }

  Future<void> _executeOutgoing(OutboxEntry row, SessionScope scope) async {
    final generation = scope.generation;
    final token = _accessToken;
    if (token == null) return;
    if (_queueExpired(row)) {
      await _stopQueued(row, OutboxState.expired, scope);
      return;
    }
    final stop = Completer<BackendChatResponse>();
    _preDispatchStops[row.requestId] = stop;
    final user = _renderOutgoing(row);
    final anchor = ChatMessage(
      role: 'reasoning',
      text: '',
      time: _nowLabel(),
      requestId: row.requestId,
    );
    sent.add(anchor);
    sending = true;
    himTyping = false;
    _beginLocalWait(row.requestId, generation);
    backendError = null;
    _replyClocks[row.requestId] = Stopwatch()..start();
    while (_replyClocks.length > 200) {
      _replyClocks.remove(_replyClocks.keys.first);
    }
    notifyListeners();

    var dispatched = false;
    var confirmed = false;
    var expired = false;
    try {
      final pending = _withLiveGrant(
        scope: scope,
        generation: generation,
        call: (grant) async {
          if (expired ||
              grant.ownerId != scope.owner ||
              grant.charId != scope.charId ||
              grant.domain != 'reality' ||
              token != _accessToken) {
            throw const BackendException('session_scope_stale');
          }
          if (!dispatched) {
            if (_queueExpired(row)) {
              await _stopQueued(row, OutboxState.expired, scope);
              throw StateError('outbox_stopped');
            }
            if (!await _outbox.setState(row, OutboxState.sending)) {
              throw StateError('outbox_stopped');
            }
            row = row.withState(OutboxState.sending);
            if (expired || !_scopeStillLive(generation, scope)) {
              await _outbox.setState(row, OutboxState.retryableFailed);
              throw StateError('outbox_stopped');
            }
            _renderOutgoing(row);
            notifyListeners();
          }
          _preDispatchStops.remove(row.requestId);
          dispatched = true;
          final backend = _backend();
          return row.files.isEmpty
              ? backend.sendChat(
                  row.text,
                  token: token,
                  replyTo: row.replyTo,
                  requestId: row.requestId,
                  sessionId: grant.sessionId,
                  voiceReceipt: row.voiceReceipt,
                )
              : backend.uploadFiles(
                  files: row.files,
                  token: token,
                  message: row.caption,
                  requestId: row.requestId,
                  sessionId: grant.sessionId,
                );
        },
      );
      final response = await Future.any([pending, stop.future]).timeout(
        outgoingAttemptTimeout,
        onTimeout: () {
          expired = true;
          // The remote operation may still finish. Retain its original ID and
          // consume its late result without keeping the sending slot occupied.
          unawaited(
            pending.then<void>(
              (response) =>
                  _reconcileLateOutgoing(response, row, scope, user, anchor),
              onError: (Object error, StackTrace stack) {},
            ),
          );
          throw TimeoutException('mobile_send_wait_expired');
        },
      );
      if (response.criticalWritten == false) {
        throw const BackendException(
          'execution_outcome_unknown',
          statusCode: 503,
        );
      }
      // A replacement controller may already own a newer persisted snapshot.
      // Leave reconciliation to it rather than committing this disposed cache.
      if (_session.disposed) return;
      await _outbox.setState(row, null);
      confirmed = true;
      if (!_scopeStillLive(generation, scope)) {
        final live = _captureScope(_session.generation);
        if (!_session.disposed && _outboxScope(live) == row.scope) {
          _outboxStates.remove(row.requestId);
          _outboxRows.remove(row.requestId);
          _settleSend(requestId: row.requestId);
          unawaited(loadHistory(reconcileLocal: true));
        }
        return;
      }
      _outboxStates.remove(row.requestId);
      _outboxRows.remove(row.requestId);
      _endLocalWait(requestId: row.requestId);
      await _applyChatResponse(
        response: response,
        userId: user.id,
        anchor: anchor,
      );
    } catch (error) {
      if (confirmed || _session.disposed) return;
      final status = error is BackendException ? error.statusCode : null;
      final state =
          status == 401 || status == 403 || status == 413 || status == 422
          ? OutboxState.blocked
          : !dispatched ||
                (error is BackendException && error.isSessionNotFound)
          ? OutboxState.retryableFailed
          : OutboxState.outcomeUnknown;
      bool changed;
      try {
        changed = await _outbox.setState(row, state, statusCode: status);
      } catch (_) {
        if (_scopeStillLive(generation, scope)) {
          _renderOutgoing(row.withState(OutboxState.outcomeUnknown));
        }
        rethrow;
      }
      if (changed &&
          _scopeStillLive(generation, scope) &&
          !_acceptedRequestIds.contains(row.requestId)) {
        _renderOutgoing(row.withState(state, statusCode: status));
        if (state != OutboxState.outcomeUnknown && error is BackendException) {
          backendError = error.message;
        }
      }
    } finally {
      expired = true;
      _preDispatchStops.remove(row.requestId);
      if (_scopeStillLive(generation, scope)) {
        if (!confirmed) sent.removeWhere((m) => m.id == anchor.id);
        sending = false;
        _endLocalWait(requestId: row.requestId);
        if (_pollingEnabled) _beginNextQueuedWait(scope);
        himTyping = false;
        notifyListeners();
        unawaited(loadHistory(reconcileLocal: true, backgroundRefresh: true));
        _flushHistoryRefresh();
      }
    }
  }

  Future<void> _reconcileLateOutgoing(
    BackendChatResponse response,
    OutboxEntry row,
    SessionScope scope,
    ChatMessage user,
    ChatMessage anchor,
  ) async {
    if (_session.disposed || response.criticalWritten == false) return;
    try {
      await _outbox.setState(row, null);
      if (_session.disposed) return;
      final live = _captureScope(_session.generation);
      if (_outboxScope(live) != row.scope) return;
      final accepted = _acceptedRequestIds.contains(row.requestId);
      _outboxStates.remove(row.requestId);
      _outboxRows.remove(row.requestId);
      _settleSend(requestId: row.requestId);
      if (_scopeStillLive(scope.generation, scope) && !accepted) {
        await _applyChatResponse(
          response: response,
          userId: user.id,
          anchor: anchor,
        );
      } else {
        notifyListeners();
        unawaited(loadHistory(reconcileLocal: true));
      }
    } catch (_) {
      _reportOutboxError(scope);
    }
  }

  Future<void> _confirmOutbox(String requestId, SessionScope scope) async {
    try {
      final rows = await _outbox.readScope(_outboxScope(scope));
      final row = rows.where((row) => row.requestId == requestId).firstOrNull;
      if (row == null || !await _outbox.setState(row, null)) return;
      if (!_scopeStillLive(scope.generation, scope)) return;
      _outboxStates.remove(requestId);
      _outboxRows.remove(requestId);
      notifyListeners();
      _requestOutboxDrain();
    } catch (_) {
      _reportOutboxError(scope);
    }
  }

  void skipReveal() {
    if (_messageQueue.isEmpty) return;
    final pending = _messageQueue.expand((batch) => batch).toList();
    _messageQueue.clear();
    if (_revealWake?.isCompleted == false) _revealWake!.complete();
    if (pending.isNotEmpty) {
      sent.addAll(pending.map((m) => m.settled()));
      _followIncoming(pending.where((message) => message.role == 'him').length);
    }
    himTyping = false;
    notifyListeners();
  }

  /// Injectable clock for tests.
  DateTime Function() clock = DateTime.now;

  /// Clears failed/uncertain state on a delivered message, by local id or by
  /// the request_id the server echoed. Returns true if anything changed.
  bool _settleSend({int? userId, String? requestId}) {
    final accepted =
        requestId ??
        [
          ...sent,
          ...history,
        ].where((m) => m.id == userId).firstOrNull?.requestId;
    if (accepted != null && accepted.isNotEmpty) {
      _endLocalWait(requestId: accepted);
      _acceptedRequestIds.add(accepted);
      if (_outboxStates.containsKey(accepted)) {
        unawaited(_confirmOutbox(accepted, _captureScope(_session.generation)));
      }
      while (_acceptedRequestIds.length > 200) {
        _acceptedRequestIds.remove(_acceptedRequestIds.first);
      }
    }
    var changed = false;
    bool matches(ChatMessage m) =>
        m.role == 'you' &&
        (m.failed || m.uncertain) &&
        ((userId != null && m.id == userId) ||
            (requestId != null &&
                requestId.isNotEmpty &&
                m.requestId == requestId));
    for (final list in [sent, history]) {
      for (var i = 0; i < list.length; i++) {
        if (matches(list[i])) {
          list[i] = list[i].copyWith(failed: false, clearUncertain: true);
          changed = true;
        }
      }
    }
    return changed;
  }

  Future<void> loadHistory({
    bool reconcileLocal = false,
    bool backgroundRefresh = false,
  }) => _session.historyRead ??=
      _readHistory(
        reconcileLocal: reconcileLocal,
        backgroundRefresh: backgroundRefresh,
      ).whenComplete(() {
        _session.historyRead = null;
        _flushHistoryRefresh();
      });

  void _flushHistoryRefresh() {
    if (!_session.takeDeferredHistoryFlush(
      loadingMoreHistory: loadingMoreHistory,
    )) {
      return;
    }
    unawaited(loadHistory(reconcileLocal: true, backgroundRefresh: true));
  }

  Future<void> _readHistory({
    required bool reconcileLocal,
    required bool backgroundRefresh,
  }) async {
    // Silent refresh waits for an in-flight send; a user refresh still
    // applies so missed remote turns are not stuck behind the pending bubble.
    if (_session.shouldHoldHistoryRead(
      backgroundRefresh: backgroundRefresh,
      loadingMoreHistory: loadingMoreHistory,
    )) {
      _session.deferHistoryRefresh();
      return;
    }
    if (_session.disposed) return;
    final token = _accessToken;
    if (loadingHistory || token == null) return;
    final backend = _backend();
    final generation = _session.generation;
    final previousSnapshot = List<ChatMessage>.of(history);
    final localSnapshot = List<ChatMessage>.of(sent);
    final silent = backgroundRefresh && historyLoaded;
    if (!silent) {
      loadingHistory = true;
      historyError = null;
      notifyListeners();
    }
    try {
      final scope = _captureScope(generation);
      final dates = (await _withLiveGrant(
        scope: scope,
        generation: generation,
        call: (grant) => backend.loadChatLogDates(
          token: token,
          sessionId: grant.sessionId,
          characterId: _deliveryCharId(),
        ),
      )).dates;
      if (_session.isStale(generation)) return;
      final loaded = <String>[];
      var messages = <ChatMessage>[];
      var exhausted = dates.isEmpty;
      if (dates.isNotEmpty) {
        final today = _dateKey(DateTime.now());
        var firstDate = dates.contains(today) ? today : dates.first;
        var day = await _withLiveGrant(
          scope: scope,
          generation: generation,
          call: (grant) => backend.loadChatLogDay(
            firstDate,
            token: token,
            sessionId: grant.sessionId,
            characterId: _deliveryCharId(),
          ),
        );
        messages = _messagesFromDay(day);
        loaded.add(firstDate);
        // 首屏只取当天一页；不足 10 条的旧日页延后到首屏后后台补。
        final index = dates.indexOf(firstDate);
        final previous = index >= 0 && index + 1 < dates.length
            ? dates[index + 1]
            : null;
        if (_conversationCount(messages) < 10 && previous != null) {
          day = await _withLiveGrant(
            scope: scope,
            generation: generation,
            call: (grant) => backend.loadChatLogDay(
              previous,
              token: token,
              sessionId: grant.sessionId,
              characterId: _deliveryCharId(),
            ),
          );
          messages = [..._messagesFromDay(day), ...messages];
          loaded.insert(0, previous);
          firstDate = previous;
        }
        final earliest = dates.indexOf(firstDate);
        exhausted = earliest < 0 || earliest >= dates.length - 1;
      }
      if (_session.isStale(generation) ||
          _accessToken != token ||
          !identical(_backend(), backend)) {
        return;
      }
      if (_session.shouldAbandonHistoryApply(
        backgroundRefresh: backgroundRefresh,
        localMutated:
            !listEquals(localSnapshot, sent) ||
            !listEquals(previousSnapshot, history),
      )) {
        _session.deferHistoryRefresh();
        return;
      }
      // Only server evidence can settle a send. Reconciliation also returns
      // retained local failures, whose request_id is not a receipt.
      for (final m in messages) {
        if (m.role == 'him' && m.requestId != null) {
          _settleSend(requestId: m.requestId);
        }
      }
      if (reconcileLocal) {
        // A row with no dateKey is local content the server has not dated yet
        // (synchronous HTTP reply, upload preview, sticker). It belongs to the
        // reconciled window: the `older` filter below drops it, so excluding it
        // here would delete it from the transcript on the next refresh.
        messages = reconcileChatHistory(
          messages,
          history
              .where((m) => m.dateKey == null || loaded.contains(m.dateKey))
              .toList(),
          List<ChatMessage>.of(sent),
          sent,
        );
      }

      final older = history
          .where(
            (m) =>
                m.dateKey != null &&
                !loaded.contains(m.dateKey) &&
                dates.contains(m.dateKey),
          )
          .toList();
      loaded.insertAll(
        0,
        _loadedDates.where((d) => !loaded.contains(d) && dates.contains(d)),
      );
      final merged = [...older, ...messages];
      final nextNoMore = loaded.isEmpty
          ? exhausted
          : dates.indexOf(loaded.first) == dates.length - 1;
      final unchanged =
          silent &&
          _sameVisibleHistory(history, merged) &&
          listEquals(_availableDates, dates) &&
          listEquals(_loadedDates, loaded) &&
          noMoreHistory == nextNoMore;
      history
        ..clear()
        ..addAll(merged);
      _availableDates
        ..clear()
        ..addAll(dates);
      _loadedDates
        ..clear()
        ..addAll(loaded);
      noMoreHistory = nextNoMore;
      historyLoaded = true;
      if (!reconcileLocal) visibleMessageLimit = initialVisibleMessageCount;
      if (unchanged) return;
      notifyListeners();
      if (!silent && previousSnapshot.isEmpty && localSnapshot.isEmpty) {
        scrollToBottom(animate: false);
      } else {
        _followIncoming(0);
      }
    } on BackendException catch (e) {
      if (_session.isCurrent(generation)) historyError = e.message;
    } catch (e) {
      if (_session.isCurrent(generation)) historyError = e.toString();
    } finally {
      loadingHistory = false;
      if (!_session.disposed && !silent) notifyListeners();
    }
  }

  bool _sameVisibleHistory(List<ChatMessage> a, List<ChatMessage> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.role != right.role ||
          left.text != right.text ||
          left.displayText != right.displayText ||
          left.quotedText != right.quotedText ||
          left.quotedLabel != right.quotedLabel ||
          left.time != right.time ||
          left.dateKey != right.dateKey ||
          left.failed != right.failed ||
          left.uncertain != right.uncertain ||
          left.toolActivity?.status != right.toolActivity?.status ||
          left.toolActivity?.eventId != right.toolActivity?.eventId ||
          left.attachments.length != right.attachments.length) {
        return false;
      }
    }
    return true;
  }

  Future<void> loadOlderHistory() async {
    final token = _accessToken;
    if (token == null ||
        loadingHistory ||
        loadingMoreHistory ||
        noMoreHistory ||
        _loadedDates.isEmpty ||
        _availableDates.isEmpty) {
      return;
    }
    final generation = _session.generation;
    final backend = _backend();
    final earliestIndex = _availableDates.indexOf(_loadedDates.first);
    final targetIndex = earliestIndex + 1;
    if (earliestIndex < 0 || targetIndex >= _availableDates.length) {
      noMoreHistory = true;
      notifyListeners();
      return;
    }
    loadingMoreHistory = true;
    historyError = null;
    notifyListeners();
    try {
      final day = await _withLiveGrant(
        scope: _captureScope(generation),
        generation: generation,
        call: (grant) => backend.loadChatLogDay(
          _availableDates[targetIndex],
          token: token,
          sessionId: grant.sessionId,
          characterId: _deliveryCharId(),
        ),
      );
      if (_session.isStale(generation) ||
          _accessToken != token ||
          !identical(_backend(), backend)) {
        return;
      }
      history.insertAll(0, _messagesFromDay(day));
      _loadedDates.insert(0, _availableDates[targetIndex]);
      noMoreHistory = targetIndex >= _availableDates.length - 1;
      notifyListeners();
    } on BackendException catch (e) {
      historyError = e.message;
    } catch (e) {
      historyError = e.toString();
    } finally {
      loadingMoreHistory = false;
      if (!_session.disposed) {
        notifyListeners();
        _flushHistoryRefresh();
      }
    }
  }

  Future<void> activateMobile({
    ChatDeliverySource source = ChatDeliverySource.live,
  }) async {
    final token = _accessToken;
    if (token == null) return;
    final generation = _session.generation;
    final origin = _deliveryOrigin()?.trim();
    final owner = _deliveryOwner()?.trim();
    final epoch = _receiveEpoch;
    _receivingBackend = _backend();
    try {
      final result = await _backend().activateMobile(token: token);
      if (epoch != _receiveEpoch || _staleDelivery(generation, origin, owner)) {
        return;
      }
      if (!result.ok || !result.active) {
        mobileActive = false;
        mobileError = result.error ?? 'mobile channel is not active';
        notifyListeners();
        return;
      }
      mobileActive = result.active;
      mobileError = null;
      notifyListeners();
      await pollIfBackgroundUnavailable(source: source);
    } on BackendRequestCancelled {
      return;
    } on BackendException catch (e) {
      if (epoch != _receiveEpoch || _staleDelivery(generation, origin, owner)) {
        return;
      }
      mobileActive = false;
      mobileError = e.message;
      notifyListeners();
    } catch (e) {
      if (epoch != _receiveEpoch || _staleDelivery(generation, origin, owner)) {
        return;
      }
      mobileActive = false;
      mobileError = e.toString();
      notifyListeners();
    }
  }

  Future<void>? _foregroundDelivery;

  Future<void> pollIfBackgroundUnavailable({
    ChatDeliverySource source = ChatDeliverySource.live,
  }) async {
    final existing = _foregroundDelivery;
    if (existing != null) return existing;
    final generation = _session.generation;
    final epoch = _receiveEpoch;
    late final Future<void> work;
    work =
        (() async {
          // Native ack and Flutter presentation are separate stages.
          await _replayPendingEnvelopes();
          if (_session.isStale(generation) || epoch != _receiveEpoch) return;
          final backgroundRunning = await _relay
              .isBackgroundServiceRunning()
              .timeout(const Duration(seconds: 2), onTimeout: () => false);
          if (_session.isStale(generation) || epoch != _receiveEpoch) return;
          await pollMobile(source: source, animate: !backgroundRunning);
        })().whenComplete(() {
          if (identical(_foregroundDelivery, work)) _foregroundDelivery = null;
        });
    _foregroundDelivery = work;
    await work;
  }

  Future<void> pollMobile({
    ChatDeliverySource source = ChatDeliverySource.live,
    bool? animate,
  }) async {
    final token = _accessToken;
    if (pollingMobile || token == null) return;
    pollingMobile = true;
    final generation = _session.generation;
    final origin = _deliveryOrigin()?.trim();
    final owner = _deliveryOwner()?.trim();
    final epoch = _receiveEpoch;
    bool stale() =>
        epoch != _receiveEpoch || _staleDelivery(generation, origin, owner);
    _receivingBackend = _backend();
    try {
      await _bindDeliveryScope();
      if (stale()) return;
      _syncDeliveryScope(origin, owner);
      final persistedSeq = await _settings.loadLastAckedMobileSeq();
      if (stale()) return;
      if (persistedSeq == null) {
        lastAckedMobileSeq = null;
      } else if (lastAckedMobileSeq == null ||
          persistedSeq > lastAckedMobileSeq!) {
        lastAckedMobileSeq = persistedSeq;
      }
      final persistedSeen = await _settings.loadSeenMobileMessageIds();
      if (stale()) return;
      for (final id in persistedSeen) {
        if (id.isNotEmpty && !_seenIds.contains(id)) _seenIds.add(id);
      }
      while (_seenIds.length > 200) {
        _seenIds.removeAt(0);
      }
      final result = await _backend().pollMobile(
        token: token,
        after: lastAckedMobileSeq,
        limit: 50,
        waitSeconds: source == ChatDeliverySource.live ? 25 : 0,
      );
      if (stale()) return;
      if (!result.ok || !result.active) {
        mobileActive = false;
        mobileError = result.error ?? 'mobile channel is not active';
        notifyListeners();
        return;
      }
      final messages = result.messages;
      // The complete inbox is durable before seen state, UI mutation or server ACK.
      await _settings.stashPendingMobileEnvelopes(
        [for (final message in messages) message.toQueueItemJson()],
        origin: origin,
        owner: owner,
      );
      if (stale()) return;
      // Reconcile unknown-outcome sends by the request_id the server echoes.
      var settled = false;
      for (final message in messages) {
        final rid = message.requestId;
        if (rid != null &&
            message.charId == _deliveryCharId() &&
            message.userId == _deliveryOwner() &&
            _settleSend(requestId: rid)) {
          settled = true;
        }
      }

      if (settled) notifyListeners();
      final scope = _captureScope(generation);
      final fresh = <MobilePollMessage>[];
      for (final message in messages) {
        if (!scope.acceptsMessageChar(message.charId)) {
          continue;
        }
        if (message.id.isNotEmpty) {
          final known =
              _seenIds.contains(message.id) ||
              _syncReplyIds.contains(message.id) ||
              _historyContainsIdentity(message.id, content: message.content);
          if (!_seenIds.contains(message.id)) {
            _seenIds.add(message.id);
            if (_seenIds.length > 200) _seenIds.removeAt(0);
          }
          if (known || _isRecentReply(message.content, msgId: message.id)) {
            continue;
          }
          _rememberReply(message.content, msgId: message.id);
        } else {
          if (source != ChatDeliverySource.live &&
                  _matchesLoadedHistory(message.content) ||
              _isRecentReply(message.content)) {
            continue;
          }
          _rememberReply(message.content);
        }
        fresh.add(message);
      }
      // All characters were parked before classification: the cursor remains
      // origin+owner scoped without dropping another character on ACK.
      // Only a turn observed while actively polling is live. Initial hydration
      // and foreground recovery must never enter the reveal queue. A large
      // batch is also rendered atomically as a final safety valve.
      final shouldAnimate =
          source == ChatDeliverySource.live &&
          (animate ?? true) &&
          !_containsStaleDelivery(fresh) &&
          _staticBubbleCount(fresh) <= 10;
      _appendMobileMessages(fresh, animate: shouldAnimate);
      mobileActive = result.active;
      mobileError = null;
      if (fresh.isNotEmpty) {
        mobileReceivedCount += fresh.length;
        lastMobileContent = fresh.last.content;
      }
      notifyListeners();
      if (stale()) return;
      if (_seenIds.isNotEmpty) {
        await _settings.saveSeenMobileMessageIds(
          List.unmodifiable(_seenIds),
          origin: origin,
          owner: owner,
        );
      }
      if (stale()) return;
      int? maxSeq;
      for (final message in messages) {
        final seq = message.seq;
        if (seq != null && (maxSeq == null || seq > maxSeq)) maxSeq = seq;
      }
      if (maxSeq != null) {
        await _backend().ackMobile(token: token, ackSeq: maxSeq);
        if (stale()) return;
        await _settings.saveLastAckedMobileSeq(
          maxSeq,
          origin: origin,
          owner: owner,
        );
        if (stale()) return;
        lastAckedMobileSeq = maxSeq;
      }
    } on BackendRequestCancelled {
      return;
    } on BackendException catch (e) {
      if (stale()) return;
      mobileActive = false;
      mobileError = e.message;
      notifyListeners();
    } catch (e) {
      if (stale()) return;
      mobileActive = false;
      mobileError = e.toString();
      notifyListeners();
    } finally {
      if (_session.isCurrent(generation) && epoch == _receiveEpoch) {
        pollingMobile = false;
      }
    }
  }

  int _staticBubbleCount(List<MobilePollMessage> messages) {
    var count = 0;
    for (final message in messages) {
      if (message.content.trim().isNotEmpty) {
        count += message.behaviorKind.isNotEmpty
            ? 1
            : _splitSegments(message.content).length;
      }
      if (message.sticker != null && _stickerEnabled()) count++;
    }
    return count;
  }

  bool _containsStaleDelivery(List<MobilePollMessage> messages) {
    final now = DateTime.now();
    return messages.any((message) {
      final timestamp = message.timestamp;
      return timestamp != null &&
          now.difference(timestamp) >= _staleDeliveryThreshold;
    });
  }

  void _appendMobileMessages(
    List<MobilePollMessage> messages, {
    required bool animate,
  }) {
    if (!animate) {
      final immediate = <ChatMessage>[];
      for (final message in messages) {
        final base = message.toChatMessage();
        if (message.content.trim().isNotEmpty) {
          final parts = message.behaviorKind.isNotEmpty
              ? [message.content]
              : _splitSegments(message.content);
          final displayParts = inlineDisplayParts(
            message.content,
            message.displayText,
            parts,
          );
          immediate.addAll(
            parts.asMap().entries.map(
              (entry) => ChatMessage(
                role: 'him',
                text: entry.value,
                displayText: displayParts[entry.key],
                time: base.time,
                dateKey: _dateKey(base.timestamp),
                turnId: message.id.trim().isEmpty ? null : message.id.trim(),
                retainOnRefresh: true,
              ),
            ),
          );
        }
        if (message.sticker != null && _stickerEnabled()) {
          immediate.add(
            ChatMessage(
              role: 'him',
              text: '',
              time: base.time,
              dateKey: _dateKey(base.timestamp),
              sticker: message.sticker,
              retainOnRefresh: true,
            ),
          );
        }
        if (message.artifacts.isNotEmpty) {
          immediate.add(
            ChatMessage(
              role: 'him',
              text: '',
              time: base.time,
              dateKey: _dateKey(base.timestamp),
              turnId: message.id.trim().isEmpty ? null : message.id.trim(),
              artifacts: message.artifacts,
              retainOnRefresh: true,
            ),
          );
        }
      }
      if (immediate.isNotEmpty) {
        final fresh = _mergeIncomingRows(immediate);
        sent.addAll(fresh);
        if (fresh.isNotEmpty) _followIncoming(fresh.length);
      }
      return;
    }
    for (final message in messages) {
      final base = message.toChatMessage();
      if (message.content.trim().isNotEmpty) {
        final parts = message.behaviorKind.isNotEmpty
            ? [message.content]
            : _splitSegments(message.content);
        unawaited(
          _appendSegments(
            parts,
            time: base.time,
            displayParts: inlineDisplayParts(
              message.content,
              message.displayText,
              parts,
            ),
            turnId: message.id.trim().isEmpty ? null : message.id.trim(),
            timestamp: message.timestamp,
          ),
        );
      }
      if (message.sticker != null && _stickerEnabled()) {
        unawaited(_appendSticker(message.sticker!, time: base.time));
      }
      if (message.artifacts.isNotEmpty) {
        unawaited(
          _appendArtifacts(
            message.artifacts,
            time: base.time,
            turnId: message.id.trim().isEmpty ? null : message.id.trim(),
          ),
        );
      }
      if (message.voiceAvailable &&
          _autoPlayVoice() &&
          message.content.trim().isNotEmpty) {
        unawaited(_synthesizeAndPlay(message.content));
      }
    }
  }

  Future<void> _synthesizeAndPlay(String text) async {
    final token = _accessToken;
    if (token == null) return;
    try {
      final voice = await _backend().synthesizeMobileVoice(text, token: token);
      final audioB64 = (voice['audio_b64'] ?? '').toString();
      if (audioB64.isNotEmpty) await _voice.playGeneratedAudio(audioB64);
    } catch (_) {
      // 语音投递失败不能影响主消息收取；文字已经正常显示。
    }
  }

  Future<void> uploadFiles(
    List<PickedUploadFile> files, {
    required String preview,
    String message = '',
  }) async {
    if (_accessToken == null || files.isEmpty) return;
    await _enqueueOutgoing(
      preview,
      files: [
        for (final file in files)
          PickedUploadFile(
            name: file.name,
            bytes: Uint8List.fromList(file.bytes),
          ),
      ],
      caption: message,
    );
  }

  Future<void> _appendReply(
    String reply, {
    String? displayText,
    String? turnId,
  }) async {
    final parts = _splitSegments(reply);
    await _appendSegments(
      parts,
      displayParts: inlineDisplayParts(reply, displayText, parts),
      turnId: turnId,
    );
  }

  /// 逐条追加分段气泡，供同步回复路径与 mobile poll 路径共用。
  ///
  /// 若前一批分段仍在播放，新分段追加到同一队列尾部顺序播放（不并行）；
  /// 每条气泡等上一条 reveal 动画播完（按 [revealCps] 估算）再出现，
  /// 期间维持 [himTyping] = true。
  Future<void> _appendSegments(
    List<String> parts, {
    String? time,
    List<String?>? displayParts,
    String? turnId,
    DateTime? timestamp,
  }) async {
    if (parts.isEmpty) return;
    await _appendMessages([
      for (final entry in parts.asMap().entries)
        ChatMessage(
          role: 'him',
          text: entry.value,
          turnId: turnId,
          timestamp: timestamp,
          dateKey: timestamp == null ? null : _dateKey(timestamp),
          displayText: displayParts?[entry.key],
          time: time ?? _nowLabel(),
          animate: true,
          retainOnRefresh: true,
        ),
    ]);
  }

  Future<void> _appendArtifacts(
    List<ChatArtifact> artifacts, {
    String? time,
    String? turnId,
  }) {
    if (artifacts.isEmpty) return Future<void>.value();
    return _appendMessages([
      ChatMessage(
        role: 'him',
        text: '',
        time: time ?? _nowLabel(),
        turnId: turnId,
        artifacts: artifacts,
        retainOnRefresh: true,
      ),
    ]);
  }

  Future<void> _appendSticker(StickerPayload sticker, {String? time}) =>
      _appendMessages([
        ChatMessage(
          role: 'him',
          text: '',
          time: time ?? _nowLabel(),
          sticker: sticker,
          retainOnRefresh: true,
        ),
      ]);

  Future<void> _appendMessages(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    messages = _mergeIncomingRows(messages);
    if (messages.isEmpty) {
      notifyListeners();
      return;
    }
    final generation = _session.generation;
    _messageQueue.add(List.of(messages));
    if (_session.playingSegments) return;
    _session.playingSegments = true;
    final random = math.Random();
    try {
      while (_messageQueue.isNotEmpty && _session.isCurrent(generation)) {
        final batch = _messageQueue.first;
        final message = batch.removeAt(0);
        if (batch.isEmpty) _messageQueue.removeAt(0);
        himTyping = false;
        sent.add(message);
        _followIncoming(message.role == 'him' ? 1 : 0);
        notifyListeners();
        if (_messageQueue.isNotEmpty) {
          himTyping = true;
          notifyListeners();
          final revealMs = (message.text.characters.length / revealCps * 1000)
              .round()
              .clamp(1, 4000);
          final wake = Completer<void>();
          _revealWake = wake;
          await Future.any<void>([
            Future<void>.delayed(
              Duration(milliseconds: revealMs + 100 + random.nextInt(901)),
            ),
            wake.future,
          ]);
          if (identical(_revealWake, wake)) _revealWake = null;
        }
      }
    } finally {
      if (_session.isCurrent(generation)) {
        himTyping = false;
        _session.playingSegments = false;
        notifyListeners();
        _flushHistoryRefresh();
      }
    }
  }

  void _followIncoming(int unread) {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (!position.hasContentDimensions) return;
    void markUnread() {
      if (unread == 0) return;
      unreadHimCount += unread;
      showJumpToLatest = true;
      notifyListeners();
    }

    if (!scrollController.following) {
      markUnread();
      return;
    }
    scrollController.followAfterLayout();
  }

  List<String> _splitSegments(String text) {
    final value = text.trim();
    if (value.isEmpty) return const ['……'];
    // Keep a markup tree intact across newlines in live, poll and replay paths.
    if (hasDisplayMarkup(value)) return [value];
    final parts = value
        .split(RegExp(r'\r?\n+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? const ['……'] : parts;
  }

  bool _staleDelivery(int generation, String? origin, String? owner) {
    return _session.isStale(generation) ||
        origin != _deliveryOrigin()?.trim() ||
        owner != _deliveryOwner()?.trim();
  }

  void _syncDeliveryScope(String? origin, String? owner) {
    final changed =
        _boundDeliveryOrigin != origin || _boundDeliveryOwner != owner;
    if (!changed) return;
    if (_boundDeliveryOrigin != null || _boundDeliveryOwner != null) {
      lastAckedMobileSeq = null;
      _seenIds.clear();
    }
    _boundDeliveryOrigin = origin;
    _boundDeliveryOwner = owner;
  }

  Future<void> _bindDeliveryScope() async {
    final origin = _deliveryOrigin()?.trim();
    final owner = _deliveryOwner()?.trim();
    if (origin == null || origin.isEmpty || owner == null || owner.isEmpty) {
      return;
    }
    await _settings.bindMobileDeliveryScope(origin: origin, owner: owner);
  }

  bool _shouldReplayPending(PendingMobileEnvelope envelope) {
    if (!envelope.replayable) return false;
    final text = envelope.content.trim();
    if (text.isEmpty &&
        envelope.artifacts.isEmpty &&
        envelope.sticker == null) {
      return false;
    }
    final identity = envelope.identity;
    if (identity == null) return false;
    // Native `seen` means notification delivery, not Flutter presentation.
    // The pending envelope is precisely the handoff of that already-seen item.
    if (envelope.artifacts.isEmpty &&
        envelope.sticker == null &&
        (_syncReplyIds.contains(identity) ||
            _historyContainsIdentity(identity, content: text))) {
      return false;
    }
    if (envelope.artifacts.isEmpty &&
        envelope.sticker == null &&
        _isRecentReply(text, msgId: identity)) {
      return false;
    }
    _rememberReply(text, msgId: identity);
    return true;
  }

  List<ChatMessage> _pendingRows(PendingMobileEnvelope envelope) {
    final base = envelope.toChatMessage();
    final parts = envelope.content.trim().isEmpty
        ? <String>[]
        : _splitSegments(envelope.content);
    final displays = inlineDisplayParts(
      envelope.content,
      envelope.displayText,
      parts,
    );
    return [
      for (var i = 0; i < parts.length; i++)
        ChatMessage(
          role: 'him',
          text: parts[i],
          displayText: displays[i],
          time: base.time,
          timestamp: base.timestamp,
          dateKey: base.dateKey,
          turnId: envelope.identity,
          retainOnRefresh: true,
        ),
      if (envelope.toArtifactMessage() case final artifact?) artifact,
      if (envelope.sticker != null && _stickerEnabled())
        ChatMessage(
          role: 'him',
          text: '',
          sticker: envelope.sticker,
          turnId: envelope.identity,
          time: base.time,
          timestamp: base.timestamp,
          dateKey: base.dateKey,
          retainOnRefresh: true,
        ),
    ];
  }

  List<List<ChatMessage>> get _replyStores => [history, sent, ..._messageQueue];

  bool _historyContainsIdentity(String identity, {required String content}) {
    final counts = <String, int>{};
    for (final row in _replyStores.expand((rows) => rows)) {
      if (row.role == 'him' && row.turnId == identity && row.text.isNotEmpty) {
        counts.update(row.text, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    if (content.trim().isEmpty) return false;
    for (final part in _splitSegments(content)) {
      final count = counts[part] ?? 0;
      if (count == 0) return false;
      counts[part] = count - 1;
    }
    return true;
  }

  /// HTTP, poll and reveal share one occurrence-aware paragraph merge.
  /// A turn is a search boundary, not a single bubble or a content hash.
  List<ChatMessage> _mergeIncomingRows(List<ChatMessage> incoming) {
    final used = <int>{};
    final fresh = <ChatMessage>[];
    for (final row in incoming) {
      var matched = false;
      if (row.role == 'him' &&
          row.turnId?.isNotEmpty == true &&
          (row.text.isNotEmpty ||
              row.artifacts.isNotEmpty ||
              row.sticker != null)) {
        for (final store in _replyStores) {
          for (var i = 0; i < store.length; i++) {
            final prior = store[i];
            if (used.contains(prior.id) ||
                prior.role != row.role ||
                prior.turnId != row.turnId ||
                prior.text != row.text ||
                prior.sticker?.dataUrl != row.sticker?.dataUrl ||
                !listEquals(
                  prior.artifacts.map((a) => a.id).toList(),
                  row.artifacts.map((a) => a.id).toList(),
                )) {
              continue;
            }
            used.add(prior.id);
            if (row.displayText != null) {
              store[i] = prior.copyWith(displayText: row.displayText);
            }
            matched = true;
            break;
          }
          if (matched) break;
        }
      }
      if (!matched) fresh.add(row);
    }
    return fresh;
  }

  String _fingerprint(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();
  bool _isRecentReply(String text, {String? msgId}) {
    final now = DateTime.now();
    _recentReplies.removeWhere(
      (_, at) => now.difference(at) > const Duration(seconds: 45),
    );
    _recentIdsByFingerprint.removeWhere(
      (key, _) => !_recentReplies.containsKey(key),
    );
    final key = _fingerprint(text);
    if (!_recentReplies.containsKey(key)) return false;
    return msgId == null ||
        !_recentIdsByFingerprint.containsKey(key) ||
        _recentIdsByFingerprint[key] == msgId;
  }

  void _rememberReply(String text, {String? msgId}) {
    final key = _fingerprint(text);
    if (key.isEmpty) return;
    _recentReplies[key] = DateTime.now();
    if (msgId == null) {
      _recentIdsByFingerprint.remove(key);
    } else {
      _recentIdsByFingerprint[key] = msgId;
    }
  }

  bool _matchesLoadedHistory(String text) {
    final parts = _splitSegments(text);
    if (parts.isEmpty) return false;
    final historyFingerprints = history
        .where((message) => message.role == 'him')
        .map((message) => _fingerprint(message.text))
        .toSet();
    return parts.every(historyFingerprints.contains);
  }

  bool _shouldAppendSynchronousReply(BackendChatResponse response) {
    void register(String id) {
      _syncReplyIds.add(id);
      while (_syncReplyIds.length > 200) {
        _syncReplyIds.remove(_syncReplyIds.first);
      }
    }

    final msgId = response.msgId;
    final turnId = response.turnId;
    if (msgId != null) register(msgId);
    if (turnId != null) register(turnId);
    if (msgId != null || turnId != null) {
      final id = msgId ?? turnId!;
      if ((msgId != null && _seenIds.contains(msgId)) ||
          (turnId != null && _seenIds.contains(turnId)) ||
          _isRecentReply(response.reply, msgId: id)) {
        return false;
      }
      _rememberReply(response.reply, msgId: id);
      return true;
    }
    if (_isRecentReply(response.reply)) return false;
    _rememberReply(response.reply);
    return true;
  }

  List<ChatMessage> _messagesFromDay(ChatLogDay day) {
    final seenTurns = <String>{};
    final seenEvents = <String>{};
    final messages = <ChatMessage>[
      for (final entry in day.entries) ...[
        if (entry.toolActivity != null &&
            seenEvents.add(entry.toolActivity!.eventId))
          ChatMessage(
            role: 'tool',
            text: entry.toolActivity!.name,
            time: entry.time,
            dateKey: day.date,
            toolActivity: entry.toolActivity,
            timestamp: entry.timestamp,
          ),
        if (entry.user.trim().isNotEmpty &&
            !entry.legacyUserOnly &&
            !(entry.assistant.trim().isEmpty &&
                _outboxRows[entry.requestId]?.hiddenOnRestore == true))
          ChatMessage(
            role: 'you',
            text: historyUserDisplay(entry.user).text,
            quotedText: historyUserDisplay(entry.user).quote,
            quotedLabel: historyUserDisplay(entry.user).quote == null
                ? null
                : 'reply',
            time: entry.time,
            dateKey: day.date,
            turnId: entry.turnId,
            requestId: entry.requestId,
            timestamp: entry.userTimestamp ?? entry.timestamp,
            mediaRefs: entry.mediaRefs,
          ),
        if (entry.turnId?.isNotEmpty == true &&
            entry.assistant.trim().isNotEmpty &&
            entry.entryKind != 'narration' &&
            seenTurns.add(entry.turnId!))
          ChatMessage(
            role: 'reasoning',
            text: entry.turnId!,
            time: '',
            timestamp: entry.timestamp,
            turnId: entry.turnId,
            dateKey: day.date,
          ),
        for (final part in _splitHistory(entry.assistant).asMap().entries)
          ChatMessage(
            role: entry.entryKind == 'narration' ? 'narration' : 'him',
            text: part.value,
            requestId: entry.requestId,
            timestamp: entry.timestamp,
            turnId: entry.turnId,
            displayText: inlineDisplayParts(
              entry.assistant,
              entry.assistantDisplayText,
              _splitHistory(entry.assistant),
            )[part.key],
            time: entry.time,
            dateKey: day.date,
          ),
        if (entry.artifacts.isNotEmpty)
          ChatMessage(
            role: 'him',
            text: '',
            turnId: entry.turnId,
            time: entry.time,
            dateKey: day.date,
            artifacts: entry.artifacts,
            timestamp: entry.timestamp,
          ),
      ],
    ];
    final knownEpochs = {
      for (final entry in day.entries) ...[
        if (entry.timestamp != null) entry.timestamp!,
        if (entry.userTimestamp != null) entry.userTimestamp!,
      ],
    };
    final turnClocks = {
      for (final entry in day.entries)
        if (entry.turnId != null) entry.turnId!: entry.time,
    };
    DateTime orderTime(ChatMessage row) {
      if (knownEpochs.contains(row.timestamp)) return row.timestamp;
      final time = row.time.isEmpty ? turnClocks[row.turnId] : row.time;
      final minute = time != null && time.length >= 5
          ? time.substring(0, 5)
          : '23:59';
      // Legacy minute precision cannot prove sub-minute order. Keep its ties
      // stable, after known epochs in that minute.
      return DateTime.tryParse('${day.date}T$minute:59.999') ?? DateTime(9999);
    }

    final ordered = messages.asMap().entries.toList();
    ordered.sort((a, b) {
      final compared = orderTime(a.value).compareTo(orderTime(b.value));
      return compared == 0 ? a.key.compareTo(b.key) : compared;
    });
    return ordered.map((entry) => entry.value).toList();
  }

  List<String> _splitHistory(String text) {
    final value = text.trim();
    if (value.isEmpty) return const [];
    if (AttachmentPlaceholder.parse(value) != null) return [value];
    return _splitSegments(value);
  }

  int _conversationCount(List<ChatMessage> messages) =>
      messages.where((m) => m.role == 'you' || m.role == 'him').length;
  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _nowLabel() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _handleScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (scrollController.following) {
      if (showJumpToLatest || unreadHimCount != 0) {
        showJumpToLatest = false;
        unreadHimCount = 0;
        notifyListeners();
      }
    } else if (!showJumpToLatest) {
      showJumpToLatest = true;
      notifyListeners();
    }
    if (position.extentBefore < 200) {
      final total = history.length + sent.length;
      if (!_revealOlder(total)) unawaited(loadOlderHistory());
    }
  }

  bool _revealOlder(int total) {
    if (visibleMessageLimit >= total) return false;
    visibleMessageLimit = math.min(
      total,
      visibleMessageLimit + visibleMessageStep,
    );
    notifyListeners();
    return true;
  }

  void scrollToBottom({bool animate = true}) {
    scrollController.follow();
    if (showJumpToLatest) {
      showJumpToLatest = false;
      unreadHimCount = 0;
      notifyListeners();
    }
    scrollController.followAfterLayout();
  }

  @override
  void dispose() {
    _session.markDisposed();
    _queueExpiryTimer?.cancel();
    for (final stop in _preDispatchStops.values) {
      if (!stop.isCompleted) stop.completeError(StateError('outbox_disposed'));
    }

    pausePolling();
    unawaited(_networkSubscription?.cancel());
    _canonicalMedia.clear();
    _canonicalMediaInflight.clear();
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
    final token = _accessToken;
    if (token != null) {
      unawaited(
        _backend()
            .deactivateMobile(token: token)
            .then<void>((_) {})
            .catchError((_) {}),
      );
    }
    super.dispose();
  }
}
