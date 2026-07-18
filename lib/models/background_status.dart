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

/// 中继连接的单一展示状态机；左右两处 UI 必须都从这里派生，不得各自判断。
enum RelayDisplayStatus { unconfigured, connecting, connected, stopped, error }

class RelayConnectionStatus {
  static const heartbeatFreshnessThreshold = Duration(minutes: 3);

  /// SSE 重连是瞬时抖动的常态（网络切换、后端重启几秒内自愈）；在这个窗口内
  /// 仍沿用上一次的"已连接"展示，避免 reconnecting 每次重试都在 UI 上闪烁。
  static const reconnectJitterDebounce = Duration(seconds: 20);

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

  bool _heartbeatWithin(Duration window) =>
      lastHeartbeatAt != null &&
      DateTime.now().difference(lastHeartbeatAt!) < window;

  /// 统一状态机：未配置 / 连接中 / 已连接 / 已停止 / 错误。
  /// 所有展示中继连接状态的 UI（标签文字、状态指示灯）都必须读这一个值，
  /// 不得各自用 connectionStatus 字符串或心跳时间单独派生。
  RelayDisplayStatus get displayStatus {
    switch (connectionStatus) {
      case 'stopped':
        return RelayDisplayStatus.stopped;
      case 'connected':
        return _heartbeatWithin(heartbeatFreshnessThreshold)
            ? RelayDisplayStatus.connected
            : RelayDisplayStatus.error;
      case 'connecting':
      case 'reconnecting':
        // 短暂重连抖动：心跳仍在去抖窗口内就继续显示"已连接"，不回落。
        return _heartbeatWithin(reconnectJitterDebounce)
            ? RelayDisplayStatus.connected
            : RelayDisplayStatus.connecting;
      case 'fallback_poll':
      case 'timeout':
        return RelayDisplayStatus.error;
      default:
        return RelayDisplayStatus.unconfigured;
    }
  }
}

/// canDrawOverlays() 为 true 不代表 addView 一定成功——部分厂商 ROM 会在
/// 系统层面额外拦截，只能在实际弹窗时捕获异常并记录，供设置页显示真实状态。
class OverlayErrorStatus {
  const OverlayErrorStatus({this.lastError, this.lastErrorAt});

  factory OverlayErrorStatus.fromPlatform(Map<dynamic, dynamic>? raw) {
    final error = raw?['lastOverlayError']?.toString().trim();
    final timestamp = raw?['lastOverlayErrorAt'];
    return OverlayErrorStatus(
      lastError: error == null || error.isEmpty ? null : error,
      lastErrorAt: timestamp is int && timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null,
    );
  }

  final String? lastError;
  final DateTime? lastErrorAt;
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
