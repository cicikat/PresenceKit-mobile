import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import '../models/inline_display.dart';
import '../models/screen_context.dart';
import '../models/session_scope.dart';
import '../services/app_settings_store.dart';
import '../services/backend_client.dart';
import '../services/device_services.dart';
import 'chat_history_reconciliation.dart';
import 'chat_session_coordinator.dart';

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
  }) : _backend = backend,
       _token = token,
       _settings = settings,
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
  final ScrollController scrollController = ScrollController();
  final List<ChatMessage> history = [];
  final List<ChatMessage> sent = [];
  final List<String> _availableDates = [];
  final List<String> _loadedDates = [];
  final List<String> _seenIds = [];
  final Set<String> _syncReplyIds = {};
  final Map<String, DateTime> _recentReplies = {};
  final Map<String, String> _recentIdsByFingerprint = {};
  final List<({String text, ReplyTarget? replyTo})> _pendingSends = [];
  Timer? _pollTimer;
  final List<List<ChatMessage>> _messageQueue = [];
  Completer<void>? _revealWake;
  final ChatSessionCoordinator _session = ChatSessionCoordinator();
  double? _lastScrollPixels;
  bool get sending => _session.sending;
  set sending(bool value) => _session.sending = value;
  bool get himTyping => _session.himTyping;
  set himTyping(bool value) => _session.himTyping = value;
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
    if (_session.initialSync != null) return _session.initialSync!;
    if (_session.initialSyncComplete) {
      _ensurePollTimer();
      await pollIfBackgroundUnavailable();
      return;
    }
    _pollTimer?.cancel();
    _session.initialSync = _startInitialSync();
    try {
      await _session.initialSync;
    } finally {
      _session.initialSync = null;
    }
  }

  Future<void> _startInitialSync() async {
    await loadHistory();
    final historyOk = historyLoaded && historyError == null;
    await activateMobile(source: ChatDeliverySource.initialSync);
    if (historyOk) {
      _session.initialSyncComplete = true;
    }
    _ensurePollTimer();
  }

  void _ensurePollTimer() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(pollIfBackgroundUnavailable()),
    );
  }

  void pausePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void resumePolling() {
    if (!_session.initialSyncComplete) {
      unawaited(start());
      return;
    }
    _ensurePollTimer();
    unawaited(refreshConnection());
  }

  Future<void> catchUpFromNotification() async {
    pendingHandoffError = null;
    try {
      final pending = await _settings.consumePendingMobileEnvelopes(
        origin: _deliveryOrigin(),
        owner: _deliveryOwner(),
        charId: _deliveryCharId(),
      );
      final fresh = <PendingMobileEnvelope>[];
      for (final envelope in pending) {
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
        sent.addAll(fresh.map((envelope) => envelope.toChatMessage()));
        mobileReceivedCount += fresh.length;
        lastMobileContent = fresh.last.content;
        await _settings.saveSeenMobileMessageIds(
          List.unmodifiable(_seenIds),
          origin: _deliveryOrigin(),
          owner: _deliveryOwner(),
        );
        notifyListeners();
      }
    } on MissingPluginException catch (e) {
      pendingHandoffError = e.message ?? e.toString();
    } on PlatformException catch (e) {
      pendingHandoffError = e.message ?? e.code;
    } catch (e) {
      pendingHandoffError = e.toString();
    }
    try {
      await refreshConnection();
    } finally {
      if (pendingHandoffError != null) notifyListeners();
      scrollToBottom();
    }
  }

  Future<void> refreshConnection() => _session.refresh ??= _refreshConnection()
      .whenComplete(() => _session.refresh = null);

  Future<void> _refreshConnection() async {
    if (_accessToken == null) return;
    if (_session.initialSync != null) await _session.initialSync;
    await loadHistory(reconcileLocal: true);
    await activateMobile(source: ChatDeliverySource.catchUp);
    if (mobileActive && mobileError == null) backendError = null;
    _ensurePollTimer();
    notifyListeners();
  }

  Future<void> resetForConnectionChange({bool restart = true}) async {
    _session.beginEpoch();
    _messageQueue.clear();
    _pendingSends.clear();
    if (_revealWake?.isCompleted == false) _revealWake!.complete();
    if (_session.historyRead != null) await _session.historyRead;
    _session.clearLiveWork();
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

  void send(String text, {ReplyTarget? replyToOverride}) {
    final value = text.trim();
    if (value.isEmpty || _accessToken == null) return;
    final replyTo =
        replyToOverride ??
        (replyTarget == null ? null : ReplyTarget.fromMessage(replyTarget!));
    if (replyToOverride == null) replyTarget = null;
    if (sending) {
      _pendingSends.add((text: value, replyTo: replyTo));
      notifyListeners();
      return;
    }
    sending = true;
    himTyping = true;
    backendError = null;
    sent.add(ChatMessage(role: 'you', text: value, time: '现在'));
    if (sent.isNotEmpty && replyTo != null) {
      sent[sent.length - 1] = sent.last.copyWith(
        quotedText: replyTo.text,
        quotedLabel: 'reply',
      );
    }
    notifyListeners();
    scrollToBottom();
    unawaited(_send(value, userId: sent.last.id, replyTo: replyTo));
  }

  void setReplyTarget(ChatMessage message) {
    replyTarget = message;
    notifyListeners();
  }

  void retryMessage(ChatMessage message) {
    if (sending || message.role != 'you' || !message.failed) return;
    final historical = history.indexWhere((item) => item.id == message.id);
    if (historical >= 0) sent.add(history.removeAt(historical));
    final index = sent.indexWhere((item) => item.id == message.id);
    if (index < 0) return;
    if (message.attachments.isNotEmpty) {
      unawaited(
        uploadFiles(
          message.attachments,
          preview: message.text,
          failureLabel: '',
          message: message.uploadNote,
          retryOf: message,
        ),
      );
      return;
    }
    sent[index] = message.copyWith(failed: false, time: _nowLabel());
    sending = true;
    himTyping = true;
    backendError = null;
    notifyListeners();
    unawaited(_send(message.text, userId: message.id));
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
    final grant = await _requirePresenceGrant();
    return _backend().loadTurnReasoning(
      turnId,
      token: _accessToken!,
      sessionId: grant.sessionId,
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
      final grant = await _requirePresenceGrant();
      if (!scope.matchesLive(
        generation: _session.generation,
        origin: _deliveryOrigin(),
        owner: _deliveryOwner(),
        charId: _deliveryCharId(),
      )) {
        return null;
      }
      final bytes = await _backend().downloadChatMedia(
        digest,
        token: token,
        sessionId: grant.sessionId,
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

  void _bindUserTurn(int id, String? turnId) {
    final index = sent.indexWhere((m) => m.id == id);
    if (index >= 0) sent[index] = sent[index].copyWith(turnId: turnId);
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

  Future<PresenceSessionGrant> _requirePresenceGrant({bool force = false}) async {
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

  Future<BackendChatResponse> _sendChatAttempt({
    required String text,
    required String token,
    required PresenceSessionGrant grant,
    required String requestId,
    ReplyTarget? replyTo,
  }) {
    return _backend().sendChat(
      text,
      token: token,
      replyTo: replyTo,
      sessionId: grant.sessionId,
      requestId: requestId,
    );
  }

  Future<BackendChatResponse> _scopedChatCall({
    required SessionScope scope,
    required int generation,
    required String requestId,
    required Future<BackendChatResponse> Function(PresenceSessionGrant grant)
    call,
  }) async {
    var grant = await _requirePresenceGrant();
    if (!_scopeStillLive(generation, scope)) {
      throw const BackendException('session_scope_stale');
    }
    try {
      return await call(grant);
    } on BackendException catch (e) {
      if (!e.isSessionNotFound || !_scopeStillLive(generation, scope)) {
        rethrow;
      }
      _onPresenceSessionInvalid?.call();
      grant = await _requirePresenceGrant(force: true);
      if (!_scopeStillLive(generation, scope)) {
        throw const BackendException('session_scope_stale');
      }
      return call(grant);
    }
  }

  Future<void> _applyChatResponse({
    required BackendChatResponse response,
    required int userId,
    required ChatMessage anchor,
  }) async {
    _bindUserTurn(userId, response.turnId);
    final anchorIndex = sent.indexWhere((m) => m.id == anchor.id);
    if (anchorIndex >= 0) {
      sent[anchorIndex] = ChatMessage(
        id: anchor.id,
        role: 'reasoning',
        text: response.turnId ?? '',
        time: anchor.time,
        failed: response.turnId == null,
        turnId: response.turnId,
      );
    }
    notifyListeners();
    lastBackendReply = response;
    if (_shouldAppendSynchronousReply(response)) {
      await _appendReply(
        response.reply,
        displayText: response.displayText,
        turnId: response.turnId,
      );
    }
  }

  Future<void> _send(
    String text, {
    required int userId,
    ReplyTarget? replyTo,
  }) async {
    final generation = _session.generation;
    final scope = _captureScope(generation);
    final anchor = ChatMessage(role: 'reasoning', text: '', time: _nowLabel());
    sent.add(anchor);
    notifyListeners();
    try {
      final requestId = mintRequestId();
      final response = await _scopedChatCall(
        scope: scope,
        generation: generation,
        requestId: requestId,
        call: (grant) => _sendChatAttempt(
          text: text,
          token: _accessToken!,
          replyTo: replyTo,
          grant: grant,
          requestId: requestId,
        ),
      );
      if (!_scopeStillLive(generation, scope)) return;
      await _applyChatResponse(
        response: response,
        userId: userId,
        anchor: anchor,
      );
    } on BackendException catch (e) {
      if (!_scopeStillLive(generation, scope)) return;
      backendError = e.message;
      if (e.isSessionNotFound) _onPresenceSessionInvalid?.call();
      _markLastSendFailed();
      /*
        ChatMessage(
          role: 'him',
          text: '（手机端暂时连不上后端：${e.message}）',
          time: _nowLabel(),
        ),
      ); */
      scrollToBottom();
    } catch (e) {
      if (_session.isStale(generation) ||
          !scope.matchesLive(
            generation: _session.generation,
            origin: _deliveryOrigin(),
            owner: _deliveryOwner(),
            charId: _deliveryCharId(),
          )) {
        return;
      }
      backendError = e.toString();
      _markLastSendFailed();
      /* sent.add(
        ChatMessage(role: 'him', text: '（手机端遇到一个未预期错误：$e）', time: _nowLabel()),
      ); */
      scrollToBottom();
    } finally {
      if (_session.isCurrent(generation)) {
        final live = scope.matchesLive(
          generation: _session.generation,
          origin: _deliveryOrigin(),
          owner: _deliveryOwner(),
          charId: _deliveryCharId(),
        );
        if (live && backendError != null) {
          sent.removeWhere((m) => m.id == anchor.id);
        }
        sending = false;
        himTyping = false;
        notifyListeners();
        if (live && backendError == null) {
          unawaited(loadHistory(reconcileLocal: true, backgroundRefresh: true));
        }
        if (live && _pendingSends.isNotEmpty) {
          final next = _pendingSends.removeAt(0);
          send(next.text, replyToOverride: next.replyTo);
        }
        if (live) _flushHistoryRefresh();
      }
    }
  }

  void skipReveal() {
    if (_messageQueue.isEmpty) return;
    final pending = _messageQueue.expand((batch) => batch).toList();
    _messageQueue.clear();
    if (_revealWake?.isCompleted == false) _revealWake!.complete();
    if (pending.isNotEmpty) sent.addAll(pending.map((m) => m.settled()));
    himTyping = false;
    notifyListeners();
  }

  void _markLastSendFailed() {
    for (var i = sent.length - 1; i >= 0; i--) {
      if (sent[i].role == 'you' && !sent[i].failed) {
        sent[i] = sent[i].copyWith(failed: true);
        return;
      }
    }
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
      final grant = await _requirePresenceGrant();
      if (_session.isStale(generation)) return;
      final dates = (await backend.loadChatLogDates(
        token: token,
        sessionId: grant.sessionId,
        characterId: _deliveryCharId(),
      )).dates;
      final loaded = <String>[];
      var messages = <ChatMessage>[];
      var exhausted = dates.isEmpty;
      if (dates.isNotEmpty) {
        final today = _dateKey(DateTime.now());
        var firstDate = dates.contains(today) ? today : dates.first;
        var day = await backend.loadChatLogDay(
          firstDate,
          token: token,
          sessionId: grant.sessionId,
          characterId: _deliveryCharId(),
        );
        messages = _messagesFromDay(day);
        loaded.add(firstDate);
        final index = dates.indexOf(firstDate);
        final previous = index >= 0 && index + 1 < dates.length
            ? dates[index + 1]
            : null;
        if (_conversationCount(messages) < 10 && previous != null) {
          day = await backend.loadChatLogDay(
            previous,
            token: token,
            sessionId: grant.sessionId,
            characterId: _deliveryCharId(),
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
      if (reconcileLocal) {
        messages = reconcileChatHistory(
          messages,
          history.where((m) => loaded.contains(m.dateKey)).toList(),
          localSnapshot,
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
      if (!silent || _isAtBottom) scrollToBottom(animate: !silent);
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
          left.time != right.time ||
          left.dateKey != right.dateKey ||
          left.failed != right.failed ||
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
    final position = scrollController.hasClients
        ? scrollController.position
        : null;
    final oldMax = position?.maxScrollExtent ?? 0;
    final oldPixels = position?.pixels ?? 0;
    loadingMoreHistory = true;
    historyError = null;
    notifyListeners();
    try {
      final grant = await _requirePresenceGrant();
      if (_session.isStale(generation)) return;
      final day = await backend.loadChatLogDay(
        _availableDates[targetIndex],
        token: token,
        sessionId: grant.sessionId,
        characterId: _deliveryCharId(),
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!scrollController.hasClients) return;
        final compensated =
            scrollController.position.maxScrollExtent - oldMax + oldPixels;
        scrollController.jumpTo(
          compensated.clamp(
            scrollController.position.minScrollExtent,
            scrollController.position.maxScrollExtent,
          ),
        );
      });
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
    try {
      final result = await _backend().activateMobile(token: token);
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
    } on BackendException catch (e) {
      mobileActive = false;
      mobileError = e.message;
      notifyListeners();
    } catch (e) {
      mobileActive = false;
      mobileError = e.toString();
      notifyListeners();
    }
  }

  Future<void> pollIfBackgroundUnavailable({
    ChatDeliverySource source = ChatDeliverySource.live,
  }) async {
    if (await _relay.isBackgroundServiceRunning()) return;
    await pollMobile(source: source);
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
    try {
      await _bindDeliveryScope();
      if (_staleDelivery(generation, origin, owner)) return;
      _syncDeliveryScope(origin, owner);
      final persistedSeq = await _settings.loadLastAckedMobileSeq();
      if (persistedSeq == null) {
        lastAckedMobileSeq = null;
      } else if (lastAckedMobileSeq == null ||
          persistedSeq > lastAckedMobileSeq!) {
        lastAckedMobileSeq = persistedSeq;
      }
      for (final id in await _settings.loadSeenMobileMessageIds()) {
        if (id.isNotEmpty && !_seenIds.contains(id)) _seenIds.add(id);
      }
      while (_seenIds.length > 200) {
        _seenIds.removeAt(0);
      }
      final result = await _backend().pollMobile(
        token: token,
        after: lastAckedMobileSeq,
        waitSeconds: source == ChatDeliverySource.live ? 5 : 0,
      );
      if (_staleDelivery(generation, origin, owner)) return;
      if (!result.ok || !result.active) {
        mobileActive = false;
        mobileError = result.error ?? 'mobile channel is not active';
        notifyListeners();
        return;
      }
      final messages = result.messages;
      final scope = _captureScope(generation);
      final fresh = <MobilePollMessage>[];
      final foreign = <MobilePollMessage>[];
      for (final message in messages) {
        if (!scope.acceptsMessageChar(message.charId)) {
          foreign.add(message);
          continue;
        }
        if (message.id.isNotEmpty) {
          final known =
              _seenIds.contains(message.id) ||
              _syncReplyIds.contains(message.id) ||
              _historyContainsIdentity(message.id);
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
      // Shared cursor: park other-character items before ack so advancing
      // seq does not drop them. Cursor scope stays origin+owner (backend B5).
      if (foreign.isNotEmpty) {
        await _settings.stashPendingMobileEnvelopes(
          [for (final message in foreign) message.toQueueItemJson()],
          origin: origin,
          owner: owner,
        );
      }
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
        if (_isAtBottom) {
          scrollToBottom();
        } else {
          showJumpToLatest = true;
          unreadHimCount += fresh.length;
        }
      }
      notifyListeners();
      if (_staleDelivery(generation, origin, owner)) return;
      if (_seenIds.isNotEmpty) {
        await _settings.saveSeenMobileMessageIds(
          List.unmodifiable(_seenIds),
          origin: origin,
          owner: owner,
        );
      }
      if (_staleDelivery(generation, origin, owner)) return;
      int? maxSeq;
      for (final message in messages) {
        final seq = message.seq;
        if (seq != null && (maxSeq == null || seq > maxSeq)) maxSeq = seq;
      }
      if (maxSeq != null) {
        await _backend().ackMobile(token: token, ackSeq: maxSeq);
        if (_staleDelivery(generation, origin, owner)) return;
        await _settings.saveLastAckedMobileSeq(
          maxSeq,
          origin: origin,
          owner: owner,
        );
        if (_staleDelivery(generation, origin, owner)) return;
        lastAckedMobileSeq = maxSeq;
      }
    } on BackendException catch (e) {
      mobileActive = false;
      mobileError = e.message;
      notifyListeners();
    } catch (e) {
      mobileActive = false;
      mobileError = e.toString();
      notifyListeners();
    } finally {
      pollingMobile = false;
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
            ),
          );
        }
      }
      if (immediate.isNotEmpty) {
        sent.addAll(immediate);
        scrollToBottom();
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
    required String failureLabel,
    String message = '',
    ChatMessage? retryOf,
  }) async {
    final token = _accessToken;
    if (sending || token == null || files.isEmpty) return;
    final generation = _session.generation;
    sending = true;
    himTyping = true;
    backendError = null;
    final outgoing =
        retryOf?.copyWith(failed: false, time: _nowLabel()) ??
        ChatMessage(
          role: 'you',
          text: preview,
          time: '现在',
          attachments: List.unmodifiable(files),
          uploadNote: message,
        );
    if (retryOf == null) {
      sent.add(outgoing);
    } else {
      final index = sent.indexWhere((item) => item.id == retryOf.id);
      if (index < 0) {
        sending = false;
        himTyping = false;
        return;
      }
      sent[index] = outgoing;
    }
    final anchor = ChatMessage(role: 'reasoning', text: '', time: _nowLabel());
    sent.add(anchor);
    notifyListeners();
    scrollToBottom();
    try {
      final requestId = mintRequestId();
      final response = await _scopedChatCall(
        scope: _captureScope(generation),
        generation: generation,
        requestId: requestId,
        call: (grant) => _backend().uploadFiles(
          files: files,
          token: token,
          channel: 'mobile',
          message: message,
          sessionId: grant.sessionId,
          requestId: requestId,
        ),
      );
      if (_session.isStale(generation)) return;
      await _applyChatResponse(
        response: response,
        userId: outgoing.id,
        anchor: anchor,
      );
    } on BackendException catch (e) {
      if (_session.isStale(generation)) return;
      backendError = e.message;
      if (e.isSessionNotFound) _onPresenceSessionInvalid?.call();
      final index = sent.indexWhere((item) => item.id == outgoing.id);
      if (index >= 0) sent[index] = outgoing.copyWith(failed: true);
      scrollToBottom();
    } catch (e) {
      if (_session.isStale(generation)) return;
      backendError = e.toString();
      final index = sent.indexWhere((item) => item.id == outgoing.id);
      if (index >= 0) sent[index] = outgoing.copyWith(failed: true);
      scrollToBottom();
    } finally {
      if (_session.isCurrent(generation)) {
        if (backendError != null) sent.removeWhere((m) => m.id == anchor.id);
        sending = false;
        himTyping = false;
        notifyListeners();
        if (backendError == null) {
          unawaited(loadHistory(reconcileLocal: true, backgroundRefresh: true));
        }
        _flushHistoryRefresh();
      }
    }
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
        ),
      ]);

  Future<void> _appendMessages(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    final generation = _session.generation;
    final wasAtBottom = _isAtBottom;
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
        notifyListeners();
        if (wasAtBottom) {
          scrollToBottom();
        } else if (message.role == 'him') {
          unreadHimCount++;
        }
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
      himTyping = false;
      _session.playingSegments = false;
      if (!_session.disposed) {
        notifyListeners();
        _flushHistoryRefresh();
      }
    }
  }

  bool get _isAtBottom =>
      !scrollController.hasClients ||
      scrollController.position.maxScrollExtent -
              scrollController.position.pixels <=
          260;

  List<String> _splitSegments(String text) {
    final value = text.trim();
    if (value.isEmpty) return const ['……'];
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
    if (text.isEmpty) return false;
    final identity = envelope.identity;
    if (identity == null) return false;
    if (_seenIds.contains(identity) ||
        _syncReplyIds.contains(identity) ||
        _historyContainsIdentity(identity)) {
      return false;
    }
    if (_isRecentReply(text, msgId: identity)) return false;
    _rememberReply(text, msgId: identity);
    return true;
  }

  bool _historyContainsIdentity(String identity) {
    return history.any((message) => message.turnId == identity) ||
        sent.any((message) => message.turnId == identity);
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
    return msgId == null || !_recentIdsByFingerprint.containsKey(key);
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
    return [
      for (final entry in day.entries) ...[
        if (entry.toolActivity != null &&
            seenEvents.add(entry.toolActivity!.eventId))
          ChatMessage(
            role: 'tool',
            text: entry.toolActivity!.name,
            time: entry.time,
            dateKey: day.date,
            toolActivity: entry.toolActivity,
          ),
        for (final part in _splitHistory(entry.user))
          ChatMessage(
            role: 'you',
            text: part,
            time: entry.time,
            dateKey: day.date,
            turnId: entry.turnId,
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
            dateKey: day.date,
          ),
        for (final part in _splitHistory(entry.assistant).asMap().entries)
          ChatMessage(
            role: entry.entryKind == 'narration' ? 'narration' : 'him',
            text: part.value,
            turnId: entry.turnId,
            displayText: inlineDisplayParts(
              entry.assistant,
              entry.assistantDisplayText,
              _splitHistory(entry.assistant),
            )[part.key],
            time: entry.time,
            dateKey: day.date,
          ),
      ],
    ];
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
    final pixels = position.pixels;
    final distanceFromBottom = position.maxScrollExtent - pixels;
    final previousPixels = _lastScrollPixels;
    _lastScrollPixels = pixels;
    var show = showJumpToLatest;
    if (previousPixels != null) {
      final delta = pixels - previousPixels;
      if (delta > 0.5) {
        // 向下滑（朝最新方向）：立即隐藏，即使距底仍 >260。
        show = false;
      } else if (delta < -0.5 && distanceFromBottom > 260) {
        // 向上滑且距底 >260：显示。
        show = true;
      }
    }
    if (distanceFromBottom <= 260) show = false;
    if (show != showJumpToLatest) {
      showJumpToLatest = show;
      notifyListeners();
    }
    if (position.pixels < 200) {
      final total = history.length + sent.length;
      if (!_revealOlder(total)) unawaited(loadOlderHistory());
    }
  }

  bool _revealOlder(int total) {
    if (visibleMessageLimit >= total) return false;
    final position = scrollController.hasClients
        ? scrollController.position
        : null;
    final oldMax = position?.maxScrollExtent ?? 0;
    final oldPixels = position?.pixels ?? 0;
    visibleMessageLimit = math.min(
      total,
      visibleMessageLimit + visibleMessageStep,
    );
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      final compensated =
          scrollController.position.maxScrollExtent - oldMax + oldPixels;
      scrollController.jumpTo(
        compensated.clamp(
          scrollController.position.minScrollExtent,
          scrollController.position.maxScrollExtent,
        ),
      );
    });
    return true;
  }

  void scrollToBottom({bool animate = true}) {
    if (showJumpToLatest) {
      showJumpToLatest = false;
      unreadHimCount = 0;
      notifyListeners();
    }
    void scroll({required bool animate}) {
      if (!scrollController.hasClients) return;
      final target = scrollController.position.maxScrollExtent;
      if (animate) {
        scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        scrollController.jumpTo(target);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scroll(animate: animate),
    );
    if (animate) {
      Future<void>.delayed(
        const Duration(milliseconds: 360),
        () => scroll(animate: false),
      );
    }
  }

  @override
  void dispose() {
    _session.markDisposed();
    pausePolling();
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
