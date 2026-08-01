import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/profile_status_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';

class _Backend extends BackendClient {
  _Backend()
    : super(
        baseUrl: 'http://127.0.0.1:8080',
        settingsStore: const AppSettingsStore(),
      );

  bool fail = false;

  @override
  Future<ActivityCurrentState> loadActivityCurrent({required String token}) {
    if (fail) throw const BackendException('activity unavailable');
    return Future.value(const ActivityCurrentState(text: 'reading', arc: null));
  }

  @override
  Future<MoodStateSnapshot> loadMoodState({required String token}) {
    if (fail) throw const BackendException('mood unavailable');
    return Future.value(
      const MoodStateSnapshot(current: 'gentle', intensity: 0.6),
    );
  }
}

void main() {
  test(
    'retains the last success and marks it stale after a refresh failure',
    () async {
      final backend = _Backend();
      final controller = ProfileStatusController(
        backend: () => backend,
        token: () => 'test-token',
      );

      await controller.load();
      final succeededAt = controller.lastSuccessfulAt;
      expect(controller.activityCurrent?.text, 'reading');
      expect(succeededAt, isNotNull);
      expect(controller.error, isNull);

      backend.fail = true;
      await controller.load();

      expect(controller.activityCurrent?.text, 'reading');
      expect(controller.moodState?.current, 'gentle');
      expect(controller.lastSuccessfulAt, succeededAt);
      expect(controller.error, 'activity unavailable');
      expect(controller.isStale, isTrue);
    },
  );
}
