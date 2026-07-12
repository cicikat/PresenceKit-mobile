import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('background service status queries the live service lifecycle flag', () {
    final activitySource = File(
      'android/app/src/main/kotlin/com/example/yexuan_memery/MainActivity.kt',
    ).readAsStringSync();
    final serviceSource = File(
      'android/app/src/main/kotlin/com/example/yexuan_memery/MobileNotificationService.kt',
    ).readAsStringSync();

    expect(
      activitySource,
      contains('result.success(MobileNotificationService.isServiceRunning)'),
    );
    expect(
      activitySource,
      isNot(contains('result.success(prefs.getBoolean("backgroundNotificationServiceRunning"'))),
    );
    expect(serviceSource, contains('var isServiceRunning: Boolean = false'));
    expect(serviceSource, contains('isServiceRunning = true'));
    expect(serviceSource, contains('isServiceRunning = false'));
  });

  final serviceSource = File(
    'android/app/src/main/kotlin/com/example/yexuan_memery/'
    'MobileNotificationService.kt',
  ).readAsStringSync();

  test('relay event routes to poll instead of direct delivery', () {
    final signal = jsonEncode({
      'id': 'signal-contract-1',
      'seq': 42,
      'user_id': '10001',
      'timestamp': 1781280000,
      'signal': 'new_message',
    });
    final event = jsonEncode({'event': 'message', 'message': signal});
    final decoded =
        jsonDecode(
              (jsonDecode(event) as Map<String, dynamic>)['message'] as String,
            )
            as Map<String, dynamic>;

    expect(decoded, contains('signal'));
    expect(decoded, isNot(contains('content')));
    expect(serviceSource, contains('triggerRelaySignalPoll(generation)'));
    expect(
      serviceSource,
      contains(
        'pollOnce(allowRelayFallback = true, allowRelayConnected = true)',
      ),
    );
  });

  test(
    'legacy relay content is ignored and still forces authenticated poll',
    () {
      final legacy = jsonEncode({
        'id': 'legacy-contract-1',
        'content': '旧式正文',
        'user_id': '10001',
        'timestamp': 1781280000,
      });
      final event = jsonEncode({'event': 'message', 'message': legacy});
      final decoded =
          jsonDecode(
                (jsonDecode(event) as Map<String, dynamic>)['message']
                    as String,
              )
              as Map<String, dynamic>;

      expect(decoded, contains('content'));
      expect(decoded, isNot(contains('signal')));
      expect(
        serviceSource,
        isNot(contains('consumeMobileMessage(item, "relay")')),
      );
      expect(
        serviceSource,
        contains('legacy payloads containing content must return to the'),
      );
    },
  );
}
