import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/models/background_status.dart';

void main() {
  group('RelayConnectionStatus.displayStatus', () {
    test('is connected while a connected relay heartbeat is fresh', () {
      final status = RelayConnectionStatus(
        connectionStatus: 'connected',
        lastHeartbeatAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );

      expect(status.displayStatus, RelayDisplayStatus.connected);
    });

    test('is error once a connected heartbeat goes stale past three minutes', () {
      final status = RelayConnectionStatus(
        connectionStatus: 'connected',
        lastHeartbeatAt: DateTime.now().subtract(const Duration(minutes: 4)),
      );

      expect(status.displayStatus, RelayDisplayStatus.error);
    });

    test('is error when a connected relay has no heartbeat', () {
      const status = RelayConnectionStatus(connectionStatus: 'connected');

      expect(status.displayStatus, RelayDisplayStatus.error);
    });

    test(
      'debounces a transient reconnect: still connected if heartbeat is recent',
      () {
        final status = RelayConnectionStatus(
          connectionStatus: 'reconnecting',
          lastHeartbeatAt: DateTime.now(),
        );

        expect(status.displayStatus, RelayDisplayStatus.connected);
      },
    );

    test(
      'falls back to connecting once the reconnect outlasts the debounce window',
      () {
        final status = RelayConnectionStatus(
          connectionStatus: 'reconnecting',
          lastHeartbeatAt: DateTime.now().subtract(const Duration(seconds: 30)),
        );

        expect(status.displayStatus, RelayDisplayStatus.connecting);
      },
    );

    test('is connecting when there is no prior heartbeat at all', () {
      const status = RelayConnectionStatus(connectionStatus: 'connecting');

      expect(status.displayStatus, RelayDisplayStatus.connecting);
    });

    test('maps fallback_poll and timeout to error', () {
      const fallback = RelayConnectionStatus(connectionStatus: 'fallback_poll');
      const timeout = RelayConnectionStatus(connectionStatus: 'timeout');

      expect(fallback.displayStatus, RelayDisplayStatus.error);
      expect(timeout.displayStatus, RelayDisplayStatus.error);
    });

    test('maps stopped and unconfigured directly', () {
      const stopped = RelayConnectionStatus(connectionStatus: 'stopped');
      const unconfigured = RelayConnectionStatus();

      expect(stopped.displayStatus, RelayDisplayStatus.stopped);
      expect(unconfigured.displayStatus, RelayDisplayStatus.unconfigured);
    });
  });
}
