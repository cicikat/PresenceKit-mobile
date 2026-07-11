part of '../main.dart';

class YexuanCompanionApp extends StatefulWidget {
  const YexuanCompanionApp({
    super.key,
    this.settingsStore = const AppSettingsStore(),
    this.backendClient,
  });

  final AppSettingsStore settingsStore;
  final BackendClient? backendClient;

  @override
  State<YexuanCompanionApp> createState() => _YexuanCompanionAppState();
}

class _YexuanCompanionAppState extends State<YexuanCompanionApp>
    with WidgetsBindingObserver {
  static const int _initialVisibleChatMessages = 80;
  static const int _visibleChatMessageStep = 50;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _chatScrollController = ScrollController();
  final ScrollController _dreamScrollController = ScrollController();
  Timer? _gardenRefreshTimer;
  Timer? _mobilePollTimer;
  Timer? _screenContextTimer;
  Timer? _dreamStateTimer;
  Timer? _sensorPushTimer;
  AppRoute _route = AppRoute.chat;
  bool _dark = false;
  bool _customThemeEnabled = false;
  bool _sending = false;
  bool _himTyping = false;
  bool _loadingHistory = false;
  bool _loadingMoreHistory = false;
  bool _noMoreHistory = false;
  bool _usingChatLogHistory = false;
  bool _historyLoaded = false;
  bool _loadingGarden = false;
  bool _loadingDiary = false;
  bool _diaryLoaded = false;
  bool _mobileActive = false;
  bool _pollingMobile = false;
  bool _backgroundNotifications = true;
  bool _screenContextUploadEnabled = false;
  bool _backendSyncStarted = false;
  bool _loadingDreamState = false;
  bool _enteringDream = false;
  bool _sendingDream = false;
  bool _loadingPromptAssets = false;
  bool _savingPromptAssets = false;
  bool _loadingDreamSettings = false;
  bool _savingDreamSettings = false;
  bool _showJumpToLatest = false;
  int _chatVisibleMessageLimit = _initialVisibleChatMessages;
  String? _backendError;
  String? _historyError;
  String? _gardenError;
  String? _diaryError;
  String? _mobileError;
  String? _dreamError;
  String? _promptAssetsError;
  String? _dreamSettingsError;
  int _mobileReceivedCount = 0;
  int? _lastAckedMobileSeq;
  String? _lastMobileContent;
  BackendChatResponse? _lastBackendReply;
  DreamState? _dreamState;
  PromptAssets? _promptAssets;
  DreamSettings? _dreamSettings;
  GardenState? _gardenState;
  String _backendBaseUrl = _defaultBackendBaseUrl;
  String? _profileNameOverride;
  Uint8List? _profileAvatarBytes;
  String _ownerUserId = '';
  String _adminToken = '';
  late final AppSettingsStore _settingsStore;
  late BackendClient _backend;
  YxPrefs _prefs = const YxPrefs();
  YxPalette? _customPalette;
  final List<ChatMessage> _history = [];
  final List<ChatMessage> _sent = [];
  final List<ChatMessage> _dreamMessages = [];
  final Map<String, DateTime> _recentAssistantReplies = {};
  final Map<String, String> _recentAssistantReplyIdsByFingerprint = {};
  final Set<String> _synchronousAssistantReplyIds = {};
  // message.id 去重：防止同一 id 在多次 poll 中重复展示；顺序维护以便 FIFO 淘汰。
  final List<String> _seenMobileMessageIds = [];
  final List<DiaryListItem> _diaryEntries = [];
  final List<String> _availableChatLogDates = [];
  final List<String> _loadedChatLogDates = [];

  YxPalette get c {
    final custom = _customPalette;
    if (_customThemeEnabled && custom != null) return custom;
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
    _settingsStore = widget.settingsStore;
    _backend =
        widget.backendClient ??
        BackendClient(baseUrl: _backendBaseUrl, settingsStore: _settingsStore);
    WidgetsBinding.instance.addObserver(this);
    _chatScrollController.addListener(_handleChatScroll);
    _applySystemUi();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applySystemUi());
    unawaited(_restoreBackendAndStart());
  }

  Future<void> _restoreBackendAndStart() async {
    final stored = await _settingsStore.loadBackendBaseUrl();
    final storedName = await _settingsStore.loadProfileDisplayName();
    final storedAvatar = await _settingsStore.loadProfileAvatar();
    final storedPalette = YxPalette.fromJsonString(
      await _settingsStore.loadCustomThemePalette(),
    );
    final backgroundNotifications = await _settingsStore
        .loadBackgroundNotificationsEnabled();
    final adminToken = await _settingsStore.loadAdminToken();
    final ownerUserId = await _settingsStore.loadOwnerUserId();
    final screenContextUploadEnabled = await _settingsStore
        .loadScreenContextUploadEnabled();
    final lastAckedMobileSeq = await _settingsStore.loadLastAckedMobileSeq();
    final normalized = await _normalizeBackendBaseUrl(stored ?? '');
    if (mounted) {
      setState(() {
        _backgroundNotifications = backgroundNotifications;
        _adminToken = adminToken?.trim() ?? '';
        _ownerUserId = ownerUserId?.trim() ?? '';
        _screenContextUploadEnabled = screenContextUploadEnabled;
        _lastAckedMobileSeq = lastAckedMobileSeq;
        _profileNameOverride = storedName;
        _profileAvatarBytes = storedAvatar;
        _customPalette = storedPalette;
        _customThemeEnabled = storedPalette != null;
        if (normalized != null) {
          _backendBaseUrl = normalized;
        }
        _backend =
            widget.backendClient ??
            BackendClient(
              baseUrl: _backendBaseUrl,
              settingsStore: _settingsStore,
            );
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
    unawaited(_loadHistory());
    unawaited(_loadGarden());
    unawaited(_activateMobile());
    _gardenRefreshTimer?.cancel();
    _gardenRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_loadGarden(silent: true)),
    );
    _startMobilePollTimer();
    if (_screenContextUploadEnabled) {
      _pushScreenContextOnce(silent: true);
    }
    _screenContextTimer?.cancel();
    _screenContextTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_screenContextUploadEnabled) {
        unawaited(_pushScreenContextOnce(silent: true));
      }
    });
    unawaited(_pushSensorDataOnce());
    _sensorPushTimer?.cancel();
    _sensorPushTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => unawaited(_pushSensorDataOnce()),
    );
  }

  void _startMobilePollTimer() {
    _stopMobilePollTimer();
    _mobilePollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_pollMobileIfRelayUnavailable()),
    );
  }

  void _stopMobilePollTimer() {
    _mobilePollTimer?.cancel();
    _mobilePollTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applySystemUi();
      if (_hasAdminToken && _mobilePollTimer == null) {
        unawaited(_activateMobile());
        _startMobilePollTimer();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stopMobilePollTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gardenRefreshTimer?.cancel();
    _stopMobilePollTimer();
    _screenContextTimer?.cancel();
    _dreamStateTimer?.cancel();
    _sensorPushTimer?.cancel();
    _chatScrollController.removeListener(_handleChatScroll);
    if (_hasAdminToken) {
      unawaited(
        _backend.deactivateMobile(token: _adminToken).catchError((_) {}),
      );
    }
    _chatScrollController.dispose();
    _dreamScrollController.dispose();
    super.dispose();
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

  Future<String?> _normalizeBackendBaseUrl(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final withScheme =
        RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)
        ? trimmed
        : 'http://$trimmed';
    return _settingsStore.normalizeOrigin(withScheme);
  }

  Future<bool> _ensureTrustedBackendOrigin(String normalized) async {
    if (await _settingsStore.isAllowedBaseUrl(normalized)) return true;
    final origin = await _settingsStore.normalizeOrigin(normalized);
    if (origin == null ||
        !await _settingsStore.isConfirmablePrivateCleartextOrigin(origin)) {
      return false;
    }
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
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
    return await _settingsStore.addTrustedCleartextOrigin(origin) && mounted;
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

    _gardenRefreshTimer?.cancel();
    _mobilePollTimer?.cancel();
    final previousBackend = _backend;
    if (_hasAdminToken) {
      unawaited(
        previousBackend.deactivateMobile(token: _adminToken).catchError((_) {}),
      );
    }
    setState(() {
      _backendBaseUrl = normalized;
      _backend = BackendClient(
        baseUrl: _backendBaseUrl,
        settingsStore: _settingsStore,
      );
      _backendError = null;
      _historyError = null;
      _gardenError = null;
      _diaryError = null;
      _mobileError = null;
      _lastBackendReply = null;
      _gardenState = null;
      _mobileActive = false;
      _historyLoaded = false;
      _loadingMoreHistory = false;
      _noMoreHistory = false;
      _usingChatLogHistory = false;
      _diaryLoaded = false;
      _history.clear();
      _availableChatLogDates.clear();
      _loadedChatLogDates.clear();
      _diaryEntries.clear();
    });
    await _settingsStore.saveBackendBaseUrl(normalized);
    if (!mounted) return;
    if (_hasAdminToken) _startBackendSync();
  }

  Future<void> _openAdminTokenSettings({bool required = false}) async {
    if (!mounted) return;
    final controller = TextEditingController();
    String? dialogError;
    final savedToken = await showDialog<String>(
      context: context,
      barrierDismissible: !required,
      builder: (dialogContext) => Theme(
        data: Theme.of(dialogContext).copyWith(
          colorScheme: Theme.of(dialogContext).colorScheme.copyWith(
            surface: c.surface,
            onSurface: c.ink1,
            primary: c.character,
            error: c.danger,
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: c.character,
            selectionColor: c.characterSoft,
            selectionHandleColor: c.character,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: c.surfaceSoft,
            labelStyle: TextStyle(color: c.ink2),
            hintStyle: TextStyle(color: c.ink3),
            errorStyle: TextStyle(color: c.danger),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: c.surfaceEdge),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: c.character, width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: c.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: c.danger, width: 1.4),
            ),
          ),
        ),
        child: StatefulBuilder(
          builder: (dialogContext, dialogSetState) => AlertDialog(
            backgroundColor: c.surface,
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
                  onPressed: () => Navigator.pop(dialogContext),
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
                    await _settingsStore.saveAdminToken(value);
                  } catch (e) {
                    if (!dialogContext.mounted) return;
                    dialogSetState(() => dialogError = '保存失败：$e');
                    return;
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext, value);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (savedToken == null || !mounted) return;
    final shouldStartSync = !_backendSyncStarted;
    _adminToken = savedToken;
    _backendError = null;
    _mobileError = null;
    Navigator.maybeOf(context, rootNavigator: true)?.popUntil(
      (route) => route.isFirst,
    );
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (!mounted) return;
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
    await _settingsStore.saveBackgroundNotificationsEnabled(enabled);
    if (!mounted) return;
    if (!enabled) {
      await _settingsStore.stopBackgroundNotifications();
    }
  }

  Future<void> _changeScreenContextUploadEnabled(bool enabled) async {
    await _settingsStore.saveScreenContextUploadEnabled(enabled);
    if (!mounted) return;
    setState(() => _screenContextUploadEnabled = enabled);
  }

  Future<void> _changeScreenTextUploadAllowedPackages(
    Set<String> values,
  ) async {
    await _settingsStore.saveScreenTextUploadAllowedPackages(values);
  }

  Future<void> _saveCustomPalette(YxPalette palette) async {
    setState(() {
      _customPalette = palette;
      _customThemeEnabled = true;
    });
    _applySystemUi();
    await _settingsStore.saveCustomThemePalette(palette.toJsonString());
  }

  Future<void> _deleteCustomPalette() async {
    setState(() {
      _customPalette = null;
      _customThemeEnabled = false;
    });
    _applySystemUi();
    await _settingsStore.deleteCustomThemePalette();
  }

  Future<void> _openCustomThemeEditor() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ThemePaletteSheet(
        c: c,
        initial: _customPalette ?? c,
        canDelete: _customPalette != null,
        onSave: _saveCustomPalette,
        onDelete: _deleteCustomPalette,
      ),
    );
  }

  Future<void> _lockScreenNow() async {
    final locked = await _settingsStore.lockScreen();
    if (!mounted) return;
    if (!locked) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先启用“陪伴锁屏确认”的设备管理器权限')));
    }
  }

  Future<void> _requestOrderAssistantPermission() async {
    final enabled = await _settingsStore.isAccessibilityServiceEnabled();
    if (!mounted) return;
    if (enabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('陪伴操作助手已授权')));
      return;
    }
    await _settingsStore.requestAccessibilityPermission();
  }

  Future<void> _openShoppingApp(String target, String label) async {
    final opened = await _settingsStore.openShoppingApp(target);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('没有找到 $label，先手动安装或确认包名')));
    }
  }

  Future<void> _showOrderBubble(String target, String label) async {
    final shown = await _settingsStore.showOrderBubble(target);
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

  Future<bool> _startVoiceRecording() async {
    var granted = await _settingsStore.hasRecordAudioPermission();
    if (!granted) {
      await _settingsStore.requestRecordAudioPermission();
      // 系统权限弹窗是异步的，这里给用户一点交互时间后再查一次；
      // 拒绝的话下面 startVoiceRecording 会失败，composer 侧会回退到未录音态。
      await Future<void>.delayed(const Duration(milliseconds: 400));
      granted = await _settingsStore.hasRecordAudioPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麦克风权限才能语音输入')),
          );
        }
        return false;
      }
    }
    return _settingsStore.startVoiceRecording();
  }

  Future<String?> _stopVoiceRecordingAndTranscribe() async {
    final filePath = await _settingsStore.stopVoiceRecording();
    if (filePath == null) return null;
    try {
      final text = await _backend.transcribeAudio(
        filePath: filePath,
        token: _requireAdminToken(),
      );
      return text;
    } on BackendException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('语音转写失败：${e.message}')));
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('语音转写失败：$e')));
      }
      return null;
    } finally {
      unawaited(File(filePath).delete().catchError((_) => File(filePath)));
    }
  }

  // ── W9：传感器上报（步数/电量，30 分钟一次） ─────────────────────────────────

  Future<void> _pushSensorDataOnce() async {
    if (!_hasAdminToken) return;
    try {
      final battery = await _settingsStore.readBatteryPercent();
      int? steps;
      final stepsGranted = await _settingsStore.hasActivityRecognitionPermission();
      if (stepsGranted) {
        steps = await _settingsStore.readTodaySteps();
      } else {
        // 首次静默申请一次；这次上报先不带步数，下次 tick 再补上。
        await _settingsStore.requestActivityRecognitionPermission();
      }
      if (battery == null && steps == null) return;
      await _backend.pushSensorData(
        token: _requireAdminToken(),
        battery: battery,
        steps: steps,
      );
    } catch (_) {
      // 传感器上报是低优先级后台任务，静默失败即可，不打扰用户。
    }
  }

  Future<void> _pushScreenContextOnce({bool silent = false}) async {
    if (!_screenContextUploadEnabled) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screen context upload is disabled')),
        );
      }
      return;
    }
    final snapshot = await _settingsStore.captureScreenContextForUpload();
    if (snapshot == null) return;
    if (snapshot.packageName == 'com.example.yexuan_memery') {
      // 前台是自己时只发焦点信号，不把聊天正文注入传感通道。
      try {
        await _backend.pushSelfFocusSignal(token: _requireAdminToken());
      } on BackendException {
        // 静默失败，与普通上下文推送行为一致。
      }
      return;
    }
    await _pushScreenContextSnapshot(snapshot, silent: silent);
  }

  Future<ScreenContextSnapshot?> _captureScreenContextForDebug({
    bool silent = false,
  }) async {
    final enabled = await _settingsStore.isAccessibilityServiceEnabled();
    if (!enabled) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先开启无障碍服务，才能读取屏幕上下文')));
      }
      return null;
    }
    final snapshot = await _settingsStore.captureScreenContext();
    if (snapshot == null || snapshot.isEmpty) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时没有可读的屏幕上下文')));
      }
      return null;
    }
    return snapshot;
  }

  Future<void> _pushScreenContextSnapshot(
    ScreenContextSnapshot snapshot, {
    bool silent = false,
  }) async {
    if (!_screenContextUploadEnabled) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screen context upload is disabled')),
        );
      }
      return;
    }
    if (snapshot.isBlocked) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sensitive screen filtered: ${snapshot.blockedReason}',
            ),
          ),
        );
      }
      return;
    }
    try {
      final allowedPackages = await _settingsStore
          .loadScreenTextUploadAllowedPackages();
      await _backend.pushScreenContext(
        snapshot,
        token: _requireAdminToken(),
        allowTextUpload: allowedPackages.contains(snapshot.packageName),
      );
      if (!silent && mounted) {
        final label = snapshot.appLabel.isNotEmpty
            ? snapshot.appLabel
            : snapshot.packageName;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已推送屏幕上下文：$label')));
      }
    } on BackendException catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('屏幕上下文推送失败：${e.message}')));
      }
    }
  }

  Future<void> _pushBehaviorTest(String kind) async {
    final spec = _BehaviorTestSpec.forKind(kind);
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
      await _pollMobileIfRelayUnavailable();
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
    await _settingsStore.saveProfileDisplayName(cleaned ?? '');
    if (!mounted) return;
    setState(() => _profileNameOverride = cleaned);
  }

  Future<void> _importProfileAvatar() async {
    final sourceBytes = await _settingsStore.pickProfileImage();
    if (!mounted || sourceBytes == null) return;
    final cropped = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AvatarCropDialog(c: c, bytes: sourceBytes),
    );
    if (!mounted || cropped == null) return;
    final saved = await _settingsStore.saveProfileAvatar(cropped);
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
    await _settingsStore.deleteProfileAvatar();
    if (!mounted) return;
    setState(() => _profileAvatarBytes = null);
  }

  Future<CapabilityStatus> _loadCapabilityStatus() async {
    final results = await Future.wait<Object>([
      _settingsStore.areNotificationsEnabled(),
      _settingsStore.canDrawOverlays(),
      _settingsStore.isAccessibilityServiceEnabled(),
      _settingsStore.isDeviceAdminActive(),
      _settingsStore.isBackgroundNotificationServiceRunning(),
      _settingsStore.loadBackgroundPollStatus(),
      _settingsStore.loadRelayConnectionStatus(),
      _settingsStore.loadNotificationGateStatus(),
      _settingsStore.isIgnoringBatteryOptimizations(),
      _settingsStore.loadScreenTextUploadAllowedPackages(),
      _settingsStore.loadScreenTextUploadAppOptions(),
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
      ignoringBatteryOptimizations: results[8] as bool,
      screenContextUploadEnabled: _screenContextUploadEnabled,
      screenTextUploadAllowedPackages: results[9] as Set<String>,
      screenTextUploadAppOptions:
          results[10] as List<ScreenTextUploadAppOption>,
      backendBaseUrl: _backendBaseUrl,
      backendReachable: _mobileActive || _historyLoaded || _gardenState != null,
      backendBusy: _pollingMobile || _loadingHistory || _loadingGarden,
      backendError: _mobileError ?? _backendError ?? _historyError,
    );
  }

  Future<void> _testBackendConnectivity() async {
    await _activateMobile();
    if (!mounted) return;
    await Future.wait([_loadHistory(), _loadGarden()]);
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
        onRequestNotifications: _settingsStore.requestNotificationPermission,
        onRequestIgnoreBatteryOptimizations:
            _settingsStore.requestIgnoreBatteryOptimizations,
        onToggleNotificationTestMode: _settingsStore.setNotificationTestMode,
        onRequestOverlay: _settingsStore.requestOverlayPermission,
        onRequestAccessibility: _settingsStore.requestAccessibilityPermission,
        onRequestDeviceAdmin: _settingsStore.requestDeviceAdmin,
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
        onDebugBackgroundDelivery: _settingsStore.debugBackgroundDelivery,
        onLoadBehaviorStatus: () =>
            _backend.loadBehaviorDecisionStatus(token: _requireAdminToken()),
        onFetchDiagnostics: () =>
            _backend.fetchDiagnostics(token: _requireAdminToken()),
        onEditBackend: _openBackendSettings,
        onEditRelay: _openRelaySettings,
      ),
    );
  }

  void _openProfilePage() {
    Navigator.of(context).maybePop();
    setState(() => _route = AppRoute.profile);
  }

  static final RegExp _safeOwnerUserIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');
  static final RegExp _safeRelayTopicPattern = RegExp(r'^[a-z0-9/_-]+$');

  void _openBackendSettings() {
    final controller = TextEditingController(text: _backendBaseUrl);
    final ownerController = TextEditingController(text: _ownerUserId);
    String? dialogError;
    String? ownerDialogError;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            return AlertDialog(
              backgroundColor: c.surface,
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
                  onPressed: () => Navigator.pop(dialogContext),
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
                    Navigator.pop(dialogContext);
                    if (ownerValue != _ownerUserId) {
                      await _settingsStore.saveOwnerUserId(ownerValue);
                      if (mounted) setState(() => _ownerUserId = ownerValue);
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
    ).whenComplete(() {
      controller.dispose();
      ownerController.dispose();
    });
  }

  Future<void> _openRelaySettings() async {
    final currentBaseUrl = await _settingsStore.loadRelayBaseUrl() ?? '';
    final currentTopic = await _settingsStore.loadRelayTopic() ?? '';
    final currentToken = await _settingsStore.loadRelayToken() ?? '';
    if (!mounted) return;

    final baseUrlController = TextEditingController(text: currentBaseUrl);
    final topicController = TextEditingController(text: currentTopic);
    final tokenController = TextEditingController(text: currentToken);
    String? baseUrlError;
    String? topicError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            return AlertDialog(
              backgroundColor: c.surface,
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
                      hintText: '例：yexuan-wake-a1b2c3（当作密码，用随机串）',
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
                  onPressed: () => Navigator.pop(dialogContext),
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
                    Navigator.pop(dialogContext);
                    await _settingsStore.saveRelayBaseUrl(normalized);
                    await _settingsStore.saveRelayTopic(topicValue);
                    await _settingsStore.saveRelayToken(
                      tokenController.text.trim(),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      baseUrlController.dispose();
      topicController.dispose();
      tokenController.dispose();
    });
  }

  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    if (!_hasAdminToken) {
      unawaited(_openAdminTokenSettings(required: true));
      return;
    }
    setState(() {
      _sending = true;
      _himTyping = true;
      _backendError = null;
      _sent.add(ChatMessage(role: 'you', text: trimmed, time: '现在'));
    });
    _scrollChatToBottom();
    unawaited(_sendToBackend(trimmed));
  }

  Future<void> _loadHistory() async {
    if (_loadingHistory) return;
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final datesResponse = await _backend.loadChatLogDates(
        token: _requireAdminToken(),
      );
      final dates = datesResponse.dates;
      final loadedDates = <String>[];
      var messages = <ChatMessage>[];
      var noMoreHistory = dates.isEmpty;

      if (dates.isNotEmpty) {
        final today = _dateKey(DateTime.now());
        var firstDate = dates.contains(today) ? today : dates.first;
        var day = await _backend.loadChatLogDay(
          firstDate,
          token: _requireAdminToken(),
        );
        messages = _messagesFromChatLogDay(day);
        loadedDates.add(firstDate);

        final firstIdx = dates.indexOf(firstDate);
        final previousDate = firstIdx >= 0 && firstIdx + 1 < dates.length
            ? dates[firstIdx + 1]
            : null;
        if (_conversationMessageCount(messages) < 10 && previousDate != null) {
          day = await _backend.loadChatLogDay(
            previousDate,
            token: _requireAdminToken(),
          );
          messages = [..._messagesFromChatLogDay(day), ...messages];
          loadedDates.insert(0, previousDate);
          firstDate = previousDate;
        }

        final earliestIdx = dates.indexOf(firstDate);
        noMoreHistory = earliestIdx < 0 || earliestIdx >= dates.length - 1;
      }

      if (!mounted) return;
      setState(() {
        _history
          ..clear()
          ..addAll(messages);
        _availableChatLogDates
          ..clear()
          ..addAll(dates);
        _loadedChatLogDates
          ..clear()
          ..addAll(loadedDates);
        _noMoreHistory = noMoreHistory;
        _usingChatLogHistory = true;
        _historyLoaded = true;
        _chatVisibleMessageLimit = _initialVisibleChatMessages;
      });
      _scrollChatToBottom();
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _historyError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _historyError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  Future<void> _loadOlderHistory() async {
    if (_loadingHistory ||
        _loadingMoreHistory ||
        _noMoreHistory ||
        !_usingChatLogHistory ||
        _loadedChatLogDates.isEmpty ||
        _availableChatLogDates.isEmpty) {
      return;
    }
    final earliestLoaded = _loadedChatLogDates.first;
    final earliestIdx = _availableChatLogDates.indexOf(earliestLoaded);
    final targetIdx = earliestIdx + 1;
    if (earliestIdx < 0 || targetIdx >= _availableChatLogDates.length) {
      setState(() => _noMoreHistory = true);
      return;
    }

    final position = _chatScrollController.hasClients
        ? _chatScrollController.position
        : null;
    final oldMaxExtent = position?.maxScrollExtent ?? 0;
    final oldPixels = position?.pixels ?? 0;
    final targetDate = _availableChatLogDates[targetIdx];

    setState(() {
      _loadingMoreHistory = true;
      _historyError = null;
    });
    try {
      final day = await _backend.loadChatLogDay(
        targetDate,
        token: _requireAdminToken(),
      );
      final olderMessages = _messagesFromChatLogDay(day);
      if (!mounted) return;
      setState(() {
        _history.insertAll(0, olderMessages);
        _loadedChatLogDates.insert(0, targetDate);
        _noMoreHistory = targetIdx >= _availableChatLogDates.length - 1;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_chatScrollController.hasClients) return;
        final newMaxExtent = _chatScrollController.position.maxScrollExtent;
        final compensated = newMaxExtent - oldMaxExtent + oldPixels;
        _chatScrollController.jumpTo(
          compensated.clamp(
            _chatScrollController.position.minScrollExtent,
            _chatScrollController.position.maxScrollExtent,
          ),
        );
      });
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _historyError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _historyError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingMoreHistory = false);
      }
    }
  }

  Future<void> _loadGarden({bool silent = false}) async {
    if (_loadingGarden) return;
    if (!silent) {
      setState(() {
        _loadingGarden = true;
        _gardenError = null;
      });
    } else {
      _loadingGarden = true;
    }
    try {
      final state = await _backend.loadGardenState(token: _requireAdminToken());
      if (!mounted) return;
      setState(() {
        _gardenState = state;
        _gardenError = null;
      });
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _gardenError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _gardenError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingGarden = false);
      } else {
        _loadingGarden = false;
      }
    }
  }

  Future<void> _loadDiaryList({bool silent = false}) async {
    if (_loadingDiary) return;
    if (!silent) {
      setState(() {
        _loadingDiary = true;
        _diaryError = null;
      });
    } else {
      _loadingDiary = true;
    }
    try {
      final entries = await _backend.loadDiaryList(token: _requireAdminToken());
      if (!mounted) return;
      setState(() {
        _diaryEntries
          ..clear()
          ..addAll(entries);
        _diaryLoaded = true;
        _diaryError = null;
      });
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _diaryError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _diaryError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingDiary = false);
      } else {
        _loadingDiary = false;
      }
    }
  }

  Future<DiaryDetail> _loadDiaryEntry(String date) {
    return _backend.loadDiaryEntry(date, token: _requireAdminToken());
  }

  Future<void> _activateMobile() async {
    try {
      await _backend.activateMobile(token: _requireAdminToken());
      if (!mounted) return;
      setState(() {
        _mobileActive = true;
        _mobileError = null;
      });
      await _pollMobileIfRelayUnavailable();
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _mobileActive = false;
        _mobileError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mobileActive = false;
        _mobileError = e.toString();
      });
    }
  }

  Future<void> _pollMobileIfRelayUnavailable() async {
    final nativeServiceRunning = await _settingsStore
        .isBackgroundNotificationServiceRunning();
    if (!mounted || nativeServiceRunning) return;
    await _pollMobile();
  }

  Future<void> _pollMobile() async {
    if (_pollingMobile) return;
    _pollingMobile = true;
    try {
      final persistedSeq = await _settingsStore.loadLastAckedMobileSeq();
      if (persistedSeq != null &&
          (_lastAckedMobileSeq == null ||
              persistedSeq > _lastAckedMobileSeq!)) {
        _lastAckedMobileSeq = persistedSeq;
      }
      final persistedSeenIds = await _settingsStore.loadSeenMobileMessageIds();
      for (final id in persistedSeenIds) {
        if (id.isEmpty || _seenMobileMessageIds.contains(id)) continue;
        _seenMobileMessageIds.add(id);
      }
      while (_seenMobileMessageIds.length > 200) {
        _seenMobileMessageIds.removeAt(0);
      }
      final token = _requireAdminToken();
      final messages = await _backend.pollMobile(
        token: token,
        after: _lastAckedMobileSeq,
        waitSeconds: 25,
      );
      if (!mounted) return;
      // 有 id 时只按 id 对账；内容指纹仅兜底旧后端/无 id 消息。
      final freshMessages = <MobilePollMessage>[];
      for (final msg in messages) {
        if (msg.id.isNotEmpty) {
          if (_seenMobileMessageIds.contains(msg.id)) continue;
          _seenMobileMessageIds.add(msg.id);
          if (_seenMobileMessageIds.length > 200) {
            _seenMobileMessageIds.removeAt(0);
          }
          if (_synchronousAssistantReplyIds.contains(msg.id)) continue;
          if (_isRecentAssistantReply(msg.content, msgId: msg.id)) continue;
          _rememberAssistantReply(msg.content, msgId: msg.id);
        } else {
          if (_isRecentAssistantReply(msg.content)) continue;
          _rememberAssistantReply(msg.content);
        }
        freshMessages.add(msg);
      }
      final incoming = <ChatMessage>[];
      for (final message in freshMessages) {
        final base = message.toChatMessage();
        // Behavior messages (lock-screen, takeout overlay, etc.) are single-line
        // by design — don't split them so their payload stays intact.
        if (message.behaviorKind.isNotEmpty) {
          incoming.add(base);
        } else {
          final parts = _splitReplySegments(message.content);
          if (parts.length <= 1) {
            incoming.add(base);
          } else {
            for (final part in parts) {
              incoming.add(ChatMessage(role: base.role, text: part, time: base.time));
            }
          }
        }
      }
      final statusChanged = !_mobileActive || _mobileError != null;
      if (incoming.isNotEmpty || statusChanged) {
        setState(() {
          _mobileActive = true;
          _mobileError = null;
          _sent.addAll(incoming);
          if (freshMessages.isNotEmpty) {
            _mobileReceivedCount += freshMessages.length;
            _lastMobileContent = freshMessages.last.content;
          }
        });
      }
      if (freshMessages.isNotEmpty) {
        _scrollChatToBottom();
      }
      if (_seenMobileMessageIds.isNotEmpty) {
        // Intentional dual write with MobileNotificationService, guarded by
        // foreground/background handoff timing. Persist before ack so an ack
        // failure can be retried without displaying the message twice.
        await _settingsStore.saveSeenMobileMessageIds(
          List<String>.unmodifiable(_seenMobileMessageIds),
        );
      }
      int? batchMaxSeq;
      for (final message in messages) {
        final seq = message.seq;
        if (seq != null && (batchMaxSeq == null || seq > batchMaxSeq)) {
          batchMaxSeq = seq;
        }
      }
      if (batchMaxSeq != null) {
        await _backend.ackMobile(token: token, ackSeq: batchMaxSeq);
        await _settingsStore.saveLastAckedMobileSeq(batchMaxSeq);
        if (_lastAckedMobileSeq == null || batchMaxSeq > _lastAckedMobileSeq!) {
          _lastAckedMobileSeq = batchMaxSeq;
        }
      }
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _mobileActive = false;
        _mobileError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mobileActive = false;
        _mobileError = e.toString();
      });
    } finally {
      _pollingMobile = false;
    }
  }

  Future<void> _sendToBackend(String message) async {
    try {
      final response = await _backend.sendChat(
        message,
        token: _requireAdminToken(),
      );
      if (!mounted) return;
      setState(() => _lastBackendReply = response);
      if (_shouldAppendSynchronousReply(response)) {
        await _appendHimReplySegments(response.reply);
      }
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _himTyping = false;
        _backendError = e.message;
        _sent.add(
          ChatMessage(
            role: 'him',
            text: '（手机端暂时连不上后端：${e.message}）',
            time: _nowLabel(),
          ),
        );
      });
      _scrollChatToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _himTyping = false;
        _backendError = e.toString();
        _sent.add(
          ChatMessage(
            role: 'him',
            text: '（手机端遇到一个未预期错误：$e）',
            time: _nowLabel(),
          ),
        );
      });
      _scrollChatToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _himTyping = false;
        });
      }
    }
  }

  Future<void> _appendHimReplySegments(String reply) async {
    final parts = _splitReplySegments(reply);
    final rng = math.Random();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: 100 + rng.nextInt(901)),
        );
      }
      if (!mounted) return;
      setState(() {
        _himTyping = false;
        _sent.add(ChatMessage(role: 'him', text: parts[i], time: _nowLabel()));
      });
      _scrollChatToBottom();
      if (i < parts.length - 1 && mounted) {
        setState(() => _himTyping = true);
        _scrollChatToBottom();
      }
    }
  }

  List<String> _splitReplySegments(String reply) {
    final normalized = reply.trim();
    if (normalized.isEmpty) return const ['……'];
    final parts = normalized
        .split(RegExp(r'\r?\n+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? const ['……'] : parts;
  }

  String _replyFingerprint(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  bool _isRecentAssistantReply(String text, {String? msgId}) {
    final now = DateTime.now();
    _recentAssistantReplies.removeWhere(
      (_, seenAt) => now.difference(seenAt) > const Duration(seconds: 45),
    );
    _recentAssistantReplyIdsByFingerprint.removeWhere(
      (fingerprint, _) => !_recentAssistantReplies.containsKey(fingerprint),
    );
    final fingerprint = _replyFingerprint(text);
    if (!_recentAssistantReplies.containsKey(fingerprint)) return false;
    if (msgId == null) return true;
    return !_recentAssistantReplyIdsByFingerprint.containsKey(fingerprint);
  }

  void _rememberAssistantReply(String text, {String? msgId}) {
    final fingerprint = _replyFingerprint(text);
    if (fingerprint.isNotEmpty) {
      _recentAssistantReplies[fingerprint] = DateTime.now();
      if (msgId == null) {
        _recentAssistantReplyIdsByFingerprint.remove(fingerprint);
      } else {
        _recentAssistantReplyIdsByFingerprint[fingerprint] = msgId;
      }
    }
  }

  bool _shouldAppendSynchronousReply(BackendChatResponse response) {
    final msgId = response.msgId;
    final turnId = response.turnId;

    // Register both ids so poll dedup catches the turn_id the backend uses
    // when fanning out to the mobile channel (see task round-移动端状态页).
    void registerId(String id) {
      _synchronousAssistantReplyIds.add(id);
      while (_synchronousAssistantReplyIds.length > 200) {
        _synchronousAssistantReplyIds.remove(
          _synchronousAssistantReplyIds.first,
        );
      }
    }

    if (msgId != null) registerId(msgId);
    if (turnId != null) registerId(turnId);

    if (msgId != null || turnId != null) {
      final alreadyReceivedFromPoll =
          (msgId != null && _seenMobileMessageIds.contains(msgId)) ||
          (turnId != null && _seenMobileMessageIds.contains(turnId));
      final effectiveId = msgId ?? turnId!;
      if (alreadyReceivedFromPoll ||
          _isRecentAssistantReply(response.reply, msgId: effectiveId)) {
        return false;
      }
      _rememberAssistantReply(response.reply, msgId: effectiveId);
      return true;
    }
    if (_isRecentAssistantReply(response.reply)) return false;
    _rememberAssistantReply(response.reply);
    return true;
  }

  List<ChatMessage> _messagesFromChatLogDay(ChatLogDay day) {
    return [
      for (final entry in day.entries) ...[
        for (final part in _splitHistorySegments(entry.user))
          ChatMessage(role: 'you', text: part, time: entry.time),
        for (final part in _splitHistorySegments(entry.assistant))
          ChatMessage(role: 'him', text: part, time: entry.time),
      ],
    ];
  }

  List<String> _splitHistorySegments(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    if (AttachmentPlaceholder.parse(trimmed) != null) return [trimmed];
    return _splitReplySegments(trimmed);
  }

  int _conversationMessageCount(List<ChatMessage> messages) {
    return messages
        .where((message) => message.role == 'you' || message.role == 'him')
        .length;
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _handleChatScroll() {
    if (_route != AppRoute.chat) return;
    if (!_chatScrollController.hasClients) return;
    final position = _chatScrollController.position;
    final shouldShowJump = position.maxScrollExtent - position.pixels > 260;
    if (shouldShowJump != _showJumpToLatest && mounted) {
      setState(() => _showJumpToLatest = shouldShowJump);
    }
    if (_chatScrollController.position.pixels < 200) {
      final totalMessages = _history.length + _sent.length;
      if (!_revealOlderLocalMessages(totalMessages)) {
        unawaited(_loadOlderHistory());
      }
    }
  }

  bool _revealOlderLocalMessages(int totalMessages) {
    if (_chatVisibleMessageLimit >= totalMessages) return false;
    final position = _chatScrollController.hasClients
        ? _chatScrollController.position
        : null;
    final oldMaxExtent = position?.maxScrollExtent ?? 0;
    final oldPixels = position?.pixels ?? 0;
    setState(() {
      _chatVisibleMessageLimit = math.min(
        totalMessages,
        _chatVisibleMessageLimit + _visibleChatMessageStep,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      final newMaxExtent = _chatScrollController.position.maxScrollExtent;
      final compensated = newMaxExtent - oldMaxExtent + oldPixels;
      _chatScrollController.jumpTo(
        compensated.clamp(
          _chatScrollController.position.minScrollExtent,
          _chatScrollController.position.maxScrollExtent,
        ),
      );
    });
    return true;
  }

  String _nowLabel() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _scrollChatToBottom() {
    if (_showJumpToLatest && mounted) {
      setState(() => _showJumpToLatest = false);
    }
    void scroll({bool animate = true}) {
      if (!mounted) return;
      if (!_chatScrollController.hasClients) return;
      final target = _chatScrollController.position.maxScrollExtent;
      if (animate) {
        _chatScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        _chatScrollController.jumpTo(target);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => scroll());
    Future<void>.delayed(
      const Duration(milliseconds: 360),
      () => scroll(animate: false),
    );
  }

  void _scrollDreamToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dreamScrollController.hasClients) return;
      _dreamScrollController.animateTo(
        _dreamScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _loadDreamState({bool silent = false}) async {
    if (_loadingDreamState || !_hasAdminToken) return;
    if (!silent && mounted) {
      setState(() {
        _loadingDreamState = true;
        _dreamError = null;
      });
    } else {
      _loadingDreamState = true;
    }
    try {
      final state = await _backend.loadDreamState(token: _requireAdminToken());
      if (!mounted) return;
      setState(() {
        _dreamState = state;
        _dreamError = null;
      });
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _dreamError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _dreamError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingDreamState = false);
      } else {
        _loadingDreamState = false;
      }
    }
  }

  void _startDreamStatePolling() {
    _dreamStateTimer?.cancel();
    unawaited(_loadDreamState());
    _dreamStateTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_loadDreamState(silent: true)),
    );
  }

  Future<void> _enterDream() async {
    if (_enteringDream || !_hasAdminToken) return;
    setState(() {
      _enteringDream = true;
      _dreamError = null;
    });
    try {
      final entered = await _backend.enterDream(token: _requireAdminToken());
      if (!mounted) return;
      if (!entered) {
        setState(() => _dreamError = '后端没有允许这次入梦');
        return;
      }
      setState(() {
        _dreamMessages.add(
          ChatMessage(role: 'system', text: '— 坠入梦中 —', time: _nowLabel()),
        );
      });
      await _loadDreamState(silent: true);
      _scrollDreamToBottom();
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _dreamError = e.message);
    } finally {
      if (mounted) setState(() => _enteringDream = false);
    }
  }

  void _sendDreamMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sendingDream || _dreamState?.isActive != true) {
      return;
    }
    setState(() {
      _sendingDream = true;
      _dreamError = null;
      _dreamMessages.add(
        ChatMessage(role: 'you', text: trimmed, time: _nowLabel()),
      );
    });
    _scrollDreamToBottom();
    unawaited(_sendDreamToBackend(trimmed));
  }

  Future<void> _sendDreamToBackend(String message) async {
    try {
      final response = await _backend.sendDreamChat(
        message,
        token: _requireAdminToken(),
      );
      if (!mounted) return;
      setState(() {
        if (response.error != null && response.error!.trim().isNotEmpty) {
          _dreamMessages.add(
            ChatMessage(
              role: 'system',
              text: '（${response.error}）',
              time: _nowLabel(),
            ),
          );
        } else {
          for (final part in _splitReplySegments(response.reply)) {
            _dreamMessages.add(
              ChatMessage(role: 'him', text: part, time: _nowLabel()),
            );
          }
        }
      });
      if (response.exitAccepted || response.forceExited) {
        await _loadDreamState(silent: true);
      }
      _scrollDreamToBottom();
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _dreamError = e.message);
    } finally {
      if (mounted) setState(() => _sendingDream = false);
    }
  }

  Future<void> _wakeFromDream() async {
    await _exitDreamAndRoute(AppRoute.chat);
  }

  Future<void> _exitDreamAndRoute(AppRoute route) async {
    if (_hasAdminToken) {
      try {
        await _backend.exitDream(token: _requireAdminToken());
      } catch (_) {
        // Returning to Reality remains available even if the backend is offline.
      }
    }
    if (!mounted) return;
    _dreamStateTimer?.cancel();
    setState(() {
      _route = route;
      _dreamState = null;
      _dreamError = null;
      _dreamMessages.clear();
    });
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

  Future<void> _updatePromptAssets({
    String? activeCharacter,
    Set<String>? enabledLorebooks,
    Set<String>? enabledJailbreaks,
  }) async {
    if (_savingPromptAssets || !_hasAdminToken) return;
    setState(() {
      _savingPromptAssets = true;
      _promptAssetsError = null;
    });
    try {
      final assets = await _backend.updatePromptAssets(
        token: _requireAdminToken(),
        activeCharacter: activeCharacter,
        enabledLorebooks: enabledLorebooks,
        enabledJailbreaks: enabledJailbreaks,
      );
      if (!mounted) return;
      setState(() => _promptAssets = assets);
    } on BackendException catch (e) {
      if (mounted) setState(() => _promptAssetsError = e.message);
    } finally {
      if (mounted) setState(() => _savingPromptAssets = false);
    }
  }

  Future<void> _loadDreamSettings() async {
    if (_loadingDreamSettings || !_hasAdminToken) return;
    setState(() {
      _loadingDreamSettings = true;
      _dreamSettingsError = null;
    });
    try {
      final settings = await _backend.loadDreamSettings(
        token: _requireAdminToken(),
      );
      if (!mounted) return;
      setState(() => _dreamSettings = settings);
    } on BackendException catch (e) {
      if (mounted) setState(() => _dreamSettingsError = e.message);
    } finally {
      if (mounted) setState(() => _loadingDreamSettings = false);
    }
  }

  Future<void> _updateDreamSettings({
    bool? enableDreamLorebook,
    String? worldLayer,
    String? jailbreakPreset,
  }) async {
    if (_savingDreamSettings || !_hasAdminToken) return;
    setState(() {
      _savingDreamSettings = true;
      _dreamSettingsError = null;
    });
    try {
      final settings = await _backend.updateDreamSettings(
        token: _requireAdminToken(),
        enableDreamLorebook: enableDreamLorebook,
        worldLayer: worldLayer,
        jailbreakPreset: jailbreakPreset,
      );
      if (!mounted) return;
      setState(() => _dreamSettings = settings);
    } on BackendException catch (e) {
      if (mounted) setState(() => _dreamSettingsError = e.message);
    } finally {
      if (mounted) setState(() => _savingDreamSettings = false);
    }
  }

  void _openSettings() {
    var requestedBackendSettings = false;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, sheetSetState) {
          if (!requestedBackendSettings) {
            requestedBackendSettings = true;
            unawaited(() async {
              await Future.wait([_loadPromptAssets(), _loadDreamSettings()]);
              if (context.mounted) sheetSetState(() {});
            }());
          }

          void updatePrefs(YxPrefs prefs) {
            sheetSetState(() => _prefs = prefs);
            setState(() {});
          }

          void updateTheme(bool dark) {
            sheetSetState(() {
              _dark = dark;
              _customThemeEnabled = false;
            });
            setState(() {});
            _applySystemUi();
          }

          void enableCustomTheme() {
            if (_customPalette == null) {
              Navigator.pop(context);
              unawaited(_openCustomThemeEditor());
              return;
            }
            sheetSetState(() => _customThemeEnabled = true);
            setState(() {});
            _applySystemUi();
          }

          void editCustomTheme() {
            Navigator.pop(context);
            unawaited(_openCustomThemeEditor());
          }

          return SettingsSheet(
            c: c,
            dark: _dark,
            customThemeEnabled: _customThemeEnabled,
            hasCustomTheme: _customPalette != null,
            prefs: _prefs,
            profileDisplayName: _profileDisplayName,
            profileAvatarBytes: _profileAvatarBytes,
            promptAssets: _promptAssets,
            dreamSettings: _dreamSettings,
            settingsBusy:
                _loadingPromptAssets ||
                _savingPromptAssets ||
                _loadingDreamSettings ||
                _savingDreamSettings,
            settingsError: _promptAssetsError ?? _dreamSettingsError,
            onTheme: updateTheme,
            onCustomTheme: enableCustomTheme,
            onEditCustomTheme: editCustomTheme,
            onPrefs: updatePrefs,
            onEditProfileName: _editProfileName,
            onImportProfileAvatar: _importProfileAvatar,
            onResetProfileAvatar: _resetProfileAvatar,
            onOpenProfile: _openProfilePage,
            onToggleLorebook: (id) {
              final current = Set<String>.from(
                _promptAssets?.enabledLorebooks ?? const <String>{},
              );
              current.contains(id) ? current.remove(id) : current.add(id);
              unawaited(() async {
                await _updatePromptAssets(enabledLorebooks: current);
                if (context.mounted) sheetSetState(() {});
              }());
            },
            onToggleJailbreak: (id) {
              final current = Set<String>.from(
                _promptAssets?.enabledJailbreaks ?? const <String>{},
              );
              current.contains(id) ? current.remove(id) : current.add(id);
              unawaited(() async {
                await _updatePromptAssets(enabledJailbreaks: current);
                if (context.mounted) sheetSetState(() {});
              }());
            },
            onDreamLorebook: (value) {
              unawaited(() async {
                await _updateDreamSettings(enableDreamLorebook: value);
                if (context.mounted) sheetSetState(() {});
              }());
            },
            onDreamWorldLayer: (value) {
              unawaited(() async {
                await _updateDreamSettings(worldLayer: value);
                if (context.mounted) sheetSetState(() {});
              }());
            },
            onDreamJailbreak: (value) {
              unawaited(() async {
                await _updateDreamSettings(jailbreakPreset: value);
                if (context.mounted) sheetSetState(() {});
              }());
            },
          );
        },
      ),
    );
  }

  void _openSystemSettings() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, sheetSetState) {
          void updateBackgroundNotifications(bool enabled) {
            sheetSetState(() => _backgroundNotifications = enabled);
            unawaited(_changeBackgroundNotifications(enabled));
          }

          return SystemSettingsSheet(
            c: c,
            hasAdminToken: _hasAdminToken,
            backgroundNotifications: _backgroundNotifications,
            backendBaseUrl: _backendBaseUrl,
            ownerUserId: _ownerUserId,
            historyLoaded: _historyLoaded,
            loadingHistory: _loadingHistory,
            historyError: _historyError,
            gardenLoaded: _gardenState != null,
            loadingGarden: _loadingGarden,
            gardenError: _gardenError,
            mobileActive: _mobileActive,
            pollingMobile: _pollingMobile,
            mobileError: _mobileError,
            mobileReceivedCount: _mobileReceivedCount,
            lastMobileContent: _lastMobileContent,
            backendBusy: _sending,
            backendError: _backendError,
            lastBackendReply: _lastBackendReply,
            onEditCredential: _openAdminTokenSettings,
            onOpenCapabilities: _openCapabilityCheck,
            onEditBackend: _openBackendSettings,
            onBackgroundNotifications: updateBackgroundNotifications,
          );
        },
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
    if (_sending) return;
    final picked = await _settingsStore.pickUploadFile();
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
    setState(() {
      _sending = true;
      _himTyping = true;
      _backendError = null;
      _sent.add(
        ChatMessage(role: 'you', text: '📎 ${picked.name}', time: '现在'),
      );
    });
    _scrollChatToBottom();
    await _uploadFilesToBackend(
      [picked],
      failurePrefix: '文件',
      unexpectedPrefix: '文件上传',
    );
  }

  Future<void> _pickAndUploadImages() async {
    if (_sending) return;
    final picked = await _settingsStore.pickUploadImages();
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
    final unsupported = picked
        .where(
          (file) => !supported.any(
            (suffix) => file.name.toLowerCase().endsWith(suffix),
          ),
        )
        .toList(growable: false);
    if (unsupported.isNotEmpty) {
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
    final preview = picked.length == 1
        ? picked.first.name
        : picked.take(3).map((file) => file.name).join('、');
    setState(() {
      _sending = true;
      _himTyping = true;
      _backendError = null;
      _sent.add(
        ChatMessage(
          role: 'you',
          text: picked.length == 1
              ? '📎 $preview'
              : '📎 ${picked.length}张图片：$preview${picked.length > 3 ? '…' : ''}',
          time: '现在',
        ),
      );
    });
    _scrollChatToBottom();
    await _uploadFilesToBackend(
      picked,
      failurePrefix: '图片',
      unexpectedPrefix: '图片上传',
    );
  }

  Future<void> _uploadFilesToBackend(
    List<PickedUploadFile> picked, {
    required String failurePrefix,
    required String unexpectedPrefix,
  }) async {
    try {
      final response = await _backend.uploadFiles(
        files: picked,
        token: _requireAdminToken(),
        channel: 'mobile',
      );
      if (!mounted) return;
      setState(() => _lastBackendReply = response);
      if (_shouldAppendSynchronousReply(response)) {
        await _appendHimReplySegments(response.reply);
      }
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _himTyping = false;
        _backendError = e.message;
        _sent.add(
          ChatMessage(
            role: 'him',
            text: '（$failurePrefix没有送过去：${e.message}）',
            time: _nowLabel(),
          ),
        );
      });
      _scrollChatToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _himTyping = false;
        _backendError = e.toString();
        _sent.add(
          ChatMessage(
            role: 'him',
            text: '（$unexpectedPrefix遇到一个未预期错误：$e）',
            time: _nowLabel(),
          ),
        );
      });
      _scrollChatToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _himTyping = false;
        });
      }
    }
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
      _startDreamStatePolling();
    } else {
      _dreamStateTimer?.cancel();
    }
    if (route == AppRoute.garden) {
      unawaited(_loadGarden(silent: true));
    } else if (route == AppRoute.diary) {
      unawaited(_loadDiaryList(silent: true));
    } else if (route == AppRoute.profile) {
      unawaited(_loadPromptAssets());
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
          onOpenSystemSettings: _openSystemSettings,
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
          backendBusy: _sending,
          himTyping: _himTyping,
          backendError: _backendError,
          loadingHistory: _loadingHistory,
          loadingMoreHistory: _loadingMoreHistory,
          historyLoaded: _historyLoaded,
          historyError: _historyError,
          lastBackendReply: _lastBackendReply,
          mobileReceivedCount: _mobileReceivedCount,
          historyMessages: _history,
          sentMessages: _sent,
          visibleMessageLimit: _chatVisibleMessageLimit,
          scrollController: _chatScrollController,
          showJumpToLatest: _showJumpToLatest,
          onSend: _sendMessage,
          onJumpToLatest: _scrollChatToBottom,
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
          onVoiceRecordCancel: () => unawaited(_settingsStore.cancelVoiceRecording()),
        );
      case AppRoute.dream:
        return DreamPage(
          key: const ValueKey('dream'),
          c: c,
          prefs: _prefs,
          profileDisplayName: _profileDisplayName,
          profileAvatarBytes: _profileAvatarBytes,
          state: _dreamState,
          loadingState: _loadingDreamState,
          entering: _enteringDream,
          sending: _sendingDream,
          error: _dreamError,
          messages: _dreamMessages,
          scrollController: _dreamScrollController,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          onEnter: _enterDream,
          onSend: _sendDreamMessage,
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
        );
      case AppRoute.diary:
        return DiaryPage(
          key: const ValueKey('diary'),
          c: c,
          profileDisplayName: _profileDisplayName,
          entries: _diaryEntries,
          loading: _loadingDiary,
          loaded: _diaryLoaded,
          error: _diaryError,
          onRefresh: _loadDiaryList,
          onLoadEntry: _loadDiaryEntry,
          onBack: () => setState(() => _route = AppRoute.chat),
        );
      case AppRoute.garden:
        return GardenPage(
          key: const ValueKey('garden'),
          c: c,
          profileDisplayName: _profileDisplayName,
          gardenState: _gardenState,
          loading: _loadingGarden,
          error: _gardenError,
          onRefresh: _loadGarden,
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
