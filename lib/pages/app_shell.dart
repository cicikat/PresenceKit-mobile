import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/chat_controller.dart';
import '../controllers/connection_controller.dart';
import '../controllers/device_controller.dart';
import '../controllers/dream_controller.dart';
import '../controllers/diary_controller.dart';
import '../controllers/garden_controller.dart';
import '../controllers/locale_controller.dart';
import '../controllers/prompt_entries_controller.dart';
import '../controllers/profile_status_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/voice_input_controller.dart';
import '../models/app_models.dart';
import '../models/background_status.dart';
import '../models/capability_status.dart';
import '../models/screen_context.dart';
import '../l10n/l10n.dart';
import '../services/app_settings_store.dart';
import '../services/backend_client.dart';
import '../services/character_naming.dart';
import '../services/device_services.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/capability_widgets.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/common_widgets.dart';
import '../widgets/diary_widgets.dart';
import '../widgets/drawer_widgets.dart';
import '../widgets/dream_widgets.dart';
import '../widgets/garden_widgets.dart';
import '../widgets/group_widgets.dart';
import '../widgets/profile_widgets.dart';
import '../widgets/settings_dialog_widgets.dart';
import '../widgets/settings_editor_widgets.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/theme_widgets.dart';
import '../widgets/upload_feedback_widgets.dart';

class CompanionApp extends StatefulWidget {
  const CompanionApp({
    super.key,
    this.settingsStore = const AppSettingsStore(),
    this.backendClient,
    this.localeController,
  });

  final AppSettingsStore settingsStore;
  final BackendClient? backendClient;
  final LocaleController? localeController;

  @override
  State<CompanionApp> createState() => _CompanionAppState();
}

class _CompanionAppState extends State<CompanionApp>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _sensorPushTimer;
  AppRoute _route = AppRoute.chat;
  bool _backgroundNotifications = true;
  bool _stickerEnabled = false;
  bool _autoPlayVoice = false;
  bool _backendSyncStarted = false;
  bool _loadingPromptAssets = false;
  bool _savingPromptAssets = false;
  String? _backendError;
  String? _promptAssetsError;
  PromptAssets? _promptAssets;
  String? _profileNameOverride;
  Uint8List? _profileAvatarBytes;
  late final SettingsStore _settings;
  late final DeviceControlService _deviceService;
  late final ScreenSensorService _screenService;
  late final RelayStatusService _relayService;
  late final ConnectionController _connectionController;
  late final DeviceController _deviceController;
  late final VoiceService _voiceService;
  late final VoiceInputController _voiceInputController;
  late final ChatController _chatController;
  late final DreamController _dreamController;
  late final GardenController _gardenController;
  late final DiaryController _diaryController;
  YxPrefs _prefs = const YxPrefs();
  late final ThemeController _themeController;
  late final PromptEntriesController _promptEntries;
  late final ProfileStatusController _profileStatusController;
  late final LocaleController _localeController;
  late final bool _ownsLocaleController;

  BackendClient get _backend => _connectionController.backend;
  String get _backendBaseUrl => _connectionController.baseUrl;
  String get _adminToken => _connectionController.token;
  String get _ownerUserId => _connectionController.ownerUserId;
  YxPalette get c {
    final custom = _themeController.activePalette;
    if (custom != null) return custom;
    return _themeController.isDark ? YxPalette.dark : YxPalette.light;
  }

  bool get _hasAdminToken => _adminToken.trim().isNotEmpty;

  bool get _hasProfileNameOverride =>
      cleanCharacterDisplayName(_profileNameOverride) != null;

  String? get _backendCharacterDisplayName {
    final assets = _promptAssets;
    if (assets == null) return null;
    for (final character in assets.characters) {
      if (character.id == assets.activeCharacter) return character.label;
    }
    return null;
  }

  String get _profileDisplayName => resolveCharacterDisplayName(
    localOverride: _profileNameOverride,
    backendName: _backendCharacterDisplayName,
  );

  /// Pushes the resolved display name to native prefs so background push
  /// notifications (`MobileNotificationService`) can title themselves with
  /// the character's name instead of the generic app label. Call after any
  /// state change that can affect [_profileDisplayName] (nickname override,
  /// prompt assets load/switch).
  void _syncCachedCharacterDisplayName() {
    unawaited(_settings.cacheCharacterDisplayName(_profileDisplayName));
  }

  String _requireAdminToken() {
    final token = _adminToken.trim();
    if (token.isEmpty) {
      throw const BackendException('Please enter an access credential first');
    }
    return token;
  }

  @override
  void initState() {
    super.initState();
    _ownsLocaleController = widget.localeController == null;
    _localeController = widget.localeController ?? LocaleController();
    if (!_localeController.loaded) unawaited(_localeController.load());
    final settingsStore = widget.settingsStore;
    _settings = SettingsStore(settingsStore);
    _themeController = ThemeController(
      loadPersisted: _settings.loadCustomThemePalette,
      savePersisted: _settings.saveCustomThemePalette,
    );
    _themeController.addListener(_handleThemeChanged);
    _promptEntries = PromptEntriesController(
      backend: () => _backend,
      token: () => _adminToken,
    );
    _promptEntries.addListener(_handlePromptEntriesChanged);

    _deviceService = DeviceControlService(settingsStore);
    _screenService = ScreenSensorService(settingsStore);
    _relayService = RelayStatusService(settingsStore);
    _connectionController = ConnectionController(
      settingsStore: settingsStore,
      backendClient: widget.backendClient,
    );
    _profileStatusController = ProfileStatusController(
      backend: () => _backend,
      token: () => _adminToken,
    );
    _profileStatusController.addListener(_handleProfileStatusChanged);
    _voiceService = VoiceService(settingsStore);
    _deviceController = DeviceController(
      device: _deviceService,
      screen: _screenService,
      backend: () => _backend,
      token: () => _adminToken,
    );
    _chatController = ChatController(
      backend: () => _backend,
      token: () => _adminToken,
      settings: _settings,
      relay: _relayService,
      voice: _voiceService,
      stickerEnabled: () => _stickerEnabled,
      autoPlayVoice: () => _autoPlayVoice,
    );
    _voiceInputController = VoiceInputController(
      voice: _voiceService,
      backend: () => _backend,
      token: () => _adminToken,
    );
    _dreamController = DreamController(
      backend: () => _backend,
      token: () => _adminToken,
    );
    _gardenController = GardenController(
      backend: () => _backend,
      token: () => _adminToken,
    );
    _diaryController = DiaryController(
      backend: () => _backend,
      token: () => _adminToken,
    );
    WidgetsBinding.instance.addObserver(this);
    _applySystemUi();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applySystemUi());
    unawaited(_restoreBackendAndStart());
  }

  Future<void> _consumeNotificationOpen() async {
    if (!_hasAdminToken ||
        !await _relayService.consumePendingOpenLatestMessage()) {
      return;
    }
    await _chatController.start();
    await _chatController.catchUpFromNotification();
  }

  Future<void> _restoreBackendAndStart() async {
    await Future.wait([
      _connectionController.restore(),
      _deviceController.restore(),
      _themeController.restore(),
    ]);
    final storedName = await _settings.loadProfileName();
    final storedAvatar = await _settings.loadAvatar();
    final backgroundNotifications = await _settings
        .loadBackgroundNotificationsEnabled();
    final stickerEnabled = await _settings.loadStickerEnabled();
    final autoPlayVoice = await _settings.loadAutoPlayVoice();
    if (mounted) {
      setState(() {
        _backgroundNotifications = backgroundNotifications;
        _stickerEnabled = stickerEnabled;
        _autoPlayVoice = autoPlayVoice;
        _profileNameOverride = storedName;
        _profileAvatarBytes = storedAvatar;
      });
      _syncCachedCharacterDisplayName();
    }
    if (!mounted) return;
    if (_hasAdminToken) {
      _startBackendSync();
      await _consumeNotificationOpen();
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_openAdminTokenSettings(required: true)),
      );
    }
  }

  void _startBackendSync() {
    if (!_hasAdminToken) return;
    _backendSyncStarted = true;
    unawaited(_chatController.start());
    unawaited(_gardenController.start());
    unawaited(
      _deviceController.restore().then((_) => _deviceController.start()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applySystemUi();
      if (_hasAdminToken) {
        _chatController.resumePolling();
        unawaited(_consumeNotificationOpen());
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _chatController.pausePolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gardenController.dispose();
    _diaryController.dispose();
    _sensorPushTimer?.cancel();
    _deviceController.dispose();
    _voiceInputController.dispose();
    _chatController.dispose();
    _dreamController.dispose();
    _themeController.removeListener(_handleThemeChanged);
    _themeController.dispose();
    _promptEntries.removeListener(_handlePromptEntriesChanged);
    _promptEntries.dispose();
    _profileStatusController.removeListener(_handleProfileStatusChanged);
    _profileStatusController.dispose();
    if (_ownsLocaleController) _localeController.dispose();
    super.dispose();
  }

  void _handleThemeChanged() {
    if (!mounted) return;
    setState(() {});
    _applySystemUi();
  }

  @override
  void didChangePlatformBrightness() {
    _themeController.updateSystemBrightness();
    _applySystemUi();
  }

  void _handlePromptEntriesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleProfileStatusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _applySystemUi() {
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    final effectivePalette = c;
    final effectiveDark =
        ThemeData.estimateBrightnessForColor(effectivePalette.surface) ==
        Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: effectiveDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: effectivePalette.surface,
        systemNavigationBarIconBrightness: effectiveDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  Future<String?> _normalizeBackendBaseUrl(String raw) =>
      _connectionController.normalizeBaseUrl(raw);

  Future<bool> _ensureTrustedBackendOrigin(String normalized) async {
    if (await _connectionController.isAllowedBaseUrl(normalized)) return true;
    final origin = await _connectionController.normalizeBaseUrl(normalized);
    if (origin == null ||
        !await _connectionController.canConfirmPrivateCleartextOrigin(origin)) {
      return false;
    }
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        scrollable: true,
        title: const Text('Confirm trusted HTTP origin'),
        content: Text(
          'This origin uses cleartext HTTP:\n$origin\n\n'
          'Only continue if you control this exact node and accept that '
          'traffic may be visible on the network.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Trust this exact origin'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    return await _connectionController.trustCleartextOrigin(origin) && mounted;
  }

  Future<void> _changeBackendBaseUrl(String raw) async {
    final normalized = await _normalizeBackendBaseUrl(raw);
    if (normalized == null) {
      setState(() => _backendError = context.l10n.backendInvalidAddress);
      return;
    }
    if (!await _ensureTrustedBackendOrigin(normalized)) {
      if (mounted) {
        setState(() => _backendError = 'Backend origin was not trusted');
      }
      return;
    }
    if (normalized == _backendBaseUrl) return;

    _gardenController.stop();
    _chatController.pausePolling();
    final previousBackend = _backend;
    if (_hasAdminToken) {
      unawaited(
        previousBackend
            .deactivateMobile(token: _adminToken)
            .then<void>((_) {})
            .catchError((_) {}),
      );
    }
    setState(() {
      _backendError = null;
      _gardenController.error = null;
      _diaryController.error = null;
      _gardenController.state = null;
      _diaryController.loaded = false;
      _diaryController.entries.clear();
    });
    await _connectionController.saveBaseUrl(normalized);
    await _chatController.resetForConnectionChange();
    if (!mounted) return;
    if (_hasAdminToken) _startBackendSync();
  }

  Future<void> _openAdminTokenSettings({bool required = false}) async {
    if (!mounted) return;
    final savedToken = await showDialog<String>(
      barrierDismissible: !required,
      context: context,
      builder: (_) => AdminTokenDialog(
        c: c,
        required: required,
        onSave: _connectionController.saveToken,
      ),
    );
    if (savedToken == null || !mounted) return;
    final shouldStartSync = !_backendSyncStarted;
    _backendError = null;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (!mounted) return;
        Navigator.maybeOf(
          context,
          rootNavigator: true,
        )?.popUntil((route) => route.isFirst);
        if (shouldStartSync) {
          _startBackendSync();
        } else {
          setState(() {});
        }
      }),
    );
  }

  Future<void> _changeBackgroundNotifications(bool enabled) async {
    setState(() => _backgroundNotifications = enabled);
    await _settings.saveBackgroundNotificationsEnabled(enabled);
    if (!mounted) return;
    if (enabled) {
      await _deviceService.requestNotificationPermission();
    } else {
      await _deviceService.stopBackgroundNotifications();
    }
  }

  Future<void> _changeScreenContextUploadEnabled(bool enabled) async {
    await _deviceController.setScreenUploadEnabled(enabled);
    if (enabled) unawaited(_deviceController.pushScreenContext(silent: true));
  }

  Future<void> _openThemePresetManager({bool? selectingDark}) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ThemePresetManagerSheet(
        c: c,
        controller: _themeController,
        selectingDark: selectingDark,
      ),
    );
  }

  Future<void> _lockScreenNow() async {
    final locked = await _deviceController.lockScreen();
    if (!mounted) return;
    if (!locked) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.deviceAdminRequired)));
    }
  }

  Future<void> _requestOrderAssistantPermission() async {
    final enabled = await _deviceController.isAccessibilityEnabled();
    if (!mounted) return;
    if (enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.accessibilityAuthorized)),
      );
      return;
    }
    await _deviceController.requestAccessibilityPermission();
  }

  Future<void> _openShoppingApp(String target, String label) async {
    final opened = await _deviceController.openShoppingApp(target);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.shoppingAppMissing(label))),
      );
    }
  }

  Future<void> _showOrderBubble(String target, String label) async {
    final shown = await _deviceController.showOrderBubble(target);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shown
              ? context.l10n.orderBubbleShown(label)
              : context.l10n.overlayPermissionRequired,
        ),
      ),
    );
  }

  // ── W9：语音输入 ──────────────────────────────────────────────────────────

  Future<String?> _startVoiceRecording() => _voiceInputController.start();
  Future<VoiceInputResult> _stopVoiceRecordingAndTranscribe() =>
      _voiceInputController.stopAndTranscribe();
  Future<void> _pushScreenContextOnce({bool silent = false}) async {
    await _deviceController.pushScreenContext(silent: silent);
    if (!silent && mounted && _deviceController.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.screenPushFailed(_deviceController.lastError ?? ''),
          ),
        ),
      );
    }
  }

  Future<ScreenContextSnapshot?> _captureScreenContextForDebug({
    bool silent = false,
  }) async {
    if (!await _deviceController.isAccessibilityEnabled()) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.accessibilityRequiredForScreen)),
        );
      }
      return null;
    }
    final snapshot = await _deviceController.captureForDebug();
    if ((snapshot == null || snapshot.isEmpty) && !silent && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.screenContextEmpty)));
    }
    return snapshot;
  }

  Future<void> _pushScreenContextSnapshot(
    ScreenContextSnapshot snapshot, {
    bool silent = false,
  }) async {
    await _deviceController.pushSnapshot(snapshot, silent: silent);
    if (!silent && mounted && _deviceController.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.screenPushFailed(_deviceController.lastError ?? ''),
          ),
        ),
      );
    }
  }

  Future<void> _pushBehaviorTest(String kind) async {
    final spec = BehaviorTestSpec.forKind(kind, context.l10n);
    try {
      await _backend.pushMobileBehaviorTest(
        token: _requireAdminToken(),
        userId: _ownerUserId,
        content: spec.content,
        kind: spec.kind,
        delivery: spec.delivery,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.behaviorTestQueued(spec.label))),
      );
      await _chatController.pollIfBackgroundUnavailable();
    } on BackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.behaviorTestFailed(e.message))),
      );
    }
  }

  Future<void> _editProfileName() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => ProfileNameDialog(
        c: c,
        initialName: cleanCharacterDisplayName(_profileNameOverride) ?? '',
      ),
    );
    if (value == null) return;
    final cleaned = cleanCharacterDisplayName(value);
    await _settings.saveProfileName(cleaned ?? '');
    if (!mounted) return;
    setState(() => _profileNameOverride = cleaned);
    _syncCachedCharacterDisplayName();
  }

  Future<void> _importProfileAvatar() async {
    final sourceBytes = await _settings.pickProfileImage();
    if (!mounted || sourceBytes == null) return;
    final cropped = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AvatarCropDialog(c: c, bytes: sourceBytes),
    );
    if (!mounted || cropped == null) return;
    final saved = await _settings.saveAvatar(cropped);
    if (!mounted) return;
    if (saved) {
      setState(() => _profileAvatarBytes = cropped);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.avatarSaveFailed)));
    }
  }

  Future<void> _resetProfileAvatar() async {
    await _settings.deleteAvatar();
    if (!mounted) return;
    setState(() => _profileAvatarBytes = null);
  }

  Future<CapabilityStatus> _loadCapabilityStatus() async {
    final results = await Future.wait<dynamic>([
      _deviceService.areNotificationsEnabled(),
      _deviceService.canDrawOverlays(),
      _deviceController.isAccessibilityEnabled(),
      _deviceService.isDeviceAdminActive(),
      _relayService.isBackgroundServiceRunning(),
      _relayService.loadBackgroundPollStatus(),
      _relayService.loadConnectionStatus(),
      _relayService.loadNotificationGateStatus(),
      _deviceService.isIgnoringBatteryOptimizations(),
      _deviceService.loadLastOverlayError(),
    ]);
    return CapabilityStatus(
      notificationsEnabled: results[0] as bool,
      overlayEnabled: results[1] as bool,
      accessibilityEnabled: results[2] as bool,
      deviceAdminEnabled: results[3] as bool,
      backgroundNotificationsEnabled: _backgroundNotifications,
      backgroundServiceRunning: results[4] as bool,
      backgroundPollStatus: results[5] as BackgroundPollStatus,
      relayConnectionStatus: results[6] as RelayConnectionStatus,
      notificationGateStatus: results[7] as NotificationGateStatus,
      overlayErrorStatus: results[9] as OverlayErrorStatus,
      ignoringBatteryOptimizations: results[8] as bool,
      screenContextUploadEnabled: _deviceController.screenUploadEnabled,
      backendBaseUrl: _backendBaseUrl,
      backendReachable:
          _chatController.mobileError == null &&
          (_chatController.mobileActive ||
              _chatController.historyLoaded ||
              _gardenController.state != null),
      backendBusy:
          _chatController.pollingMobile ||
          _chatController.loadingHistory ||
          _gardenController.loading,
      backendError:
          _chatController.mobileError ??
          _backendError ??
          _chatController.historyError,
    );
  }

  Future<void> _testBackendConnectivity() async {
    await _chatController.activateMobile();
    if (!mounted) return;
    await Future.wait([
      _chatController.loadHistory(),
      _gardenController.load(),
    ]);
  }

  void _openCapabilityCheck() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CapabilitySheet(
        c: c,
        onLoadStatus: _loadCapabilityStatus,
        onRequestNotifications: _deviceService.requestNotificationPermission,
        onRequestIgnoreBatteryOptimizations:
            _deviceService.requestIgnoreBatteryOptimizations,
        onRequestOverlay: _deviceService.requestOverlayPermission,
        onRequestAccessibility: _deviceService.requestAccessibilityPermission,
        onRequestDeviceAdmin: _deviceService.requestDeviceAdmin,
        onToggleBackgroundNotifications: _changeBackgroundNotifications,
        onToggleScreenContextUpload: _changeScreenContextUploadEnabled,
        onTestBackend: _testBackendConnectivity,
        onPushScreenContext: () => _pushScreenContextOnce(silent: false),
        onCaptureScreenContext: () =>
            _captureScreenContextForDebug(silent: false),
        onPushCapturedScreenContext: (snapshot) =>
            _pushScreenContextSnapshot(snapshot, silent: false),
        onPushBehaviorTest: _pushBehaviorTest,
        onDebugBackgroundDelivery: _deviceService.debugBackgroundDelivery,
        onLoadBehaviorStatus: () =>
            _backend.loadBehaviorDecisionStatus(token: _requireAdminToken()),
        onFetchDiagnostics: () =>
            _backend.fetchDiagnostics(token: _requireAdminToken()),
        onTestPhoneControl: (task) => _backend.debugStartPhoneControl(
          task: task,
          token: _requireAdminToken(),
        ),
        onEditBackend: _openBackendSettings,
        historyLoaded: _chatController.historyLoaded,
        loadingHistory: _chatController.loadingHistory,
        historyError: _chatController.historyError,
        gardenLoaded: _gardenController.state != null,
        loadingGarden: _gardenController.loading,
        gardenError: _gardenController.error,
        mobileActive: _chatController.mobileActive,
        pollingMobile: _chatController.pollingMobile,
        mobileError: _chatController.mobileError,
        mobileReceivedCount: _chatController.mobileReceivedCount,
        lastMobileContent: _chatController.lastMobileContent,
      ),
    );
  }

  void _openProfilePage() {
    Navigator.of(context).maybePop();
    setState(() => _route = AppRoute.profile);
    unawaited(_profileStatusController.load());
  }

  static final RegExp _safeOwnerUserIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');
  static final RegExp _safeRelayTopicPattern = RegExp(r'^[a-z0-9/_-]+$');

  Future<void> _openBackendSettings() async {
    final result = await showDialog<BackendSettingsResult>(
      context: context,
      builder: (_) => BackendSettingsDialog(
        c: c,
        initialBaseUrl: _backendBaseUrl,
        initialOwnerUserId: _ownerUserId,
        normalizeBaseUrl: _normalizeBackendBaseUrl,
        isOwnerUserIdValid: _safeOwnerUserIdPattern.hasMatch,
      ),
    );
    if (result == null || !mounted) return;
    if (result.ownerUserId != _ownerUserId) {
      await _connectionController.saveOwnerUserId(result.ownerUserId);
      if (!mounted) return;
      setState(() {});
    }
    unawaited(_changeBackendBaseUrl(result.baseUrl));
  }

  Future<void> _openRelaySettings() async {
    final result = await showDialog<RelaySettingsResult>(
      context: context,
      builder: (_) => RelaySettingsDialog(
        c: c,
        initialBaseUrl: _connectionController.relayBaseUrl,
        initialTopic: _connectionController.relayTopic,
        initialToken: _connectionController.relayToken,
        normalizeBaseUrl: _normalizeBackendBaseUrl,
        ensureTrustedOrigin: _ensureTrustedBackendOrigin,
        isTopicValid: (topic) =>
            _safeRelayTopicPattern.hasMatch(topic) && topic.length <= 128,
      ),
    );
    if (result == null || !mounted) return;
    await _connectionController.saveRelay(
      baseUrl: result.baseUrl,
      topic: result.topic,
      token: result.token,
    );
  }

  Future<void> _wakeFromDream() async {
    final result = await _dreamController.wake();
    if (!mounted || result == null || result.exited || !result.retained) {
      await _exitDreamAndRoute(AppRoute.chat, callBackendExit: result == null);
      return;
    }
    final stay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          DreamLeaveDialog(c: c, retentionText: result.retentionText),
    );
    if (!mounted) return;
    if (stay == true) {
      await _dreamController.resume();
    } else {
      await _exitDreamAndRoute(AppRoute.chat);
    }
  }

  Future<void> _exitDreamAndRoute(
    AppRoute route, {
    bool callBackendExit = true,
  }) async {
    await _dreamController.exit(callBackendExit: callBackendExit);
    if (mounted) setState(() => _route = route);
  }

  Future<void> _loadPromptAssets() async {
    if (_loadingPromptAssets || !_hasAdminToken) return;
    setState(() {
      _loadingPromptAssets = true;
      _promptAssetsError = null;
    });
    try {
      final assets = await _backend.loadPromptAssets(
        token: _requireAdminToken(),
      );
      if (!mounted) return;
      setState(() => _promptAssets = assets);
      _syncCachedCharacterDisplayName();
    } on BackendException catch (e) {
      if (mounted) setState(() => _promptAssetsError = e.message);
    } finally {
      if (mounted) setState(() => _loadingPromptAssets = false);
    }
  }

  Future<void> _updatePromptAssets({String? activeCharacter}) async {
    if (_savingPromptAssets || !_hasAdminToken) return;
    setState(() {
      _savingPromptAssets = true;
      _promptAssetsError = null;
    });
    try {
      final assets = await _backend.updatePromptAssets(
        token: _requireAdminToken(),
        activeCharacter: activeCharacter,
      );
      if (!mounted) return;
      setState(() => _promptAssets = assets);
      _syncCachedCharacterDisplayName();
    } on BackendException catch (e) {
      if (mounted) setState(() => _promptAssetsError = e.message);
    } finally {
      if (mounted) setState(() => _savingPromptAssets = false);
    }
  }

  void _openSettings() {
    var requestedBackendSettings = false;
    var notificationTestMode = false;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => StatefulBuilder(
          builder: (context, sheetSetState) {
            if (!requestedBackendSettings) {
              requestedBackendSettings = true;
              unawaited(() async {
                final results = await Future.wait<dynamic>([
                  _loadPromptAssets(),
                  _promptEntries.load(),
                  _dreamController.loadSettings(),
                  _relayService.loadNotificationGateStatus(),
                ]);
                notificationTestMode =
                    (results[3] as NotificationGateStatus).testModeEnabled;
                if (context.mounted) sheetSetState(() {});
              }());
            }

            void updatePrefs(YxPrefs prefs) {
              sheetSetState(() => _prefs = prefs);
              setState(() {});
            }

            void updateTheme(bool dark) {
              unawaited(
                _themeController.setMode(
                  dark ? AppThemeMode.dark : AppThemeMode.light,
                ),
              );
            }

            void manageThemes(bool selectingDark) {
              Navigator.pop(context);
              unawaited(_openThemePresetManager(selectingDark: selectingDark));
            }

            return SettingsPage(
              c: c,
              language: _localeController.language,
              dark: _themeController.isDark,
              lightThemePresetName: _themeController.lightThemePreset?.name,
              darkThemePresetName: _themeController.darkThemePreset?.name,
              themePresetCount: _themeController.presets.length,
              prefs: _prefs,
              profileDisplayName: _profileDisplayName,
              profileAvatarBytes: _profileAvatarBytes,
              promptAssets: _promptAssets,
              loreEntries: _promptEntries.loreEntries,
              jailbreakEntries: _promptEntries.jailbreakEntries,
              dreamSettings: _dreamController.settings,
              settingsBusy:
                  _loadingPromptAssets ||
                  _savingPromptAssets ||
                  _dreamController.loadingSettings ||
                  _dreamController.savingSettings,
              settingsError:
                  _promptAssetsError ??
                  _promptEntries.error ??
                  _dreamController.settingsError,
              promptEntriesSaving: _promptEntries.saving,
              onTheme: updateTheme,
              onLanguage: (language) {
                unawaited(_localeController.setLanguage(language));
                sheetSetState(() {});
              },
              onManageThemes: () => manageThemes(_themeController.isDark),
              onManageThemesForMode: manageThemes,
              onPrefs: updatePrefs,
              onEditProfileName: _editProfileName,
              onImportProfileAvatar: _importProfileAvatar,
              onResetProfileAvatar: _resetProfileAvatar,
              onOpenProfile: _openProfilePage,
              hasAdminToken: _hasAdminToken,
              backgroundNotifications: _backgroundNotifications,
              backendBaseUrl: _backendBaseUrl,
              ownerUserId: _ownerUserId,
              notificationTestMode: notificationTestMode,
              onEditCredential: _openAdminTokenSettings,
              onEditBackend: _openBackendSettings,
              onEditRelay: _openRelaySettings,
              onBackgroundNotifications: (enabled) {
                sheetSetState(() => _backgroundNotifications = enabled);
                unawaited(_changeBackgroundNotifications(enabled));
              },
              onNotificationTestMode: (enabled) {
                sheetSetState(() => notificationTestMode = enabled);
                unawaited(_deviceService.setNotificationTestMode(enabled));
              },
              onOpenCapabilities: _openCapabilityCheck,
              stickerEnabled: _stickerEnabled,
              autoPlayVoice: _autoPlayVoice,
              onStickerEnabledChanged: (enabled) {
                sheetSetState(() => _stickerEnabled = enabled);
                unawaited(_settings.saveStickerEnabled(enabled));
              },
              onAutoPlayVoiceChanged: (enabled) {
                sheetSetState(() => _autoPlayVoice = enabled);
                unawaited(_settings.saveAutoPlayVoice(enabled));
              },
              onToggleLorebook: (id) {
                unawaited(() async {
                  await _promptEntries.toggleLore(id);
                  if (context.mounted) sheetSetState(() {});
                }());
              },
              onToggleJailbreak: (id) {
                unawaited(() async {
                  await _promptEntries.toggleJailbreak(id);
                  if (context.mounted) sheetSetState(() {});
                }());
              },
              onDreamLorebook: (value) {
                unawaited(() async {
                  await _dreamController.updateSettings(
                    enableDreamLorebook: value,
                  );
                  if (context.mounted) sheetSetState(() {});
                }());
              },
              onDreamWorldLayer: (value) {
                unawaited(() async {
                  await _dreamController.updateSettings(worldLayer: value);
                  if (context.mounted) sheetSetState(() {});
                }());
              },
              onDreamJailbreak: (value) {
                unawaited(() async {
                  await _dreamController.updateSettings(jailbreakPreset: value);
                  if (context.mounted) sheetSetState(() {});
                }());
              },
            );
          },
        ),
      ),
    );
  }

  void _openAttach() {
    if (!_hasAdminToken) {
      unawaited(_openAdminTokenSettings(required: true));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AttachSheet(
        c: c,
        onUploadFile: () {
          Navigator.pop(context);
          unawaited(_pickAndUploadFile());
        },
        onUploadImages: () {
          Navigator.pop(context);
          unawaited(_pickAndUploadImages());
        },
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    if (_chatController.sending) return;
    final picked = await _settings.pickUploadFile();
    if (!mounted || picked == null) return;
    final lowerName = picked.name.toLowerCase();
    const supported = ['.txt', '.md', '.docx'];
    if (!supported.any(lowerName.endsWith)) {
      UploadFeedback.fileTypeUnsupported(context);
      return;
    }
    if (picked.bytes.length > 5 * 1024 * 1024) {
      UploadFeedback.fileTooLarge(context);
      return;
    }
    await _chatController.uploadFiles(
      [picked],
      preview: UploadFeedback.filePreview(picked.name),
      failureLabel: UploadFeedback.fileFailureLabel(context),
    );
  }

  Future<void> _pickAndUploadImages() async {
    if (_chatController.sending) return;
    final picked = await _settings.pickUploadImages();
    if (!mounted || picked.isEmpty) return;
    const supported = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.heic',
      '.heif',
      '.bmp',
    ];
    if (picked.any(
      (file) => !supported.any(file.name.toLowerCase().endsWith),
    )) {
      UploadFeedback.imageTypeUnsupported(context);
      return;
    }
    if (picked.any((file) => file.bytes.length > 10 * 1024 * 1024)) {
      UploadFeedback.imageTooLarge(context);
      return;
    }
    final names = picked.length == 1
        ? picked.first.name
        : picked.take(3).map((file) => file.name).join('、');
    final preview = UploadFeedback.imagePreview(
      context,
      count: picked.length,
      names: names,
      hasMore: picked.length > 3,
    );
    await _chatController.uploadFiles(
      picked,
      preview: preview,
      failureLabel: UploadFeedback.imageFailureLabel(context),
    );
  }

  void _pickRoute(AppRoute route) {
    if (_route == AppRoute.dream && route != AppRoute.dream) {
      _scaffoldKey.currentState?.closeDrawer();
      unawaited(_exitDreamAndRoute(route));
      return;
    }
    setState(() => _route = route);
    _scaffoldKey.currentState?.closeDrawer();
    if (route == AppRoute.dream) {
      _dreamController.startPolling();
    } else {
      _dreamController.stopPolling();
    }
    if (route == AppRoute.garden) {
      unawaited(_gardenController.load(silent: true));
    } else if (route == AppRoute.diary) {
      unawaited(_diaryController.load(silent: true));
    } else if (route == AppRoute.profile) {
      unawaited(_loadPromptAssets());
      unawaited(_profileStatusController.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _themeController.isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: c.surface,
        systemNavigationBarIconBrightness: _themeController.isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: YxDrawer(
          c: c,
          route: _route,
          profileDisplayName: _profileDisplayName,
          profileAvatarBytes: _profileAvatarBytes,
          onRoute: _pickRoute,
          onOpenSettings: _openSettings,
        ),
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          color: c.surface,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildRoute(),
                  ),
                ),
                NavPill(c: c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoute() {
    switch (_route) {
      case AppRoute.chat:
        return ChatScene(
          key: const ValueKey('chat'),
          c: c,
          dark: _themeController.isDark,
          prefs: _prefs,
          profileDisplayName: _profileDisplayName,
          profileAvatarBytes: _profileAvatarBytes,
          controller: _chatController,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          onOpenSettings: _openSettings,
          onOpenAttach: _openAttach,
          onToggleTheme: () => unawaited(_themeController.toggleMode()),
          onLockNow: () => unawaited(_lockScreenNow()),
          onOpenOrderAccessibility: () =>
              unawaited(_requestOrderAssistantPermission()),
          onOpenMeituan: () =>
              unawaited(_openShoppingApp('meituan', context.l10n.meituanName)),
          onOpenTaobao: () =>
              unawaited(_openShoppingApp('taobao', context.l10n.taobaoName)),
          onShowOrderBubble: () =>
              unawaited(_showOrderBubble('meituan', context.l10n.meituanName)),
          onVoiceRecordStart: _startVoiceRecording,
          onVoiceRecordStop: _stopVoiceRecordingAndTranscribe,
          onVoiceRecordCancel: () => unawaited(_voiceInputController.cancel()),
        );
      case AppRoute.dream:
        return DreamPage(
          key: const ValueKey('dream'),
          c: c,
          prefs: _prefs,
          profileDisplayName: _profileDisplayName,
          profileAvatarBytes: _profileAvatarBytes,
          controller: _dreamController,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          onWake: _wakeFromDream,
        );
      case AppRoute.profile:
        return ProfilePage(
          key: const ValueKey('profile'),
          c: c,
          profileDisplayName: _profileDisplayName,
          hasProfileNameOverride: _hasProfileNameOverride,
          profileAvatarBytes: _profileAvatarBytes,
          onBack: () => setState(() => _route = AppRoute.chat),
          onEditProfileName: _editProfileName,
          onImportProfileAvatar: _importProfileAvatar,
          onResetProfileAvatar: _resetProfileAvatar,
          promptAssets: _promptAssets,
          loadingPromptAssets: _loadingPromptAssets,
          savingPromptAssets: _savingPromptAssets,
          promptAssetsError: _promptAssetsError,
          onSelectCharacter: (value) =>
              unawaited(_updatePromptAssets(activeCharacter: value)),
          onReloadPromptAssets: () => unawaited(_loadPromptAssets()),
          activityCurrent: _profileStatusController.activityCurrent,
          moodState: _profileStatusController.moodState,
          loadingStatusSnapshot: _profileStatusController.loading,
          statusSnapshotLastSuccessfulAt:
              _profileStatusController.lastSuccessfulAt,
          statusSnapshotError: _profileStatusController.error,
          onReloadStatusSnapshot: () =>
              unawaited(_profileStatusController.load()),
        );
      case AppRoute.diary:
        return DiaryPage(
          key: const ValueKey('diary'),
          c: c,
          profileDisplayName: _profileDisplayName,
          controller: _diaryController,
          onBack: () => setState(() => _route = AppRoute.chat),
        );
      case AppRoute.garden:
        return GardenPage(
          key: const ValueKey('garden'),
          c: c,
          profileDisplayName: _profileDisplayName,
          controller: _gardenController,
          onBack: () => setState(() => _route = AppRoute.chat),
        );
      case AppRoute.activity:
        return ActivityHomePage(
          key: const ValueKey('activity'),
          c: c,
          backend: _backend,
          requireToken: _requireAdminToken,
          onBack: () => setState(() => _route = AppRoute.chat),
        );
      case AppRoute.group:
        return GroupListScreen(
          key: const ValueKey('group'),
          c: c,
          backend: _backend,
          requireToken: _requireAdminToken,
          onBack: () => setState(() => _route = AppRoute.chat),
        );
    }
  }
}
