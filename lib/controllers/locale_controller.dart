import 'package:flutter/material.dart';

import '../services/language_preference_store.dart';

enum AppLanguage {
  system('system'),
  simplifiedChinese('zh-CN'),
  english('en-US');

  const AppLanguage(this.storageValue);

  final String storageValue;

  static AppLanguage fromStorage(String? value) {
    return AppLanguage.values.firstWhere(
      (language) => language.storageValue == value,
      orElse: () => AppLanguage.system,
    );
  }
}

class LocaleController extends ChangeNotifier {
  LocaleController({
    LanguagePreferenceStore store = const PlatformLanguagePreferenceStore(),
  }) : _store = store;

  final LanguagePreferenceStore _store;
  AppLanguage _language = AppLanguage.system;
  bool _loaded = false;

  AppLanguage get language => _language;
  bool get loaded => _loaded;

  Locale? get locale => switch (_language) {
    AppLanguage.system => null,
    AppLanguage.simplifiedChinese => const Locale('zh'),
    AppLanguage.english => const Locale('en'),
  };

  Future<void> load() async {
    if (_loaded) return;
    _language = AppLanguage.fromStorage(await _store.load());
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    await _store.save(language.storageValue);
  }
}
