import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/theme_controller.dart';
import 'package:presencekit_mobile/models/theme_models.dart';
import 'package:presencekit_mobile/models/ui_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'layout choices restore independently without changing colors',
    () async {
      String? saved;
      final c = ThemeController(
        loadPersisted: () async => saved,
        savePersisted: (value) async {
          saved = value;
        },
      );
      await c.setDailyLayout(DailyLayout.messenger);
      await c.setDreamLayout(DreamLayout.moonlit);
      final restored = ThemeController(
        loadPersisted: () async => saved,
        savePersisted: (value) async {
          saved = value;
        },
      );
      await restored.restore();
      expect(restored.dailyLayout, DailyLayout.messenger);
      expect(restored.dreamLayout, DreamLayout.moonlit);
      expect(restored.activeId, isNull);
      c.dispose();
      restored.dispose();
    },
  );
  test('legacy and unknown layout preferences use classic', () {
    final s = ThemePresetSnapshot.fromJsonString(
      '{"schema":"presencekit-mobile-color-presets","version":1,'
      '"presets":[],"dailyLayout":"future","dreamLayout":17}',
    );
    expect(s!.dailyLayout, DailyLayout.classic);
    expect(s.dreamLayout, DreamLayout.classic);
  });
}
