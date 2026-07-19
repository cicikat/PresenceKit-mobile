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
import '../controllers/theme_controller.dart';
import '../models/app_models.dart';
import '../models/background_status.dart';
import '../models/capability_status.dart';
import '../models/screen_context.dart';
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
import '../widgets/settings_editor_widgets.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/theme_widgets.dart';

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
  bool _dark = false;
  bool _backgroundNotifications = true;
  bool _backendSyncStarted = false;
  bool _loadingPromptAssets = false;
  bool _savingPromptAssets = false;
  String? _backendError;
  String? _promptAssetsError;
  ActivityCurrentState? _activityCurrent;
  MoodStateSnapshot? _moodState;
  bool _loadingStatusSnapshot = false;
  PromptAssets? _promptAssets;
  String? _profileNameOverride;
  Uint8List? _profileAvatarBytes;
  late final SettingsStore _settings;
  late final DeviceControlService _deviceService;
  late final ScreenSensorService _screenService;
  late final RelayStatusService _relayService;
  late final ConnectionController _connectionController;
  late final DeviceController _deviceController;
  late final ChatController _chatController;
  late final DreamController _dreamController;
  late final GardenController _gardenController;
  late final DiaryController _diaryController;
  YxPrefs _prefs = const YxPrefs();
  late final ThemeController _themeController;
  late final PromptEntriesController _promptEntries;
  late final LocaleController _localeController;
  late final bool _ownsLocaleController;

  BackendClient get _backend => _connectionController.backend;
  String get _backendBaseUrl => _connectionController.baseUrl;
  String get _adminToken => _connectionController.token;
  String get _ownerUserId => _connectionController.ownerUserId;
  YxPalette get c {
    final custom = _themeController.activePalette;
    if (custom != null) return custom;
    return _dark ? YxPalette.dark : YxPalette.light;
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
    _deviceController = DeviceController(
      device: _deviceService,
      voice: VoiceService(settingsStore),
      screen: _screenService,
      backend: () => _backend,
      token: () => _adminToken,
    );
    _chatController = ChatController(
      backend: () => _backend,
      token: () => _adminToken,
      settings: _settings,
      relay: _relayService,
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
    if (mounted) {
      setState(() {
        _backgroundNotifications = backgroundNotifications;
        _profileNameOverride = storedName;
        _profileAvatarBytes = storedAvatar;
      });
    }
    if (!mounted) return;
    if (_hasAdminToken) {
      _startBackendSync();
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
      if (_hasAdminToken) _chatController.resumePolling();
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
    _chatController.dispose();
    _dreamController.dispose();
    _themeController.removeListener(_handleThemeChanged);
    _themeController.dispose();
    _promptEntries.removeListener(_handlePromptEntriesChanged);
    _promptEntries.dispose();
    if (_ownsLocaleController) _localeController.dispose();
    super.dispose();
  }

  void _handleThemeChanged() {
    if (!mounted) return;
    setState(() {});
    _applySystemUi();
  }

  void _handlePromptEntriesChanged() {
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
      setState(() => _backendError = '后端地址格式不对');
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
        previousBackend.deactivateMobile(token: _adminToken).catchError((_) {}),
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
    final controller = TextEditingController();
    String? dialogError;
    final savedToken = await _showTextInputDialog<String>(
      controllers: [controller],
      barrierDismissible: !required,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          backgroundColor: c.surface,
          scrollable: true,
          title: Text(
            required ? '设置访问 Token' : '设置 / 更换 Token',
            style: TextStyle(color: c.ink1),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '填后端签发的 mobile token（emt_ 开头）；旧 admin secret 仍可用但不建议。'
                'Token 只保存在 Android 本机私有存储中，不会打包进应用。',
                style: TextStyle(color: c.ink2),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: false,
                enableInteractiveSelection: true,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                style: TextStyle(color: c.ink1),
                decoration: InputDecoration(
                  labelText: '访问 Token',
                  errorText: dialogError,
                ),
              ),
            ],
          ),
          actions: [
            if (!required)
              TextButton(
                onPressed: () => _dismissTextInputDialog(dialogContext),
                child: const Text('取消'),
              ),
            FilledButton(
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  dialogSetState(() => dialogError = '请填写访问 Token');
                  return;
                }
                try {
                  await _connectionController.saveToken(value);
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  dialogSetState(() => dialogError = '保存失败：$e');
                  return;
                }
                if (!dialogContext.mounted) return;
                _dismissTextInputDialog(dialogContext, result: value);
              },
              child: const Text('保存'),
            ),
          ],
        ),
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

  Future<void> _changeScreenTextUploadAllowedPackages(Set<String> values) =>
      _deviceController.saveAllowedPackages(values);
  Future<void> _openThemePresetManager() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ThemePresetManagerSheet(c: c, controller: _themeController),
    );
  }

  Future<void> _lockScreenNow() async {
    final locked = await _deviceController.lockScreen();
    if (!mounted) return;
    if (!locked) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先启用“陪伴锁屏确认”的设备管理器权限')));
    }
  }

  Future<void> _requestOrderAssistantPermission() async {
    final enabled = await _deviceController.isAccessibilityEnabled();
    if (!mounted) return;
    if (enabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('陪伴操作助手已授权')));
      return;
    }
    await _deviceController.requestAccessibilityPermission();
  }

  Future<void> _openShoppingApp(String target, String label) async {
    final opened = await _deviceController.openShoppingApp(target);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('没有找到 $label，先手动安装或确认包名')));
    }
  }

  Future<void> _showOrderBubble(String target, String label) async {
    final shown = await _deviceController.showOrderBubble(target);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shown ? '已弹出 $label 购物车确认悬浮窗' : '请先允许“显示在其他应用上层”，回来后再点一次',
        ),
      ),
    );
  }

  // ── W9：语音输入 ──────────────────────────────────────────────────────────

  Future<bool> _startVoiceRecording() =>
      _deviceController.startVoiceRecording();
  Future<String?> _stopVoiceRecordingAndTranscribe() =>
      _deviceController.stopVoiceRecordingAndTranscribe();
  Future<void> _pushScreenContextOnce({bool silent = false}) async {
    await _deviceController.pushScreenContext(silent: silent);
    if (!silent && mounted && _deviceController.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('屏幕上下文推送失败：${_deviceController.lastError}')),
      );
    }
  }

  Future<ScreenContextSnapshot?> _captureScreenContextForDebug({
    bool silent = false,
  }) async {
    if (!await _deviceController.isAccessibilityEnabled()) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先开启无障碍服务，才能读取屏幕上下文')));
      }
      return null;
    }
    final snapshot = await _deviceController.captureForDebug();
    if ((snapshot == null || snapshot.isEmpty) && !silent && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂时没有可读的屏幕上下文')));
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
        SnackBar(content: Text('屏幕上下文推送失败：${_deviceController.lastError}')),
      );
    }
  }

  Future<void> _pushBehaviorTest(String kind) async {
    final spec = BehaviorTestSpec.forKind(kind);
    try {
      await _backend.pushMobileBehaviorTest(
        token: _requireAdminToken(),
        userId: _ownerUserId,
        content: spec.content,
        kind: spec.kind,
        delivery: spec.delivery,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已写入主动行为测试：${spec.label}')));
      await _chatController.pollIfBackgroundUnavailable();
    } on BackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('主动行为测试失败：${e.message}')));
    }
  }

  Future<void> _editProfileName() async {
    final controller = TextEditingController(
      text: cleanCharacterDisplayName(_profileNameOverride) ?? '',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: c.surface,
          scrollable: true,
          title: Text('本机备注名', style: serif(c, 20)),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 12,
            decoration: const InputDecoration(
              hintText: '留空则显示后端角色名',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('恢复默认'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (value == null) return;
    final cleaned = cleanCharacterDisplayName(value);
    await _settings.saveProfileName(cleaned ?? '');
    if (!mounted) return;
    setState(() => _profileNameOverride = cleaned);
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
      ).showSnackBar(const SnackBar(content: Text('头像保存失败')));
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
      _screenService.loadAllowedPackages(),
      _screenService.loadAppOptions(),
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
      overlayErrorStatus: results[11] as OverlayErrorStatus,
      ignoringBatteryOptimizations: results[8] as bool,
      screenContextUploadEnabled: _deviceController.screenUploadEnabled,
      screenTextUploadAllowedPackages: results[9] as Set<String>,
      screenTextUploadAppOptions:
          results[10] as List<ScreenTextUploadAppOption>,
      backendBaseUrl: _backendBaseUrl,
      backendReachable:
          _chatController.mobileActive ||
          _chatController.historyLoaded ||
          _gardenController.state != null,
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
        onChangeScreenTextUploadAllowedPackages:
            _changeScreenTextUploadAllowedPackages,
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
    unawaited(_loadStatusSnapshot());
  }

  // W6：状态感知——资料页"此刻"卡片，读一次当前动向 + 心情，不轮询（省电）。
  Future<void> _loadStatusSnapshot() async {
    if (_loadingStatusSnapshot || !_hasAdminToken) return;
    setState(() => _loadingStatusSnapshot = true);
    try {
      final results = await Future.wait([
        _backend.loadActivityCurrent(token: _requireAdminToken()),
        _backend.loadMoodState(token: _requireAdminToken()),
      ]);
      if (!mounted) return;
      setState(() {
        _activityCurrent = results[0] as ActivityCurrentState;
        _moodState = results[1] as MoodStateSnapshot;
      });
    } catch (_) {
      // 只读展示，失败保留旧值即可，不打扰用户
    } finally {
      if (mounted) setState(() => _loadingStatusSnapshot = false);
    }
  }

  static final RegExp _safeOwnerUserIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');
  static final RegExp _safeRelayTopicPattern = RegExp(r'^[a-z0-9/_-]+$');

  Future<T?> _showTextInputDialog<T>({
    required List<TextEditingController> controllers,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    try {
      return await showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (dialogContext) => PopScope<T>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _dismissTextInputDialog<T>(dialogContext);
          },
          child: builder(dialogContext),
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 320), () {
            for (final controller in controllers) {
              controller.dispose();
            }
          }),
        );
      });
    }
  }

  void _dismissTextInputDialog<T>(BuildContext dialogContext, {T? result}) {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop<T>(result);
      }
    });
  }

  void _openBackendSettings() {
    final controller = TextEditingController(text: _backendBaseUrl);
    final ownerController = TextEditingController(text: _ownerUserId);
    String? dialogError;
    String? ownerDialogError;

    unawaited(
      _showTextInputDialog<void>(
        controllers: [controller, ownerController],
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, dialogSetState) {
              return AlertDialog(
                backgroundColor: c.surface,
                scrollable: true,
                title: Text('后端节点', style: serif(c, 20)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      style: mono(c, 13),
                      decoration: InputDecoration(
                        hintText: 'http://192.168.1.23:8080',
                        errorText: dialogError,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '插线调试用 127.0.0.1；脱线使用电脑局域网 IP。',
                      style: serif(c, 12, color: c.ink3),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ownerController,
                      keyboardType: TextInputType.text,
                      style: mono(c, 13),
                      decoration: InputDecoration(
                        labelText: '用户 ID',
                        hintText: 'QQ 号或后端约定的 uid，仅限字母数字下划线短横线',
                        errorText: ownerDialogError,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => _dismissTextInputDialog(dialogContext),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final normalized = await _normalizeBackendBaseUrl(
                        controller.text,
                      );
                      if (normalized == null) {
                        dialogSetState(() => dialogError = '请输入有效地址');
                        return;
                      }
                      final ownerValue = ownerController.text.trim();
                      if (ownerValue.isNotEmpty &&
                          !_safeOwnerUserIdPattern.hasMatch(ownerValue)) {
                        dialogSetState(
                          () => ownerDialogError = '仅支持字母、数字、下划线、短横线',
                        );
                        return;
                      }
                      if (!dialogContext.mounted) return;
                      _dismissTextInputDialog(dialogContext);
                      if (ownerValue != _ownerUserId) {
                        await _connectionController.saveOwnerUserId(ownerValue);
                        if (mounted) setState(() {});
                      }
                      unawaited(_changeBackendBaseUrl(normalized));
                    },
                    child: const Text('保存并重连'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openRelaySettings() async {
    final currentBaseUrl = _connectionController.relayBaseUrl;
    final currentTopic = _connectionController.relayTopic;
    final currentToken = _connectionController.relayToken;
    if (!mounted) return;

    final baseUrlController = TextEditingController(text: currentBaseUrl);
    final topicController = TextEditingController(text: currentTopic);
    final tokenController = TextEditingController(text: currentToken);
    String? baseUrlError;
    String? topicError;

    await _showTextInputDialog<void>(
      controllers: [baseUrlController, topicController, tokenController],
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            return AlertDialog(
              backgroundColor: c.surface,
              scrollable: true,
              title: Text('推送中继（ntfy）', style: serif(c, 20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: baseUrlController,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    style: mono(c, 13),
                    decoration: InputDecoration(
                      labelText: '中继地址',
                      hintText: 'https://ntfy.sh 或 http://192.168.x.x:8090',
                      errorText: baseUrlError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: topicController,
                    keyboardType: TextInputType.text,
                    style: mono(c, 13),
                    decoration: InputDecoration(
                      labelText: 'topic',
                      hintText: '例：mychar-wake-a1b2c3（当作密码，用随机串）',
                      errorText: topicError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tokenController,
                    keyboardType: TextInputType.text,
                    style: mono(c, 13),
                    decoration: const InputDecoration(
                      labelText: 'token（可选）',
                      hintText: '中继服务无鉴权时留空',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '需与后端 config.yaml 的 relay_base_url/relay_topic/relay_token 三项一致。'
                    '留空 topic 会关闭中继实时唤醒，退化为周期补偿轮询。',
                    style: serif(c, 12, color: c.ink3),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => _dismissTextInputDialog(dialogContext),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    final topicValue = topicController.text.trim();
                    if (topicValue.isNotEmpty &&
                        (!_safeRelayTopicPattern.hasMatch(topicValue) ||
                            topicValue.length > 128)) {
                      dialogSetState(
                        () => topicError = '仅支持小写字母、数字、/ _ -，且不超过 128 字符',
                      );
                      return;
                    }
                    final rawBaseUrl = baseUrlController.text.trim();
                    String normalized = '';
                    if (rawBaseUrl.isNotEmpty) {
                      final resolved = await _normalizeBackendBaseUrl(
                        rawBaseUrl,
                      );
                      if (resolved == null) {
                        dialogSetState(() => baseUrlError = '请输入有效地址');
                        return;
                      }
                      if (!await _ensureTrustedBackendOrigin(resolved)) {
                        dialogSetState(() => baseUrlError = '未信任该地址');
                        return;
                      }
                      normalized = resolved;
                    }
                    if (!dialogContext.mounted) return;
                    _dismissTextInputDialog(dialogContext);
                    await _connectionController.saveRelay(
                      baseUrl: normalized,
                      topic: topicValue,
                      token: tokenController.text.trim(),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        scrollable: true,
        title: Text('要走了吗', style: serif(c, 18, color: c.ink1)),
        content: Text(
          result.retentionText ?? '再待一会儿吧。',
          style: serif(c, 14, color: c.ink2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('还是要走'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('留下'),
          ),
        ],
      ),
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
              sheetSetState(() => _dark = dark);
              unawaited(_themeController.select(null));
              setState(() {});
              _applySystemUi();
            }

            void manageThemes() {
              Navigator.pop(context);
              unawaited(_openThemePresetManager());
            }

            return SettingsPage(
              c: c,
              language: _localeController.language,
              dark: _dark,
              activeThemePresetName: _themeController.activePreset?.name,
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
                  _promptAssetsError ?? _dreamController.settingsError,
              onTheme: updateTheme,
              onLanguage: (language) {
                unawaited(_localeController.setLanguage(language));
                sheetSetState(() {});
              },
              onManageThemes: manageThemes,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('后端当前只支持 txt / md / docx')));
      return;
    }
    if (picked.bytes.length > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('后端文件上限是 5MB')));
      return;
    }
    await _chatController.uploadFiles(
      [picked],
      preview: '📎 ${picked.name}',
      failureLabel: '文件',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('后端当前只支持 jpg / png / gif / webp / heic / bmp'),
        ),
      );
      return;
    }
    if (picked.any((file) => file.bytes.length > 10 * 1024 * 1024)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('后端图片上限是单张 10MB')));
      return;
    }
    final names = picked.length == 1
        ? picked.first.name
        : picked.take(3).map((file) => file.name).join('、');
    final preview = picked.length == 1
        ? '📎 $names'
        : '📎 ${picked.length}张图片：$names${picked.length > 3 ? '…' : ''}';
    await _chatController.uploadFiles(
      picked,
      preview: preview,
      failureLabel: '图片',
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
      unawaited(_loadStatusSnapshot());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: c.surface,
        systemNavigationBarIconBrightness: _dark
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
          dark: _dark,
          prefs: _prefs,
          profileDisplayName: _profileDisplayName,
          profileAvatarBytes: _profileAvatarBytes,
          controller: _chatController,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          onOpenSettings: _openSettings,
          onOpenAttach: _openAttach,
          onToggleTheme: () => setState(() => _dark = !_dark),
          onLockNow: () => unawaited(_lockScreenNow()),
          onOpenOrderAccessibility: () =>
              unawaited(_requestOrderAssistantPermission()),
          onOpenMeituan: () => unawaited(_openShoppingApp('meituan', '美团')),
          onOpenTaobao: () => unawaited(_openShoppingApp('taobao', '淘宝')),
          onShowOrderBubble: () => unawaited(_showOrderBubble('meituan', '美团')),
          onVoiceRecordStart: _startVoiceRecording,
          onVoiceRecordStop: _stopVoiceRecordingAndTranscribe,
          onVoiceRecordCancel: () =>
              unawaited(_deviceController.cancelVoiceRecording()),
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
          activityCurrent: _activityCurrent,
          moodState: _moodState,
          loadingStatusSnapshot: _loadingStatusSnapshot,
          onReloadStatusSnapshot: () => unawaited(_loadStatusSnapshot()),
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
