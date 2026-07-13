import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/screen_context.dart';
import '../services/backend_client.dart';
import '../services/device_services.dart';

/// Coordinates local device capabilities; UI decides how to present [lastError].
class DeviceController extends ChangeNotifier {
  DeviceController({
    required DeviceControlService device,
    required VoiceService voice,
    required ScreenSensorService screen,
    required BackendClient Function() backend,
    required String? Function() token,
  }) : _device = device,
       _voice = voice,
       _screen = screen,
       _backend = backend,
       _token = token;

  final DeviceControlService _device;
  final VoiceService _voice;
  final ScreenSensorService _screen;
  final BackendClient Function() _backend;
  final String? Function() _token;
  Timer? _screenTimer;
  Timer? _sensorTimer;
  bool screenUploadEnabled = false;
  String? lastError;

  Future<void> restore() async {
    screenUploadEnabled = await _screen.loadUploadEnabled();
    notifyListeners();
  }

  Future<void> setScreenUploadEnabled(bool value) async {
    await _screen.saveUploadEnabled(value);
    screenUploadEnabled = value;
    notifyListeners();
  }

  Future<bool> lockScreen() => _device.lockScreen();
  Future<bool> openShoppingApp(String target) =>
      _device.openShoppingApp(target);
  Future<bool> showOrderBubble(String target) =>
      _device.showOrderBubble(target);
  Future<void> requestAccessibilityPermission() =>
      _device.requestAccessibilityPermission();
  Future<bool> isAccessibilityEnabled() => _device.isAccessibilityEnabled();
  Future<bool> startVoiceRecording() async {
    if (!await _voice.hasPermission()) {
      await _voice.requestPermission();
      if (!await _voice.hasPermission()) return false;
    }
    return _voice.startRecording();
  }

  Future<void> cancelVoiceRecording() => _voice.cancelRecording();
  Future<String?> stopVoiceRecordingAndTranscribe() async {
    final path = await _voice.stopRecording();
    final token = _token()?.trim();
    if (path == null || token == null || token.isEmpty) return null;
    try {
      return await _backend().transcribeAudio(filePath: path, token: token);
    } on BackendException catch (e) {
      lastError = e.message;
      notifyListeners();
      return null;
    }
  }

  void start() {
    stop();
    unawaited(pushScreenContext(silent: true));
    unawaited(pushSensorData());
    _screenTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => pushScreenContext(silent: true),
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

  Future<void> pushSensorData() async {
    final token = _token()?.trim();
    if (token == null || token.isEmpty) return;
    try {
      final battery = await _screen.readBatteryPercent();
      int? steps;
      if (await _screen.hasActivityPermission()) {
        steps = await _screen.readTodaySteps();
      } else {
        await _screen.requestActivityPermission();
      }
      if (battery == null && steps == null) return;
      await _backend().pushSensorData(
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
    final snapshot = await _screen.captureForUpload();
    if (snapshot == null || snapshot.isBlocked) return;
    try {
      if (snapshot.packageName == 'com.presencekit.mobile') {
        await _backend().pushSelfFocusSignal(token: token);
        return;
      }
      final allowed = await _screen.loadAllowedPackages();
      await _backend().pushScreenContext(
        snapshot,
        token: token,
        allowTextUpload: allowed.contains(snapshot.packageName),
      );
      lastError = null;
    } on BackendException catch (e) {
      lastError = e.message;
      if (!silent) notifyListeners();
    }
  }

  Future<void> saveAllowedPackages(Set<String> values) =>
      _screen.saveAllowedPackages(values);

  Future<void> pushSnapshot(
    ScreenContextSnapshot snapshot, {
    bool silent = false,
  }) async {
    if (!screenUploadEnabled || snapshot.isBlocked) return;
    final token = _token()?.trim();
    if (token == null || token.isEmpty) return;
    try {
      final allowed = await _screen.loadAllowedPackages();
      await _backend().pushScreenContext(
        snapshot,
        token: token,
        allowTextUpload: allowed.contains(snapshot.packageName),
      );
      lastError = null;
      if (!silent) notifyListeners();
    } on BackendException catch (e) {
      lastError = e.message;
      if (!silent) notifyListeners();
    }
  }

  Future<ScreenContextSnapshot?> captureForDebug() async =>
      _screen.captureForDebug();
  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
