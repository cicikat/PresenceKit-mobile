import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/app_models.dart';
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
  String? error;
  String? settingsError;
  bool loadingState = false;
  bool entering = false;
  bool sending = false;
  bool loadingSettings = false;
  bool savingSettings = false;

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
    if (!silent) error = null;
    notifyListeners();
    try {
      state = await _backend().loadDreamState(token: token);
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
    if (entering || token == null) return;
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
    if (message.isEmpty || sending || state?.isActive != true) return;
    sending = true;
    error = null;
    messages.add(ChatMessage(role: 'you', text: message, time: _nowLabel()));
    notifyListeners();
    _scrollToBottom();
    unawaited(_send(message));
  }

  Future<void> _send(String message) async {
    final token = _accessToken;
    if (token == null) return;
    try {
      final response = await _backend().sendDreamChat(message, token: token);
      if (response.error != null && response.error!.trim().isNotEmpty) {
        messages.add(
          ChatMessage(
            role: 'system',
            text: '（${response.error}）',
            time: _nowLabel(),
          ),
        );
      } else {
        for (final part in _splitReply(response.reply)) {
          messages.add(
            ChatMessage(
              role: 'him',
              text: part,
              time: _nowLabel(),
              animate: true,
            ),
          );
        }
      }
      if (response.exitAccepted || response.forceExited)
        await loadState(silent: true);
      _scrollToBottom();
    } on BackendException catch (e) {
      error = e.message;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<DreamWakeResult?> wake() async {
    final token = _accessToken;
    if (token == null) return null;
    try {
      return await _backend().dreamWake(token: token);
    } on BackendException {
      return null;
    }
  }

  Future<void> resume() async {
    final token = _accessToken;
    if (token == null) return;
    try {
      await _backend().dreamResume(token: token);
    } catch (_) {
      // 下轮状态同步会恢复真实状态。
    }
    await loadState(silent: true);
  }

  Future<void> exit({bool callBackendExit = true}) async {
    final token = _accessToken;
    if (callBackendExit && token != null) {
      try {
        await _backend().exitDream(token: token);
      } catch (_) {
        // 后端离线时仍允许回到现实页。
      }
    }
    stopPolling();
    state = null;
    stats = null;
    error = null;
    messages.clear();
    notifyListeners();
  }

  Future<void> loadSettings() async {
    final token = _accessToken;
    if (loadingSettings || token == null) return;
    loadingSettings = true;
    settingsError = null;
    notifyListeners();
    try {
      settings = await _backend().loadDreamSettings(token: token);
    } on BackendException catch (e) {
      settingsError = e.message;
    } finally {
      loadingSettings = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings({
    bool? enableDreamLorebook,
    String? worldLayer,
    String? jailbreakPreset,
  }) async {
    final token = _accessToken;
    if (savingSettings || token == null) return;
    savingSettings = true;
    settingsError = null;
    notifyListeners();
    try {
      settings = await _backend().updateDreamSettings(
        token: token,
        enableDreamLorebook: enableDreamLorebook,
        worldLayer: worldLayer,
        jailbreakPreset: jailbreakPreset,
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
      if (!scrollController.hasClients) return;
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
    _stateTimer?.cancel();
    scrollController.dispose();
    super.dispose();
  }
}
