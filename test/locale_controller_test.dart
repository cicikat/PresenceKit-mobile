import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/locale_controller.dart';
import 'package:presencekit_mobile/services/language_preference_store.dart';

class _MemoryLanguageStore implements LanguagePreferenceStore {
  _MemoryLanguageStore([this.value]);

  String? value;

  @override
  Future<String?> load() async => value;

  @override
  Future<void> save(String value) async {
    this.value = value;
  }
}

void main() {
  test('defaults to system and restores a persisted language', () async {
    final defaultController = LocaleController(store: _MemoryLanguageStore());
    await defaultController.load();
    expect(defaultController.language, AppLanguage.system);
    expect(defaultController.locale, isNull);

    final englishController = LocaleController(
      store: _MemoryLanguageStore('en-US'),
    );
    await englishController.load();
    expect(englishController.language, AppLanguage.english);
    expect(englishController.locale?.languageCode, 'en');
  });

  test('switches immediately and persists the selection', () async {
    final store = _MemoryLanguageStore();
    final controller = LocaleController(store: store);
    await controller.load();

    var notifications = 0;
    controller.addListener(() => notifications += 1);
    final saving = controller.setLanguage(AppLanguage.simplifiedChinese);

    expect(controller.language, AppLanguage.simplifiedChinese);
    expect(controller.locale?.languageCode, 'zh');
    expect(notifications, 1);

    await saving;
    expect(store.value, 'zh-CN');
  });

  test('unknown persisted values safely fall back to system', () async {
    final controller = LocaleController(
      store: _MemoryLanguageStore('unsupported'),
    );
    await controller.load();
    expect(controller.language, AppLanguage.system);
  });
}
