import 'package:flutter/foundation.dart';

import '../services/backend_client.dart';
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
  }) : _voice = voice,
       _backend = backend,
       _token = token;

  final VoiceService _voice;
  final BackendClient Function() _backend;
  final String? Function() _token;
  bool _recording = false;

  Future<String?> start() async {
    if (_recording) return 'Recording is already in progress.';
    try {
      if (!await _voice.hasPermission()) {
        await _voice.requestPermission();
        if (!await _voice.hasPermission()) {
          return 'Microphone permission was denied.';
        }
      }
      if (!await _voice.startRecording()) return 'Could not start recording.';
      _recording = true;
      return null;
    } catch (_) {
      return 'Could not start recording.';
    }
  }

  Future<void> cancel() async {
    if (!_recording) return;
    _recording = false;
    await _voice.cancelRecording();
  }

  Future<VoiceInputResult> stopAndTranscribe() async {
    if (!_recording) {
      return const VoiceInputResult(error: 'Recording is not active.');
    }
    _recording = false;
    try {
      final path = await _voice.stopRecording();
      final token = _token()?.trim();
      if (path == null || path.isEmpty) {
        return const VoiceInputResult(error: 'Recording failed.');
      }
      if (token == null || token.isEmpty) {
        return const VoiceInputResult(
          error: 'An access credential is required for transcription.',
        );
      }
      return VoiceInputResult(
        text: await _backend().transcribeAudio(filePath: path, token: token),
      );
    } on BackendException catch (e) {
      return VoiceInputResult(error: e.message);
    } catch (_) {
      return const VoiceInputResult(error: 'Transcription failed.');
    }
  }
}
