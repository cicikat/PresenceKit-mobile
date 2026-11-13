import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/screen_context.dart';
import '../services/backend_client.dart';
import '../services/device_services.dart';
import '../services/platform_settings_channel.dart';
import '../models/session_scope.dart';

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
    String? Function()? character,
    bool Function()? restored,
    bool Function()? foreground,
  }) : _device = device,
       _screen = screen,
       _backend = backend,
       _token = token,
       _character = character,
       _restored = restored ?? _alwaysTrue,
       _foreground = foreground ?? _alwaysTrue;

  static bool _alwaysTrue() => true;

  final DeviceControlService _device;
  final ScreenSensorService _screen;
  final BackendClient Function() _backend;
  final String? Function() _token;
  final bool Function() _restored;
  final bool Function() _foreground;
  final String? Function()? _character;
  PresenceSessionGrant? _ambientGrant;
  bool _ambientBusy = false;
  Timer? _ambientTimer;
  Timer? _screenTimer;
  Timer? _sensorTimer;
  bool screenUploadEnabled = false;
  String? lastError;
  bool _disposed = false;
  int _generation = 0;
  bool _started = false;
  @visibleForTesting
  bool get hasPeriodicTimers => _screenTimer != null || _sensorTimer != null;

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
    if (PlatformSettingsChannel.available && _character != null) {
      unawaited(pushAmbient());
      _ambientTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(pushAmbient()),
      );
    }
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
    _ambientTimer?.cancel();
    _ambientTimer = null;
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
    _ambientGrant = null;
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

  Future<void> pushAmbient({String? cleared}) async {
    final token = _token()?.trim();
    final character = _character?.call();
    if (!PlatformSettingsChannel.available ||
        token == null ||
        token.isEmpty ||
        character == null ||
        _disposed ||
        (cleared == null && !_foreground())) {
      return;
    }
    if (_ambientBusy && cleared == null) return;
    final generation = _generation;
    final backend = _backend();
    final observedAt = DateTime.now().millisecondsSinceEpoch / 1000;
    if (cleared == null) _ambientBusy = true;
    try {
      final observation = cleared == null
          ? await PlatformSettingsChannel.deliveryCall<Map>('sampleAmbient')
          : {
              cleared: {'status': 'unavailable', 'observed_at': observedAt},
            };
      if (observation == null || observation.isEmpty) return;
      var grant = _ambientGrant;
      if (grant == null || grant.charId != character) {
        grant = await backend.createPresenceSession(
          token: token,
          charId: character,
        );
      }
      if (!_live(generation, token, backend) ||
          _character?.call() != character ||
          (cleared == null && !_foreground())) {
        return;
      }
      _ambientGrant = grant;
      await backend.pushAmbient(
        token: token,
        sessionId: grant.sessionId,
        observation: Map<String, dynamic>.from(observation),
      );
    } catch (_) {
      if (_live(generation, token, backend)) _ambientGrant = null;
    } finally {
      if (cleared == null) _ambientBusy = false;
    }
  }

  Future<void> pushSensorData() async {
    final token = _token()?.trim();
    if (token == null || token.isEmpty) return;
    final generation = _generation;
    final backend = _backend();
    try {
      final battery = await _screen.readBatteryStatus();
      // Skip steps without permission; do not prompt from timers/start.
      final steps = await _screen.hasActivityPermission()
          ? await _screen.readTodaySteps()
          : null;
      if (!_live(generation, token, backend)) return;
      // Charging alone is worth sending: the character can react to the phone
      // being plugged in even when the percentage could not be read.
      if (battery.isEmpty && steps == null) return;
      await backend.pushSensorData(
        token: token,
        battery: battery.percent,
        charging: battery.charging,
        plugged: battery.plugged,
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
