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

  @override
  String get settingsBackendNodeTitle => 'Backend node & user ID';

  @override
  String settingsBackendNodeSubtitle(String baseUrl, String userId) {
    return '$baseUrl · User $userId';
  }

  @override
  String get settingsEditBackendTooltip => 'Edit backend address';

  @override
  String get settingsRelayTitle => 'ntfy push relay';

  @override
  String get settingsRelaySubtitle =>
      'The relay only carries new-message signals; content is fetched from the authenticated backend.';

  @override
  String get settingsEditRelayTooltip => 'Edit relay address';

  @override
  String get settingsNotificationsSection => 'Notifications & proactivity';

  @override
  String get settingsBackgroundNotificationsTitle => 'Background notifications';

  @override
  String get settingsBackgroundNotificationsSubtitle =>
      'Live relay · Long-disconnect fallback · Quiet hours/cooldown';

  @override
  String get settingsNotificationTestTitle =>
      'Notification gate test mode (debug only)';

  @override
  String get settingsNotificationTestSubtitle =>
      'Only bypasses quiet hours and the 30-minute cooldown; message consumption is unchanged.';

  @override
  String get settingsAppearanceSection => 'Appearance & display';

  @override
  String get settingsProfileTitle => 'Character profile';

  @override
  String get settingsProfileSubtitle =>
      'Local name and avatar · Full details on the profile page';

  @override
  String get settingsOpenProfileTooltip => 'Open character profile';

  @override
  String get settingsEditProfileNameTooltip => 'Edit local display name';

  @override
  String get settingsImportAvatarTooltip => 'Import and crop avatar';

  @override
  String get settingsResetAvatarTooltip => 'Restore default avatar';

  @override
  String get settingsThemeTitle => 'Appearance theme';

  @override
  String settingsThemeBuiltInSubtitle(int count) {
    return 'Paper · Night · $count color presets';
  }

  @override
  String settingsThemePresetSubtitle(String name, int count) {
    return 'Current: $name · $count presets total';
  }

  @override
  String get themePaper => 'Paper';

  @override
  String get themeNight => 'Night';

  @override
  String settingsColorPresets(int count) {
    return 'Color presets ($count)';
  }

  @override
  String get settingsInfoStripTitle => 'Conversation info bar';

  @override
  String get settingsInfoStripSubtitle =>
      'Controls the dark green status area on the home screen';

  @override
  String get settingsFontSizeTitle => 'Text size';

  @override
  String settingsFontSizeSubtitle(int size) {
    return '${size}px · Affects bubbles and body text';
  }

  @override
  String get settingsShowAvatarTitle => 'Show my avatar';

  @override
  String get settingsShowAvatarSubtitle =>
      'Display a small avatar beside my chat bubbles';

  @override
  String get settingsProactiveRateTitle => 'Proactive message frequency';

  @override
  String get settingsProactiveRateSubtitle =>
      'Controls the approximate density of proactive reminders';

  @override
  String get rateLow => 'Low';

  @override
  String get rateMedium => 'Medium';

  @override
  String get rateHigh => 'High';

  @override
  String get settingsNightSilentTitle => 'Quiet hours at night';

  @override
  String get settingsNightSilentSubtitle =>
      'He will not proactively contact you from 23:30 to 06:30';

  @override
  String get settingsChatContentSection => 'Conversation content';

  @override
  String get settingsChatLorebookTitle => 'Chat lorebook';

  @override
  String get settingsChatLorebookSubtitle =>
      'Used by Reality chat · Multiple selection';

  @override
  String get settingsChatJailbreakTitle => 'Chat jailbreak';

  @override
  String get settingsChatJailbreakSubtitle =>
      'Independent Reality jailbreak · Multiple selection';

  @override
  String get settingsDreamLorebookTitle => 'Dream lorebook';

  @override
  String get settingsDreamLorebookSubtitle =>
      'Independent Dream lorebook switch';

  @override
  String get settingsDreamWorldTitle => 'Dream world layer';

  @override
  String get settingsDreamWorldSubtitle =>
      'Used the next time you enter a dream';

  @override
  String get dreamWorldRealityDerived => 'Derived from reality';

  @override
  String get dreamWorldAbo => 'ABO';

  @override
  String get dreamWorldVampire => 'Vampire';

  @override
  String get dreamWorldCat => 'Cat';

  @override
  String get dreamWorldFlowerBud => 'Flower bud';

  @override
  String get customOption => 'Custom';

  @override
  String get settingsDreamJailbreakTitle => 'Dream jailbreak';

  @override
  String get settingsDreamJailbreakSubtitle => 'Independent Dream D0 preset';

  @override
  String get defaultOption => 'Default';

  @override
  String settingsBackendSaveError(String error) {
    return 'Could not load/save backend settings: $error';
  }

  @override
  String get settingsDiagnosticsSection => 'Diagnostics';

  @override
  String get settingsCapabilitiesTitle => 'Capability check';

  @override
  String get settingsCapabilitiesSubtitle =>
      'Permissions, backend, relay and sync status';

  @override
  String get openAction => 'Open';

  @override
  String get settingsThinClientNotice =>
      'The mobile client handles chat, notifications, overlays and local display; personality, memory and scheduling remain on the backend.';

  @override
  String get localDeviceLabel => 'Local';

  @override
  String get refreshAction => 'Refresh';

  @override
  String get loadingAction => 'Loading…';

  @override
  String get profileTitle => 'Character profile';

  @override
  String profileEyebrow(String name) {
    return '$name · Local display';
  }

  @override
  String get profileAvatarConfigured => 'Local avatar configured';

  @override
  String get profileAvatarDefault => 'Using the default letter avatar';

  @override
  String get profileNameAction => 'Display name';

  @override
  String get profileAvatarAction => 'Avatar';

  @override
  String get profileDefaultAction => 'Default';

  @override
  String get profileNowSection => 'Right now';

  @override
  String get profileNoActivity => 'Nothing in particular right now';

  @override
  String profileMoodStatus(String label, int percent) {
    return 'Mood: $label ($percent%)';
  }

  @override
  String get profileLocalNameTitle => 'Local display name';

  @override
  String get profileDefaultCharacterName => 'Default character name';

  @override
  String get profileLocalNameBody =>
      'Only affects display on this phone: top bar, drawer, preferences and HIM chat bubbles. It is not written to the backend or the core personality configuration.';

  @override
  String get profileAvatarScopeTitle => 'Avatar scope';

  @override
  String get profileDefaultAvatar => 'Default avatar';

  @override
  String get profileAvatarScopeBody =>
      'The avatar is stored in the app\'s private directory and used only as a local mobile avatar. It is not uploaded to the backend or synced to other clients.';

  @override
  String get profileRealityCardTitle => 'Reality character card';

  @override
  String get profileRealityCardBody =>
      'Switching changes the personality card used by the main chat. The backend saves it and syncs it to other clients.';

  @override
  String get profileCurrentCardLabel => 'Current character card';

  @override
  String get profileLoadCards => 'Load character cards';

  @override
  String get profileSyncBoundaryTitle => 'Sync boundary';

  @override
  String get profileSyncBoundaryValue => 'Mobile display override';

  @override
  String get profileSyncBoundaryBody =>
      'If local names are synced to the backend later, that should use a separate confirmation action. This profile remains a thin-client setting to avoid changing core configuration by mistake.';

  @override
  String get profileDisplayLocationTitle => 'Display locations';

  @override
  String get profileDisplayLocationValue => 'UI updated';

  @override
  String profileDisplayLocationBody(String name) {
    return 'The top bar, drawer, preferences and $name\'s message avatar all use this local profile. Your own avatar remains separate.';
  }

  @override
  String profileFooterNotice(String name) {
    return 'This page only manages the mobile thin client\'s visual identity. $name\'s core personality, memory and scheduling remain on the backend.';
  }

  @override
  String get activityTitle => 'Activities';

  @override
  String get activityEyebrow => 'Do something together';

  @override
  String get activityReadingTitle => 'Read together';

  @override
  String get activityReadingSubtitle =>
      'Upload a PDF and chat while turning pages';

  @override
  String get activityGomokuTitle => 'Gomoku';

  @override
  String get activityGomokuSubtitle =>
      'Play against the character AI by tapping the board';

  @override
  String get activityChessTitle => 'Chess';

  @override
  String get activityChessSubtitle => 'Play against the character AI';

  @override
  String get activityDreamBuildTitle => 'Dream setup';

  @override
  String get activityDreamBuildSubtitle =>
      'Talk about tonight\'s dream before you leave';

  @override
  String get activityChatPrompt => 'Say something about how it\'s going';

  @override
  String get saySomethingHint => 'Say something…';

  @override
  String sendFailedMessage(String error) {
    return '(Send failed: $error)';
  }

  @override
  String get endAction => 'End';

  @override
  String get dreamBuildIntro =>
      'Dream setup has not started yet. Once started, you can talk about what you want to dream tonight. The conversation becomes a seed when you finish.';

  @override
  String get dreamBuildStart => 'Start setup';

  @override
  String get dreamBuildChatTitle => 'Setup chat';

  @override
  String get openChatAction => 'Open chat';

  @override
  String get diaryAllFilter => 'All';

  @override
  String get diaryTitle => 'Diary';

  @override
  String diaryEyebrow(String name) {
    return '$name · Private writing';
  }

  @override
  String get syncingStatus => 'Syncing';

  @override
  String get syncedStatus => 'Synced';

  @override
  String get diarySearchHint => 'Search · Keyword / date / mood';

  @override
  String get retryAction => 'Retry';

  @override
  String get diaryLoadingList => 'Loading diary entries from the backend…';

  @override
  String get diaryEmpty => 'He has not started writing a diary yet.';

  @override
  String get diaryNoResults => 'No matching diary entries.';

  @override
  String diaryRecentRefreshError(String error) {
    return 'Most recent refresh failed: $error';
  }

  @override
  String get diaryOpenToLoad => 'Open an entry to load its content.';

  @override
  String get diaryTapToLoad => 'Tap to load content';

  @override
  String get loadingStatus => 'Loading…';

  @override
  String get noData => 'No data';

  @override
  String loadFailedMessage(String error) {
    return 'Load failed: $error';
  }

  @override
  String get gardenTitle => 'Companion garden';

  @override
  String gardenEyebrow(String name) {
    return '$name · State garden';
  }

  @override
  String get gardenShortTitle => 'Garden';

  @override
  String get gardenLoadingDescription =>
      'Loading garden state from the backend.';

  @override
  String get gardenErrorDescription =>
      'Garden sync failed. You can refresh again later.';

  @override
  String get gardenLoadedDescription =>
      'Garden state loaded. It keeps growing while you are away.';

  @override
  String get gardenNotLoadedDescription =>
      'No garden state has been loaded yet.';

  @override
  String get gardenDominantMood => 'Right now · Dominant mood';

  @override
  String get waitingStatus => 'Waiting';

  @override
  String get gardenWaitingData => 'Waiting for garden data';

  @override
  String get gardenSyncing => 'Syncing garden';

  @override
  String get syncFailedStatus => 'Sync failed';

  @override
  String get gardenAutoRefresh => 'Backend · Refreshes every 30 seconds';

  @override
  String get notSyncedStatus => 'Not synced';

  @override
  String get gardenRefreshTooltip => 'Refresh garden';

  @override
  String get gardenSyncingMessage => 'Syncing garden…';

  @override
  String get gardenEmpty => 'No garden data';

  @override
  String get gardenWaitingSlot =>
      'Waiting for the backend to return a garden slot.';

  @override
  String gardenStageSummary(
    String mood,
    int percent,
    String harvest,
    String vase,
  ) {
    return '$mood is closest to the next stage · $percent% · Harvest $harvest · Vase $vase';
  }

  @override
  String dreamHeaderTitle(String name) {
    return 'Dream · $name';
  }

  @override
  String get dreamInProgress => 'In progress';

  @override
  String get dreamReady => 'DREAM · READY';

  @override
  String get dreamWakeAction => 'Wake up';

  @override
  String dreamConnectionError(String error) {
    return 'Dream connection error · $error';
  }

  @override
  String get dreamResponding => 'The dream is responding';

  @override
  String get dreamStability => 'Stability';

  @override
  String get dreamDepth => 'Depth';

  @override
  String get dreamFindingEntrance => 'Finding the dream entrance';

  @override
  String get dreamEntranceOpen => 'The dream entrance is open';

  @override
  String get dreamEntranceDescription =>
      'Inside, the conversation pauses somewhere lighter and slower. This message flow is separate from the main chat.';

  @override
  String dreamValidCount(int count) {
    return '$count valid dreams so far';
  }

  @override
  String get dreamEntering => 'Falling in…';

  @override
  String get dreamEnterAction => 'Enter dream';

  @override
  String get dreamComposerHint => 'Write something here…';

  @override
  String get dreamWaitingBehindDoor => 'The dream is waiting behind the door';
}
