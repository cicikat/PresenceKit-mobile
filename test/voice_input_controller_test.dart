// Recording identity is captured before the microphone starts. Controlled STT
// futures catch role/connection/epoch changes without timing or a real model.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/voice_input_controller.dart';
import 'package:presencekit_mobile/models/session_scope.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Voice extends VoiceService {
  _Voice() : super(const AppSettingsStore());
  int starts = 0, stops = 0, cancels = 0;
  final startEntered = Completer<void>();
  final stopEntered = Completer<void>();
  Completer<bool>? startGate;
  Completer<String?>? stopGate;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> startRecording() async {
    starts++;
    if (!startEntered.isCompleted) startEntered.complete();
    return startGate == null ? true : await startGate!.future;
  }

  @override
  Future<String?> stopRecording() async {
    stops++;
    if (!stopEntered.isCompleted) stopEntered.complete();
    return stopGate == null ? 'fixture.m4a' : await stopGate!.future;
  }

  @override
  Future<void> cancelRecording() async {
    cancels++;
  }
}

class _Backend extends BackendClient {
  _Backend()
    : super(
        baseUrl: 'http://fixture.invalid',
        settingsStore: const AppSettingsStore(),
      );
  final calls = <VoiceInputScope>[];
  final entered = Completer<void>();
  Completer<String>? response;
  @override
  Future<String> transcribeAudio({
    required String filePath,
    required String token,
    required VoiceInputScope scope,
    required bool Function() isCurrent,
    String channel = 'mobile',
  }) {
    calls.add(scope);
    if (!entered.isCompleted) entered.complete();
    return response?.future ?? Future.value('hello');
  }
}

VoiceInputScope _scope({
  String role = 'role-a',
  String session = 'session-a',
  int epoch = 1,
}) => VoiceInputScope(
  origin: 'http://fixture.invalid',
  generation: epoch,
  grant: PresenceSessionGrant(
    sessionId: session,
    charId: role,
    ownerId: 'fixture-owner',
    domain: 'reality',
  ),
);

void main() {
  late _Voice voice;
  late _Backend backend;
  late VoiceInputScope? live;
  late String token;
  late VoiceInputController controller;
  setUp(() {
    voice = _Voice();
    backend = _Backend();
    live = _scope();
    token = 'fixture-token';
    controller = VoiceInputController(
      voice: voice,
      backend: () => backend,
      token: () => token,
      presenceGrant: () async => live?.grant,
      scope: () => live,
    );
  });
  tearDown(() => controller.dispose());

  test(
    'cancelled hardware start must finish before another recording starts',
    () async {
      voice.startGate = Completer<bool>();
      final pending = controller.start();
      await voice.startEntered.future;
      await controller.cancel();
      expect(await controller.start(), '正在录音，请先松手');
      voice.startGate!.complete(true);
      expect(await pending, 'session_scope_stale');
      expect(voice.cancels, 1);
      expect(await controller.start(), isNull);
    },
  );

  test('hardware stop finishes before a new recording may start', () async {
    await controller.start();
    voice.stopGate = Completer<String?>();
    final pending = controller.stopAndTranscribe();
    await voice.stopEntered.future;
    expect(await controller.start(), '正在录音，请先松手');
    voice.stopGate!.complete('fixture.m4a');
    expect((await pending).text, 'hello');
    expect(await controller.start(), isNull);
  });

  test(
    'normal recording transcribes with the grant captured at start',
    () async {
      final original = live!;
      expect(await controller.start(), isNull);
      final result = await controller.stopAndTranscribe();
      expect(result.text, 'hello');
      expect(result.error, isNull);
      expect(backend.calls.single, same(original));
      expect(voice.starts, 1);
    },
  );

  for (final change in [
    'role',
    'ABA',
    'session',
    'token',
    'backend',
    'revoked',
  ]) {
    test('recording rejects $change before sending audio', () async {
      final original = backend;
      expect(await controller.start(), isNull);
      switch (change) {
        case 'role':
          live = _scope(role: 'role-b', session: 'session-b', epoch: 2);
        case 'ABA':
          live = _scope(epoch: 3);
        case 'session':
          live = _scope(session: 'replacement', epoch: 2);
        case 'token':
          token = 'changed-token';
        case 'backend':
          backend = _Backend();
        case 'revoked':
          live = null;
      }
      final result = await controller.stopAndTranscribe();
      expect(result.error, 'session_scope_stale');
      expect(result.text, isNull);
      expect(original.calls, isEmpty);
      expect(backend.calls, isEmpty);
    });
  }

  test('A to B to A during transcription cannot return old text', () async {
    backend.response = Completer<String>();
    await controller.start();
    final pending = controller.stopAndTranscribe();
    await backend.entered.future;
    live = _scope(role: 'role-b', session: 'session-b', epoch: 2);
    live = _scope(epoch: 3);
    backend.response!.complete('late A');
    final result = await pending;
    expect(result.text, isNull);
    expect(result.error, 'session_scope_stale');
  });

  test(
    'starting a newer recording invalidates an older transcription',
    () async {
      backend.response = Completer<String>();
      await controller.start();
      final pending = controller.stopAndTranscribe();
      await backend.entered.future;
      expect(await controller.start(), isNull);
      backend.response!.complete('old recording');
      expect((await pending).text, isNull);
      expect(voice.starts, 2);
    },
  );
}
