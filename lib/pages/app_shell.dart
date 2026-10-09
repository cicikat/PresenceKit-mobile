import '../models/ui_layout.dart';
import '../widgets/moonlit_scene.dart';
import '../widgets/conversation_presentation.dart';
import '../widgets/conversation_calendar_widgets.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/attachment_coordinator.dart';
import '../controllers/capability_settings_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/life_records_controller.dart';
import '../widgets/life_records_widgets.dart';
import '../controllers/connection_controller.dart';
import '../controllers/device_controller.dart';
import '../controllers/dream_controller.dart';
import '../controllers/diary_controller.dart';
import '../controllers/garden_controller.dart';
import '../controllers/locale_controller.dart';
import '../controllers/profile_appearance_controller.dart';
import '../controllers/profile_status_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/personalization_controller.dart';
import '../controllers/voice_input_controller.dart';
import '../models/app_models.dart';
import '../models/background_status.dart';
import '../widgets/scene_background.dart';
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
  AppRoute _route = AppRoute.chat;
  bool _restoreComplete = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  String? _backendError;
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
  late final LifeRecordsController _lifeRecordsController;
  late final ThemeController _themeController;
  late final PersonalizationController _personalization;
  late final ProfileStatusController _profileStatusController;
  late final ProfileAppearanceController _profileAppearance;
  late final CapabilitySettingsController _capabilitySettings;
  late final AttachmentCoordinator _attachments;
  late final LocaleController _localeController;
  late final bool _ownsLocaleController;

  BackendClient get _backend => _connectionController.backend;
  String get _backendBaseUrl => _connectionController.baseUrl;
  String get _adminToken => _connectionController.token;
  String get _ownerUserId => _connectionController.ownerUserId;
  YxPalette get c {
    final custom = _themeController.activePalette;
    if (custom != null) return custom;
    if (_route == AppRoute.dream &&
        _themeController.dreamLayout == DreamLayout.moonlit) {
      return moonlitPalette(YxPalette.dark);
    }
    final base = _themeController.isDark ? YxPalette.dark : YxPalette.light;
    return dailyLayoutPalette(_themeController.dailyLayout, base);
  }

  bool get _hasAdminToken => _adminToken.trim().isNotEmpty;
  String? get _currentCharacterId => _profileAppearance.currentCharacterId;
  String get _profileDisplayName => _profileAppearance.profileDisplayName;
  YxPrefs get _prefs => _profileAppearance.prefs;

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
    _personalization = PersonalizationController(settingsStore)
      ..addListener(_handleThemeChanged);
    _themeController = ThemeController(
      loadPersisted: _settings.loadCustomThemePalette,
      savePersisted: _settings.saveCustomThemePalette,
    );
    _themeController.addListener(_handleThemeChanged);

    _deviceService = DeviceControlService(settingsStore);
    _screenService = ScreenSensorService(settingsStore);
    _relayService = RelayStatusService(settingsStore);
    _connectionController = ConnectionController(
      settingsStore: settingsStore,
      backendClient: widget.backendClient,
    );
    _lifeRecordsController = LifeRecordsController(
      origin: () => _backendBaseUrl,
      owner: () => _ownerUserId,
    );
    _connectionController.addListener(_lifeRecordsController.connectionChanged);
    _profileStatusController = ProfileStatusController(
      backend: () => _backend,
      token: () => _adminToken,
      charId: () => _currentCharacterId,
    );
    _profileStatusController.addListener(_handleShellChanged);
    _profileAppearance = ProfileAppearanceController(
      settings: _settings,
      backend: () => _backend,
      token: () => _adminToken,
      origin: () => _backendBaseUrl,
      owner: () => _ownerUserId,
    )..addListener(_handleShellChanged);
    _voiceService = VoiceService(settingsStore);
    _deviceController = DeviceController(
      device: _deviceService,
      screen: _screenService,
      backend: () => _backend,
      token: () => _adminToken,
      restored: () => _restoreComplete,
      foreground: () =>
          _lifecycle == AppLifecycleState.resumed ||
          _lifecycle == AppLifecycleState.inactive,
    );
    _capabilitySettings = CapabilitySettingsController(
      settings: _settings,
      device: _deviceService,
      deviceController: _deviceController,
      relay: _relayService,
      chat: () => _chatController,
      garden: () => _gardenController,
      backendBaseUrl: () => _backendBaseUrl,
      extraBackendError: () => _backendError,
    )..addListener(_handleShellChanged);
    _attachments = AttachmentCoordinator(settings: _settings);
    _chatController = ChatController(
      backend: () => _backend,
      token: () => _adminToken,
      settings: _settings,
      relay: _relayService,
      voice: _voiceService,
      stickerEnabled: () => _capabilitySettings.stickerEnabled,
      autoPlayVoice: () => _capabilitySettings.autoPlayVoice,
      deliveryOrigin: () => _backendBaseUrl,
      deliveryOwner: () => _ownerUserId,
      deliveryCharId: () => _currentCharacterId,
      resolvePresenceSession: ({required String charId, bool force = false}) {
        return _profileAppearance.ensurePresenceSession(
          charId: charId,
          force: force,
        );
      },
      onPresenceSessionInvalid: _profileAppearance.invalidatePresenceGrant,
      presenceBindError: () => _profileAppearance.sessionBindError,
    );
    _voiceInputController = VoiceInputController(
      voice: _voiceService,
      backend: () => _backend,
      token: () => _adminToken,
    );
    _dreamController = DreamController(
      backend: () => _backend,
      token: () => _adminToken,
      charId: () => _currentCharacterId,
    );
    _gardenController = GardenController(
      backend: () => _backend,
      token: () => _adminToken,
      charId: () => _currentCharacterId,
    );
    _diaryController = DiaryController(
      backend: () => _backend,
      token: () => _adminToken,
      charId: () => _currentCharacterId,
    );
    WidgetsBinding.instance.addObserver(this);
    _applySystemUi();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applySystemUi());
    unawaited(_restoreBackendAndStart());
  }

  Future<void> _consumeNotificationOpen() async {
    if (!_hasAdminToken ||
        _profileAppearance.promptAssetsError != null ||
        !await _relayService.consumePendingOpenLatestMessage()) {
      return;
    }
    await _chatController.start();
    await _chatController.catchUpFromNotification();
  }

  Future<void> _restoreBackendAndStart() async {
    unawaited(_themeController.restore());
    unawaited(_personalization.restore());
    await Future.wait([
      _connectionController.restore(),
      _deviceController.restore(),
      _profileAppearance.restore(includeSessionCharacter: false),
      _capabilitySettings.restore(),
    ]);
    await _profileAppearance.restoreSessionCharacter();
    _restoreComplete = true;
    if (!mounted) return;
    if (_hasAdminToken) {
      _lifeRecordsController.start();
      await _prepareSessionAndStartSync();
      await _consumeNotificationOpen();
    } else {
      await _applyActiveCharacterPresentation(reloadConversation: false);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_openAdminTokenSettings(required: true)),
      );
    }
  }

  Future<void> _prepareSessionAndStartSync() async {
    if (!_hasAdminToken) return;
    await _loadPromptAssets();
    if (!mounted || !_hasAdminToken) return;
    _startBackendSync();
  }

  void _startBackendSync() {
    if (!_hasAdminToken) return;
    unawaited(_chatController.start());
    unawaited(_gardenController.start());
    _deviceController.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _deviceController.handleAppLifecycle(state);
    if (state == AppLifecycleState.resumed) {
      _lifeRecordsController.start();
      _applySystemUi();
      if (_hasAdminToken) {
        _chatController.resumePolling();
        unawaited(_consumeNotificationOpen());
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _lifeRecordsController.pause();
      _chatController.pausePolling();
    }
  }

  Future<void> _invalidateIdentity({
    required bool realmChanged,
    bool restartSync = false,
  }) async {
    _backendError = null;
    _gardenController.invalidateForIdentityChange();
    _diaryController.invalidateForIdentityChange();
    _profileStatusController.invalidateForIdentityChange();
    _deviceController.invalidateForIdentityChange();
    _dreamController.invalidateLocalSession(clearSettings: true);
    await _profileAppearance.invalidateForIdentityChange(
      realmChanged: realmChanged,
    );
    await _chatController.resetForConnectionChange(restart: false);
    if (!mounted) return;
    if (restartSync && _hasAdminToken) {
      await _prepareSessionAndStartSync();
      if (!mounted) return;
      unawaited(_diaryController.load());
      unawaited(_profileStatusController.load());
    }
  }

  @override
  void dispose() {
    _connectionController.removeListener(
      _lifeRecordsController.connectionChanged,
    );
    _lifeRecordsController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _gardenController.dispose();
    _diaryController.dispose();
    _deviceController.dispose();
    _voiceInputController.dispose();
    _chatController.dispose();
    _dreamController.dispose();
    _themeController.removeListener(_handleThemeChanged);
    _themeController.dispose();
    _personalization.removeListener(_handleThemeChanged);
    _personalization.dispose();
    _profileStatusController.removeListener(_handleShellChanged);
    _profileStatusController.dispose();
    _profileAppearance.removeListener(_handleShellChanged);
    _profileAppearance.dispose();
    _capabilitySettings.removeListener(_handleShellChanged);
    _capabilitySettings.dispose();
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

  void _handleShellChanged() {
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

  Future<bool> _changeBackendBaseUrl(String raw) async {
    final normalized = await _normalizeBackendBaseUrl(raw);
    if (normalized == null) {
      setState(() => _backendError = context.l10n.backendInvalidAddress);
      return false;
    }
    if (!await _ensureTrustedBackendOrigin(normalized)) {
      if (mounted) {
        setState(() => _backendError = 'Backend origin was not trusted');
      }
      return false;
    }
    if (normalized == _backendBaseUrl) return false;

    try {
      await _connectionController.saveBaseUrl(normalized);
    } catch (error) {
      if (mounted) {
        setState(() => _backendError = error.toString());
      }
      return false;
    }
    return true;
  }

  Future<void> _openAdminTokenSettings({bool required = false}) async {
    if (!mounted) return;
    final previousToken = _adminToken;
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
    final replaced = previousToken.trim() != savedToken.trim();
    if (replaced && previousToken.trim().isNotEmpty) {
      unawaited(
        _backend
            .deactivateMobile(token: previousToken)
            .then<void>((_) {})
            .catchError((_) {}),
      );
    }
    if (replaced) {
      await _invalidateIdentity(
        realmChanged: false,
        restartSync: _hasAdminToken,
      );
    }
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (!mounted) return;
        Navigator.maybeOf(
          context,
          rootNavigator: true,
        )?.popUntil((route) => route.isFirst);
        if (!replaced) setState(() {});
      }),
    );
  }

  Future<void> _changeBackgroundNotifications(bool enabled) =>
      _capabilitySettings.setBackgroundNotifications(enabled);

  Future<void> _changeScreenContextUploadEnabled(bool enabled) =>
      _capabilitySettings.setScreenContextUploadEnabled(enabled);

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

  Future<String?> _startVoiceRecording() async {
    final error = await _voiceInputController.start();
    return error == null ? null : _localizeVoiceError(error);
  }

  Future<VoiceInputResult> _stopVoiceRecordingAndTranscribe() async {
    final result = await _voiceInputController.stopAndTranscribe();
    return VoiceInputResult(
      text: result.text,
      error: result.error == null ? null : _localizeVoiceError(result.error!),
    );
  }

  String _localizeVoiceError(String error) {
    final l10n = context.l10n;
    if (error.contains('正在录音')) return l10n.voiceRecordingActive;
    if (error.contains('权限')) return l10n.voicePermissionDenied;
    if (error.contains('开始录音')) return l10n.voiceStartFailed;
    if (error.contains('没有正在')) return l10n.voiceNotActive;
    if (error == '录音失败') return l10n.voiceRecordingFailed;
    if (error.contains('访问凭证')) return l10n.voiceCredentialRequired;
    if (error.contains('转写')) return l10n.voiceTranscriptionFailed;
    return error;
  }

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
        initialName:
            cleanCharacterDisplayName(_profileAppearance.profileNameOverride) ??
            '',
      ),
    );
    if (value == null) return;
    await _profileAppearance.saveProfileName(cleanCharacterDisplayName(value));
  }

  Future<void> _importProfileAvatar() async {
    final sourceBytes = await _profileAppearance.pickProfileImage();
    if (!mounted || sourceBytes == null) return;
    final cropped = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AvatarCropDialog(c: c, bytes: sourceBytes),
    );
    if (!mounted || cropped == null) return;
    final saved = await _profileAppearance.saveAvatar(cropped);
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.avatarSaveFailed)));
    }
  }

  Future<void> _resetProfileAvatar() => _profileAppearance.deleteAvatar();

  Future<void> _importChatBackground({bool night = false}) async {
    final sourceBytes = await _profileAppearance.pickBackgroundImage();
    if (!mounted || sourceBytes == null) return;
    final draft = await showDialog<ChatBackgroundDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChatBackgroundEditorDialog(
        c: c,
        bytes: sourceBytes,
        initialBlur: _prefs.chatBackgroundBlur,
        initialOpacity: _prefs.chatBubbleOpacity,
      ),
    );
    if (!mounted || draft == null) return;
    final saved = await _profileAppearance.saveChatBackground(
      night: night,
      bytes: draft.bytes,
      blur: draft.blur,
      opacity: draft.opacity,
    );
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatBackgroundSaveFailed)),
      );
    }
  }

  Future<void> _importDreamBackground() async {
    final bytes = await _profileAppearance.pickBackgroundImage();
    if (!mounted || bytes == null) return;
    final draft = await showDialog<ChatBackgroundDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChatBackgroundEditorDialog(
        c: c,
        bytes: bytes,
        initialBlur: 0,
        initialOpacity: 1,
      ),
    );
    if (!mounted || draft == null) return;
    await _profileAppearance.saveDreamBackground(draft.bytes);
  }

  Future<void> _resetDreamBackground() =>
      _profileAppearance.resetDreamBackground();

  Future<void> _resetChatBackground({bool night = false}) =>
      _profileAppearance.resetChatBackground(night: night);

  Future<void> _testBackendConnectivity() async {
    await _chatController.activateMobile();
    if (!mounted) return;
    await Future.wait([
      _chatController.loadHistory(),
      _gardenController.load(),
    ]);
  }

  void _openCapabilityCheck({bool controlsOnly = false}) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CapabilitySheet(
        controlsOnly: controlsOnly,
        c: c,
        onLoadStatus: _capabilitySettings.loadStatus,
        onRequestNotifications: _deviceService.requestNotificationPermission,
        onRequestIgnoreBatteryOptimizations:
            _deviceService.requestIgnoreBatteryOptimizations,
        onRequestOverlay: _deviceService.requestOverlayPermission,
        onRequestAccessibility: _deviceService.requestAccessibilityPermission,
        onRequestDeviceAdmin: _deviceService.requestDeviceAdmin,
        onRequestActivityRecognition:
            _deviceController.requestActivityPermission,
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
    var realmChanged = false;
    if (result.ownerUserId != _ownerUserId) {
      try {
        realmChanged = await _connectionController.saveOwnerUserId(
          result.ownerUserId,
        );
      } catch (error) {
        if (mounted) {
          setState(() => _backendError = error.toString());
        }
        return;
      }
      if (!mounted) return;
    }
    final nodeChanged = await _changeBackendBaseUrl(result.baseUrl);
    if (!mounted) return;
    if (realmChanged || nodeChanged) {
      await _invalidateIdentity(
        realmChanged: true,
        restartSync: _hasAdminToken,
      );
    }
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
    if (!mounted || result == null) return;
    if (result.confirmedClosed) {
      await _exitDreamAndRoute(AppRoute.chat, callBackendExit: false);
      return;
    }
    if (!result.retained) return;
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
    final closed = await _dreamController.exit(
      callBackendExit: callBackendExit,
    );
    if (mounted && closed) setState(() => _route = route);
  }

  Future<void> _loadPromptAssets() async {
    if (!_hasAdminToken) return;
    await _profileAppearance.loadPromptAssets();
    if (!mounted || _profileAppearance.promptAssetsError != null) return;
    await _applyActiveCharacterPresentation(reloadConversation: false);
  }

  Future<void> _selectSessionCharacter(String characterId) async {
    if (!_hasAdminToken) return;
    await _profileAppearance.selectSessionCharacter(characterId);
    if (!mounted || _profileAppearance.promptAssetsError != null) return;
    await _applyActiveCharacterPresentation();
  }

  Future<void> _applyActiveCharacterPresentation({
    bool reloadConversation = true,
  }) async {
    final switched = await _profileAppearance
        .applyActiveCharacterPresentation();
    if (!mounted) return;
    if (!switched || !reloadConversation || !_hasAdminToken) return;
    _dreamController.invalidateLocalSession(clearSettings: false);
    _diaryController.clear();
    _gardenController.clear();
    unawaited(_diaryController.load());
    unawaited(_gardenController.load());
    unawaited(_profileStatusController.load());
    await _chatController.resetForConnectionChange();
  }

  void _openSettings() {
    var requestedBackendSettings = false;
    var notificationTestMode = false;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ListenableBuilder(
          listenable: Listenable.merge([
            _dreamController,
            _connectionController,
            _themeController,
            _personalization,
            _localeController,
            _profileStatusController,
            _profileAppearance,
            _capabilitySettings,
          ]),
          builder: (context, _) => StatefulBuilder(
            builder: (context, sheetSetState) {
              if (!requestedBackendSettings) {
                requestedBackendSettings = true;
                unawaited(
                  Future<void>(() async {
                    final results = await Future.wait<dynamic>([
                      _dreamController.loadSettings(),
                      _relayService.loadNotificationGateStatus(),
                      _loadPromptAssets(),
                      _profileStatusController.load(),
                    ]);
                    notificationTestMode =
                        (results[1] as NotificationGateStatus).testModeEnabled;
                    if (context.mounted) sheetSetState(() {});
                  }),
                );
              }

              void updatePrefs(YxPrefs prefs) {
                unawaited(_profileAppearance.savePrefs(prefs));
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
                unawaited(
                  _openThemePresetManager(selectingDark: selectingDark),
                );
              }

              return SettingsPage(
                profileContent: _buildProfile(
                  onChanged: () {
                    if (context.mounted) sheetSetState(() {});
                  },
                ),
                personalization: _personalization,
                c: c,
                language: _localeController.language,
                dark: _themeController.isDark,
                lightThemePresetName: _themeController.lightThemePreset?.name,
                darkThemePresetName: _themeController.darkThemePreset?.name,
                dailyLayout: _themeController.dailyLayout,
                dreamLayout: _themeController.dreamLayout,
                onDailyLayout: (v) =>
                    unawaited(_themeController.setDailyLayout(v)),
                onDreamLayout: (v) =>
                    unawaited(_themeController.setDreamLayout(v)),
                themePresetCount: _themeController.presets.length,
                prefs: _prefs,
                profileDisplayName: _profileDisplayName,
                profileAvatarBytes: _profileAppearance.profileAvatarBytes,
                chatBackground: _prefs.chatBackground,
                nightChatBackground: _prefs.nightChatBackground,
                onImportNightChatBackground: () async {
                  await _importChatBackground(night: true);
                  if (context.mounted) sheetSetState(() {});
                },
                onResetNightChatBackground: () async {
                  await _resetChatBackground(night: true);
                  if (context.mounted) sheetSetState(() {});
                },

                dreamSettings: _dreamController.settings,
                onDreamContext: (field, value) async {
                  await _dreamController.updateSettings(
                    memoryAccess: field == 'memory_access' ? value : null,
                    boundaryLevel: field == 'boundary_level' ? value : null,
                    lucidMode: field == 'lucid_mode' ? value : null,
                  );
                  if (context.mounted) sheetSetState(() {});
                },
                dreamWorlds: _dreamController.worlds,
                dreamPresets: _dreamController.presets,
                onOpenSystemControls: () =>
                    _openCapabilityCheck(controlsOnly: true),
                onRetryDream: () async {
                  await _dreamController.loadSettings();
                  if (context.mounted) sheetSetState(() {});
                },
                dreamActive: _dreamController.state?.isActive == true,
                settingsBusy:
                    _dreamController.loadingSettings ||
                    _dreamController.savingSettings,
                settingsError: _dreamController.settingsError,

                onTheme: updateTheme,
                onLanguage: (language) {
                  unawaited(_localeController.setLanguage(language));
                  sheetSetState(() {});
                },
                onManageThemes: () => manageThemes(_themeController.isDark),
                onManageThemesForMode: manageThemes,
                onPrefs: updatePrefs,
                onEditProfileName: () async {
                  await _editProfileName();
                  if (context.mounted) sheetSetState(() {});
                },
                onImportProfileAvatar: () async {
                  await _importProfileAvatar();
                  if (context.mounted) sheetSetState(() {});
                },
                onResetProfileAvatar: () {
                  _resetProfileAvatar();
                  sheetSetState(() {});
                },
                onImportChatBackground: () async {
                  await _importChatBackground();
                  if (context.mounted) sheetSetState(() {});
                },
                onResetChatBackground: () async {
                  await _resetChatBackground();
                  if (context.mounted) sheetSetState(() {});
                },
                onImportDreamBackground: () async {
                  await _importDreamBackground();
                  if (context.mounted) sheetSetState(() {});
                },
                onResetDreamBackground: _resetDreamBackground,
                hasAdminToken: _hasAdminToken,
                backgroundNotifications:
                    _capabilitySettings.backgroundNotifications,
                backendBaseUrl: _backendBaseUrl,
                ownerUserId: _ownerUserId,
                notificationTestMode: notificationTestMode,
                onEditCredential: () async {
                  await _openAdminTokenSettings();
                  await _dreamController.loadSettings();
                },
                onEditBackend: () async {
                  await _openBackendSettings();
                  await _dreamController.loadSettings();
                },
                onEditRelay: _openRelaySettings,
                onBackgroundNotifications: (enabled) {
                  unawaited(_changeBackgroundNotifications(enabled));
                },
                onNotificationTestMode: (enabled) {
                  sheetSetState(() => notificationTestMode = enabled);
                  unawaited(
                    _capabilitySettings.setNotificationTestMode(enabled),
                  );
                },
                onOpenCapabilities: _openCapabilityCheck,
                stickerEnabled: _capabilitySettings.stickerEnabled,
                autoPlayVoice: _capabilitySettings.autoPlayVoice,
                onStickerEnabledChanged: (enabled) {
                  unawaited(_capabilitySettings.setStickerEnabled(enabled));
                },
                onAutoPlayVoiceChanged: (enabled) {
                  unawaited(_capabilitySettings.setAutoPlayVoice(enabled));
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
                    final selected = _dreamController.settings!.jailbreakPresets
                        .toSet();
                    if (!selected.remove(value)) selected.add(value);
                    await _dreamController.updateSettings(
                      jailbreakPresets: selected.toList(),
                    );
                    if (context.mounted) sheetSetState(() {});
                  }());
                },
              );
            },
          ),
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
    final picked = await _attachments.pickFile();
    if (!mounted || picked == null) return;
    switch (_attachments.validateFile(picked)) {
      case AttachmentValidationError.typeUnsupported:
        UploadFeedback.fileTypeUnsupported(context);
        return;
      case AttachmentValidationError.tooLarge:
        UploadFeedback.fileTooLarge(context);
        return;
      case null:
        break;
    }
    await _chatController.uploadFiles(
      [picked],
      preview: _attachments.filePreview(picked),
      failureLabel: UploadFeedback.fileFailureLabel(context),
    );
  }

  Future<void> _pickAndUploadImages() async {
    if (_chatController.sending) return;
    final picked = await _attachments.pickImages();
    if (!mounted || picked.isEmpty) return;
    switch (_attachments.validateImages(picked)) {
      case AttachmentValidationError.typeUnsupported:
        UploadFeedback.imageTypeUnsupported(context);
        return;
      case AttachmentValidationError.tooLarge:
        UploadFeedback.imageTooLarge(context);
        return;
      case null:
        break;
    }
    final preview = UploadFeedback.imagePreview(
      context,
      count: picked.length,
      names: _attachments.imageNamesPreview(picked),
      hasMore: _attachments.imagesHaveMore(picked),
    );
    final message = await showDialog<String>(
      context: context,
      builder: (context) => const ImageCaptionDialog(),
    );
    if (!mounted || message == null) return;
    await _chatController.uploadFiles(
      picked,
      preview: preview,
      failureLabel: UploadFeedback.imageFailureLabel(context),
      message: message,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTypography.family = _personalization.family;
    AppTypography.scale = _personalization.themeSize / 16;
    final conversation = _route == AppRoute.chat || _route == AppRoute.dream;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: c.surface.computeLuminance() < .2
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: conversation ? Colors.black : c.surface,
        systemNavigationBarIconBrightness:
            conversation || _themeController.isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: SceneBackground(
        bytes: _route == AppRoute.chat
            ? (_themeController.isDark
                  ? _prefs.nightChatBackground
                  : _prefs.chatBackground)
            : _route == AppRoute.dream
            ? _prefs.dreamBackground
            : null,
        color: c.surface,
        blur: _route == AppRoute.chat ? _prefs.chatBackgroundBlur : 0,
        darken: _route == AppRoute.dream,
        child: LayoutBackdrop(
          c: c,
          moonlit:
              _route == AppRoute.dream &&
              _themeController.dreamLayout == DreamLayout.moonlit &&
              _prefs.dreamBackground == null,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            key: _scaffoldKey,
            drawer: YxDrawer(
              personalization: _personalization,
              c: c,
              route: _route,
              profileDisplayName: _profileDisplayName,
              profileAvatarBytes: _profileAppearance.profileAvatarBytes,
              onRoute: _pickRoute,
              onOpenSettings: _openSettings,
            ),
            body: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              color: Colors.transparent,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _buildRoute(),
                      ),
                    ),
                    BottomSystemInset(
                      color: conversation ? Colors.black : c.surface,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfile({VoidCallback? onChanged}) {
    return ProfileSettingsContent(
      c: c,
      promptAssets: _profileAppearance.promptAssets,
      sessionCharacterId: _profileAppearance.currentCharacterId,
      loadingPromptAssets: _profileAppearance.loadingPromptAssets,
      savingPromptAssets: _profileAppearance.savingPromptAssets,
      promptAssetsError: _profileAppearance.promptAssetsError,
      sessionBindError: _profileAppearance.sessionBindError,
      bindingPresenceSession: _profileAppearance.bindingPresenceSession,
      onSelectCharacter: (value) async {
        final pending = _selectSessionCharacter(value);
        onChanged?.call();
        await pending;
        onChanged?.call();
        await _profileStatusController.load();
      },
      onReloadPromptAssets: () async {
        await _loadPromptAssets();
        onChanged?.call();
      },
      activityCurrent: _profileStatusController.activityCurrent,
      moodState: _profileStatusController.moodState,
      loadingStatusSnapshot: _profileStatusController.loading,
      statusSnapshotLastSuccessfulAt: _profileStatusController.lastSuccessfulAt,
      statusSnapshotError: _profileStatusController.error,
      onReloadStatusSnapshot: () => unawaited(_profileStatusController.load()),
    );
  }

  Widget _buildRoute() {
    switch (_route) {
      case AppRoute.conversationCalendar:
        return ConversationCalendarPage(
          c: c,
          palette: _prefs.calendarPalette,
          name: _profileDisplayName,
          characterId: _currentCharacterId,
          sessionId: _profileAppearance
              .grantFor(_currentCharacterId)
              ?.sessionId,
          backend: _backend,
          token: _adminToken,
          onBack: () => setState(() => _route = AppRoute.chat),
        );
      case AppRoute.lifeRecords:
        return LifeRecordsPage(
          c: c,
          controller: _lifeRecordsController,
          onBack: () => setState(() => _route = AppRoute.chat),
        );
      case AppRoute.chat:
        return ChatScene(
          key: const ValueKey('chat'),
          layout: _themeController.dailyLayout,
          userName: _personalization.name,
          userAvatar: _personalization.avatar,
          onRoute: _pickRoute,
          c: c,
          dark: _themeController.isDark,
          prefs: _prefs,
          profileDisplayName: _profileDisplayName,
          profileAvatarBytes: _profileAppearance.profileAvatarBytes,
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
          layout: _themeController.dreamLayout,
          c: c,
          prefs: _prefs,
          profileDisplayName: _profileDisplayName,
          profileAvatarBytes: _profileAppearance.profileAvatarBytes,
          controller: _dreamController,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          onWake: _wakeFromDream,
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
    }
  }
}
