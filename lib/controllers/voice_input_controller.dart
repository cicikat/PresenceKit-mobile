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
    required String? Function() characterId,
  }) : _voice = voice,
       _backend = backend,
       _token = token,
       _presenceGrant = presenceGrant,
       _characterId = characterId;

  final VoiceService _voice;
  final BackendClient Function() _backend;
  final String? Function() _token;
  final Future<PresenceSessionGrant?> Function() _presenceGrant;
  final String? Function() _characterId;
  bool _recording = false;

  Future<String?> start() async {
    if (_recording) return '正在录音，请先松手';
    try {
      if (!await _voice.hasPermission()) {
        await _voice.requestPermission();
        if (!await _voice.hasPermission()) {
          return '麦克风权限未开启';
        }
      }
      if (!await _voice.startRecording()) return '无法开始录音';
      _recording = true;
      return null;
    } catch (_) {
      return '无法开始录音';
    }
  }

  Future<void> cancel() async {
    if (!_recording) return;
    _recording = false;
    await _voice.cancelRecording();
  }

  Future<VoiceInputResult> stopAndTranscribe() async {
    if (!_recording) {
      return const VoiceInputResult(error: '当前没有正在进行的录音');
    }
    _recording = false;
    try {
      final path = await _voice.stopRecording();
      final token = _token()?.trim();
      if (path == null || path.isEmpty) {
        return const VoiceInputResult(error: '录音失败');
      }
      if (token == null || token.isEmpty) {
        return const VoiceInputResult(error: '语音转写需要先配置访问凭证');
      }
      final backend = _backend();
      final characterId = _characterId();
      final grant = await _presenceGrant();
      if (grant == null || grant.charId != characterId || grant.isExpired) {
        throw const BackendException('session_not_found');
      }
      final text = await backend.transcribeAudio(
        filePath: path, token: token, sessionId: grant.sessionId,
      );
      if (_token() != token || _characterId() != characterId || !identical(_backend(), backend)) {
        throw const BackendException('session_scope_stale');
      }
      return VoiceInputResult(text: text);
    } on BackendException catch (e) {
      return VoiceInputResult(error: e.message);
    } catch (_) {
      return const VoiceInputResult(error: '语音转写失败');
    }
  }
}
