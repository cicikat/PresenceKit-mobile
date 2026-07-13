import 'dart:typed_data';

import '../models/background_status.dart';
import '../models/screen_context.dart';
import 'app_settings_store.dart';

/// Domain facade for persisted app preferences and identity fields.
class SettingsStore {
  const SettingsStore(this._store);
  final AppSettingsStore _store;

  Future<String?> loadBackendBaseUrl() => _store.loadBackendBaseUrl();
  Future<void> saveBackendBaseUrl(String value) =>
      _store.saveBackendBaseUrl(value);
  Future<String?> loadToken() => _store.loadAdminToken();
  Future<void> saveToken(String value) => _store.saveAdminToken(value);
  Future<String?> loadOwnerUserId() => _store.loadOwnerUserId();
  Future<void> saveOwnerUserId(String value) => _store.saveOwnerUserId(value);
  Future<String?> loadProfileName() => _store.loadProfileDisplayName();
  Future<void> saveProfileName(String value) =>
      _store.saveProfileDisplayName(value);
  Future<Uint8List?> loadAvatar() => _store.loadProfileAvatar();
  Future<bool> saveAvatar(Uint8List value) => _store.saveProfileAvatar(value);
  Future<void> deleteAvatar() => _store.deleteProfileAvatar();

  Future<bool> loadBackgroundNotificationsEnabled() =>
      _store.loadBackgroundNotificationsEnabled();
  Future<void> saveBackgroundNotificationsEnabled(bool value) =>
      _store.saveBackgroundNotificationsEnabled(value);

  Future<List<String>> loadSeenMobileMessageIds() =>
      _store.loadSeenMobileMessageIds();
  Future<void> saveSeenMobileMessageIds(List<String> ids) =>
      _store.saveSeenMobileMessageIds(ids);
  Future<int?> loadLastAckedMobileSeq() => _store.loadLastAckedMobileSeq();
  Future<void> saveLastAckedMobileSeq(int value) =>
      _store.saveLastAckedMobileSeq(value);
  Future<String?> loadCustomThemePalette() => _store.loadCustomThemePalette();
  Future<void> saveCustomThemePalette(String value) =>
      _store.saveCustomThemePalette(value);
  Future<void> deleteCustomThemePalette() => _store.deleteCustomThemePalette();
  Future<Uint8List?> pickProfileImage() => _store.pickProfileImage();
  Future<PickedUploadFile?> pickUploadFile() => _store.pickUploadFile();
  Future<List<PickedUploadFile>> pickUploadImages() =>
      _store.pickUploadImages();
}

class VoiceService {
  const VoiceService(this._store);
  final AppSettingsStore _store;
  Future<bool> hasPermission() => _store.hasRecordAudioPermission();
  Future<void> requestPermission() => _store.requestRecordAudioPermission();
  Future<bool> startRecording() => _store.startVoiceRecording();
  Future<String?> stopRecording() => _store.stopVoiceRecording();
  Future<void> cancelRecording() => _store.cancelVoiceRecording();
}

class DeviceControlService {
  const DeviceControlService(this._store);
  final AppSettingsStore _store;
  Future<bool> canDrawOverlays() => _store.canDrawOverlays();
  Future<void> requestOverlayPermission() => _store.requestOverlayPermission();
  Future<bool> isDeviceAdminActive() => _store.isDeviceAdminActive();
  Future<void> requestDeviceAdmin() => _store.requestDeviceAdmin();
  Future<bool> lockScreen() => _store.lockScreen();
  Future<bool> isAccessibilityEnabled() =>
      _store.isAccessibilityServiceEnabled();
  Future<void> requestAccessibilityPermission() =>
      _store.requestAccessibilityPermission();
  Future<bool> openShoppingApp(String target) => _store.openShoppingApp(target);
  Future<bool> showOrderBubble(String target) => _store.showOrderBubble(target);
  Future<bool> areNotificationsEnabled() => _store.areNotificationsEnabled();
  Future<void> requestNotificationPermission() =>
      _store.requestNotificationPermission();
  Future<bool> isIgnoringBatteryOptimizations() =>
      _store.isIgnoringBatteryOptimizations();
  Future<void> requestIgnoreBatteryOptimizations() =>
      _store.requestIgnoreBatteryOptimizations();
  Future<void> stopBackgroundNotifications() =>
      _store.stopBackgroundNotifications();
  Future<bool> debugBackgroundDelivery({
    required String content,
    String? behaviorJson,
  }) => _store.debugBackgroundDelivery(
    content: content,
    behaviorJson: behaviorJson,
  );
  Future<void> setNotificationTestMode(bool value) =>
      _store.setNotificationTestMode(value);
}

class ScreenSensorService {
  const ScreenSensorService(this._store);
  final AppSettingsStore _store;
  Future<bool> loadUploadEnabled() => _store.loadScreenContextUploadEnabled();
  Future<void> saveUploadEnabled(bool value) =>
      _store.saveScreenContextUploadEnabled(value);
  Future<ScreenContextSnapshot?> captureForUpload() =>
      _store.captureScreenContextForUpload();
  Future<ScreenContextSnapshot?> captureForDebug() =>
      _store.captureScreenContext();
  Future<Set<String>> loadAllowedPackages() =>
      _store.loadScreenTextUploadAllowedPackages();

  Future<void> saveAllowedPackages(Set<String> values) =>
      _store.saveScreenTextUploadAllowedPackages(values);
  Future<List<ScreenTextUploadAppOption>> loadAppOptions() =>
      _store.loadScreenTextUploadAppOptions();

  Future<int?> readBatteryPercent() => _store.readBatteryPercent();
  Future<bool> hasActivityPermission() =>
      _store.hasActivityRecognitionPermission();
  Future<void> requestActivityPermission() =>
      _store.requestActivityRecognitionPermission();
  Future<int?> readTodaySteps() => _store.readTodaySteps();
}

class RelayStatusService {
  const RelayStatusService(this._store);
  final AppSettingsStore _store;
  Future<RelayConnectionStatus> loadConnectionStatus() =>
      _store.loadRelayConnectionStatus();
  Future<BackgroundPollStatus> loadBackgroundPollStatus() =>
      _store.loadBackgroundPollStatus();
  Future<NotificationGateStatus> loadNotificationGateStatus() =>
      _store.loadNotificationGateStatus();
  Future<bool> isBackgroundServiceRunning() =>
      _store.isBackgroundNotificationServiceRunning();
  Future<String?> loadBaseUrl() => _store.loadRelayBaseUrl();
  Future<void> saveBaseUrl(String value) => _store.saveRelayBaseUrl(value);
  Future<String?> loadToken() => _store.loadRelayToken();
  Future<void> saveToken(String value) => _store.saveRelayToken(value);
  Future<String?> loadTopic() => _store.loadRelayTopic();
  Future<void> saveTopic(String value) => _store.saveRelayTopic(value);
}
