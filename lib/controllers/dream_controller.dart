import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/app_models.dart';
import 'chat_controller.dart';
import '../services/backend_client.dart';

class DreamController extends ChangeNotifier {
  DreamController({
    required BackendClient Function() backend,
    required String? Function() token,
  }) : _backend = backend,
       _token = token;

  final BackendClient Function() _backend;
  final String? Function() _token;
  final ScrollController scrollController = ScrollController();
  final List<ChatMessage> messages = [];
  Timer? _stateTimer;

  DreamState? state;
  DreamStats? stats;
  DreamSettings? settings;
  List<PromptAssetOption> worlds = [];
  List<PromptAssetOption> presets = [];
  String? error;
  String? settingsError;
  bool loadingState = false;
  bool entering = false;
  bool sending = false;
  bool loadingSettings = false;
  bool savingSettings = false;
  bool transitioning = false;
  bool transitionFailed = false;
  bool _disposed = false;
  int _generation = 0;
  Completer<void>? _revealDone;
  int? _revealingId;

  void markRevealStarted(ChatMessage message) {
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) messages[index] = messages[index].settled();
  }

  void finishReveal([int? messageId]) {
    if (messageId != null && messageId != _revealingId) return;
    if (_revealDone?.isCompleted == false) _revealDone!.complete();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  String? get _accessToken {
    final value = _token()?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> startPolling() async {
    _stateTimer?.cancel();
    unawaited(loadState());
    unawaited(loadStats());
    _stateTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(loadState(silent: true)),
    );
  }

  void stopPolling() => _stateTimer?.cancel();

  Future<void> loadState({bool silent = false}) async {
    final token = _accessToken;
    if (loadingState || token == null) return;
    loadingState = true;
    if (!silent) {
      error = null;
      notifyListeners();
    }
    try {
      final generation = _generation;
      final loaded = await _backend().loadDreamState(token: token);
      if (_disposed || generation != _generation) return;
      state = loaded;
      error = null;
    } on BackendException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      loadingState = false;
      notifyListeners();
    }
  }

  Future<void> loadStats() async {
    final token = _accessToken;
    if (token == null) return;
    try {
      stats = await _backend().loadDreamStats(token: token);
      notifyListeners();
    } catch (_) {
      // 只读统计失败时保留上一次成功值。
    }
  }

  Future<void> enter() async {
    final token = _accessToken;
    if (entering || transitioning || token == null) return;
    entering = true;
    error = null;
    notifyListeners();
    try {
      if (!await _backend().enterDream(token: token)) {
        error = '后端没有允许这次入梦';
        return;
      }
      messages.add(
        ChatMessage(role: 'system', text: '— 坠入梦中 —', time: _nowLabel()),
      );
      await loadState(silent: true);
      _scrollToBottom();
    } on BackendException catch (e) {
      error = e.message;
    } finally {
      entering = false;
      notifyListeners();
    }
  }

  void send(String text) {
    final message = text.trim();
    if (message.isEmpty || state?.isActive != true) return;
    if (sending || transitioning || _accessToken == null) return;
    sending = true;
    error = null;
    messages.add(ChatMessage(role: 'you', text: message, time: _nowLabel()));
    notifyListeners();
    _scrollToBottom();
    unawaited(_send(message));
  }

  Future<void> _send(String message) async {
    final token = _accessToken;
    final generation = _generation;
    if (token == null) return;
    try {
      final response = await _backend().sendDreamChat(message, token: token);
      if (_disposed || generation != _generation) return;
      if (response.error != null && response.error!.trim().isNotEmpty) {
        messages.add(
          ChatMessage(
            role: 'system',
            text: '（${response.error}）',
            time: _nowLabel(),
          ),
        );
      } else {
        final segments = response.segments.isNotEmpty
            ? response.segments
            : [NarrativeSegment(type: 'say', text: response.reply)];
        for (final segment in segments) {
          for (final part in _splitReply(segment.text)) {
            if (_disposed || generation != _generation) return;
            final done = Completer<void>();
            _revealDone = done;
            final revealed = ChatMessage(
              role: 'him',
              text: part,
              time: _nowLabel(),
              animate: true,
              segments: [NarrativeSegment(type: segment.type, text: part)],
            );
            messages.add(revealed);
            _revealingId = revealed.id;
            notifyListeners();
            _scrollToBottom();
            // Same grapheme cadence as the main chat; tap completes this paragraph.
            final duration = Duration(
              milliseconds:
                  (part.characters.length / ChatController.revealCps * 1000)
                      .round()
                      .clamp(1, 60000) +
                  120,
            );
            final timer = Timer(duration, () {
              if (!done.isCompleted) done.complete();
            });
            final follow = Timer.periodic(const Duration(milliseconds: 100), (
              _,
            ) {
              if (_disposed || !scrollController.hasClients) return;
              final position = scrollController.position;
              if (position.maxScrollExtent - position.pixels < 100) {
                scrollController.jumpTo(position.maxScrollExtent);
              }
            });
            await done.future;
            timer.cancel();
            follow.cancel();
            markRevealStarted(revealed);
            if (identical(_revealDone, done)) _revealDone = null;
          }
        }
      }
      if (_disposed || generation != _generation) return;
      if (response.exitAccepted || response.forceExited) {
        await loadState(silent: true);
      }
      _scrollToBottom();
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = e is BackendException ? e.message : e.toString();
      }
    } finally {
      if (!_disposed && generation == _generation) sending = false;
      notifyListeners();
    }
  }

  Future<DreamWakeResult?> wake() async {
    final token = _accessToken;
    if (transitioning || entering || token == null) return null;
    transitioning = true;
    transitionFailed = false;
    notifyListeners();
    try {
      final result = await _backend().dreamWake(token: token);
      transitionFailed = !result.retained && !result.confirmedClosed;
      return result;
    } catch (_) {
      transitionFailed = true;
      return null;
    } finally {
      transitioning = false;
      notifyListeners();
    }
  }

  Future<void> resume() async {
    final token = _accessToken;
    if (token == null || transitioning) return;
    transitioning = true;
    transitionFailed = false;
    notifyListeners();
    try {
      await _backend().dreamResume(token: token);
    } catch (_) {
      transitionFailed = true;
    } finally {
      transitioning = false;
      notifyListeners();
    }
    await loadState(silent: true);
  }

  Future<bool> exit({bool callBackendExit = true}) async {
    final token = _accessToken;
    if (transitioning || entering) return false;
    transitioning = true;
    transitionFailed = false;
    notifyListeners();
    try {
      if (callBackendExit) {
        if (token == null ||
            !(await _backend().exitDream(token: token)).confirmedClosed) {
          transitionFailed = true;
          return false;
        }
      }
      _generation++;
      sending = false;
      finishReveal();
      stopPolling();
      state = null;
      stats = null;
      error = null;
      messages.clear();
      return true;
    } catch (_) {
      transitionFailed = true;
      return false;
    } finally {
      transitioning = false;
      notifyListeners();
    }
  }

  Future<void> loadSettings() async {
    final token = _accessToken;
    if (loadingSettings) return;
    if (token == null) {
      settings = null;
      worlds = [];
      presets = [];
      settingsError = null;
      notifyListeners();
      return;
    }
    final backend = _backend();
    loadingSettings = true;
    settingsError = null;
    settings = null;
    worlds = [];
    presets = [];
    notifyListeners();
    try {
      final loadedSettings = await backend.loadDreamSettings(token: token);
      final loadedWorlds = await backend.loadDreamOptions(
        token: token,
        worlds: true,
      );
      final loadedPresets = await backend.loadDreamOptions(
        token: token,
        worlds: false,
      );
      if (token == _accessToken && identical(backend, _backend())) {
        settings = loadedSettings;
        worlds = loadedWorlds;
        presets = loadedPresets;
      }
    } on BackendException catch (e) {
      if (token == _accessToken && identical(backend, _backend())) {
        settingsError = e.message;
      }
    } finally {
      loadingSettings = false;
      notifyListeners();
    }
    if (token != _accessToken || !identical(backend, _backend())) {
      await loadSettings();
    }
  }

  Future<void> updateSettings({
    bool? enableDreamLorebook,
    String? worldLayer,
    String? jailbreakPreset,
    List<String>? jailbreakPresets,
    String? memoryAccess,
    String? boundaryLevel,
    String? lucidMode,
  }) async {
    final token = _accessToken;
    if (savingSettings ||
        loadingSettings ||
        state?.isActive == true ||
        token == null) {
      return;
    }
    savingSettings = true;
    settingsError = null;
    notifyListeners();
    try {
      settings = await _backend().updateDreamSettings(
        token: token,
        enableDreamLorebook: enableDreamLorebook,
        worldLayer: worldLayer,
        jailbreakPreset: jailbreakPreset,
        jailbreakPresets: jailbreakPresets,
        memoryAccess: memoryAccess,
        boundaryLevel: boundaryLevel,
        lucidMode: lucidMode,
      );
    } on BackendException catch (e) {
      settingsError = e.message;
    } finally {
      savingSettings = false;
      notifyListeners();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !scrollController.hasClients) return;
      if (scrollController.position.maxScrollExtent -
              scrollController.position.pixels >
          260) {
        return;
      }
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  static String _nowLabel() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  static List<String> _splitReply(String reply) => reply
      .split(RegExp(r'\n\s*\n'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    finishReveal();
    _stateTimer?.cancel();
    scrollController.dispose();
    super.dispose();
  }
}
