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
  bool _pollingWanted = false;

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

  bool _live(int generation) => !_disposed && generation == _generation;

  Future<void> startPolling() async {
    if (_disposed) return;
    _pollingWanted = true;
    if (_stateTimer != null) {
      unawaited(loadState(silent: true));
      return;
    }
    unawaited(loadState());
    unawaited(loadStats());
    _stateTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(loadState(silent: true)),
    );
  }

  void stopPolling() {
    _pollingWanted = false;
    _stateTimer?.cancel();
    _stateTimer = null;
  }

  /// Local display invalidation only. Does not POST exit/wake/archive.
  void invalidateLocalSession({required bool clearSettings}) {
    _generation++;
    finishReveal();
    _stateTimer?.cancel();
    _stateTimer = null;
    messages.clear();
    state = null;
    stats = null;
    error = null;
    settingsError = null;
    loadingState = false;
    entering = false;
    sending = false;
    loadingSettings = false;
    savingSettings = false;
    transitioning = false;
    transitionFailed = false;
    if (clearSettings) {
      settings = null;
      worlds = [];
      presets = [];
    }
    notifyListeners();
    if (_pollingWanted && !_disposed) unawaited(startPolling());
  }

  Future<void> loadState({bool silent = false}) async {
    final token = _accessToken;
    if (loadingState || token == null) return;
    final generation = _generation;
    final backend = _backend();
    loadingState = true;
    if (!silent) {
      error = null;
      notifyListeners();
    }
    try {
      final loaded = await backend.loadDreamState(token: token);
      if (!_live(generation)) return;
      state = loaded;
      error = null;
    } on BackendException catch (e) {
      if (!_live(generation)) return;
      error = e.message;
    } catch (e) {
      if (!_live(generation)) return;
      error = e.toString();
    } finally {
      if (_live(generation)) {
        loadingState = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadStats() async {
    final token = _accessToken;
    if (token == null) return;
    final generation = _generation;
    try {
      final loaded = await _backend().loadDreamStats(token: token);
      if (!_live(generation)) return;
      stats = loaded;
      notifyListeners();
    } catch (_) {
      // Keep the last successful stats when a read-only refresh fails.
    }
  }

  Future<void> enter() async {
    final token = _accessToken;
    if (entering || transitioning || token == null) return;
    final generation = _generation;
    final backend = _backend();
    entering = true;
    error = null;
    notifyListeners();
    try {
      if (!await backend.enterDream(token: token)) {
        if (!_live(generation)) return;
        error = '后端没有允许这次入梦';
        return;
      }
      if (!_live(generation)) return;
      messages.add(
        ChatMessage(role: 'system', text: '— 坠入梦中 —', time: _nowLabel()),
      );
      await loadState(silent: true);
      _scrollToBottom();
    } on BackendException catch (e) {
      if (!_live(generation)) return;
      error = e.message;
    } finally {
      if (_live(generation)) {
        entering = false;
        notifyListeners();
      }
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
    final backend = _backend();
    if (token == null) return;
    try {
      final response = await backend.sendDreamChat(message, token: token);
      if (!_live(generation)) return;
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
            if (!_live(generation)) return;
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
            if (!_live(generation)) return;
            markRevealStarted(revealed);
            if (identical(_revealDone, done)) _revealDone = null;
          }
        }
      }
      if (!_live(generation)) return;
      if (response.exitAccepted || response.forceExited) {
        await loadState(silent: true);
      }
      _scrollToBottom();
    } catch (e) {
      if (_live(generation)) {
        error = e is BackendException ? e.message : e.toString();
      }
    } finally {
      if (_live(generation)) sending = false;
      notifyListeners();
    }
  }

  Future<DreamWakeResult?> wake() async {
    final token = _accessToken;
    if (transitioning || entering || token == null) return null;
    final generation = _generation;
    final backend = _backend();
    transitioning = true;
    transitionFailed = false;
    notifyListeners();
    try {
      final result = await backend.dreamWake(token: token);
      if (!_live(generation)) return null;
      transitionFailed = !result.retained && !result.confirmedClosed;
      return result;
    } catch (_) {
      if (!_live(generation)) return null;
      transitionFailed = true;
      return null;
    } finally {
      if (_live(generation)) {
        transitioning = false;
        notifyListeners();
      }
    }
  }

  Future<void> resume() async {
    final token = _accessToken;
    if (token == null || transitioning) return;
    final generation = _generation;
    final backend = _backend();
    transitioning = true;
    transitionFailed = false;
    notifyListeners();
    try {
      await backend.dreamResume(token: token);
      if (!_live(generation)) return;
    } catch (_) {
      if (!_live(generation)) return;
      transitionFailed = true;
    } finally {
      if (_live(generation)) {
        transitioning = false;
        notifyListeners();
      }
    }
    if (_live(generation)) await loadState(silent: true);
  }

  Future<bool> exit({bool callBackendExit = true}) async {
    final token = _accessToken;
    if (transitioning || entering) return false;
    final generation = _generation;
    final backend = _backend();
    transitioning = true;
    transitionFailed = false;
    notifyListeners();
    var closed = false;
    try {
      if (callBackendExit) {
        if (token == null ||
            !(await backend.exitDream(token: token)).confirmedClosed) {
          if (!_live(generation)) return false;
          transitionFailed = true;
          return false;
        }
      }
      if (!_live(generation)) return false;
      _generation++;
      sending = false;
      finishReveal();
      stopPolling();
      state = null;
      stats = null;
      error = null;
      messages.clear();
      closed = true;
      return true;
    } catch (_) {
      if (!_live(generation)) return false;
      transitionFailed = true;
      return false;
    } finally {
      // Success increments generation once. Identity invalidation increments
      // independently. Only this call may clear transitioning.
      final expected = closed ? generation + 1 : generation;
      if (!_disposed && _generation == expected) {
        transitioning = false;
        notifyListeners();
      }
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
    final generation = _generation;
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
      if (!_live(generation) || token != _accessToken) return;
      settings = loadedSettings;
      worlds = loadedWorlds;
      presets = loadedPresets;
    } on BackendException catch (e) {
      if (!_live(generation) || token != _accessToken) return;
      settingsError = e.message;
    } finally {
      if (_live(generation)) {
        loadingSettings = false;
        notifyListeners();
      }
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
    final generation = _generation;
    final backend = _backend();
    savingSettings = true;
    settingsError = null;
    notifyListeners();
    try {
      final updated = await backend.updateDreamSettings(
        token: token,
        enableDreamLorebook: enableDreamLorebook,
        worldLayer: worldLayer,
        jailbreakPreset: jailbreakPreset,
        jailbreakPresets: jailbreakPresets,
        memoryAccess: memoryAccess,
        boundaryLevel: boundaryLevel,
        lucidMode: lucidMode,
      );
      if (!_live(generation) || token != _accessToken) return;
      settings = updated;
    } on BackendException catch (e) {
      if (!_live(generation) || token != _accessToken) return;
      settingsError = e.message;
    } finally {
      if (_live(generation)) {
        savingSettings = false;
        notifyListeners();
      }
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
    stopPolling();
    scrollController.dispose();
    super.dispose();
  }
}
