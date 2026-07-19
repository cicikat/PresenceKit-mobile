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

  @override
  String get drawerClientSubtitle => 'Mobile thin client · Local display';

  @override
  String get drawerPagesSection => 'Pages';

  @override
  String get drawerChatTitle => 'Chat';

  @override
  String get drawerChatSubtitle => 'Main conversation';

  @override
  String get drawerDreamTitle => 'Dream';

  @override
  String get drawerDreamSubtitle => 'A separate Dream conversation';

  @override
  String get drawerProfileTitle => 'Profile';

  @override
  String get drawerProfileSubtitle => 'Local name and avatar';

  @override
  String drawerDiaryTitle(String name) {
    return '$name\'s diary';
  }

  @override
  String get drawerDiarySubtitle => 'What he writes for himself';

  @override
  String get drawerActivityTitle => 'Activities';

  @override
  String get drawerActivitySubtitle => 'Reading / Gomoku / Chess / Dream setup';

  @override
  String get drawerGroupTitle => 'Group chat';

  @override
  String get drawerGroupSubtitle => 'Chat with multiple characters';

  @override
  String get drawerGrowthSection => 'Growth';

  @override
  String get drawerGardenTitle => 'State garden';

  @override
  String get drawerGardenSubtitle => 'His state of mind today';

  @override
  String get drawerSettingsTitle => 'Settings';

  @override
  String get drawerSettingsSubtitle =>
      'Connection, notifications, appearance and chat';

  @override
  String get drawerCurrent => 'Current';

  @override
  String get presenceOnline => 'Present';

  @override
  String get presenceMobileOnline => 'Mobile online';

  @override
  String get presenceReady => 'Ready';

  @override
  String get presenceChatting => 'Chatting';

  @override
  String get presenceNow => 'Now';

  @override
  String get backTooltip => 'Back';

  @override
  String get chatLoadingOlder => 'Loading earlier conversations…';

  @override
  String chatHiddenOlder(int count) {
    return '$count earlier messages collapsed · Swipe up to expand';
  }

  @override
  String get chatLoadingHistory => 'Loading chat history from the backend';

  @override
  String get chatEmptyHistory => 'Backend connected · No chat history yet';

  @override
  String chatHistoryError(String error) {
    return 'Could not load history · $error';
  }

  @override
  String get chatWaitingReply => 'Sent to backend · Waiting for his reply';

  @override
  String chatBackendError(String error) {
    return 'Backend connection error · $error';
  }

  @override
  String chatBackendStatus(String emotion, int affection) {
    return 'Backend connected · $emotion · Affection $affection';
  }

  @override
  String chatMobileReceived(int count) {
    return 'Received $count proactive messages';
  }

  @override
  String get chatTyping => 'Typing';

  @override
  String get drawerTooltip => 'Drawer';

  @override
  String get preferencesTooltip => 'Preferences';

  @override
  String get switchToLightTooltip => 'Switch to light mode';

  @override
  String get switchToDarkTooltip => 'Switch to dark mode';

  @override
  String get copyAction => 'Copy';

  @override
  String get selectAllAction => 'Select all';

  @override
  String get replyAction => 'Reply';

  @override
  String get cancelReplyTooltip => 'Cancel reply';

  @override
  String get imageAttachment => 'Image attachment';

  @override
  String get fileAttachment => 'File attachment';

  @override
  String get composerPlaceholder => 'Say something to him…';

  @override
  String get attachmentTooltip => 'Attachments';

  @override
  String get releaseToSendTooltip => 'Release to send';

  @override
  String get holdToTalkTooltip => 'Hold to talk';

  @override
  String get waitAction => 'Wait';

  @override
  String get sendAction => 'Send';

  @override
  String characterCount(int count) {
    return '$count characters';
  }
}
