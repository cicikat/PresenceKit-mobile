import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/theme_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/theme_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saves multiple presets and restores the active preset', () async {
    String? stored;
    final controller = ThemeController(
      loadPersisted: () async => stored,
      savePersisted: (value) async => stored = value,
    );

    final first = await controller.create(name: '暖色', base: 'light');
    final second = await controller.create(name: '深夜', base: 'dark');

    expect(controller.userPresetCount, 2);
    expect(controller.activeId, second.id);
    expect(stored, isNotNull);

    final restored = ThemeController(
      loadPersisted: () async => stored,
      savePersisted: (value) async => stored = value,
    );
    await restored.restore();

    expect(restored.userPresetCount, 2);
    expect(restored.activePreset?.name, '深夜');
    expect(restored.presets.map((item) => item.id), contains(first.id));
  });

  test('migrates the legacy single palette', () async {
    String? stored = YxPalette.dark.toJsonString();
    final controller = ThemeController(
      loadPersisted: () async => stored,
      savePersisted: (value) async => stored = value,
    );

    await controller.restore();

    expect(controller.userPresetCount, 1);
    expect(controller.activePreset?.name, '旧版自定义');
    expect(ThemePresetSnapshot.fromJsonString(stored)?.presets, hasLength(1));
  });

  test(
    'reset restores the selected preset base and delete removes it',
    () async {
      String? stored;
      final controller = ThemeController(
        loadPersisted: () async => stored,
        savePersisted: (value) async => stored = value,
      );
      final preset = await controller.create(name: 'test', base: 'dark');
      await controller.savePreset(
        preset.copyWith(
          palette: preset.palette.copyWith(surface: const Color(0xFF123456)),
        ),
      );

      await controller.reset(preset.id);
      expect(controller.activePalette?.surface, YxPalette.dark.surface);

      await controller.delete(preset.id);
      expect(controller.userPresetCount, 0);
      expect(controller.activePalette, isNull);
    },
  );

  test('color mod is complete, versioned and round-trips ARGB', () {
    const preset = ThemeColorPreset(
      id: 'rose-night',
      name: 'Rose Night',
      base: 'dark',
      palette: YxPalette.dark,
    );

    final decoded = ThemeColorPreset.fromModJson(preset.toModJson());

    expect(decoded, isNotNull);
    expect(decoded!.palette.scrim.toARGB32(), YxPalette.dark.scrim.toARGB32());
    expect(
      decoded.palette.surface.toARGB32(),
      YxPalette.dark.surface.toARGB32(),
    );
    expect(preset.toModJson()['schema'], mobileColorModSchema);
  });
}
