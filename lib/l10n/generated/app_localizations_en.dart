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
  String drawerVersionLabel(String version) {
    return 'Version $version';
  }

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
  String chatBackendStatus(String emotion) {
    return 'Backend connected · $emotion';
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
  String get stickerLoadFailed => 'Sticker failed to load';

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
      'Current Reality selections · Select and enable/disable only; no editor';

  @override
  String get settingsChatJailbreakTitle => 'Chat jailbreak';

  @override
  String get settingsChatJailbreakSubtitle =>
      'Current Reality selections · Select and enable/disable only; no editor';

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
  String get profileStatusUpdating => 'Refreshing status…';

  @override
  String profileStatusLastUpdated(String time) {
    return 'Last successful update: $time';
  }

  @override
  String profileStatusLoadError(String error) {
    return 'Could not refresh status; showing the last successful values: $error';
  }

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

  @override
  String get cancelAction => 'Cancel';

  @override
  String get deleteAction => 'Delete';

  @override
  String get saveAction => 'Save';

  @override
  String get savingAction => 'Saving…';

  @override
  String get closeAction => 'Close';

  @override
  String get startGameAction => 'Start game';

  @override
  String groupDeleteTitle(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get groupDeleteWarning =>
      'The chat history will also be deleted and cannot be recovered.';

  @override
  String get groupTitle => 'Group chat';

  @override
  String get groupEyebrow => 'Chat with multiple characters';

  @override
  String get groupCreateAction => 'New group';

  @override
  String get groupEmpty => 'No group chats yet';

  @override
  String groupRosterDeleteHint(String members) {
    return '$members · Hold to delete';
  }

  @override
  String get groupSelectAtLeastOne => 'Select at least one character';

  @override
  String groupSelectedCount(int count) {
    return 'Select members ($count selected)';
  }

  @override
  String get groupNoCharacters => 'No characters available';

  @override
  String groupMinResponders(int count) {
    return 'N minimum responders: $count';
  }

  @override
  String groupMaxResponders(int count) {
    return 'M maximum responders: $count';
  }

  @override
  String get groupCreating => 'Creating…';

  @override
  String get groupConfirmCreate => 'Create group';

  @override
  String get groupSendToStart => 'Send a message to start the group chat';

  @override
  String get groupMembersResponding => 'Members are responding…';

  @override
  String get groupSendHint => 'Send a message…';

  @override
  String get groupKeepAtLeastOne => 'Keep at least one member';

  @override
  String get groupSettingsTitle => 'Group settings';

  @override
  String groupManagingCount(int count) {
    return 'Manage members ($count selected)';
  }

  @override
  String get groupDreamEnterAction => 'Dream';

  @override
  String get groupDreamTitle => 'Group Dream';

  @override
  String get groupDreamEntering => 'Falling asleep…';

  @override
  String get groupDreamEnterFailed =>
      'The backend did not allow entering the dream';

  @override
  String get groupDreamSendToStart => 'Send a message to start the group dream';

  @override
  String get groupDreamMembersResponding => 'The others are responding…';

  @override
  String get groupDreamSendHint => 'Say something in the dream…';

  @override
  String get groupDreamExitAction => 'Wake up';

  @override
  String get groupDreamExitConfirmTitle => 'Wake up now?';

  @override
  String get groupDreamExitConfirmBody =>
      'This ends the group dream immediately and it can\'t be resumed.';

  @override
  String get groupDreamBlockedHint =>
      'Group dream in progress — reality chat is locked';

  @override
  String readingDeleteTitle(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get irreversibleWarning => 'This action cannot be undone.';

  @override
  String get readingInProgress => 'Reading';

  @override
  String get readingTogetherTitle => 'Read together';

  @override
  String get readingChatTitle => 'Reading chat';

  @override
  String get readingLibrary => 'Library';

  @override
  String get readingAdding => 'Adding…';

  @override
  String get readingAddPdf => 'Add PDF';

  @override
  String get readingEmptyLibrary => 'The library is empty. Add a PDF to begin.';

  @override
  String readingBookPages(String pages) {
    return '$pages pages · Hold to delete';
  }

  @override
  String readingPageStatus(String current, String total) {
    return 'Page $current of $total';
  }

  @override
  String get readingLoadingPage => 'Loading page content…';

  @override
  String get readingPreviousPage => '← Previous';

  @override
  String get readingNextPage => 'Next →';

  @override
  String get chessTitle => 'Chess';

  @override
  String get chessIntro =>
      'Play a game of chess with him. You play White and move first: tap a piece, then its destination.';

  @override
  String chessGameOver(String result) {
    return 'Game over: $result';
  }

  @override
  String chessTurn(String side) {
    return 'Turn: $side';
  }

  @override
  String get whiteSide => 'White';

  @override
  String get blackSide => 'Black';

  @override
  String get gameChatTitle => 'Game chat';

  @override
  String get gomokuTitle => 'Gomoku';

  @override
  String get gomokuIntro =>
      'Play a game of Gomoku with him. You move first by tapping the board.';

  @override
  String get drawResult => 'Draw';

  @override
  String gomokuWinner(String stone) {
    return '$stone wins';
  }

  @override
  String gomokuTurn(String stone) {
    return 'Turn: $stone';
  }

  @override
  String get blackStone => 'Black';

  @override
  String get whiteStone => 'White';

  @override
  String get boardLoading => 'Loading board…';

  @override
  String get themePresetsTitle => 'Color presets';

  @override
  String get themePresetsDescription =>
      'Save multiple presets locally; export color mods in the browser.';

  @override
  String get newAction => 'New';

  @override
  String get themeNoCustomPresets => 'No custom presets yet';

  @override
  String get themeBundledReadOnly => 'Built into mods/ · Read-only';

  @override
  String themeLocalPreset(String base) {
    return '$base base · Local preset';
  }

  @override
  String get themeCopyEdit => 'Copy and edit';

  @override
  String get editAction => 'Edit';

  @override
  String get themeResetColors => 'Reset colors';

  @override
  String get themeExportMod => 'Export mod';

  @override
  String get themeDeleteTitle => 'Delete color preset?';

  @override
  String themeDeleteWarning(String name) {
    return '“$name” will be deleted from this device. This cannot be undone.';
  }

  @override
  String get themeExportSuccess =>
      'Color mod downloaded. Place it in the project\'s mods/ folder manually.';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get themeEditTitle => 'Edit color preset';

  @override
  String get themePresetNameLabel => 'Preset name';

  @override
  String get themeComponentColors => 'Component colors';

  @override
  String get themeFreeColor => 'Custom color';

  @override
  String themeHue(int value) {
    return 'Hue $value°';
  }

  @override
  String themeOpacity(int value) {
    return 'Opacity $value%';
  }

  @override
  String get themeApplyRgbTooltip => 'Apply RGB';

  @override
  String get previewLabel => 'Preview';

  @override
  String get themeCharacterPreview => 'Character message and body colors';

  @override
  String get themeUserPreview => 'User message color';

  @override
  String get themeDefaultName => 'My palette';

  @override
  String get themeNewTitle => 'New color preset';

  @override
  String get nameLabel => 'Name';

  @override
  String get themeLightBase => 'Paper base';

  @override
  String get themeDarkBase => 'Night base';

  @override
  String get createAction => 'Create';

  @override
  String get avatarCropTitle => 'Crop avatar';

  @override
  String get avatarCropHelp =>
      'Drag to reposition and pinch or gesture to zoom. The saved avatar remains local to mobile.';

  @override
  String get resetAction => 'Reset';

  @override
  String get closeTooltip => 'Close';

  @override
  String get themeCustomPaletteTitle => 'Custom palette';

  @override
  String themeEditingRole(String role) {
    return 'Editing: $role';
  }

  @override
  String get themePreviewBody =>
      'These colors apply to chat, drawer and settings components.';

  @override
  String get themeSidebarPreview =>
      'Sidebar background / text and icons / selection';

  @override
  String get themeUserBubblePreview => 'User bubbles update too.';

  @override
  String get noOptions => 'No options available';

  @override
  String get attachmentSheetTitle => 'Attach content';

  @override
  String get attachmentDocument => 'Document';

  @override
  String get attachmentDocumentSubtitle => 'txt / md / docx · Up to 5 MB';

  @override
  String get attachmentImage => 'Images';

  @override
  String get attachmentImageSubtitle => 'Multiple selection · Backend vision';

  @override
  String get themeRoleSurface => 'Page background';

  @override
  String get themeRoleSurfaceSoft => 'Input background';

  @override
  String get themeRoleSurfaceDeep => 'Deep background';

  @override
  String get themeRoleSurfaceEdge => 'Borders';

  @override
  String get themeRoleInk1 => 'Primary text';

  @override
  String get themeRoleInk2 => 'Secondary text';

  @override
  String get themeRoleInk3 => 'Muted text';

  @override
  String get themeRoleInk4 => 'Faint lines';

  @override
  String get themeRoleCharacter => 'Character accent/focus';

  @override
  String get themeRoleCharacterDeep => 'Top bar/sidebar';

  @override
  String get themeRoleCharacterSoft => 'Selection/soft background';

  @override
  String get themeRoleCharacterOn => 'Sidebar text';

  @override
  String get themeRoleDanger => 'Danger';

  @override
  String get themeRoleWarn => 'Warning';

  @override
  String get themeRoleOk => 'Success';

  @override
  String get themeRoleSend => 'Send button';

  @override
  String get themeRoleUserBubble => 'User bubble';

  @override
  String get themeRoleUserBubbleText => 'User bubble text';

  @override
  String get themeRoleScrim => 'Scrim';

  @override
  String get backendInvalidAddress => 'Invalid backend address';

  @override
  String get tokenSetTitle => 'Set access token';

  @override
  String get tokenReplaceTitle => 'Set / replace token';

  @override
  String get tokenHelp =>
      'Enter a mobile token issued by the backend (starts with emt_). Legacy admin secrets still work but are not recommended. The token stays in Android private storage and is never bundled with the app.';

  @override
  String get tokenRequiredError => 'Enter an access token';

  @override
  String saveFailedMessage(String error) {
    return 'Save failed: $error';
  }

  @override
  String get deviceAdminRequired =>
      'Enable device administrator permission for Companion lock confirmation first';

  @override
  String get accessibilityAuthorized => 'Companion assistant is authorized';

  @override
  String shoppingAppMissing(String label) {
    return 'Could not find $label. Install it manually or verify the package name.';
  }

  @override
  String orderBubbleShown(String label) {
    return 'Opened the $label cart confirmation overlay';
  }

  @override
  String get overlayPermissionRequired =>
      'Allow display over other apps, then return and try again';

  @override
  String screenPushFailed(String error) {
    return 'Could not push screen context: $error';
  }

  @override
  String get accessibilityRequiredForScreen =>
      'Enable accessibility before reading screen context';

  @override
  String get screenContextEmpty => 'No readable screen context available';

  @override
  String behaviorTestQueued(String label) {
    return 'Queued proactive behavior test: $label';
  }

  @override
  String behaviorTestFailed(String error) {
    return 'Proactive behavior test failed: $error';
  }

  @override
  String get profileNameHint => 'Leave blank to use the backend character name';

  @override
  String get restoreDefaultAction => 'Restore default';

  @override
  String get avatarSaveFailed => 'Could not save avatar';

  @override
  String get backendNodeTitle => 'Backend node';

  @override
  String get backendNodeHelp =>
      'Use 127.0.0.1 with a cable; use the computer\'s LAN IP when disconnected.';

  @override
  String get userIdLabel => 'User ID';

  @override
  String get userIdHint =>
      'QQ number or backend uid; letters, numbers, underscores and hyphens only';

  @override
  String get invalidAddressError => 'Enter a valid address';

  @override
  String get userIdInvalidError =>
      'Only letters, numbers, underscores and hyphens are supported';

  @override
  String get saveReconnectAction => 'Save and reconnect';

  @override
  String get relayDialogTitle => 'Push relay (ntfy)';

  @override
  String get relayAddressLabel => 'Relay address';

  @override
  String get relayTopicHint =>
      'Example: mychar-wake-a1b2c3 (treat as a password; use random text)';

  @override
  String get relayTokenLabel => 'Token (optional)';

  @override
  String get relayTokenHint =>
      'Leave blank when the relay has no authentication';

  @override
  String get relayHelp =>
      'Must match relay_base_url, relay_topic and relay_token in the backend config.yaml. An empty topic disables live relay wakeups and falls back to periodic polling.';

  @override
  String get relayTopicInvalidError =>
      'Use lowercase letters, numbers, / _ - only, up to 128 characters';

  @override
  String get untrustedAddressError => 'This address is not trusted';

  @override
  String get dreamLeaveTitle => 'Leaving?';

  @override
  String get dreamStayFallback => 'Stay a little longer.';

  @override
  String get dreamLeaveAction => 'Leave anyway';

  @override
  String get dreamStayAction => 'Stay';

  @override
  String get fileTypeUnsupported =>
      'The backend currently supports txt / md / docx only';

  @override
  String get fileTooLarge => 'The backend file limit is 5 MB';

  @override
  String get fileFailureLabel => 'File';

  @override
  String get imageTypeUnsupported =>
      'The backend currently supports jpg / png / gif / webp / heic / bmp only';

  @override
  String get imageTooLarge => 'The backend image limit is 10 MB per image';

  @override
  String imageCountPreview(int count, String names, String suffix) {
    return '📎 $count images: $names$suffix';
  }

  @override
  String get imageFailureLabel => 'Image';

  @override
  String get meituanName => 'Meituan';

  @override
  String get taobaoName => 'Taobao';

  @override
  String get capabilityTitle => 'Capability check';

  @override
  String get capabilityRefreshTooltip => 'Run checks again';

  @override
  String get capabilityLoading => 'Reading system status…';

  @override
  String get capabilityUnavailable => 'Status is unavailable. Try again later.';

  @override
  String get capabilityNotificationTitle => 'Notification permission';

  @override
  String get capabilityNotificationSubtitle =>
      'System notifications are required for proactive background messages.';

  @override
  String get enabledStatus => 'Enabled';

  @override
  String get disabledStatus => 'Disabled';

  @override
  String get enableAction => 'Enable';

  @override
  String get configureAction => 'Configure';

  @override
  String get authorizeAction => 'Authorize';

  @override
  String get authorizedStatus => 'Exempt';

  @override
  String get capabilityBatteryTitle => 'Battery optimization exemption';

  @override
  String get capabilityBatteryEnabled =>
      'Background operation is allowed. Also check the vendor\'s auto-start and background allowlists.';

  @override
  String get capabilityBatteryDisabled =>
      'Not exempt: background polling may pause while the screen is off or in Doze.';

  @override
  String get capabilityOverlayTitle => 'Overlay permission';

  @override
  String get capabilityOverlaySubtitle =>
      'Displays short reminders and confirmations over the desktop and other apps.';

  @override
  String get capabilityAccessibilityTitle => 'Accessibility service';

  @override
  String get capabilityAccessibilitySubtitle =>
      'Reads the current app, window title and visible text summary; screenshots are not uploaded.';

  @override
  String get capabilityScreenContextTitle => 'Screen context';

  @override
  String get capabilityScreenContextEnabled =>
      'Enabled: only locally filtered, non-sensitive text summaries are uploaded.';

  @override
  String get capabilityScreenContextDisabled =>
      'Off by default; this page can still read a locally filtered snapshot.';

  @override
  String get capabilityDeviceAdminTitle => 'Device administrator lock';

  @override
  String get capabilityDeviceAdminSubtitle =>
      'Required for lockNow; every action still needs UI confirmation.';

  @override
  String get capabilityBackgroundServiceTitle =>
      'Background notification service';

  @override
  String get switchEnabledStatus => 'Switch on';

  @override
  String get capabilityRelayTitle => 'Relay connection';

  @override
  String get capabilityGateTitle => 'Notification gate';

  @override
  String get testingStatus => 'Testing';

  @override
  String get normalStatus => 'Normal';

  @override
  String get capabilityBackendTitle => 'adb reverse / backend';

  @override
  String get detectingStatus => 'Checking';

  @override
  String get connectedStatus => 'Connected';

  @override
  String get detectAction => 'Check';

  @override
  String get notConnectedStatus => 'Disconnected';

  @override
  String get capabilityEditBackendTooltip => 'Edit backend node';

  @override
  String get capabilityDetectBackendTooltip => 'Check backend connection';

  @override
  String capabilityBackendLastError(String error) {
    return 'Latest connection error: $error';
  }

  @override
  String get capabilityBackendNotice =>
      'This page shows only status the phone can verify. adb reverse runs on the computer; the phone infers it from backend reachability at 127.0.0.1.';

  @override
  String get relayConnected => 'Connected';

  @override
  String get relayConnecting => 'Connecting';

  @override
  String get relayStopped => 'Stopped';

  @override
  String get relayError => 'Error';

  @override
  String get relayUnconfigured => 'Not configured';

  @override
  String get syncStatusTitle => 'Sync status';

  @override
  String get readingStatus => 'Reading';

  @override
  String failedStatus(String error) {
    return 'Failed: $error';
  }

  @override
  String get pendingSyncStatus => 'Pending';

  @override
  String get pollingStatus => 'Polling';

  @override
  String get activatedStatus => 'Active';

  @override
  String get pendingActivationStatus => 'Pending activation';

  @override
  String syncChatStatus(String status) {
    return 'Chat history: $status';
  }

  @override
  String syncGardenStatus(String status) {
    return 'Garden state: $status';
  }

  @override
  String syncMobileStatus(String status, String received) {
    return 'Proactive messages: $status$received';
  }

  @override
  String syncReceivedSuffix(int count) {
    return ' · $count received';
  }

  @override
  String syncLatestMessage(String content) {
    return 'Latest: $content';
  }

  @override
  String get screenSnapshotEmpty => 'No screen snapshot';

  @override
  String get screenDebugTitle => 'Screen context debug';

  @override
  String get readAction => 'Read';

  @override
  String get pushAction => 'Push';

  @override
  String screenWindow(String value) {
    return 'Window: $value';
  }

  @override
  String screenVisible(String value) {
    return 'Visible: $value';
  }

  @override
  String screenClickable(String value) {
    return 'Clickable: $value';
  }

  @override
  String get behaviorTestTitle => 'Proactive behavior test';

  @override
  String get behaviorTestDescription =>
      'Writes to the backend mobile queue and polls immediately; overlay and confirmation actions appear directly in foreground.';

  @override
  String get behaviorOverlayTestMessage =>
      '(Test) I\'ll wait by the edge of your screen for a moment.';

  @override
  String get behaviorLockTestMessage =>
      '(Test) Would you like me to lock the screen? It only happens after confirmation.';

  @override
  String get behaviorTakeoutTestMessage =>
      '(Test) Want me to open the takeout page? No order will be placed automatically.';

  @override
  String get behaviorNotificationTestMessage =>
      '(Test) This is a regular proactive message.';

  @override
  String get notificationLabel => 'Notification';

  @override
  String get overlayLabel => 'Overlay';

  @override
  String get lockConfirmLabel => 'Lock confirmation';

  @override
  String get takeoutConfirmLabel => 'Takeout confirmation';

  @override
  String get backgroundDeliveryTitle => 'Background delivery test';

  @override
  String get backgroundDeliveryDescription =>
      'Tests mobile background notification, presence overlay and tool confirmation routing without the backend.';

  @override
  String get normalNotificationLabel => 'Regular notification';

  @override
  String get presenceOverlayLabel => 'Presence overlay';

  @override
  String get lockRequestLabel => 'Lock request';

  @override
  String get takeoutRequestLabel => 'Takeout request';

  @override
  String get behaviorDecisionTitle => 'Behavior decision';

  @override
  String get behaviorDecisionEmpty =>
      'Not loaded yet. Refresh to see why the latest backend behavior decision did or did not show.';

  @override
  String readFailedMessage(String error) {
    return 'Read failed: $error';
  }

  @override
  String get fieldTime => 'Time';

  @override
  String get fieldReason => 'Reason';

  @override
  String get fieldEvent => 'Event';

  @override
  String get fieldApp => 'App';

  @override
  String get fieldNarrative => 'Narrative';

  @override
  String get fieldScreen => 'Screen';

  @override
  String get fieldReply => 'Reply';

  @override
  String get backendDiagnosticsTitle => 'Backend / asset diagnostics';

  @override
  String get backendDiagnosticsEmpty =>
      'Tap Read to fetch the backend node, data path, model, character card, lorebook, jailbreak and Dream configuration.';

  @override
  String get diagnosticBackendNode => 'Backend node';

  @override
  String get diagnosticDataPath => 'Data path';

  @override
  String get diagnosticNoPermission =>
      'No permission (expected with a mobile token)';

  @override
  String get diagnosticMetaMode => 'Meta mode';

  @override
  String get diagnosticDangerMode => 'Danger mode';

  @override
  String get diagnosticSafeMode => 'Safe mode';

  @override
  String get diagnosticModel => 'Model';

  @override
  String get diagnosticShortTermRounds => 'Short-term rounds';

  @override
  String get diagnosticCharacterCard => 'Character card';

  @override
  String get diagnosticLorebook => 'Lorebook';

  @override
  String get diagnosticJailbreak => 'Jailbreak';

  @override
  String diagnosticEntries(int count) {
    return '$count entries';
  }

  @override
  String get diagnosticDream => 'Dream';

  @override
  String get diagnosticDreamLorebook => 'Dream lorebook';

  @override
  String get enabledShortStatus => 'Enabled';

  @override
  String get disabledShortStatus => 'Disabled';

  @override
  String get diagnosticDreamLayer => 'Dream layer';

  @override
  String get diagnosticDreamJailbreak => 'Dream jailbreak';

  @override
  String get diagnosticPhoneControlTool =>
      'Phone control · character authorized';

  @override
  String get diagnosticPhoneControlVision => 'Phone control · vision model';

  @override
  String get capabilityDeveloperDiagnosticsTitle => 'Developer diagnostics';

  @override
  String get capabilityDeveloperDiagnosticsSubtitle =>
      'Off by default; enables diagnostics that can start test behavior.';

  @override
  String get phoneControlTestTitle => 'Phone control test';

  @override
  String get phoneControlTestDescription =>
      'Skips the LLM decision and in-chat confirmation, starting a phone automation task directly; danger mode must still be enabled on the backend first, or it\'s refused in safe mode.';

  @override
  String get phoneControlTestHint =>
      'Task description, e.g. order me a bubble tea';

  @override
  String get phoneControlTestButton => 'Start test task';

  @override
  String get phoneControlTestEmptyTask => 'Describe the task to test first';

  @override
  String get capabilityLastPollNone => 'Latest fallback poll: none';

  @override
  String capabilityLastPoll(String time) {
    return 'Latest fallback poll: $time';
  }

  @override
  String get capabilityLastErrorNone => 'Latest error: none';

  @override
  String capabilityLastError(String error) {
    return 'Latest error: $error';
  }

  @override
  String get capabilityNativeRelayRunning => 'Native relay service is running';

  @override
  String get capabilityNativeRelayStopped =>
      'Native relay service is stopped; Flutter checks proactive messages every 5 seconds in foreground';

  @override
  String get capabilityGateTestOn =>
      'Test mode is on: quiet hours and the 30-minute cooldown are bypassed';

  @override
  String get capabilityGateTestOff =>
      'Test mode is off: quiet hours 23:30–06:30; regular notifications are 30 minutes apart';

  @override
  String get noneStatus => 'None';

  @override
  String capabilityGateSummary(String mode, int count, String reason) {
    return '$mode.\nSuppressed: $count / Latest reason: $reason';
  }

  @override
  String capabilityOverlayLastError(String base, String time, String error) {
    return '$base\nPermission is granted, but the latest overlay failed$time: $error';
  }

  @override
  String get capabilitySignalNone => 'Latest signal: none';

  @override
  String capabilitySignalTime(String time) {
    return 'Latest signal: $time';
  }

  @override
  String get capabilityHeartbeatNone => 'Latest relay heartbeat: none';

  @override
  String capabilityHeartbeatTime(String time) {
    return 'Latest relay heartbeat: $time';
  }

  @override
  String capabilityRelayLastError(String error) {
    return '\nLatest relay error: $error';
  }

  @override
  String get capabilityRelayConfigWarning =>
      '\nConnected does not mean the backend is configured; ensure backend relay_base_url and relay_topic match exactly.';

  @override
  String capabilityLoopbackHint(String url) {
    return '$url · Real-device debugging requires adb reverse tcp:8080 tcp:8080';
  }

  @override
  String capabilityRemoteHint(String url) {
    return '$url · LAN/VPN/tunnel address must be reachable';
  }

  @override
  String get notEnabledStatus => 'Not enabled';

  @override
  String get sandboxSuffix => '  ⚠ Sandbox';

  @override
  String diagnosticReadError(String label, String message) {
    return '$label: read failed — $message';
  }

  @override
  String get backgroundTestPresenceMessage =>
      'I\'m here. It\'s okay if you don\'t feel like talking.';

  @override
  String get backgroundTestLockMessage =>
      'It\'s getting late. Would you like me to lock the screen?';

  @override
  String get backgroundTestTakeoutMessage =>
      'You haven\'t eaten yet. Want me to open the takeout page?';

  @override
  String get backgroundTestDefaultMessage =>
      'I sent you a message earlier. You can read it when you get back.';

  @override
  String get checkingStatus => 'Checking';

  @override
  String get notRunStatus => 'Not run';

  @override
  String chatTodayLine(String date, String time) {
    return 'Today · $date · $time';
  }

  @override
  String get moodNeutral => 'Calm';

  @override
  String get moodGentle => 'Gentle';

  @override
  String get moodThinking => 'Thoughtful';

  @override
  String get moodHappy => 'Happy';

  @override
  String get moodSad => 'A little sad';

  @override
  String get moodSurprised => 'A little surprised';

  @override
  String get moodAngry => 'A little upset';

  @override
  String get moodSleepy => 'Sleepy';

  @override
  String get moodYandere => 'Intense';

  @override
  String oemBackgroundGuide(String appName) {
    return 'Vendor background allowlist reference:\nXiaomi: Settings → Apps → Manage apps → $appName → Battery saver/Autostart → No restrictions and enable autostart\nOPPO: Settings → Apps → Autostart/Power usage → $appName → Allow background activity\nvivo: Settings → Battery → Background power usage → $appName → Allow high background power usage\nHuawei: Settings → Apps & services → App launch → $appName → Manage manually and allow background activity';
  }

  @override
  String get settingsChatSection => 'Chat & Stickers';

  @override
  String get settingsStickerTitle => 'Receive stickers';

  @override
  String get settingsStickerSubtitle =>
      'Disable to stop receiving sticker messages';

  @override
  String get settingsAutoPlayVoiceTitle => 'Auto-play voice';

  @override
  String get settingsAutoPlayVoiceSubtitle =>
      'Enable when voice is available on the backend';
}
