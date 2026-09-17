import 'package:flutter/foundation.dart';

import '../models/background_status.dart';
import '../models/capability_status.dart';
import '../services/device_services.dart';
import 'chat_controller.dart';
import 'device_controller.dart';
import 'garden_controller.dart';

/// Local capability flags and the capability-sheet snapshot.
///
/// Device timers, lock/overlay/accessibility actions, and screen upload stay
/// on [DeviceController]. This object only holds settings-page flags and
/// assembles a read model from existing controllers.
class CapabilitySettingsController extends ChangeNotifier {
  CapabilitySettingsController({
    required SettingsStore settings,
    required DeviceControlService device,
    required DeviceController deviceController,
    required RelayStatusService relay,
    required ChatController Function() chat,
    required GardenController Function() garden,
    required String Function() backendBaseUrl,
    required String? Function() extraBackendError,
  }) : _settings = settings,
       _device = device,
       _deviceController = deviceController,
       _relay = relay,
       _chat = chat,
       _garden = garden,
       _backendBaseUrl = backendBaseUrl,
       _extraBackendError = extraBackendError;

  final SettingsStore _settings;
  final DeviceControlService _device;
  final DeviceController _deviceController;
  final RelayStatusService _relay;
  final ChatController Function() _chat;
  final GardenController Function() _garden;
  final String Function() _backendBaseUrl;
  final String? Function() _extraBackendError;

  bool _disposed = false;
  bool backgroundNotifications = true;
  bool stickerEnabled = false;
  bool autoPlayVoice = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> restore() async {
    final results = await Future.wait<dynamic>([
      _settings.loadBackgroundNotificationsEnabled(),
      _settings.loadStickerEnabled(),
      _settings.loadAutoPlayVoice(),
    ]);
    backgroundNotifications = results[0] as bool;
    stickerEnabled = results[1] as bool;
    autoPlayVoice = results[2] as bool;
    notifyListeners();
  }

  Future<void> setBackgroundNotifications(bool enabled) async {
    backgroundNotifications = enabled;
    notifyListeners();
    await _settings.saveBackgroundNotificationsEnabled(enabled);
    if (enabled) {
      await _device.requestNotificationPermission();
    } else {
      await _device.stopBackgroundNotifications();
    }
  }

  Future<void> setStickerEnabled(bool enabled) async {
    stickerEnabled = enabled;
    notifyListeners();
    await _settings.saveStickerEnabled(enabled);
  }

  Future<void> setAutoPlayVoice(bool enabled) async {
    autoPlayVoice = enabled;
    notifyListeners();
    await _settings.saveAutoPlayVoice(enabled);
  }

  Future<void> setScreenContextUploadEnabled(bool enabled) async {
    await _deviceController.setScreenUploadEnabled(enabled);
    if (enabled) {
      await _deviceController.pushScreenContext(silent: true);
    }
  }

  Future<void> setNotificationTestMode(bool enabled) =>
      _device.setNotificationTestMode(enabled);

  Future<CapabilityStatus> loadStatus() async {
    final results = await Future.wait<dynamic>([
      _device.areNotificationsEnabled(),
      _device.canDrawOverlays(),
      _deviceController.isAccessibilityEnabled(),
      _device.isDeviceAdminActive(),
      _deviceController.hasActivityPermission(),
      _relay.isBackgroundServiceRunning(),
      _relay.loadBackgroundPollStatus(),
      _relay.loadConnectionStatus(),
      _relay.loadNotificationGateStatus(),
      _device.isIgnoringBatteryOptimizations(),
      _device.loadLastOverlayError(),
    ]);
    final chat = _chat();
    final garden = _garden();
    return CapabilityStatus(
      notificationsEnabled: results[0] as bool,
      overlayEnabled: results[1] as bool,
      accessibilityEnabled: results[2] as bool,
      deviceAdminEnabled: results[3] as bool,
      activityRecognitionEnabled: results[4] as bool,
      backgroundNotificationsEnabled: backgroundNotifications,
      backgroundServiceRunning: results[5] as bool,
      backgroundPollStatus: results[6] as BackgroundPollStatus,
      relayConnectionStatus: results[7] as RelayConnectionStatus,
      notificationGateStatus: results[8] as NotificationGateStatus,
      overlayErrorStatus: results[10] as OverlayErrorStatus,
      ignoringBatteryOptimizations: results[9] as bool,
      screenContextUploadEnabled: _deviceController.screenUploadEnabled,
      backendBaseUrl: _backendBaseUrl(),
      backendReachable:
          chat.mobileError == null &&
          (chat.mobileActive || chat.historyLoaded || garden.state != null),
      backendBusy: chat.pollingMobile || chat.loadingHistory || garden.loading,
      backendError:
          chat.mobileError ?? _extraBackendError() ?? chat.historyError,
    );
  }
}
