import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/screen_context.dart';
import '../services/backend_client.dart';
import '../services/device_services.dart';

/// Coordinates local device capabilities; UI decides how to present [lastError].
///
/// Dart periodic capture runs only while the Flutter view is foregrounded.
/// Native [MobileNotificationService] already owns the background screen path.
class DeviceController extends ChangeNotifier {
  DeviceController({
    required DeviceControlService device,
    required ScreenSensorService screen,
    required BackendClient Function() backend,
    required String? Function() token,
    bool Function()? restored,
    bool Function()? foreground,
  }) : _device = device,
       _screen = screen,
       _backend = backend,
       _token = token,
       _restored = restored ?? _alwaysTrue,
       _foreground = foreground ?? _alwaysTrue;

  static bool _alwaysTrue() => true;

  final DeviceControlService _device;
  final ScreenSensorService _screen;
  final BackendClient Function() _backend;
  final String? Function() _token;
  final bool Function() _restored;
  final bool Function() _foreground;
  Timer? _screenTimer;
  Timer? _sensorTimer;
  bool screenUploadEnabled = false;
  String? lastError;
  bool _disposed = false;
  int _generation = 0;
  bool _started = false;
  @visibleForTesting
  bool get hasPeriodicTimers =>
      _screenTimer != null || _sensorTimer != null;

  Future<void> restore() async {
    screenUploadEnabled = await _screen.loadUploadEnabled();
    notifyListeners();
  }

  Future<void> setScreenUploadEnabled(bool value) async {
    await _screen.saveUploadEnabled(value);
    screenUploadEnabled = value;
    notifyListeners();
    if (!value) _generation++;
  }

  Future<bool> lockScreen() => _device.lockScreen();
  Future<bool> openShoppingApp(String target) =>
      _device.openShoppingApp(target);
  Future<bool> showOrderBubble(String target) =>
      _device.showOrderBubble(target);
  Future<void> requestAccessibilityPermission() =>
      _device.requestAccessibilityPermission();
  Future<bool> isAccessibilityEnabled() => _device.isAccessibilityEnabled();

  void start() {
    if (_disposed) return;
    _started = true;
    if (!_restored() || !_foreground()) {
      stop();
      return;
    }
    if (_screenTimer != null && _sensorTimer != null) return;
    stop();
    unawaited(pushScreenContext(silent: true));
    unawaited(pushSensorData());
    _screenTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(pushScreenContext(silent: true)),
    );
    _sensorTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => unawaited(pushSensorData()),
    );
  }

  void stop() {
    _screenTimer?.cancel();
    _screenTimer = null;
    _sensorTimer?.cancel();
    _sensorTimer = null;
  }

  /// hidden/paused stop Dart timers; inactive keeps them for permission sheets.
  void handleAppLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_started) start();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        stop();
        break;
    }
  }

  void invalidateForIdentityChange() {
    _generation++;
    lastError = null;
    stop();
    if (_started && _restored() && _foreground()) start();
    notifyListeners();
  }

  Future<bool> hasActivityPermission() => _screen.hasActivityPermission();

  /// Explicit user action only. Periodic sensor upload must never call this.
  Future<void> requestActivityPermission() =>
      _screen.requestActivityPermission();

  Future<void> pushSensorData() async {
    final token = _token()?.trim();
    if (token == null || token.isEmpty) return;
    final generation = _generation;
    final backend = _backend();
    try {
      final battery = await _screen.readBatteryPercent();
      // Skip steps without permission; do not prompt from timers/start.
      final steps = await _screen.hasActivityPermission()
          ? await _screen.readTodaySteps()
          : null;
      if (!_live(generation, token, backend)) return;
      if (battery == null && steps == null) return;
      await backend.pushSensorData(
        token: token,
        battery: battery,
        steps: steps,
      );
    } catch (_) {}
  }

  Future<void> pushScreenContext({bool silent = false}) async {
    if (!screenUploadEnabled) return;
    final token = _token()?.trim();
    if (token == null || token.isEmpty) return;
    final generation = _generation;
    final backend = _backend();
    if (!_mayCapture()) return;
    final snapshot = await _screen.captureForUpload();
    if (snapshot == null || snapshot.isBlocked) return;
    if (!_live(generation, token, backend) || !_mayCapture()) return;
    try {
      if (snapshot.packageName == 'com.presencekit.mobile' ||
          snapshot.packageName == 'com.presencekit.mobile.dev') {
        await backend.pushSelfFocusSignal(token: token);
        return;
      }
      await backend.pushScreenContext(snapshot, token: token);
      if (!_live(generation, token, backend)) return;
      lastError = null;
    } on BackendException catch (e) {
      if (!_live(generation, token, backend)) return;
      lastError = e.message;
      if (!silent) notifyListeners();
    }
  }

  Future<void> pushSnapshot(
    ScreenContextSnapshot snapshot, {
    bool silent = false,
  }) async {
    if (!screenUploadEnabled || snapshot.isBlocked) return;
    final token = _token()?.trim();
    if (token == null || token.isEmpty) return;
    final generation = _generation;
    final backend = _backend();
    if (!_live(generation, token, backend) || !_mayCapture()) return;
    try {
      await backend.pushScreenContext(snapshot, token: token);
      if (!_live(generation, token, backend)) return;
      lastError = null;
      if (!silent) notifyListeners();
    } on BackendException catch (e) {
      if (!_live(generation, token, backend)) return;
      lastError = e.message;
      if (!silent) notifyListeners();
    }
  }

  Future<ScreenContextSnapshot?> captureForDebug() async =>
      _screen.captureForDebug();

  bool _mayCapture() =>
      !_disposed && screenUploadEnabled && _foreground() && _restored();

  bool _live(int generation, String token, BackendClient backend) {
    return !_disposed &&
        generation == _generation &&
        _token()?.trim() == token &&
        identical(_backend(), backend);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _started = false;
    stop();
    super.dispose();
  }
}
