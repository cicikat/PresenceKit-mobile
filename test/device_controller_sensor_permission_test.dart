import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/device_controller.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Store extends AppSettingsStore {
  bool activityRecognition = false;
  int activityRequests = 0;
  int? steps = 1200;
  int? battery = 80;
  final List<Map<String, int?>> pushes = [];

  @override
  Future<bool> hasActivityRecognitionPermission() async => activityRecognition;

  @override
  Future<void> requestActivityRecognitionPermission() async {
    activityRequests += 1;
    activityRecognition = true;
  }

  @override
  Future<int?> readBatteryPercent() async => battery;

  @override
  Future<int?> readTodaySteps() async => steps;

  @override
  Future<bool> loadScreenContextUploadEnabled() async => false;
}

class _Backend extends BackendClient {
  _Backend(this.store)
    : super(baseUrl: 'http://127.0.0.1:8080', settingsStore: store);

  final _Store store;

  @override
  Future<void> pushSensorData({
    required String token,
    int? steps,
    int? battery,
    int? screenSessions,
  }) async {
    store.pushes.add({'battery': battery, 'steps': steps});
  }
}

void main() {
  late _Store store;
  late DeviceController controller;

  setUp(() {
    store = _Store();
    controller = DeviceController(
      device: DeviceControlService(store),
      screen: ScreenSensorService(store),
      backend: () => _Backend(store),
      token: () => 'token',
    );
  });

  tearDown(() => controller.dispose());

  test('pushSensorData never requests activity permission', () async {
    store.activityRecognition = false;
    await controller.pushSensorData();
    expect(store.activityRequests, 0);
    expect(store.pushes, [
      {'battery': 80, 'steps': null},
    ]);
  });

  test('pushSensorData includes steps only when already granted', () async {
    store.activityRecognition = true;
    await controller.pushSensorData();
    expect(store.activityRequests, 0);
    expect(store.pushes, [
      {'battery': 80, 'steps': 1200},
    ]);
  });

  test('explicit requestActivityPermission is the only prompt path', () async {
    expect(await controller.hasActivityPermission(), isFalse);
    await controller.requestActivityPermission();
    expect(store.activityRequests, 1);
    expect(await controller.hasActivityPermission(), isTrue);
  });

  test('start/periodic path still does not request permission', () async {
    store.activityRecognition = false;
    controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(store.activityRequests, 0);
    controller.stop();
  });
}
