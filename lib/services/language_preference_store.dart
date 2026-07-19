import 'package:flutter/foundation.dart';

import 'app_settings_store.dart';
import 'language_web_bridge.dart';

abstract interface class LanguagePreferenceStore {
  Future<String?> load();

  Future<void> save(String value);
}

class PlatformLanguagePreferenceStore implements LanguagePreferenceStore {
  const PlatformLanguagePreferenceStore({
    this.settingsStore = const AppSettingsStore(),
  });

  final AppSettingsStore settingsStore;

  @override
  Future<String?> load() =>
      kIsWeb ? loadWebAppLanguage() : settingsStore.loadAppLanguage();

  @override
  Future<void> save(String value) =>
      kIsWeb ? saveWebAppLanguage(value) : settingsStore.saveAppLanguage(value);
}
