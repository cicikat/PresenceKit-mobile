import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/device_controller.dart';
import 'package:presencekit_mobile/models/session_scope.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';
import 'package:presencekit_mobile/services/platform_settings_channel.dart';

class _Backend extends BackendClient {
  _Backend() : super(baseUrl: 'http://127.0.0.1:8080', settingsStore: AppSettingsStore());
  Completer<PresenceSessionGrant>? gate;
  final writes = <Map<String, dynamic>>[];
  final observations = <Map<String, dynamic>>[];
  @override
  Future<PresenceSessionGrant> createPresenceSession({
    required String token,
    required String charId,
  }) async => gate == null
      ? PresenceSessionGrant(
          sessionId: 'fixture-session',
          charId: charId,
          ownerId: 'fixture-owner',
          domain: 'reality',
        )
      : gate!.future;
  @override
  Future<Map<String, dynamic>> loadAmbientPolicy({
    required String token,
    required String sessionId,
  }) async => {'char_id': 'fixture-character'};
  @override
  Future<Map<String, dynamic>> saveAmbientPolicy({
    required String token,
    required String sessionId,
    required Map<String, dynamic> patch,
  }) async {
    writes.add(patch);
    return {'char_id': 'fixture-character'};
  }

  @override
  Future<void> pushAmbient({
    required String token,
    required String sessionId,
    required Map<String, dynamic> observation,
  }) async {
    observations.add(observation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Backend backend;
  late DeviceController controller;
  var character = 'fixture-character';
  setUp(() {
    character = 'fixture-character';
    backend = _Backend();
    final store = AppSettingsStore();
    controller = DeviceController(
      device: DeviceControlService(store),
      screen: ScreenSensorService(store),
      backend: () => backend,
      token: () => 'synthetic-token',
      character: () => character,
    );
    PlatformSettingsChannel.debugForceChannelAvailable = true;
  });
  tearDown(() {
    controller.dispose();
    PlatformSettingsChannel.debugForceChannelAvailable = false;
  });
  test(
    'role switch while preparing session never writes consent to old role',
    () async {
      backend.gate = Completer<PresenceSessionGrant>();
      final saving = controller.saveAmbientPolicy({
        'enabled': true,
      }, expectedCharacter: character);
      final rejected = expectLater(saving, throwsStateError);
      character = 'another-character';
      controller.invalidateForIdentityChange();
      backend.gate!.complete(
        const PresenceSessionGrant(
          sessionId: 'old-session',
          charId: 'fixture-character',
          ownerId: 'fixture-owner',
          domain: 'reality',
        ),
      );
      await rejected;
      expect(backend.writes, isEmpty);
    },
  );
  test(
    'pause clears existing observations without sampling or new timers',
    () async {
      await controller.loadAmbientPolicy();
      controller.handleAppLifecycle(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(backend.observations, hasLength(1));
      expect(
        backend.observations.single.keys,
        unorderedEquals(['light', 'motion', 'usage']),
      );
      for (final fact in backend.observations.single.values) {
        expect(fact['status'], 'unavailable');
        expect(fact.keys, unorderedEquals(['status', 'observed_at']));
      }
      expect(controller.hasPeriodicTimers, isFalse);
    },
  );
}
