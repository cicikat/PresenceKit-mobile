import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/screen_context.dart';
import '../services/backend_client.dart';
import '../services/device_services.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required BackendClient Function() backend,
    required String? Function() token,
    required SettingsStore settings,
    required RelayStatusService relay,
  }) : _backend = backend,
       _token = token,
       _settings = settings,
       _relay = relay {
    scrollController.addListener(_handleScroll);
  }

  static const initialVisibleMessageCount = 80;
  static const visibleMessageStep = 50;
  // Mirrors chat_widgets.dart AnimatedRevealText (kept in sync with
  // Emerald-client/src/windows/room/useVnPresenter.ts, 40 CPS).
  static const revealCps = 40.0;
  final BackendClient Function() _backend;
  final String? Function() _token;
  final SettingsStore _settings;
  final RelayStatusService _relay;
  final ScrollController scrollController = ScrollController();
  final List<ChatMessage> history = [];
  final List<ChatMessage> sent = [];
  final List<String> _availableDates = [];
  final List<String> _loadedDates = [];
  final List<String> _seenIds = [];
  final Set<String> _syncReplyIds = {};
  final Map<String, DateTime> _recentReplies = {};
  final Map<String, String> _recentIdsByFingerprint = {};
  Timer? _pollTimer;
  final List<List<ChatMessage>> _messageQueue = [];
  bool _playingSegments = false;
  double? _lastScrollPixels;
  bool sending = false;
  bool himTyping = false;
  bool loadingHistory = false;
  bool loadingMoreHistory = false;
  bool noMoreHistory = false;
  bool historyLoaded = false;
  bool pollingMobile = false;
  bool mobileActive = false;
  bool showJumpToLatest = false;
  int visibleMessageLimit = initialVisibleMessageCount;
  int mobileReceivedCount = 0;
  int? lastAckedMobileSeq;
  String? backendError;
  String? historyError;
  String? mobileError;
  String? lastMobileContent;
  BackendChatResponse? lastBackendReply;
  ChatMessage? replyTarget;

  String? get _accessToken {
    final value = _token()?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> start() async {
    if (_accessToken == null) return;
    _pollTimer?.cancel();
    unawaited(loadHistory());
    unawaited(activateMobile());
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
    if (_pollTimer == null) unawaited(start());
  }

  Future<void> resetForConnectionChange() async {
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
    await start();
  }

  void send(String text) {
    final value = text.trim();
    if (value.isEmpty || sending || _accessToken == null) return;
    final replyTo = replyTarget == null
        ? null
        : ReplyTarget.fromMessage(replyTarget!);
    replyTarget = null;
    sending = true;
    himTyping = true;
    backendError = null;
    sent.add(ChatMessage(role: 'you', text: value, time: '现在'));
    notifyListeners();
    scrollToBottom();
    unawaited(_send(value, replyTo: replyTo));
  }

  void setReplyTarget(ChatMessage message) {
    replyTarget = message;
    notifyListeners();
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

  Future<void> _send(String text, {ReplyTarget? replyTo}) async {
    try {
      final response = await _backend().sendChat(
        text,
        token: _accessToken!,
        replyTo: replyTo,
      );
      lastBackendReply = response;
      if (_shouldAppendSynchronousReply(response)) {
        await _appendReply(response.reply);
      }
    } on BackendException catch (e) {
      backendError = e.message;
      sent.add(
        ChatMessage(
          role: 'him',
          text: '（手机端暂时连不上后端：${e.message}）',
          time: _nowLabel(),
        ),
      );
      scrollToBottom();
    } catch (e) {
      backendError = e.toString();
      sent.add(
        ChatMessage(role: 'him', text: '（手机端遇到一个未预期错误：$e）', time: _nowLabel()),
      );
      scrollToBottom();
    } finally {
      sending = false;
      himTyping = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    final token = _accessToken;
    if (loadingHistory || token == null) return;
    loadingHistory = true;
    historyError = null;
    notifyListeners();
    try {
      final dates = (await _backend().loadChatLogDates(token: token)).dates;
      final loaded = <String>[];
      var messages = <ChatMessage>[];
      var exhausted = dates.isEmpty;
      if (dates.isNotEmpty) {
        final today = _dateKey(DateTime.now());
        var firstDate = dates.contains(today) ? today : dates.first;
        var day = await _backend().loadChatLogDay(firstDate, token: token);
        messages = _messagesFromDay(day);
        loaded.add(firstDate);
        final index = dates.indexOf(firstDate);
        final previous = index >= 0 && index + 1 < dates.length
            ? dates[index + 1]
            : null;
        if (_conversationCount(messages) < 10 && previous != null) {
          day = await _backend().loadChatLogDay(previous, token: token);
          messages = [..._messagesFromDay(day), ...messages];
          loaded.insert(0, previous);
          firstDate = previous;
        }
        final earliest = dates.indexOf(firstDate);
        exhausted = earliest < 0 || earliest >= dates.length - 1;
      }
      history
        ..clear()
        ..addAll(messages);
      _availableDates
        ..clear()
        ..addAll(dates);
      _loadedDates
        ..clear()
        ..addAll(loaded);
      noMoreHistory = exhausted;
      historyLoaded = true;
      visibleMessageLimit = initialVisibleMessageCount;
      notifyListeners();
      scrollToBottom();
    } on BackendException catch (e) {
      historyError = e.message;
    } catch (e) {
      historyError = e.toString();
    } finally {
      loadingHistory = false;
      notifyListeners();
    }
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
      final day = await _backend().loadChatLogDay(
        _availableDates[targetIndex],
        token: token,
      );
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
      notifyListeners();
    }
  }

  Future<void> activateMobile() async {
    final token = _accessToken;
    if (token == null) return;
    try {
      await _backend().activateMobile(token: token);
      mobileActive = true;
      mobileError = null;
      notifyListeners();
      await pollIfBackgroundUnavailable();
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

  Future<void> pollIfBackgroundUnavailable() async {
    if (await _relay.isBackgroundServiceRunning()) return;
    await pollMobile();
  }

  Future<void> pollMobile() async {
    final token = _accessToken;
    if (pollingMobile || token == null) return;
    pollingMobile = true;
    try {
      final persistedSeq = await _settings.loadLastAckedMobileSeq();
      if (persistedSeq != null &&
          (lastAckedMobileSeq == null || persistedSeq > lastAckedMobileSeq!)) {
        lastAckedMobileSeq = persistedSeq;
      }
      for (final id in await _settings.loadSeenMobileMessageIds()) {
        if (id.isNotEmpty && !_seenIds.contains(id)) _seenIds.add(id);
      }
      while (_seenIds.length > 200) {
        _seenIds.removeAt(0);
      }
      final messages = await _backend().pollMobile(
        token: token,
        after: lastAckedMobileSeq,
        waitSeconds: 25,
      );
      final fresh = <MobilePollMessage>[];
      for (final message in messages) {
        if (message.id.isNotEmpty) {
          if (_seenIds.contains(message.id)) continue;
          _seenIds.add(message.id);
          if (_seenIds.length > 200) _seenIds.removeAt(0);
          if (_syncReplyIds.contains(message.id) ||
              _isRecentReply(message.content, msgId: message.id)) {
            continue;
          }
          _rememberReply(message.content, msgId: message.id);
        } else {
          if (_isRecentReply(message.content)) continue;
          _rememberReply(message.content);
        }
        fresh.add(message);
      }
      for (final message in fresh) {
        final base = message.toChatMessage();
        if (message.content.trim().isNotEmpty) {
          final parts = message.behaviorKind.isNotEmpty
              ? [message.content]
              : _splitSegments(message.content);
          unawaited(_appendSegments(parts, time: base.time));
        }
        if (message.sticker != null) {
          unawaited(_appendSticker(message.sticker!, time: base.time));
        }
      }
      mobileActive = true;
      mobileError = null;
      if (fresh.isNotEmpty) {
        mobileReceivedCount += fresh.length;
        lastMobileContent = fresh.last.content;
        scrollToBottom();
      }
      notifyListeners();
      if (_seenIds.isNotEmpty) {
        await _settings.saveSeenMobileMessageIds(List.unmodifiable(_seenIds));
      }
      int? maxSeq;
      for (final message in messages) {
        final seq = message.seq;
        if (seq != null && (maxSeq == null || seq > maxSeq)) maxSeq = seq;
      }
      if (maxSeq != null) {
        await _backend().ackMobile(token: token, ackSeq: maxSeq);
        await _settings.saveLastAckedMobileSeq(maxSeq);
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

  Future<void> uploadFiles(
    List<PickedUploadFile> files, {
    required String preview,
    required String failureLabel,
  }) async {
    final token = _accessToken;
    if (sending || token == null || files.isEmpty) return;
    sending = true;
    himTyping = true;
    backendError = null;
    sent.add(ChatMessage(role: 'you', text: preview, time: '现在'));
    notifyListeners();
    scrollToBottom();
    try {
      final response = await _backend().uploadFiles(
        files: files,
        token: token,
        channel: 'mobile',
      );
      lastBackendReply = response;
      if (_shouldAppendSynchronousReply(response)) {
        await _appendReply(response.reply);
      }
    } on BackendException catch (e) {
      backendError = e.message;
      sent.add(
        ChatMessage(
          role: 'him',
          text: '（$failureLabel没有送过去：${e.message}）',
          time: _nowLabel(),
        ),
      );
      scrollToBottom();
    } catch (e) {
      backendError = e.toString();
      sent.add(
        ChatMessage(
          role: 'him',
          text: '（$failureLabel上传遇到一个未预期错误：$e）',
          time: _nowLabel(),
        ),
      );
      scrollToBottom();
    } finally {
      sending = false;
      himTyping = false;
      notifyListeners();
    }
  }

  Future<void> _appendReply(String reply) async {
    await _appendSegments(_splitSegments(reply));
  }

  /// 逐条追加分段气泡，供同步回复路径与 mobile poll 路径共用。
  ///
  /// 若前一批分段仍在播放，新分段追加到同一队列尾部顺序播放（不并行）；
  /// 每条气泡等上一条 reveal 动画播完（按 [revealCps] 估算）再出现，
  /// 期间维持 [himTyping] = true。
  Future<void> _appendSegments(List<String> parts, {String? time}) async {
    if (parts.isEmpty) return;
    await _appendMessages([
      for (final part in parts)
        ChatMessage(
          role: 'him',
          text: part,
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
    _messageQueue.add(messages);
    if (_playingSegments) return;
    _playingSegments = true;
    final random = math.Random();
    try {
      while (_messageQueue.isNotEmpty) {
        final batch = _messageQueue.removeAt(0);
        for (var i = 0; i < batch.length; i++) {
          himTyping = false;
          sent.add(batch[i]);
          notifyListeners();
          scrollToBottom();
          final hasNext = i < batch.length - 1 || _messageQueue.isNotEmpty;
          if (hasNext) {
            himTyping = true;
            notifyListeners();
            final revealMs =
                (batch[i].text.characters.length / revealCps * 1000)
                    .round()
                    .clamp(1, 60000);
            await Future<void>.delayed(
              Duration(milliseconds: revealMs + 100 + random.nextInt(901)),
            );
          }
        }
      }
    } finally {
      himTyping = false;
      _playingSegments = false;
      notifyListeners();
    }
  }

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

  List<ChatMessage> _messagesFromDay(ChatLogDay day) => [
    for (final entry in day.entries) ...[
      for (final part in _splitHistory(entry.user))
        ChatMessage(role: 'you', text: part, time: entry.time),
      for (final part in _splitHistory(entry.assistant))
        ChatMessage(role: 'him', text: part, time: entry.time),
    ],
  ];
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

  void scrollToBottom() {
    if (showJumpToLatest) {
      showJumpToLatest = false;
      notifyListeners();
    }
    void scroll({bool animate = true}) {
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

    WidgetsBinding.instance.addPostFrameCallback((_) => scroll());
    Future<void>.delayed(
      const Duration(milliseconds: 360),
      () => scroll(animate: false),
    );
  }

  @override
  void dispose() {
    pausePolling();
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
    final token = _accessToken;
    if (token != null) {
      unawaited(_backend().deactivateMobile(token: token).catchError((_) {}));
    }
    super.dispose();
  }
}
