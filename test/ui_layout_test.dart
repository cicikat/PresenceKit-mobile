import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/theme_controller.dart';
import 'package:presencekit_mobile/models/theme_models.dart';
import 'package:presencekit_mobile/models/ui_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'each layout retains its own palette and classic restores the old selection',
    () async {
      String? saved;
      final c = ThemeController(
        loadPersisted: () async => saved,
        savePersisted: (v) async {
          saved = v;
        },
      );
      final old = await c.create(name: 'Existing', base: 'light');
      await c.setDailyLayout(DailyLayout.noir);
      expect(c.activeId, isNull);
      final custom = await c.create(name: 'Noir custom', base: 'light');
      await c.setDailyLayout(DailyLayout.letter);
      expect(c.activeId, isNull);
      await c.setDailyLayout(DailyLayout.classic);
      expect(c.activeId, old.id);
      final restored = ThemeController(
        loadPersisted: () async => saved,
        savePersisted: (v) async {
          saved = v;
        },
      );
      await restored.restore();
      expect(restored.activeId, old.id);
      await restored.setDailyLayout(DailyLayout.noir);
      expect(restored.activeId, custom.id);
      await restored.delete(custom.id);
      expect(restored.activeId, isNull);
      c.dispose();
      restored.dispose();
    },
  );
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
