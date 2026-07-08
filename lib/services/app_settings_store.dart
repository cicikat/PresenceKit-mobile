import 'dart:io';

import 'package:flutter/services.dart';

import '../models/background_status.dart';
import '../models/screen_context.dart';

class AppSettingsStore {
  static const MethodChannel _channel = MethodChannel('presence_mobile/settings');

  const AppSettingsStore();

  Future<String?> loadBackendBaseUrl() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getBackendBaseUrl');
    } on PlatformException {
      return null;
    }
  }

  Future<void> saveBackendBaseUrl(String value) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setBackendBaseUrl', {'value': value});
    } on PlatformException {
      // The app can still use the runtime value even if persistence fails.
    }
  }

  Future<String?> loadAdminToken() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getAdminToken');
    } on PlatformException {
      return null;
    }
  }

  Future<void> saveAdminToken(String value) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setAdminToken', {'value': value});
  }

  Future<String?> loadOwnerUserId() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getOwnerUserId');
    } on PlatformException {
      return null;
    }
  }

  Future<void> saveOwnerUserId(String value) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setOwnerUserId', {'value': value});
  }

  Future<Set<String>> loadTrustedCleartextOrigins() async {
    if (!Platform.isAndroid) return const {};
    try {
      final values = await _channel.invokeMethod<List<dynamic>>(
        'getTrustedCleartextOrigins',
      );
      return values?.map((v) => v.toString()).toSet() ?? const {};
    } on PlatformException {
      return const {};
    }
  }

  Future<bool> addTrustedCleartextOrigin(String value) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('addTrustedCleartextOrigin', {
            'value': value,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isAllowedBaseUrl(String raw) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isAllowedBaseUrl', {
            'value': raw,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> normalizeOrigin(String raw) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String?>('normalizeOrigin', {
        'value': raw,
      });
    } on PlatformException {
      return null;
    }
  }

  Future<bool> isConfirmablePrivateCleartextOrigin(String origin) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'isConfirmablePrivateCleartextOrigin',
            {'value': origin},
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> loadScreenContextUploadEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'getScreenContextUploadEnabled',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> saveScreenContextUploadEnabled(bool value) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setScreenContextUploadEnabled', {
      'value': value,
    });
  }

  Future<Set<String>> loadScreenTextUploadAllowedPackages() async {
    if (!Platform.isAndroid) return const {};
    try {
      final values = await _channel.invokeMethod<List<dynamic>>(
        'getScreenTextUploadAllowedPackages',
      );
      return values
              ?.map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toSet() ??
          const {};
    } on PlatformException {
      return const {};
    }
  }

  Future<void> saveScreenTextUploadAllowedPackages(Set<String> values) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setScreenTextUploadAllowedPackages', {
      'values': values.toList(growable: false),
    });
  }

  Future<List<ScreenTextUploadAppOption>>
  loadScreenTextUploadAppOptions() async {
    if (!Platform.isAndroid) return const [];
    try {
      final values = await _channel.invokeMethod<List<dynamic>>(
        'getScreenTextUploadAppOptions',
      );
      return values
              ?.whereType<Map<dynamic, dynamic>>()
              .map(ScreenTextUploadAppOption.fromPlatform)
              .where((option) => option.packageName.isNotEmpty)
              .toList(growable: false) ??
          const [];
    } on PlatformException {
      return const [];
    }
  }

  Future<String?> loadCustomThemePalette() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getCustomThemePalette');
    } on PlatformException {
      return null;
    }
  }

  Future<void> saveCustomThemePalette(String value) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setCustomThemePalette', {
        'value': value,
      });
    } on PlatformException {
      // A custom theme is cosmetic; keep the runtime theme even if persistence fails.
    }
  }

  Future<void> deleteCustomThemePalette() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('deleteCustomThemePalette');
    } on PlatformException {
      // Optional local theme; ignore failed delete attempts.
    }
  }

  Future<String?> loadProfileDisplayName() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getProfileDisplayName');
    } on PlatformException {
      return null;
    }
  }

  Future<void> saveProfileDisplayName(String value) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setProfileDisplayName', {
        'value': value,
      });
    } on PlatformException {
      // Local display names are cosmetic; failing to persist is non-fatal.
    }
  }

  Future<Uint8List?> pickProfileImage() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('pickProfileImage');
    } on PlatformException {
      return null;
    }
  }

  Future<PickedUploadFile?> pickUploadFile() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'pickUploadFile',
      );
      if (raw == null) return null;
      final bytes = raw['bytes'];
      if (bytes is! Uint8List || bytes.isEmpty) return null;
      final name = (raw['name'] ?? 'file').toString().trim();
      return PickedUploadFile(name: name.isEmpty ? 'file' : name, bytes: bytes);
    } on PlatformException {
      return null;
    }
  }

  Future<List<PickedUploadFile>> pickUploadImages() async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'pickUploadImages',
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((item) => Map<dynamic, dynamic>.from(item))
          .map((item) {
            final bytes = item['bytes'];
            if (bytes is! Uint8List || bytes.isEmpty) return null;
            final name = (item['name'] ?? 'image').toString().trim();
            return PickedUploadFile(
              name: name.isEmpty ? 'image' : name,
              bytes: bytes,
            );
          })
          .nonNulls
          .toList(growable: false);
    } on PlatformException {
      return const [];
    }
  }

  Future<Uint8List?> loadProfileAvatar() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('loadProfileAvatar');
    } on PlatformException {
      return null;
    }
  }

  Future<bool> saveProfileAvatar(Uint8List bytes) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('saveProfileAvatar', {
            'bytes': bytes,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> deleteProfileAvatar() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('deleteProfileAvatar');
    } on PlatformException {
      // Optional local avatar; ignore failed delete attempts.
    }
  }

  Future<bool> loadBackgroundNotificationsEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'getBackgroundNotificationsEnabled',
          ) ??
          true;
    } on PlatformException {
      return true;
    }
  }

  Future<void> saveBackgroundNotificationsEnabled(bool value) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setBackgroundNotificationsEnabled', {
        'value': value,
      });
    } on PlatformException {
      // Background notifications are optional; foreground polling still works.
    }
  }

  Future<void> startBackgroundNotifications() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('startBackgroundNotifications');
    } on PlatformException {
      // Ignore here; the app will reconnect when it returns to foreground.
    }
  }

  Future<void> saveSeenMobileMessageIds(List<String> ids) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setSeenMobileMessageIds', {'ids': ids});
  }

  Future<List<String>> loadSeenMobileMessageIds() async {
    if (!Platform.isAndroid) return const [];
    final values = await _channel.invokeMethod<List<dynamic>>(
      'getSeenMobileMessageIds',
    );
    return values?.map((value) => value.toString()).toList(growable: false) ??
        const [];
  }

  Future<int?> loadLastAckedMobileSeq() async {
    if (!Platform.isAndroid) return null;
    return await _channel.invokeMethod<int>('getLastAckedMobileSeq');
  }

  Future<void> saveLastAckedMobileSeq(int value) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setLastAckedMobileSeq', {
      'value': value,
    });
  }

  Future<bool> debugBackgroundDelivery({
    required String content,
    String? behaviorJson,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('debugBackgroundDelivery', {
            'content': content,
            'behavior': behaviorJson ?? '',
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> stopBackgroundNotifications() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopBackgroundNotifications');
    } on PlatformException {
      // Ignore here; stopping is best-effort across Android versions.
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('areNotificationsEnabled') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestNotificationPermission');
    } on PlatformException {
      // The user can still open Android notification settings manually.
    }
  }

  Future<bool> isBackgroundNotificationServiceRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'isBackgroundNotificationServiceRunning',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<BackgroundPollStatus> loadBackgroundPollStatus() async {
    if (!Platform.isAndroid) return const BackgroundPollStatus();
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getBackgroundPollStatus',
      );
      return BackgroundPollStatus.fromPlatform(raw);
    } on PlatformException {
      return const BackgroundPollStatus();
    }
  }

  Future<RelayConnectionStatus> loadRelayConnectionStatus() async {
    if (!Platform.isAndroid) return const RelayConnectionStatus();
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getRelayConnectionStatus',
      );
      return RelayConnectionStatus.fromPlatform(raw);
    } on PlatformException {
      return const RelayConnectionStatus();
    }
  }

  Future<NotificationGateStatus> loadNotificationGateStatus() async {
    if (!Platform.isAndroid) return const NotificationGateStatus();
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getNotificationGateStatus',
      );
      return NotificationGateStatus.fromPlatform(raw);
    } on PlatformException {
      return const NotificationGateStatus();
    }
  }

  Future<void> setNotificationTestMode(bool value) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setNotificationTestMode', {
        'value': value,
      });
    } on PlatformException {
      // Test mode is optional; keep normal notification gates on failure.
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } on PlatformException {
      // Some OEM builds only expose their own battery-management settings.
    }
  }

  Future<bool> canDrawOverlays() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestOverlayPermission');
    } on PlatformException {
      // The user can still open Android settings manually.
    }
  }

  Future<bool> showFloatingBubble() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('showFloatingBubble') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> showOrderBubble(String target) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('showOrderBubble', {
            'target': target,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> hideFloatingBubble() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('hideFloatingBubble');
    } on PlatformException {
      // Optional system overlay; ignore failures here.
    }
  }

  Future<bool> isDeviceAdminActive() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isDeviceAdminActive') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestDeviceAdmin() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestDeviceAdmin');
    } on PlatformException {
      // The user can still open Android settings manually.
    }
  }

  Future<bool> lockScreen() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('lockScreen') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'isAccessibilityServiceEnabled',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestAccessibilityPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestAccessibilityPermission');
    } on PlatformException {
      // The user can still open Android settings manually.
    }
  }

  Future<ScreenContextSnapshot?> captureScreenContext() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'captureScreenContext',
      );
      if (raw == null) return null;
      return ScreenContextSnapshot.fromPlatform(raw);
    } on PlatformException {
      return null;
    }
  }

  Future<ScreenContextSnapshot?> captureScreenContextForUpload() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'captureScreenContextForUpload',
      );
      if (raw == null) return null;
      return ScreenContextSnapshot.fromPlatform(raw);
    } on PlatformException {
      return null;
    }
  }

  Future<bool> openShoppingApp(String target) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openShoppingApp', {
            'target': target,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> loadRelayBaseUrl() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getRelayBaseUrl');
    } on PlatformException {
      return null;
    }
  }

  Future<void> saveRelayBaseUrl(String value) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setRelayBaseUrl', {'value': value});
  }

  Future<String?> loadRelayToken() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getRelayToken');
    } on PlatformException {
      return null;
    }
  }

  Future<void> saveRelayToken(String value) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setRelayToken', {'value': value});
  }

  Future<String?> loadRelayTopic() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getRelayTopic');
    } on PlatformException {
      return null;
    }
  }

  Future<void> saveRelayTopic(String value) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setRelayTopic', {'value': value});
  }
}
