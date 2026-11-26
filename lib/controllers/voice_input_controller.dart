import 'dart:async';
import 'package:flutter/foundation.dart';

import '../services/backend_client.dart';
import '../models/session_scope.dart';
import '../services/device_services.dart';

class VoiceInputResult {
  const VoiceInputResult({this.text, this.error});

  final String? text;
  final String? error;
  bool get isSuccess => error == null;
}

/// Owns the composer microphone permission, recording, and transcription flow.
class VoiceInputController extends ChangeNotifier {
  VoiceInputController({
    required VoiceService voice,
    required BackendClient Function() backend,
    required String? Function() token,
    required Future<PresenceSessionGrant?> Function() presenceGrant,
    required VoiceInputScope? Function() scope,
  }) : _voice = voice,
       _backend = backend,
       _token = token,
       _presenceGrant = presenceGrant,
       _scope = scope;

  final VoiceService _voice;
  final BackendClient Function() _backend;
  final String? Function() _token;
  final Future<PresenceSessionGrant?> Function() _presenceGrant;
  final VoiceInputScope? Function() _scope;
  _Recording? _recording;
  bool _starting = false;
  bool _disposed = false;
  int _operation = 0;

  bool _current(_Recording recording) =>
      !_disposed &&
      recording.operation == _operation &&
      _token()?.trim() == recording.token &&
      identical(_backend(), recording.backend) &&
      recording.scope.matches(_scope()) &&
      !recording.scope.grant.isExpired;

  Future<String?> start() async {
    if (_disposed) return 'session_scope_stale';
    if (_recording != null || _starting) return '正在录音，请先松手';
    _starting = true;
    final operation = ++_operation;
    try {
      final backend = _backend(), token = _token()?.trim();
      if (token == null || token.isEmpty) return '语音转写需要先配置访问凭证';
      final grant = await _presenceGrant();
      final scope = _scope();
      if (grant == null ||
          scope == null ||
          grant.sessionId != scope.grant.sessionId) {
        return 'session_scope_stale';
      }
      final recording = _Recording(backend, token, scope, operation);
      if (!_current(recording)) return 'session_scope_stale';
      backend.invalidateVoiceReceipts();
      if (!await _voice.hasPermission()) {
        if (!_current(recording)) return 'session_scope_stale';
        await _voice.requestPermission();
        if (!await _voice.hasPermission()) {
          return '麦克风权限未开启';
        }
      }
      if (!_current(recording)) return 'session_scope_stale';
      if (!await _voice.startRecording()) return '无法开始录音';
      if (!_current(recording)) {
        await _voice.cancelRecording();
        return 'session_scope_stale';
      }
      _recording = recording;
      return null;
    } catch (_) {
      return '无法开始录音';
    } finally {
      _starting = false;
    }
  }

  Future<void> cancel() async {
    _operation++;
    final recording = _recording;
    _recording = null;
    _backend().invalidateVoiceReceipts();
    if (recording != null) await _voice.cancelRecording();
  }

  Future<VoiceInputResult> stopAndTranscribe() async {
    final recording = _recording;
    if (recording == null) {
      return const VoiceInputResult(error: '当前没有正在进行的录音');
    }
    _recording = null;
    try {
      _starting = true;
      String? path;
      try {
        path = await _voice.stopRecording();
      } finally {
        _starting = false;
      }
      if (!_current(recording)) {
        return const VoiceInputResult(error: 'session_scope_stale');
      }
      if (path == null || path.isEmpty) {
        return const VoiceInputResult(error: '录音失败');
      }
      final text = await recording.backend.transcribeAudio(
        filePath: path,
        token: recording.token,
        scope: recording.scope,
        isCurrent: () => _current(recording),
      );
      if (!_current(recording)) {
        throw const BackendException('session_scope_stale');
      }
      return VoiceInputResult(text: text);
    } on BackendException catch (e) {
      return VoiceInputResult(error: e.message);
    } catch (_) {
      return const VoiceInputResult(error: '语音转写失败');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(cancel());
    super.dispose();
  }
}

class _Recording {
  const _Recording(this.backend, this.token, this.scope, this.operation);
  final BackendClient backend;
  final String token;
  final VoiceInputScope scope;
  final int operation;
}
