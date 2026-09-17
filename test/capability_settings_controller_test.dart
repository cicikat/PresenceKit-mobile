import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/capability_settings_controller.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/controllers/device_controller.dart';
import 'package:presencekit_mobile/controllers/garden_controller.dart';
import 'package:presencekit_mobile/models/background_status.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Store extends AppSettingsStore {
  bool backgroundNotifications = true;
  bool stickerEnabled = false;
  bool autoPlayVoice = false;
  bool notificationsEnabled = true;
  bool overlays = true;
  bool accessibility = true;
  bool deviceAdmin = true;
  bool backgroundRunning = false;
  bool ignoringBattery = true;
  bool screenUpload = false;
  int notificationPermissionCalls = 0;
  int stopBackgroundCalls = 0;
  int overlayRequests = 0;
  bool? lastNotificationTestMode;

  @override
  Future<bool> loadBackgroundNotificationsEnabled() async =>
      backgroundNotifications;

  @override
  Future<void> saveBackgroundNotificationsEnabled(bool value) async {
    backgroundNotifications = value;
  }

  @override
  Future<bool> loadStickerEnabled() async => stickerEnabled;

  @override
  Future<void> saveStickerEnabled(bool value) async {
    stickerEnabled = value;
  }

  @override
  Future<bool> loadAutoPlayVoice() async => autoPlayVoice;

  @override
  Future<void> saveAutoPlayVoice(bool value) async {
    autoPlayVoice = value;
  }

  @override
  Future<bool> areNotificationsEnabled() async => notificationsEnabled;

  @override
  Future<void> requestNotificationPermission() async {
    notificationPermissionCalls += 1;
    notificationsEnabled = true;
  }

  @override
  Future<void> stopBackgroundNotifications() async {
    stopBackgroundCalls += 1;
  }

  @override
  Future<bool> canDrawOverlays() async => overlays;

  @override
  Future<void> requestOverlayPermission() async {
    overlayRequests += 1;
  }

  @override
  Future<bool> isAccessibilityServiceEnabled() async => accessibility;

  @override
  Future<bool> isDeviceAdminActive() async => deviceAdmin;

  @override
  Future<bool> isBackgroundNotificationServiceRunning() async =>
      backgroundRunning;

  @override
  Future<BackgroundPollStatus> loadBackgroundPollStatus() async =>
      const BackgroundPollStatus();

  @override
  Future<RelayConnectionStatus> loadRelayConnectionStatus() async =>
      const RelayConnectionStatus();

  @override
  Future<NotificationGateStatus> loadNotificationGateStatus() async =>
      const NotificationGateStatus();

  @override
  Future<OverlayErrorStatus> loadLastOverlayError() async =>
      const OverlayErrorStatus();

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => ignoringBattery;

  @override
  Future<bool> loadScreenContextUploadEnabled() async => screenUpload;

  @override
  Future<void> saveScreenContextUploadEnabled(bool value) async {
    screenUpload = value;
  }

  @override
  Future<void> setNotificationTestMode(bool value) async {
    lastNotificationTestMode = value;
  }
}

void main() {
  late _Store store;
  late CapabilitySettingsController controller;
  late DeviceController deviceController;
  late ChatController chat;
  late GardenController garden;

  setUp(() {
    store = _Store();
    final settings = SettingsStore(store);
    deviceController = DeviceController(
      device: DeviceControlService(store),
      screen: ScreenSensorService(store),
      backend: () =>
          BackendClient(baseUrl: 'http://127.0.0.1:8080', settingsStore: store),
      token: () => 'token',
    );
    chat = ChatController(
      backend: () =>
          BackendClient(baseUrl: 'http://127.0.0.1:8080', settingsStore: store),
      token: () => 'token',
      settings: settings,
      relay: RelayStatusService(store),
    );
    garden = GardenController(
      backend: () =>
          BackendClient(baseUrl: 'http://127.0.0.1:8080', settingsStore: store),
      token: () => 'token',
    );
    controller = CapabilitySettingsController(
      settings: settings,
      device: DeviceControlService(store),
      deviceController: deviceController,
      relay: RelayStatusService(store),
      chat: () => chat,
      garden: () => garden,
      backendBaseUrl: () => 'http://127.0.0.1:8080',
      extraBackendError: () => 'node missing',
    );
  });

  tearDown(() {
    controller.dispose();
    deviceController.dispose();
    chat.dispose();
    garden.dispose();
  });

  test('restore and toggles persist without moving device timers', () async {
    store.backgroundNotifications = false;
    store.stickerEnabled = true;
    store.autoPlayVoice = true;
    await controller.restore();
    expect(controller.backgroundNotifications, isFalse);
    expect(controller.stickerEnabled, isTrue);
    expect(controller.autoPlayVoice, isTrue);

    await controller.setBackgroundNotifications(true);
    expect(store.backgroundNotifications, isTrue);
    expect(store.notificationPermissionCalls, 1);
    await controller.setBackgroundNotifications(false);
    expect(store.stopBackgroundCalls, 1);

    await controller.setStickerEnabled(false);
    await controller.setAutoPlayVoice(false);
    expect(store.stickerEnabled, isFalse);
    expect(store.autoPlayVoice, isFalse);

    await controller.setNotificationTestMode(true);
    expect(store.lastNotificationTestMode, isTrue);
  });

  test(
    'capability snapshot reads existing controllers and device flags',
    () async {
      store.notificationsEnabled = false;
      store.overlays = false;
      store.accessibility = false;
      chat.historyLoaded = true;
      chat.historyError = 'history down';
      garden.state = null;
      await deviceController.restore();

      final status = await controller.loadStatus();
      expect(status.notificationsEnabled, isFalse);
      expect(status.overlayEnabled, isFalse);
      expect(status.accessibilityEnabled, isFalse);
      expect(status.backendBaseUrl, 'http://127.0.0.1:8080');
      expect(status.backendReachable, isTrue);
      expect(status.backendError, 'node missing');
      expect(status.screenContextUploadEnabled, isFalse);
    },
  );
}
