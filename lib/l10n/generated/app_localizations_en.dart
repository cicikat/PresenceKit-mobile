// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Companion';

  @override
  String get appErrorTitle => 'Something went wrong';

  @override
  String get backHome => 'Back to home';

  @override
  String get retry => 'Retry';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneralSection => 'General';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSubtitle =>
      'Changes apply immediately and are saved on this device';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsConnectionAccountSection => 'Connection & account';

  @override
  String get settingsAccessTokenTitle => 'Access token';

  @override
  String get settingsAccessTokenConfigured =>
      'Configured · Stored in Android private storage';

  @override
  String get settingsAccessTokenMissing =>
      'Not configured · Required before connecting';

  @override
  String get settingsReplaceAction => 'Replace';

  @override
  String get settingsSetAction => 'Set';
}
