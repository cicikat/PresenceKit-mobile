import 'background_status.dart';
import 'screen_context.dart';

class CapabilityStatus {
  const CapabilityStatus({
    required this.notificationsEnabled,
    required this.overlayEnabled,
    required this.accessibilityEnabled,
    required this.deviceAdminEnabled,
    required this.backgroundNotificationsEnabled,
    required this.backgroundServiceRunning,
    required this.backgroundPollStatus,
    required this.relayConnectionStatus,
    required this.notificationGateStatus,
    required this.overlayErrorStatus,
    required this.ignoringBatteryOptimizations,
    required this.screenContextUploadEnabled,
    required this.screenTextUploadAllowedPackages,
    required this.screenTextUploadAppOptions,
    required this.backendBaseUrl,
    required this.backendReachable,
    required this.backendBusy,
    required this.backendError,
  });

  final bool notificationsEnabled;
  final bool overlayEnabled;
  final bool accessibilityEnabled;
  final bool deviceAdminEnabled;
  final bool backgroundNotificationsEnabled;
  final bool backgroundServiceRunning;
  final BackgroundPollStatus backgroundPollStatus;
  final RelayConnectionStatus relayConnectionStatus;
  final NotificationGateStatus notificationGateStatus;
  final OverlayErrorStatus overlayErrorStatus;
  final bool ignoringBatteryOptimizations;
  final bool screenContextUploadEnabled;
  final Set<String> screenTextUploadAllowedPackages;
  final List<ScreenTextUploadAppOption> screenTextUploadAppOptions;
  final String backendBaseUrl;
  final bool backendReachable;
  final bool backendBusy;
  final String? backendError;
}
