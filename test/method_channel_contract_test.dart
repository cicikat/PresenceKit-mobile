// Contract tests for the `presence_mobile/settings` MethodChannel, scoped to
// the categories flagged as uncovered in docs/quality/testing-and-dev.md:
// background service start/stop, accessibility, and floating-bubble calls.
//
// `flutter test` always runs as the host OS, so `Platform.isAndroid` is
// never true here. `AppSettingsStore.debugForceChannelAvailable` (added for
// this test) forces the channel path open without touching production
// behaviour, which only ever runs on a real Android device.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('presence_mobile/settings');
  late AppSettingsStore store;
  late List<MethodCall> calls;
  late Future<Object?> Function(MethodCall call) handler;

  void reply(Object? value) {
    handler = (_) async => value;
  }

  void throwPlatformError() {
    handler = (_) async => throw PlatformException(code: 'boom');
  }

  setUp(() {
    AppSettingsStore.debugForceChannelAvailable = true;
    store = const AppSettingsStore();
    calls = <MethodCall>[];
    handler = (_) async => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler(call);
        });
  });

  tearDown(() {
    AppSettingsStore.debugForceChannelAvailable = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('应用语言', () {
    test('loads and saves the language through the stable channel', () async {
      reply('en-US');
      expect(await store.loadAppLanguage(), 'en-US');
      expect(calls.single.method, 'getAppLanguage');

      calls.clear();
      await store.saveAppLanguage('zh-CN');
      expect(calls.single.method, 'setAppLanguage');
      expect(calls.single.arguments, {'value': 'zh-CN'});
    });

    test('falls back safely when language persistence fails', () async {
      throwPlatformError();
      expect(await store.loadAppLanguage(), isNull);
      await store.saveAppLanguage('en-US');
    });
  });

  group('后台服务启停', () {
    test(
      'startBackgroundNotifications calls the channel with no args and swallows platform errors',
      () async {
        throwPlatformError();
        await store.startBackgroundNotifications();
        expect(calls.single.method, 'startBackgroundNotifications');
        expect(calls.single.arguments, isNull);
      },
    );

    test(
      'stopBackgroundNotifications calls the channel and swallows platform errors',
      () async {
        throwPlatformError();
        await store.stopBackgroundNotifications();
        expect(calls.single.method, 'stopBackgroundNotifications');
      },
    );

    test(
      'isBackgroundNotificationServiceRunning parses the bool reply',
      () async {
        reply(true);
        expect(await store.isBackgroundNotificationServiceRunning(), isTrue);
        expect(calls.single.method, 'isBackgroundNotificationServiceRunning');
      },
    );

    test(
      'isBackgroundNotificationServiceRunning falls back to false on a platform error',
      () async {
        throwPlatformError();
        expect(await store.isBackgroundNotificationServiceRunning(), isFalse);
      },
    );

    test('getBackgroundPollStatus parses the platform map', () async {
      reply({
        'lastBackgroundPollAt': 1781280000000,
        'lastBackgroundError': ' boom ',
      });
      final status = await store.loadBackgroundPollStatus();
      expect(calls.single.method, 'getBackgroundPollStatus');
      expect(
        status.lastPollAt,
        DateTime.fromMillisecondsSinceEpoch(1781280000000),
      );
      expect(status.lastError, 'boom');
    });

    test(
      'getBackgroundPollStatus falls back to the empty default on a platform error',
      () async {
        throwPlatformError();
        final status = await store.loadBackgroundPollStatus();
        expect(status.lastPollAt, isNull);
        expect(status.lastError, isNull);
      },
    );

    test('getRelayConnectionStatus parses the platform map', () async {
      reply({
        'connectionStatus': 'connected',
        'lastHeartbeatAt': 1781280000000,
      });
      final status = await store.loadRelayConnectionStatus();
      expect(calls.single.method, 'getRelayConnectionStatus');
      expect(status.connectionStatus, 'connected');
    });

    test(
      'getRelayConnectionStatus falls back to unconfigured on a platform error',
      () async {
        throwPlatformError();
        final status = await store.loadRelayConnectionStatus();
        expect(status.connectionStatus, 'unconfigured');
      },
    );

    test('getNotificationGateStatus parses the platform map', () async {
      reply({
        'suppressedCount': 3,
        'lastSuppressReason': 'quiet_hours',
        'testModeEnabled': true,
      });
      final status = await store.loadNotificationGateStatus();
      expect(calls.single.method, 'getNotificationGateStatus');
      expect(status.suppressedCount, 3);
      expect(status.lastSuppressReason, 'quiet_hours');
      expect(status.testModeEnabled, isTrue);
    });

    test(
      'debugBackgroundDelivery sends content/behavior args and parses the bool reply',
      () async {
        reply(true);
        final ok = await store.debugBackgroundDelivery(
          content: 'hi',
          behaviorJson: '{"kind":"notify"}',
        );
        expect(ok, isTrue);
        expect(calls.single.method, 'debugBackgroundDelivery');
        expect(calls.single.arguments, {
          'content': 'hi',
          'behavior': '{"kind":"notify"}',
        });
      },
    );

    test(
      'debugBackgroundDelivery defaults the behavior arg to an empty string',
      () async {
        reply(true);
        await store.debugBackgroundDelivery(content: 'hi');
        expect(calls.single.arguments, {'content': 'hi', 'behavior': ''});
      },
    );

    test(
      'debugBackgroundDelivery falls back to false on a platform error',
      () async {
        throwPlatformError();
        expect(await store.debugBackgroundDelivery(content: 'hi'), isFalse);
      },
    );
  });

  group('无障碍', () {
    test('isAccessibilityServiceEnabled parses the bool reply', () async {
      reply(true);
      expect(await store.isAccessibilityServiceEnabled(), isTrue);
      expect(calls.single.method, 'isAccessibilityServiceEnabled');
    });

    test(
      'isAccessibilityServiceEnabled falls back to false on a platform error',
      () async {
        throwPlatformError();
        expect(await store.isAccessibilityServiceEnabled(), isFalse);
      },
    );

    test(
      'requestAccessibilityPermission calls the channel and swallows platform errors',
      () async {
        throwPlatformError();
        await store.requestAccessibilityPermission();
        expect(calls.single.method, 'requestAccessibilityPermission');
      },
    );

    test(
      'captureScreenContext parses the platform map into a snapshot',
      () async {
        reply({
          'isBlocked': false,
          'packageName': 'com.example.shop',
          'appLabel': 'Shop',
          'windowTitle': 'Cart',
          'visibleText': ['a', 'b'],
          'clickableText': ['结算'],
          'capturedAt': 1781280000.5,
        });
        final snapshot = await store.captureScreenContext();
        expect(calls.single.method, 'captureScreenContext');
        expect(snapshot, isNotNull);
        expect(snapshot!.packageName, 'com.example.shop');
        expect(snapshot.visibleText, ['a', 'b']);
        expect(snapshot.capturedAt, 1781280000.5);
      },
    );

    test(
      'captureScreenContext returns null when the platform has nothing to report',
      () async {
        reply(null);
        expect(await store.captureScreenContext(), isNull);
      },
    );

    test('captureScreenContext returns null on a platform error', () async {
      throwPlatformError();
      expect(await store.captureScreenContext(), isNull);
    });

    test('captureScreenContextForUpload uses its own method name', () async {
      reply(null);
      await store.captureScreenContextForUpload();
      expect(calls.single.method, 'captureScreenContextForUpload');
    });
  });

  group('悬浮窗', () {
    test('canDrawOverlays parses the bool reply', () async {
      reply(true);
      expect(await store.canDrawOverlays(), isTrue);
      expect(calls.single.method, 'canDrawOverlays');
    });

    test('canDrawOverlays falls back to false on a platform error', () async {
      throwPlatformError();
      expect(await store.canDrawOverlays(), isFalse);
    });

    test(
      'requestOverlayPermission calls the channel and swallows platform errors',
      () async {
        throwPlatformError();
        await store.requestOverlayPermission();
        expect(calls.single.method, 'requestOverlayPermission');
      },
    );

    test('showFloatingBubble parses the bool reply', () async {
      reply(true);
      expect(await store.showFloatingBubble(), isTrue);
      expect(calls.single.method, 'showFloatingBubble');
    });

    test(
      'showFloatingBubble falls back to false on a platform error',
      () async {
        throwPlatformError();
        expect(await store.showFloatingBubble(), isFalse);
      },
    );

    test(
      'showOrderBubble sends the target arg and parses the bool reply',
      () async {
        reply(true);
        final ok = await store.showOrderBubble('taobao');
        expect(ok, isTrue);
        expect(calls.single.method, 'showOrderBubble');
        expect(calls.single.arguments, {'target': 'taobao'});
      },
    );

    test('showOrderBubble falls back to false on a platform error', () async {
      throwPlatformError();
      expect(await store.showOrderBubble('taobao'), isFalse);
    });

    test(
      'hideFloatingBubble calls the channel and swallows platform errors',
      () async {
        throwPlatformError();
        await store.hideFloatingBubble();
        expect(calls.single.method, 'hideFloatingBubble');
      },
    );

    test('isDeviceAdminActive parses the bool reply', () async {
      reply(true);
      expect(await store.isDeviceAdminActive(), isTrue);
      expect(calls.single.method, 'isDeviceAdminActive');
    });

    test(
      'isDeviceAdminActive falls back to false on a platform error',
      () async {
        throwPlatformError();
        expect(await store.isDeviceAdminActive(), isFalse);
      },
    );

    test(
      'requestDeviceAdmin calls the channel and swallows platform errors',
      () async {
        throwPlatformError();
        await store.requestDeviceAdmin();
        expect(calls.single.method, 'requestDeviceAdmin');
      },
    );

    test('lockScreen parses the bool reply', () async {
      reply(true);
      expect(await store.lockScreen(), isTrue);
      expect(calls.single.method, 'lockScreen');
    });

    test('lockScreen falls back to false on a platform error', () async {
      throwPlatformError();
      expect(await store.lockScreen(), isFalse);
    });

    test(
      'openShoppingApp sends the target arg and parses the bool reply',
      () async {
        reply(true);
        final ok = await store.openShoppingApp('jd');
        expect(ok, isTrue);
        expect(calls.single.method, 'openShoppingApp');
        expect(calls.single.arguments, {'target': 'jd'});
      },
    );

    test('openShoppingApp falls back to false on a platform error', () async {
      throwPlatformError();
      expect(await store.openShoppingApp('jd'), isFalse);
    });
  });
}
