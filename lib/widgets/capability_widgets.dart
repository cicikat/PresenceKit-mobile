part of '../main.dart';

class CapabilitySheet extends StatefulWidget {
  const CapabilitySheet({
    super.key,
    required this.c,
    required this.onLoadStatus,
    required this.onRequestNotifications,
    required this.onRequestIgnoreBatteryOptimizations,
    required this.onToggleNotificationTestMode,
    required this.onRequestOverlay,
    required this.onRequestAccessibility,
    required this.onRequestDeviceAdmin,
    required this.onToggleBackgroundNotifications,
    required this.onToggleScreenContextUpload,
    required this.onChangeScreenTextUploadAllowedPackages,
    required this.onTestBackend,
    required this.onPushScreenContext,
    required this.onCaptureScreenContext,
    required this.onPushCapturedScreenContext,
    required this.onPushBehaviorTest,
    required this.onDebugBackgroundDelivery,
    required this.onLoadBehaviorStatus,
    required this.onFetchDiagnostics,
    required this.onEditBackend,
  });

  final YxPalette c;
  final Future<CapabilityStatus> Function() onLoadStatus;
  final Future<void> Function() onRequestNotifications;
  final Future<void> Function() onRequestIgnoreBatteryOptimizations;
  final Future<void> Function(bool enabled) onToggleNotificationTestMode;
  final Future<void> Function() onRequestOverlay;
  final Future<void> Function() onRequestAccessibility;
  final Future<void> Function() onRequestDeviceAdmin;
  final Future<void> Function(bool enabled) onToggleBackgroundNotifications;
  final Future<void> Function(bool enabled) onToggleScreenContextUpload;
  final Future<void> Function(Set<String> values)
  onChangeScreenTextUploadAllowedPackages;
  final Future<void> Function() onTestBackend;
  final Future<void> Function() onPushScreenContext;
  final Future<ScreenContextSnapshot?> Function() onCaptureScreenContext;
  final Future<void> Function(ScreenContextSnapshot snapshot)
  onPushCapturedScreenContext;
  final Future<void> Function(String kind) onPushBehaviorTest;
  final Future<bool> Function({required String content, String? behaviorJson})
  onDebugBackgroundDelivery;
  final Future<BehaviorDecisionStatus> Function() onLoadBehaviorStatus;
  final Future<BackendDiagnostics> Function() onFetchDiagnostics;
  final VoidCallback onEditBackend;

  @override
  State<CapabilitySheet> createState() => _CapabilitySheetState();
}

class _CapabilitySheetState extends State<CapabilitySheet>
    with WidgetsBindingObserver {
  late Future<CapabilityStatus> _statusFuture;
  ScreenContextSnapshot? _screenSnapshot;
  BehaviorDecisionStatus? _behaviorStatus;
  String? _behaviorStatusError;
  bool _loadingBehaviorStatus = false;
  BackendDiagnostics? _diagnostics;
  String? _diagnosticsError;
  bool _loadingDiagnostics = false;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _statusFuture = widget.onLoadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _statusFuture = widget.onLoadStatus());
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _acting = false);
        _refresh();
      }
    }
  }

  Future<void> _captureScreenContext() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final snapshot = await widget.onCaptureScreenContext();
      if (mounted) setState(() => _screenSnapshot = snapshot);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _pushCapturedScreenContext() async {
    final snapshot = _screenSnapshot;
    if (snapshot == null || _acting) return;
    await _run(() => widget.onPushCapturedScreenContext(snapshot));
  }

  Future<void> _editScreenTextUploadWhitelist(CapabilityStatus status) async {
    final selected = status.screenTextUploadAllowedPackages.toSet();
    final updated = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('屏幕正文上传白名单'),
          content: SizedBox(
            width: 520,
            child: status.screenTextUploadAppOptions.isEmpty
                ? const Text('没有读取到可启动的 App。默认不会上传任何 App 的屏幕正文。')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: status.screenTextUploadAppOptions.length,
                    itemBuilder: (context, index) {
                      final option = status.screenTextUploadAppOptions[index];
                      return CheckboxListTile(
                        value: selected.contains(option.packageName),
                        title: Text(option.appLabel),
                        subtitle: Text(option.packageName),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selected.add(option.packageName);
                            } else {
                              selected.remove(option.packageName);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (updated == null) return;
    await _run(() => widget.onChangeScreenTextUploadAllowedPackages(updated));
  }

  Future<void> _loadBehaviorStatus() async {
    if (_loadingBehaviorStatus) return;
    setState(() {
      _loadingBehaviorStatus = true;
      _behaviorStatusError = null;
    });
    try {
      final status = await widget.onLoadBehaviorStatus();
      if (mounted) setState(() => _behaviorStatus = status);
    } on BackendException catch (e) {
      if (mounted) setState(() => _behaviorStatusError = e.message);
    } catch (e) {
      if (mounted) setState(() => _behaviorStatusError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingBehaviorStatus = false);
    }
  }

  Future<void> _loadDiagnostics() async {
    if (_loadingDiagnostics) return;
    setState(() {
      _loadingDiagnostics = true;
      _diagnosticsError = null;
    });
    try {
      final d = await widget.onFetchDiagnostics();
      if (mounted) setState(() => _diagnostics = d);
    } on BackendException catch (e) {
      if (mounted) setState(() => _diagnosticsError = e.message);
    } catch (e) {
      if (mounted) setState(() => _diagnosticsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingDiagnostics = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.surfaceEdge)),
      ),
      child: FutureBuilder<CapabilityStatus>(
        future: _statusFuture,
        builder: (context, snapshot) {
          final status = snapshot.data;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.ink4.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Row(
                    children: [
                      Icon(Icons.health_and_safety_outlined, color: c.ink2),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '能力检查',
                          style: serif(c, 22, weight: FontWeight.w500),
                        ),
                      ),
                      YxIconButton(
                        c: c,
                        icon: Icons.refresh_rounded,
                        onPressed: _acting ? () {} : _refresh,
                        tooltip: '重新检测',
                      ),
                      const SizedBox(width: 8),
                      YxIconButton(
                        c: c,
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.pop(context),
                        tooltip: '关闭',
                      ),
                    ],
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    status == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 30, 16, 42),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: c.character),
                        const SizedBox(height: 14),
                        Text('正在读取系统状态…', style: mono(c, 12)),
                      ],
                    ),
                  )
                else if (status == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: Text('暂时读不到状态，稍后再试。', style: serif(c, 14)),
                  )
                else ...[
                  CapabilityRow(
                    c: c,
                    icon: Icons.notifications_active_outlined,
                    title: '通知权限',
                    subtitle: '允许系统通知，后台主动消息才能弹出来。',
                    enabled: status.notificationsEnabled,
                    actionLabel: status.notificationsEnabled ? '已开启' : '去开启',
                    onPressed: status.notificationsEnabled
                        ? null
                        : () => _run(widget.onRequestNotifications),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.battery_saver_outlined,
                    title: '电池优化豁免',
                    subtitle: status.ignoringBatteryOptimizations
                        ? '已允许后台持续运行；仍建议检查厂商自启动与后台白名单。'
                        : '未豁免：息屏或 Doze 时后台轮询可能暂停。',
                    enabled: status.ignoringBatteryOptimizations,
                    actionLabel: status.ignoringBatteryOptimizations
                        ? '已豁免'
                        : '去授权',
                    onPressed: status.ignoringBatteryOptimizations
                        ? null
                        : () =>
                              _run(widget.onRequestIgnoreBatteryOptimizations),
                  ),
                  _OemBackgroundGuide(c: c),
                  CapabilityRow(
                    c: c,
                    icon: Icons.picture_in_picture_alt_outlined,
                    title: '悬浮窗权限',
                    subtitle: '显示在桌面和其他 App 上层，用于短句提醒和确认。',
                    enabled: status.overlayEnabled,
                    actionLabel: status.overlayEnabled ? '已开启' : '去设置',
                    onPressed: status.overlayEnabled
                        ? null
                        : () => _run(widget.onRequestOverlay),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.accessibility_new_rounded,
                    title: '无障碍服务',
                    subtitle: '读取当前 App、窗口标题和可见文字摘要；不上传截图。',
                    enabled: status.accessibilityEnabled,
                    actionLabel: status.accessibilityEnabled ? '已开启' : '去设置',
                    onPressed: status.accessibilityEnabled
                        ? null
                        : () => _run(widget.onRequestAccessibility),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.visibility_outlined,
                    title: '屏幕上下文',
                    subtitle: status.screenContextUploadEnabled
                        ? '已开启：仅上传经过本机过滤的非敏感文本摘要。'
                        : '默认关闭；能力页仍可读取经过本机过滤的快照。',
                    enabled: status.screenContextUploadEnabled,
                    actionLabel: status.screenContextUploadEnabled
                        ? '已开启'
                        : '已关闭',
                    trailing: Switch(
                      value: status.screenContextUploadEnabled,
                      onChanged: _acting
                          ? null
                          : (value) => _run(
                              () => widget.onToggleScreenContextUpload(value),
                            ),
                    ),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.fact_check_outlined,
                    title: '屏幕正文上传白名单',
                    subtitle: status.screenTextUploadAllowedPackages.isEmpty
                        ? '当前为空：所有 App 仅上报包名和 App 名，不上传窗口标题或可见正文。'
                        : '仅勾选的 ${status.screenTextUploadAllowedPackages.length} 个 App 可上传正文；敏感页面仍会二次拦截。',
                    enabled: status.screenTextUploadAllowedPackages.isNotEmpty,
                    actionLabel: '管理',
                    onPressed: _acting
                        ? null
                        : () => _editScreenTextUploadWhitelist(status),
                  ),
                  ScreenContextDebugCard(
                    c: c,
                    snapshot: _screenSnapshot,
                    acting: _acting,
                    enabled: status.accessibilityEnabled,
                    uploadEnabled: status.screenContextUploadEnabled,
                    onCapture: _captureScreenContext,
                    onPush: _pushCapturedScreenContext,
                  ),
                  BehaviorTestPanel(
                    c: c,
                    acting: _acting,
                    onTest: (kind) =>
                        _run(() => widget.onPushBehaviorTest(kind)),
                  ),
                  BackgroundDeliveryTestPanel(
                    c: c,
                    acting: _acting,
                    onTest: (kind) => _run(() async {
                      final spec = _BackgroundDeliveryTestSpec.forKind(kind);
                      await widget.onDebugBackgroundDelivery(
                        content: spec.content,
                        behaviorJson: spec.behaviorJson,
                      );
                    }),
                  ),
                  BehaviorDecisionDebugCard(
                    c: c,
                    status: _behaviorStatus,
                    error: _behaviorStatusError,
                    loading: _loadingBehaviorStatus,
                    onRefresh: _loadBehaviorStatus,
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.screen_lock_portrait_outlined,
                    title: '设备管理器锁屏',
                    subtitle: '授权后才能执行 lockNow，每次仍由界面确认。',
                    enabled: status.deviceAdminEnabled,
                    actionLabel: status.deviceAdminEnabled ? '已开启' : '去授权',
                    onPressed: status.deviceAdminEnabled
                        ? null
                        : () => _run(widget.onRequestDeviceAdmin),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.sync_lock_outlined,
                    title: '后台通知服务',
                    subtitle: _backgroundServiceSubtitle(status),
                    enabled: status.backgroundNotificationsEnabled,
                    actionLabel: status.backgroundNotificationsEnabled
                        ? '开关已开'
                        : '已关闭',
                    trailing: Switch(
                      value: status.backgroundNotificationsEnabled,
                      onChanged: _acting
                          ? null
                          : (value) => _run(
                              () =>
                                  widget.onToggleBackgroundNotifications(value),
                            ),
                    ),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.cell_tower_outlined,
                    title: '中继连接状态',
                    subtitle: _relayConnectionSubtitle(status),
                    enabled: status.relayConnectionStatus.connected,
                    actionLabel: _relayConnectionLabel(
                      status.relayConnectionStatus,
                    ),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.science_outlined,
                    title: '通知闸门测试模式（仅调试）',
                    subtitle: _notificationGateSubtitle(status),
                    enabled: status.notificationGateStatus.testModeEnabled,
                    actionLabel: status.notificationGateStatus.testModeEnabled
                        ? '测试中'
                        : '正常',
                    trailing: Switch(
                      value: status.notificationGateStatus.testModeEnabled,
                      onChanged: _acting
                          ? null
                          : (value) => _run(
                              () => widget.onToggleNotificationTestMode(value),
                            ),
                    ),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.hub_outlined,
                    title: 'adb reverse / 后端连通',
                    subtitle: _backendCapabilitySubtitle(status),
                    enabled: status.backendReachable,
                    actionLabel: status.backendBusy
                        ? '检测中'
                        : status.backendReachable
                        ? '已接入'
                        : '检测',
                    trailing: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        YxStatusPill(
                          c: c,
                          enabled: status.backendReachable,
                          waiting: status.backendBusy,
                          enabledLabel: '已接入',
                          disabledLabel: '未接通',
                        ),
                        YxIconButton(
                          c: c,
                          icon: Icons.edit_location_alt_rounded,
                          onPressed: widget.onEditBackend,
                          tooltip: '修改后端节点',
                          size: 30,
                        ),
                        YxIconButton(
                          c: c,
                          icon: Icons.wifi_tethering_rounded,
                          onPressed: _acting
                              ? () {}
                              : () => _run(widget.onTestBackend),
                          tooltip: '检测后端连通',
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                  BackendDiagnosticsCard(
                    c: c,
                    diagnostics: _diagnostics,
                    error: _diagnosticsError,
                    loading: _loadingDiagnostics,
                    onRefresh: _loadDiagnostics,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.surfaceSoft,
                        border: Border.all(color: c.ink4),
                      ),
                      child: Text(
                        status.backendError != null
                            ? '最近连接错误：${status.backendError}'
                            : '能力页只显示手机端可验证的状态；adb reverse 本身在电脑侧执行，手机端通过 127.0.0.1 后端是否可达来判断。',
                        style: serif(
                          c,
                          13,
                          color: c.ink2,
                        ).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _backgroundServiceSubtitle(CapabilityStatus status) {
    final poll = status.backgroundPollStatus;
    final heartbeat = poll.lastPollAt == null
        ? '最近周期补偿：暂无'
        : '最近周期补偿：${_formatCapabilityTime(poll.lastPollAt!)}';
    final error = poll.lastError == null
        ? '最近错误原因：无'
        : '最近错误原因：${poll.lastError}';
    final service = status.backgroundServiceRunning
        ? '原生中继服务正在运行'
        : '原生中继服务未运行；前台由 Flutter 每 5 秒读取主动消息';
    return '$service。\n$heartbeat / $error';
  }

  String _notificationGateSubtitle(CapabilityStatus status) {
    final gate = status.notificationGateStatus;
    final mode = gate.testModeEnabled
        ? '测试模式已开启：仅绕过静音时段和 30 分钟冷却'
        : '测试模式关闭：静音时段 23:30–06:30，普通通知间隔 30 分钟';
    final reason = gate.lastSuppressReason ?? '无';
    return '$mode。\n被吞计数：${gate.suppressedCount} / 最近原因：$reason';
  }

  String _relayConnectionLabel(RelayConnectionStatus relay) {
    return switch (relay.connectionStatus) {
      'connected' => '已连接',
      'connecting' || 'reconnecting' => '连接中',
      'fallback_poll' => '周期补偿',
      'timeout' => '已超时',
      'stopped' => '已停止',
      _ => '未配置',
    };
  }

  String _relayConnectionSubtitle(CapabilityStatus status) {
    final relay = status.relayConnectionStatus;
    final delivered = relay.lastDeliveredAt == null
        ? '最近信号时间：暂无'
        : '最近信号时间：${_formatCapabilityTime(relay.lastDeliveredAt!)}';
    final heartbeat = relay.lastHeartbeatAt == null
        ? '最近中继心跳：暂无'
        : '最近中继心跳：${_formatCapabilityTime(relay.lastHeartbeatAt!)}';
    final error = relay.lastError == null ? '' : '\n最近中继错误：${relay.lastError}';
    return '${_relayConnectionLabel(relay)}；$delivered / $heartbeat$error';
  }

  String _formatCapabilityTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _backendCapabilitySubtitle(CapabilityStatus status) {
    final uri = Uri.tryParse(status.backendBaseUrl);
    final host = uri?.host ?? '';
    final needsReverse = host == '127.0.0.1' || host == 'localhost';
    if (needsReverse) {
      return '${status.backendBaseUrl} · 真机调试依赖 adb reverse tcp:8080 tcp:8080';
    }
    return '${status.backendBaseUrl} · 局域网/VPN/内网穿透需可达';
  }
}

class ScreenContextDebugCard extends StatelessWidget {
  const ScreenContextDebugCard({
    super.key,
    required this.c,
    required this.snapshot,
    required this.acting,
    required this.enabled,
    required this.uploadEnabled,
    required this.onCapture,
    required this.onPush,
  });

  final YxPalette c;
  final ScreenContextSnapshot? snapshot;
  final bool acting;
  final bool enabled;
  final bool uploadEnabled;
  final VoidCallback onCapture;
  final VoidCallback onPush;

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    final label = snap == null
        ? '暂无屏幕快照'
        : [
            if (snap.appLabel.isNotEmpty) snap.appLabel,
            if (snap.packageName.isNotEmpty) snap.packageName,
          ].join(' · ');
    final visible = snap?.visibleText.take(8).join(' / ') ?? '';
    final clickable = snap?.clickableText.take(6).join(' / ') ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        border: Border(bottom: BorderSide(color: c.surfaceEdge)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.manage_search_rounded, color: c.ink2, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '屏幕上下文调试',
                  style: serif(c, 16, weight: FontWeight.w500),
                ),
              ),
              OutlinedButton.icon(
                onPressed: enabled && !acting ? onCapture : null,
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('读取'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed:
                    enabled &&
                        uploadEnabled &&
                        !acting &&
                        snap != null &&
                        !snap.isBlocked
                    ? onPush
                    : null,
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: const Text('推送'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: mono(c, 11, color: c.ink2)),
          if (snap?.isBlocked == true) ...[
            const SizedBox(height: 4),
            Text(
              'Sensitive screen filtered locally: ${snap!.blockedReason}',
              style: mono(c, 10.5, color: c.danger),
            ),
          ],
          if (snap?.windowTitle.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              '窗口：${snap!.windowTitle}',
              style: mono(c, 10.5, color: c.ink3),
            ),
          ],
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '可见：$visible',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: mono(c, 10.5, color: c.ink3),
            ),
          ],
          if (clickable.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '可点：$clickable',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: mono(c, 10.5, color: c.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

class BehaviorTestPanel extends StatelessWidget {
  const BehaviorTestPanel({
    super.key,
    required this.c,
    required this.acting,
    required this.onTest,
  });

  final YxPalette c;
  final bool acting;
  final ValueChanged<String> onTest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.surfaceEdge)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_outlined, color: c.ink2, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '主动行为测试',
                  style: serif(c, 16, weight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '写入后端 mobile queue，并立刻轮询一次；悬浮/确认类会在前台直接弹。',
            style: mono(c, 10.5, color: c.ink3),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _testButton('notify', Icons.notifications_none_rounded, '通知'),
              _testButton(
                'overlay_message',
                Icons.picture_in_picture_alt_outlined,
                '悬浮',
              ),
              _testButton(
                'lock_screen_confirm',
                Icons.screen_lock_portrait_outlined,
                '锁屏确认',
              ),
              _testButton(
                'takeout_overlay',
                Icons.shopping_bag_outlined,
                '外卖确认',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _testButton(String kind, IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: acting ? null : () => onTest(kind),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class BackgroundDeliveryTestPanel extends StatelessWidget {
  const BackgroundDeliveryTestPanel({
    super.key,
    required this.c,
    required this.acting,
    required this.onTest,
  });

  final YxPalette c;
  final bool acting;
  final ValueChanged<String> onTest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        border: Border(bottom: BorderSide(color: c.surfaceEdge)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mark_chat_unread_outlined, color: c.ink2, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '后台交付测试',
                  style: serif(c, 16, weight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '不经过后端，直接测试手机端后台通知 / 存在感悬浮 / 工具确认分流。',
            style: mono(c, 10.5, color: c.ink3),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _testButton('notify', Icons.notifications_none_rounded, '普通通知'),
              _testButton(
                'presence',
                Icons.picture_in_picture_alt_outlined,
                '存在感悬浮',
              ),
              _testButton('lock', Icons.screen_lock_portrait_outlined, '锁屏请求'),
              _testButton('takeout', Icons.shopping_bag_outlined, '外卖请求'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _testButton(String kind, IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: acting ? null : () => onTest(kind),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _BackgroundDeliveryTestSpec {
  const _BackgroundDeliveryTestSpec({required this.content, this.behaviorJson});

  factory _BackgroundDeliveryTestSpec.forKind(String kind) {
    return switch (kind) {
      'presence' => const _BackgroundDeliveryTestSpec(
        content: '我在这里。你不想说话也没关系。',
        behaviorJson:
            '{"kind":"overlay_message","delivery":"overlay","level":"attention_grab","behavior_id":"presence_ping"}',
      ),
      'lock' => const _BackgroundDeliveryTestSpec(
        content: '已经很晚了。要我替你锁一下屏吗？',
        behaviorJson:
            '{"kind":"lock_screen_confirm","delivery":"overlay","level":"direct_act","behavior_id":"lock_screen","requires_confirmation":true}',
      ),
      'takeout' => const _BackgroundDeliveryTestSpec(
        content: '你还没吃东西。要不要我帮你打开外卖页看一眼？',
        behaviorJson:
            '{"kind":"takeout_overlay","delivery":"overlay","level":"direct_act","behavior_id":"takeout_order","requires_confirmation":true}',
      ),
      _ => const _BackgroundDeliveryTestSpec(content: '我刚才给你发了一句话，回来再看也可以。'),
    };
  }

  final String content;
  final String? behaviorJson;
}

class BehaviorDecisionDebugCard extends StatelessWidget {
  const BehaviorDecisionDebugCard({
    super.key,
    required this.c,
    required this.status,
    required this.error,
    required this.loading,
    required this.onRefresh,
  });

  final YxPalette c;
  final BehaviorDecisionStatus? status;
  final String? error;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final s = status;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        border: Border(bottom: BorderSide(color: c.surfaceEdge)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule_folder_outlined, color: c.ink2, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '行为裁决状态',
                  style: serif(c, 16, weight: FontWeight.w500),
                ),
              ),
              OutlinedButton.icon(
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (error != null)
            Text('读取失败：$error', style: mono(c, 10.5, color: c.danger))
          else if (s == null)
            Text(
              '还没读取。刷新后会显示后端最近一次行为裁决为什么弹或为什么没弹。',
              style: mono(c, 10.5, color: c.ink3),
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                YxTag(
                  c: c,
                  text: s.sent ? 'SENT' : s.stage.toUpperCase(),
                  variant: s.sent ? 'ok' : 'warn',
                ),
                if (s.score != null) YxTag(c: c, text: 'score ${s.score}'),
                if (s.risk != null) YxTag(c: c, text: 'risk ${s.risk}'),
                if (s.behaviorKind.isNotEmpty)
                  YxTag(c: c, text: s.behaviorKind, variant: 'warm'),
                if (s.behaviorId.isNotEmpty) YxTag(c: c, text: s.behaviorId),
              ],
            ),
            const SizedBox(height: 8),
            _line('时间', s.timeLabel),
            _line('原因', s.reason),
            if (s.eventType.isNotEmpty) _line('事件', s.eventType),
            if (s.focusApp.isNotEmpty) _line('应用', s.focusApp),
            if (s.narrative.isNotEmpty) _line('叙事', s.narrative),
            if (s.screenTextHint.isNotEmpty) _line('屏幕', s.screenTextHint),
            if (s.replyPreview.isNotEmpty) _line('回复', s.replyPreview),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        '$label：$value',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: mono(c, 10.5, color: c.ink3),
      ),
    );
  }
}

class _OemBackgroundGuide extends StatelessWidget {
  const _OemBackgroundGuide({required this.c});

  final YxPalette c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.surfaceEdge)),
      ),
      child: Text(
        '厂商后台白名单参考：\n'
        '小米：设置 → 应用设置 → 应用管理 → 叶瑄 → 省电策略/自启动 → 无限制并开启自启动\n'
        'OPPO：设置 → 应用 → 自启动/耗电管理 → 叶瑄 → 允许后台运行\n'
        'vivo：设置 → 电池 → 后台耗电管理 → 叶瑄 → 允许后台高耗电\n'
        '华为：设置 → 应用和服务 → 应用启动管理 → 叶瑄 → 手动管理并允许后台活动',
        style: mono(c, 10.5, color: c.ink3),
      ),
    );
  }
}

class CapabilityRow extends StatelessWidget {
  const CapabilityRow({
    super.key,
    required this.c,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.actionLabel,
    this.onPressed,
    this.trailing,
  });

  final YxPalette c;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final String actionLabel;
  final VoidCallback? onPressed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final controls =
        trailing ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            YxStatusPill(c: c, enabled: enabled),
            if (onPressed != null) ...[
              const SizedBox(width: 8),
              OutlinedButton(onPressed: onPressed, child: Text(actionLabel)),
            ],
          ],
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final label = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: c.ink2, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: serif(c, 16, weight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: mono(c, 10.5, color: c.ink3)),
                ],
              ),
            ),
          ],
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.surfaceEdge)),
          ),
          child: constraints.maxWidth < 430
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: controls),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: label),
                    const SizedBox(width: 12),
                    controls,
                  ],
                ),
        );
      },
    );
  }
}

class YxStatusPill extends StatelessWidget {
  const YxStatusPill({
    super.key,
    required this.c,
    required this.enabled,
    this.waiting = false,
    this.enabledLabel = '已开启',
    this.disabledLabel = '未开启',
    this.waitingLabel = '检测中',
  });

  final YxPalette c;
  final bool enabled;
  final bool waiting;
  final String enabledLabel;
  final String disabledLabel;
  final String waitingLabel;

  @override
  Widget build(BuildContext context) {
    final text = waiting
        ? waitingLabel
        : enabled
        ? enabledLabel
        : disabledLabel;
    final color = waiting
        ? c.warn
        : enabled
        ? c.ok
        : c.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(1),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: mono(c, 10, color: color, weight: FontWeight.w700),
      ),
    );
  }
}

class BackendDiagnosticsCard extends StatelessWidget {
  const BackendDiagnosticsCard({
    super.key,
    required this.c,
    required this.diagnostics,
    required this.error,
    required this.loading,
    required this.onRefresh,
  });

  final YxPalette c;
  final BackendDiagnostics? diagnostics;
  final String? error;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final d = diagnostics;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.surfaceEdge)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage_outlined, color: c.ink2, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '后端 / 资产诊断',
                  style: serif(c, 16, weight: FontWeight.w500),
                ),
              ),
              OutlinedButton.icon(
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.character,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('读取'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (error != null)
            Text('读取失败：$error', style: mono(c, 10.5, color: c.danger))
          else if (d == null)
            Text(
              '点击"读取"拉取后端节点、数据目录、模型、角色卡、世界书、破限和梦境配置。',
              style: mono(c, 10.5, color: c.ink3),
            )
          else ...[
            // ── 最重要：后端节点 + 数据目录 ────────────────────────────
            _highlightRow(
              label: '后端节点',
              value: d.backendBase,
              highlight: false,
            ),
            if (d.dataPathForbidden)
              _infoRow('数据目录', '无权限（mobile token 预期行为）')
            else if (d.dataPathError != null)
              _errorRow('数据目录', d.dataPathError!)
            else
              _highlightRow(
                label: '数据目录',
                value: d.dataPath ?? '—',
                highlight: d.dataPathIsSandbox,
                highlightSuffix: d.dataPathIsSandbox ? '  ⚠ 沙盒' : null,
              ),
            const SizedBox(height: 6),
            // ── 元模式 ──────────────────────────────────────────────────
            if (d.metaModeError != null)
              _errorRow('元模式', d.metaModeError!)
            else if (d.metaMode != null)
              _infoRow(
                '元模式',
                d.metaMode!.isDanger
                    ? '危险模式${d.metaMode!.expiresAt != null ? "（到 ${d.metaMode!.expiresAt}）" : ""}'
                    : '安全模式',
                danger: d.metaMode!.isDanger,
              ),
            // ── 模型 ─────────────────────────────────────────────────────
            if (d.statusSummaryError != null)
              _errorRow('模型', d.statusSummaryError!)
            else if (d.statusSummary != null) ...[
              if (d.statusSummary!.llmModel != null)
                _infoRow(
                  '模型',
                  [
                    d.statusSummary!.llmModel!,
                    if (d.statusSummary!.llmProvider != null)
                      d.statusSummary!.llmProvider!,
                  ].join(' · '),
                ),
              if (d.statusSummary!.shortTermRounds != null)
                _infoRow('短期轮数', '${d.statusSummary!.shortTermRounds}'),
            ],
            // ── 角色卡 ───────────────────────────────────────────────────
            if (d.activeCharacterError != null)
              _errorRow('角色卡', d.activeCharacterError!)
            else if (d.activeCharacter != null)
              _infoRow('角色卡', d.activeCharacter!.display),
            // ── 世界书 / 破限 ────────────────────────────────────────────
            if (d.lorebookError != null)
              _errorRow('世界书', d.lorebookError!)
            else if (d.lorebookCount != null)
              _infoRow('世界书', '${d.lorebookCount} 条'),
            if (d.jailbreakError != null)
              _errorRow('破限', d.jailbreakError!)
            else if (d.jailbreakCount != null)
              _infoRow('破限', '${d.jailbreakCount} 条'),
            // ── 梦境配置 ─────────────────────────────────────────────────
            if (d.dreamSettingsError != null)
              _errorRow('梦境', d.dreamSettingsError!)
            else if (d.dreamSettings != null) ...[
              _infoRow(
                '梦境世界书',
                d.dreamSettings!.enableDreamLorebook == true ? '已启用' : '未启用',
              ),
              if (d.dreamSettings!.worldLayer != null)
                _infoRow('梦境层', d.dreamSettings!.worldLayer!),
              if (d.dreamSettings!.jailbreakPreset != null)
                _infoRow('梦境破限', d.dreamSettings!.jailbreakPreset!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _highlightRow({
    required String label,
    required String value,
    required bool highlight,
    String? highlightSuffix,
  }) {
    final color = highlight ? c.danger : c.ink2;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(
        text: TextSpan(
          style: mono(c, 11, color: c.ink3),
          children: [
            TextSpan(
              text: '$label：',
              style: mono(c, 11, color: c.ink3),
            ),
            TextSpan(
              text: value,
              style: mono(
                c,
                11,
                color: color,
                weight: highlight ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            if (highlightSuffix != null)
              TextSpan(
                text: highlightSuffix,
                style: mono(c, 11, color: c.danger, weight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool danger = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        '$label：$value',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: mono(c, 10.5, color: danger ? c.danger : c.ink3),
      ),
    );
  }

  Widget _errorRow(String label, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        '$label：读取失败 — $message',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: mono(c, 10.5, color: c.danger),
      ),
    );
  }
}
