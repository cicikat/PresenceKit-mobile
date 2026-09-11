import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/theme_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/theme_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('import validates complete colors, preserves existing presets and selects target mode', () async {
    String? saved;
    final controller = ThemeController(loadPersisted: () async => saved, savePersisted: (value) async { saved = value; });
    final original = await controller.create(name: 'Original', base: 'light');
    final imported = ThemeColorPreset(id: original.id, name: 'Night', base: 'dark', palette: YxPalette.dark);
    expect(await controller.importJson(imported.toModJsonString(), dark: true), isTrue);
    expect(controller.presets.length, 2);
    expect(controller.lightThemePresetId, original.id);
    expect(controller.darkThemePresetId, isNot(original.id));
    expect(controller.darkThemePreset!.palette.toHexMap(), imported.palette.toHexMap());
    final invalid = imported.toModJson();
    (invalid['colors'] as Map).remove('surface');
    final previous = saved;
    expect(await controller.importJson(jsonEncode(invalid)), isFalse);
    expect(await controller.importJson('{'), isFalse);
    expect(saved, previous);
    expect(controller.presets.length, 2);
    controller.dispose();
  });
}
