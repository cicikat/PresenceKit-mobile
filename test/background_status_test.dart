import 'package:flutter_test/flutter_test.dart';
import 'package:yexuan_memery/models/background_status.dart';

void main() {
  group('RelayConnectionStatus.connected', () {
    test('is true while a connected relay heartbeat is fresh', () {
      final status = RelayConnectionStatus(
        connectionStatus: 'connected',
        lastHeartbeatAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );

      expect(status.connected, isTrue);
    });

    test('is false after the heartbeat is older than three minutes', () {
      final status = RelayConnectionStatus(
        connectionStatus: 'connected',
        lastHeartbeatAt: DateTime.now().subtract(const Duration(minutes: 4)),
      );

      expect(status.connected, isFalse);
    });

    test('is false when a connected relay has no heartbeat', () {
      const status = RelayConnectionStatus(connectionStatus: 'connected');

      expect(status.connected, isFalse);
    });

    test('is false when the relay status is not connected', () {
      final status = RelayConnectionStatus(
        connectionStatus: 'reconnecting',
        lastHeartbeatAt: DateTime.now(),
      );

      expect(status.connected, isFalse);
    });
  });
}
