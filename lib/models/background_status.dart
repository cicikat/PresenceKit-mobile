class BackgroundPollStatus {
  const BackgroundPollStatus({this.lastPollAt, this.lastError});

  factory BackgroundPollStatus.fromPlatform(Map<dynamic, dynamic>? raw) {
    final timestamp = raw?['lastBackgroundPollAt'];
    final error = raw?['lastBackgroundError']?.toString().trim();
    return BackgroundPollStatus(
      lastPollAt: timestamp is int && timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null,
      lastError: error == null || error.isEmpty ? null : error,
    );
  }

  final DateTime? lastPollAt;
  final String? lastError;
}

class RelayConnectionStatus {
  static const heartbeatFreshnessThreshold = Duration(minutes: 3);

  const RelayConnectionStatus({
    this.connectionStatus = 'unconfigured',
    this.lastDeliveredAt,
    this.lastHeartbeatAt,
    this.lastError,
  });

  factory RelayConnectionStatus.fromPlatform(Map<dynamic, dynamic>? raw) {
    DateTime? parseTimestamp(dynamic value) => value is int && value > 0
        ? DateTime.fromMillisecondsSinceEpoch(value)
        : null;
    final error = raw?['lastError']?.toString().trim();
    return RelayConnectionStatus(
      connectionStatus:
          raw?['connectionStatus']?.toString().trim().isNotEmpty == true
          ? raw!['connectionStatus'].toString().trim()
          : 'unconfigured',
      lastDeliveredAt: parseTimestamp(raw?['lastDeliveredAt']),
      lastHeartbeatAt: parseTimestamp(raw?['lastHeartbeatAt']),
      lastError: error == null || error.isEmpty ? null : error,
    );
  }

  final String connectionStatus;
  final DateTime? lastDeliveredAt;
  final DateTime? lastHeartbeatAt;
  final String? lastError;

  bool get connected =>
      connectionStatus == 'connected' &&
      lastHeartbeatAt != null &&
      DateTime.now().difference(lastHeartbeatAt!) < heartbeatFreshnessThreshold;
}

class NotificationGateStatus {
  const NotificationGateStatus({
    this.suppressedCount = 0,
    this.lastSuppressReason,
    this.testModeEnabled = false,
  });

  factory NotificationGateStatus.fromPlatform(Map<dynamic, dynamic>? raw) {
    final count = raw?['suppressedCount'];
    final reason = raw?['lastSuppressReason']?.toString().trim();
    return NotificationGateStatus(
      suppressedCount: count is int && count > 0 ? count : 0,
      lastSuppressReason: reason == null || reason.isEmpty ? null : reason,
      testModeEnabled: raw?['testModeEnabled'] == true,
    );
  }

  final int suppressedCount;
  final String? lastSuppressReason;
  final bool testModeEnabled;
}
