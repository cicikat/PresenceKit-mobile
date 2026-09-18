import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/device_controller.dart';
import 'package:presencekit_mobile/models/screen_context.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Store extends AppSettingsStore {
  bool activityRecognition = false;
  int activityRequests = 0;
  int? steps = 1200;
  int? battery = 80;
  bool screenUpload = true;
  ScreenContextSnapshot? snapshot;
  Completer<void>? captureGate;
  final List<Map<String, int?>> pushes = [];
  int captures = 0;

  @override
  Future<bool> hasActivityRecognitionPermission() async => activityRecognition;

  @override
  Future<void> requestActivityRecognitionPermission() async {
    activityRequests += 1;
    activityRecognition = true;
  }

  @override
  Future<int?> readBatteryPercent() async => battery;

  @override
  Future<int?> readTodaySteps() async => steps;

  @override
  Future<bool> loadScreenContextUploadEnabled() async => screenUpload;

  @override
  Future<void> saveScreenContextUploadEnabled(bool value) async {
    screenUpload = value;
  }

  @override
  Future<ScreenContextSnapshot?> captureScreenContextForUpload() async {
    await captureGate?.future;
    captures += 1;
    return snapshot;
  }
}

class _Backend extends BackendClient {
  _Backend(this.store)
    : super(baseUrl: 'http://127.0.0.1:8080', settingsStore: store);

  final _Store store;
  int screenPushes = 0;
  int selfFocus = 0;
  Completer<void>? screenGate;
  final tokens = <String>[];

  @override
  Future<void> pushSensorData({
    required String token,
    int? steps,
    int? battery,
    int? screenSessions,
  }) async {
    store.pushes.add({'battery': battery, 'steps': steps});
  }

  @override
  Future<void> pushScreenContext(
    ScreenContextSnapshot snapshot, {
    required String token,
  }) async {
    tokens.add(token);
    await screenGate?.future;
    screenPushes += 1;
  }

  @override
  Future<void> pushSelfFocusSignal({required String token}) async {
    selfFocus += 1;
  }
}

void main() {
  late _Store store;
  late _Backend backend;
  late DeviceController controller;
  var restored = true;
  var foreground = true;
  var token = 'token';

  setUp(() {
    store = _Store();
    backend = _Backend(store);
    restored = true;
    foreground = true;
    token = 'token';
    controller = DeviceController(
      device: DeviceControlService(store),
      screen: ScreenSensorService(store),
      backend: () => backend,
      token: () => token,
      restored: () => restored,
      foreground: () => foreground,
    );
  });

  tearDown(() => controller.dispose());

  test('pushSensorData never requests activity permission', () async {
    store.activityRecognition = false;
    await controller.pushSensorData();
    expect(store.activityRequests, 0);
    expect(store.pushes, [
      {'battery': 80, 'steps': null},
    ]);
  });

  test('pushSensorData includes steps only when already granted', () async {
    store.activityRecognition = true;
    await controller.pushSensorData();
    expect(store.activityRequests, 0);
    expect(store.pushes, [
      {'battery': 80, 'steps': 1200},
    ]);
  });

  test('explicit requestActivityPermission is the only prompt path', () async {
    expect(await controller.hasActivityPermission(), isFalse);
    await controller.requestActivityPermission();
    expect(store.activityRequests, 1);
    expect(await controller.hasActivityPermission(), isTrue);
  });

  test('start/periodic path still does not request permission', () async {
    store.activityRecognition = false;
    controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(store.activityRequests, 0);
    controller.stop();
  });

  test('hidden/paused stop Dart timers; inactive keeps them', () {
    controller.start();
    expect(controller.hasPeriodicTimers, isTrue);
    controller.handleAppLifecycle(AppLifecycleState.inactive);
    expect(controller.hasPeriodicTimers, isTrue);
    controller.handleAppLifecycle(AppLifecycleState.hidden);
    expect(controller.hasPeriodicTimers, isFalse);
    controller.handleAppLifecycle(AppLifecycleState.paused);
    expect(controller.hasPeriodicTimers, isFalse);
    controller.handleAppLifecycle(AppLifecycleState.resumed);
    expect(controller.hasPeriodicTimers, isTrue);
    controller.handleAppLifecycle(AppLifecycleState.detached);
    expect(controller.hasPeriodicTimers, isFalse);
  });

  test('restore-incomplete start does not create a background Dart timer', () {
    restored = false;
    controller.start();
    expect(controller.hasPeriodicTimers, isFalse);
    restored = true;
    foreground = false;
    controller.start();
    expect(controller.hasPeriodicTimers, isFalse);
    foreground = true;
    controller.start();
    expect(controller.hasPeriodicTimers, isTrue);
    controller.start();
    expect(controller.hasPeriodicTimers, isTrue);
  });

  test('late capture does not upload after identity or background change', () async {
    await controller.restore();
    store.snapshot = const ScreenContextSnapshot(
      isBlocked: false,
      blockedReason: '',
      textUploadAllowed: true,
      packageName: 'com.example.app',
      appLabel: 'Example',
      className: '',
      windowTitle: 'Hi',
      visibleText: ['hi'],
      clickableText: [],
      capturedAt: 1,
    );
    store.captureGate = Completer<void>();
    final first = controller.pushScreenContext(silent: true);
    await Future<void>.delayed(Duration.zero);
    token = 'next';
    controller.invalidateForIdentityChange();
    store.captureGate!.complete();
    await first;
    expect(store.captures, 1);
    expect(backend.screenPushes, 0);

    token = 'token';
    store.captureGate = Completer<void>();
    final second = controller.pushScreenContext(silent: true);
    await Future<void>.delayed(Duration.zero);
    foreground = false;
    store.captureGate!.complete();
    await second;
    expect(store.captures, 2);
    expect(backend.screenPushes, 0);
  });

  test('disabled upload and missing restore never start a substitute task', () async {
    await controller.setScreenUploadEnabled(false);
    await controller.pushScreenContext(silent: true);
    expect(store.captures, 0);
    expect(backend.screenPushes, 0);
    restored = false;
    await controller.setScreenUploadEnabled(true);
    await controller.pushScreenContext(silent: true);
    expect(store.captures, 0);
  });
}
