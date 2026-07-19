import 'dart:async';

import 'package:flutter/material.dart';

import '../app_constants.dart';
import '../models/app_models.dart';
import '../models/background_status.dart';
import '../models/capability_status.dart';
import '../l10n/l10n.dart';
import '../models/screen_context.dart';
import '../services/backend_client.dart';

import '../widgets/common_widgets.dart';

class CapabilitySheet extends StatefulWidget {
  const CapabilitySheet({
    super.key,
    required this.c,
    required this.onLoadStatus,
    required this.onRequestNotifications,
    required this.onRequestIgnoreBatteryOptimizations,
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
    required this.historyLoaded,
    required this.loadingHistory,
    required this.historyError,
    required this.gardenLoaded,
    required this.loadingGarden,
    required this.gardenError,
    required this.mobileActive,
    required this.pollingMobile,
    required this.mobileError,
    required this.mobileReceivedCount,
    required this.lastMobileContent,
  });

  final YxPalette c;
  final Future<CapabilityStatus> Function() onLoadStatus;
  final Future<void> Function() onRequestNotifications;
  final Future<void> Function() onRequestIgnoreBatteryOptimizations;
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
  final bool historyLoaded;
  final bool loadingHistory;
  final String? historyError;
  final bool gardenLoaded;
  final bool loadingGarden;
  final String? gardenError;
  final bool mobileActive;
  final bool pollingMobile;
  final String? mobileError;
  final int mobileReceivedCount;
  final String? lastMobileContent;

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
          scrollable: true,
          title: Text(context.l10n.capabilityWhitelistTitle),
          content: SizedBox(
            width: 520,
            child: status.screenTextUploadAppOptions.isEmpty
                ? Text(context.l10n.capabilityWhitelistNoApps)
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
              child: Text(context.l10n.cancelAction),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: Text(context.l10n.saveAction),
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
                          context.l10n.capabilityTitle,
                          style: serif(c, 22, weight: FontWeight.w500),
                        ),
                      ),
                      YxIconButton(
                        c: c,
                        icon: Icons.refresh_rounded,
                        onPressed: _acting ? () {} : _refresh,
                        tooltip: context.l10n.capabilityRefreshTooltip,
                      ),
                      const SizedBox(width: 8),
                      YxIconButton(
                        c: c,
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.pop(context),
                        tooltip: context.l10n.closeTooltip,
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
                        Text(
                          context.l10n.capabilityLoading,
                          style: mono(c, 12),
                        ),
                      ],
                    ),
                  )
                else if (status == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: Text(
                      context.l10n.capabilityUnavailable,
                      style: serif(c, 14),
                    ),
                  )
                else ...[
                  CapabilityRow(
                    c: c,
                    icon: Icons.notifications_active_outlined,
                    title: context.l10n.capabilityNotificationTitle,
                    subtitle: context.l10n.capabilityNotificationSubtitle,
                    enabled: status.notificationsEnabled,
                    actionLabel: status.notificationsEnabled
                        ? context.l10n.enabledStatus
                        : context.l10n.enableAction,
                    onPressed: status.notificationsEnabled
                        ? null
                        : () => _run(widget.onRequestNotifications),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.battery_saver_outlined,
                    title: context.l10n.capabilityBatteryTitle,
                    subtitle: status.ignoringBatteryOptimizations
                        ? context.l10n.capabilityBatteryEnabled
                        : context.l10n.capabilityBatteryDisabled,
                    enabled: status.ignoringBatteryOptimizations,
                    actionLabel: status.ignoringBatteryOptimizations
                        ? context.l10n.authorizedStatus
                        : context.l10n.authorizeAction,
                    onPressed: status.ignoringBatteryOptimizations
                        ? null
                        : () =>
                              _run(widget.onRequestIgnoreBatteryOptimizations),
                  ),
                  _OemBackgroundGuide(c: c, appDisplayName: appDisplayName),
                  CapabilityRow(
                    c: c,
                    icon: Icons.picture_in_picture_alt_outlined,
                    title: context.l10n.capabilityOverlayTitle,
                    subtitle: _overlaySubtitle(status),
                    // 权限已授予不等于弹窗一定成功：部分厂商 ROM 会在实际弹出时
                    // 才拦截，因此这里同时看权限位和最近一次弹窗失败记录。
                    enabled:
                        status.overlayEnabled &&
                        status.overlayErrorStatus.lastError == null,
                    actionLabel: status.overlayEnabled
                        ? context.l10n.enabledStatus
                        : context.l10n.configureAction,
                    onPressed: status.overlayEnabled
                        ? null
                        : () => _run(widget.onRequestOverlay),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.accessibility_new_rounded,
                    title: context.l10n.capabilityAccessibilityTitle,
                    subtitle: context.l10n.capabilityAccessibilitySubtitle,
                    enabled: status.accessibilityEnabled,
                    actionLabel: status.accessibilityEnabled
                        ? context.l10n.enabledStatus
                        : context.l10n.configureAction,
                    onPressed: status.accessibilityEnabled
                        ? null
                        : () => _run(widget.onRequestAccessibility),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.visibility_outlined,
                    title: context.l10n.capabilityScreenContextTitle,
                    subtitle: status.screenContextUploadEnabled
                        ? context.l10n.capabilityScreenContextEnabled
                        : context.l10n.capabilityScreenContextDisabled,
                    enabled: status.screenContextUploadEnabled,
                    actionLabel: status.screenContextUploadEnabled
                        ? context.l10n.enabledStatus
                        : context.l10n.disabledStatus,
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
                    title: context.l10n.capabilityWhitelistTitle,
                    subtitle: status.screenTextUploadAllowedPackages.isEmpty
                        ? context.l10n.capabilityWhitelistEmpty
                        : context.l10n.capabilityWhitelistCount(
                            status.screenTextUploadAllowedPackages.length,
                          ),
                    enabled: status.screenTextUploadAllowedPackages.isNotEmpty,
                    actionLabel: context.l10n.manageAction,
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
                      final spec = _BackgroundDeliveryTestSpec.forKind(
                        kind,
                        context.l10n,
                      );
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
                    title: context.l10n.capabilityDeviceAdminTitle,
                    subtitle: context.l10n.capabilityDeviceAdminSubtitle,
                    enabled: status.deviceAdminEnabled,
                    actionLabel: status.deviceAdminEnabled
                        ? context.l10n.enabledStatus
                        : context.l10n.authorizeAction,
                    onPressed: status.deviceAdminEnabled
                        ? null
                        : () => _run(widget.onRequestDeviceAdmin),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.sync_lock_outlined,
                    title: context.l10n.capabilityBackgroundServiceTitle,
                    subtitle: _backgroundServiceSubtitle(status),
                    enabled: status.backgroundNotificationsEnabled,
                    actionLabel: status.backgroundNotificationsEnabled
                        ? context.l10n.switchEnabledStatus
                        : context.l10n.disabledStatus,
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
                  _SyncStatusSection(c: c, sheet: widget),
                  CapabilityRow(
                    c: c,
                    icon: Icons.cell_tower_outlined,
                    title: context.l10n.capabilityRelayTitle,
                    subtitle: _relayConnectionSubtitle(status),
                    enabled:
                        status.relayConnectionStatus.displayStatus ==
                        RelayDisplayStatus.connected,
                    actionLabel: _relayConnectionLabel(
                      status.relayConnectionStatus,
                    ),
                    trailing: _relayStatusPill(c, status.relayConnectionStatus),
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.notifications_paused_outlined,
                    title: context.l10n.capabilityGateTitle,
                    subtitle: _notificationGateSubtitle(status),
                    enabled: status.notificationGateStatus.testModeEnabled,
                    actionLabel: status.notificationGateStatus.testModeEnabled
                        ? context.l10n.testingStatus
                        : context.l10n.normalStatus,
                  ),
                  CapabilityRow(
                    c: c,
                    icon: Icons.hub_outlined,
                    title: context.l10n.capabilityBackendTitle,
                    subtitle: _backendCapabilitySubtitle(status),
                    enabled: status.backendReachable,
                    actionLabel: status.backendBusy
                        ? context.l10n.detectingStatus
                        : status.backendReachable
                        ? context.l10n.connectedStatus
                        : context.l10n.detectAction,
                    trailing: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        YxStatusPill(
                          c: c,
                          enabled: status.backendReachable,
                          waiting: status.backendBusy,
                          enabledLabel: context.l10n.connectedStatus,
                          disabledLabel: context.l10n.notConnectedStatus,
                        ),
                        YxIconButton(
                          c: c,
                          icon: Icons.edit_location_alt_rounded,
                          onPressed: widget.onEditBackend,
                          tooltip: context.l10n.capabilityEditBackendTooltip,
                          size: 30,
                        ),
                        YxIconButton(
                          c: c,
                          icon: Icons.wifi_tethering_rounded,
                          onPressed: _acting
                              ? () {}
                              : () => _run(widget.onTestBackend),
                          tooltip: context.l10n.capabilityDetectBackendTooltip,
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
                            ? context.l10n.capabilityBackendLastError(
                                status.backendError!,
                              )
                            : context.l10n.capabilityBackendNotice,
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
        ? context.l10n.capabilityLastPollNone
        : context.l10n.capabilityLastPoll(
            _formatCapabilityTime(poll.lastPollAt!),
          );
    final error = poll.lastError == null
        ? context.l10n.capabilityLastErrorNone
        : context.l10n.capabilityLastError(poll.lastError!);
    final service = status.backgroundServiceRunning
        ? context.l10n.capabilityNativeRelayRunning
        : context.l10n.capabilityNativeRelayStopped;
    return '$service。\n$heartbeat / $error';
  }

  String _notificationGateSubtitle(CapabilityStatus status) {
    final gate = status.notificationGateStatus;
    final mode = gate.testModeEnabled
        ? context.l10n.capabilityGateTestOn
        : context.l10n.capabilityGateTestOff;
    final reason = gate.lastSuppressReason ?? context.l10n.noneStatus;
    return context.l10n.capabilityGateSummary(
      mode,
      gate.suppressedCount,
      reason,
    );
  }

  String _overlaySubtitle(CapabilityStatus status) {
    final base = context.l10n.capabilityOverlaySubtitle;
    final overlayError = status.overlayErrorStatus;
    if (overlayError.lastError == null) return base;
    final at = overlayError.lastErrorAt == null
        ? ''
        : '（${_formatCapabilityTime(overlayError.lastErrorAt!)}）';
    return context.l10n.capabilityOverlayLastError(
      base,
      at,
      overlayError.lastError!,
    );
  }

  String _relayConnectionLabel(RelayConnectionStatus relay) {
    return switch (relay.displayStatus) {
      RelayDisplayStatus.connected => context.l10n.relayConnected,
      RelayDisplayStatus.connecting => context.l10n.relayConnecting,
      RelayDisplayStatus.stopped => context.l10n.relayStopped,
      RelayDisplayStatus.error => context.l10n.relayError,
      RelayDisplayStatus.unconfigured => context.l10n.relayUnconfigured,
    };
  }

  /// 与 [_relayConnectionLabel] 同源：状态指示灯必须显示同一个五态文案，
  /// 不能各自从 connectionStatus/心跳时间独立派生，否则左右会互相矛盾。
  Widget _relayStatusPill(YxPalette c, RelayConnectionStatus relay) {
    final label = _relayConnectionLabel(relay);
    return YxStatusPill(
      c: c,
      enabled: relay.displayStatus == RelayDisplayStatus.connected,
      waiting: relay.displayStatus == RelayDisplayStatus.connecting,
      enabledLabel: label,
      disabledLabel: label,
      waitingLabel: label,
    );
  }

  String _relayConnectionSubtitle(CapabilityStatus status) {
    final relay = status.relayConnectionStatus;
    final delivered = relay.lastDeliveredAt == null
        ? context.l10n.capabilitySignalNone
        : context.l10n.capabilitySignalTime(
            _formatCapabilityTime(relay.lastDeliveredAt!),
          );
    final heartbeat = relay.lastHeartbeatAt == null
        ? context.l10n.capabilityHeartbeatNone
        : context.l10n.capabilityHeartbeatTime(
            _formatCapabilityTime(relay.lastHeartbeatAt!),
          );
    final error = relay.lastError == null
        ? ''
        : context.l10n.capabilityRelayLastError(relay.lastError!);
    final configurationHint = relay.lastDeliveredAt == null
        ? context.l10n.capabilityRelayConfigWarning
        : '';
    return '${_relayConnectionLabel(relay)}；$delivered / $heartbeat$error$configurationHint';
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
      return context.l10n.capabilityLoopbackHint(status.backendBaseUrl);
    }
    return context.l10n.capabilityRemoteHint(status.backendBaseUrl);
  }
}

class _SyncStatusSection extends StatelessWidget {
  const _SyncStatusSection({required this.c, required this.sheet});

  final YxPalette c;
  final CapabilitySheet sheet;

  String _state({
    required AppLocalizations l10n,
    required bool loading,
    required bool ready,
    required String? error,
  }) {
    if (loading) return l10n.readingStatus;
    if (error != null) return l10n.failedStatus(error);
    return ready ? l10n.syncedStatus : l10n.pendingSyncStatus;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mobileState = sheet.pollingMobile
        ? l10n.pollingStatus
        : sheet.mobileError != null
        ? l10n.failedStatus(sheet.mobileError!)
        : sheet.mobileActive
        ? l10n.activatedStatus
        : l10n.pendingActivationStatus;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.syncStatusTitle,
            style: serif(c, 15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.syncChatStatus(
              _state(
                l10n: l10n,
                loading: sheet.loadingHistory,
                ready: sheet.historyLoaded,
                error: sheet.historyError,
              ),
            ),
            style: mono(c, 11, color: c.ink2),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.syncGardenStatus(
              _state(
                l10n: l10n,
                loading: sheet.loadingGarden,
                ready: sheet.gardenLoaded,
                error: sheet.gardenError,
              ),
            ),
            style: mono(c, 11, color: c.ink2),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.syncMobileStatus(
              mobileState,
              sheet.mobileReceivedCount > 0
                  ? l10n.syncReceivedSuffix(sheet.mobileReceivedCount)
                  : '',
            ),
            style: mono(c, 11, color: c.ink2),
          ),
          if (sheet.lastMobileContent != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.syncLatestMessage(sheet.lastMobileContent!),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: mono(c, 11, color: c.ink2),
            ),
          ],
        ],
      ),
    );
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
        ? context.l10n.screenSnapshotEmpty
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
                  context.l10n.screenDebugTitle,
                  style: serif(c, 16, weight: FontWeight.w500),
                ),
              ),
              OutlinedButton.icon(
                onPressed: enabled && !acting ? onCapture : null,
                icon: const Icon(Icons.search_rounded, size: 16),
                label: Text(context.l10n.readAction),
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
                label: Text(context.l10n.pushAction),
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
              context.l10n.screenWindow(snap!.windowTitle),
              style: mono(c, 10.5, color: c.ink3),
            ),
          ],
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.screenVisible(visible),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: mono(c, 10.5, color: c.ink3),
            ),
          ],
          if (clickable.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.screenClickable(clickable),
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
                  context.l10n.behaviorTestTitle,
                  style: serif(c, 16, weight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            context.l10n.behaviorTestDescription,
            style: mono(c, 10.5, color: c.ink3),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _testButton(
                'notify',
                Icons.notifications_none_rounded,
                context.l10n.notificationLabel,
              ),
              _testButton(
                'overlay_message',
                Icons.picture_in_picture_alt_outlined,
                context.l10n.overlayLabel,
              ),
              _testButton(
                'lock_screen_confirm',
                Icons.screen_lock_portrait_outlined,
                context.l10n.lockConfirmLabel,
              ),
              _testButton(
                'takeout_overlay',
                Icons.shopping_bag_outlined,
                context.l10n.takeoutConfirmLabel,
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
                  context.l10n.backgroundDeliveryTitle,
                  style: serif(c, 16, weight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            context.l10n.backgroundDeliveryDescription,
            style: mono(c, 10.5, color: c.ink3),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _testButton(
                'notify',
                Icons.notifications_none_rounded,
                context.l10n.normalNotificationLabel,
              ),
              _testButton(
                'presence',
                Icons.picture_in_picture_alt_outlined,
                context.l10n.presenceOverlayLabel,
              ),
              _testButton(
                'lock',
                Icons.screen_lock_portrait_outlined,
                context.l10n.lockRequestLabel,
              ),
              _testButton(
                'takeout',
                Icons.shopping_bag_outlined,
                context.l10n.takeoutRequestLabel,
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

class _BackgroundDeliveryTestSpec {
  const _BackgroundDeliveryTestSpec({required this.content, this.behaviorJson});

  factory _BackgroundDeliveryTestSpec.forKind(
    String kind,
    AppLocalizations l10n,
  ) {
    return switch (kind) {
      'presence' => _BackgroundDeliveryTestSpec(
        content: l10n.backgroundTestPresenceMessage,
        behaviorJson:
            '{"kind":"overlay_message","delivery":"overlay","level":"attention_grab","behavior_id":"presence_ping"}',
      ),
      'lock' => _BackgroundDeliveryTestSpec(
        content: l10n.backgroundTestLockMessage,
        behaviorJson:
            '{"kind":"lock_screen_confirm","delivery":"overlay","level":"direct_act","behavior_id":"lock_screen","requires_confirmation":true}',
      ),
      'takeout' => _BackgroundDeliveryTestSpec(
        content: l10n.backgroundTestTakeoutMessage,
        behaviorJson:
            '{"kind":"takeout_overlay","delivery":"overlay","level":"direct_act","behavior_id":"takeout_order","requires_confirmation":true}',
      ),
      _ => _BackgroundDeliveryTestSpec(
        content: l10n.backgroundTestDefaultMessage,
      ),
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
                  context.l10n.behaviorDecisionTitle,
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
                label: Text(context.l10n.refreshAction),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (error != null)
            Text(
              context.l10n.readFailedMessage(error!),
              style: mono(c, 10.5, color: c.danger),
            )
          else if (s == null)
            Text(
              context.l10n.behaviorDecisionEmpty,
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
            _line(context.l10n.fieldTime, s.timeLabel),
            _line(context.l10n.fieldReason, s.reason),
            if (s.eventType.isNotEmpty)
              _line(context.l10n.fieldEvent, s.eventType),
            if (s.focusApp.isNotEmpty) _line(context.l10n.fieldApp, s.focusApp),
            if (s.narrative.isNotEmpty)
              _line(context.l10n.fieldNarrative, s.narrative),
            if (s.screenTextHint.isNotEmpty)
              _line(context.l10n.fieldScreen, s.screenTextHint),
            if (s.replyPreview.isNotEmpty)
              _line(context.l10n.fieldReply, s.replyPreview),
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
  const _OemBackgroundGuide({required this.c, required this.appDisplayName});

  final YxPalette c;
  final String appDisplayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.surfaceEdge)),
      ),
      child: Text(
        context.l10n.oemBackgroundGuide(appDisplayName),
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
    this.enabledLabel,
    this.disabledLabel,
    this.waitingLabel,
  });

  final YxPalette c;
  final bool enabled;
  final bool waiting;
  final String? enabledLabel;
  final String? disabledLabel;
  final String? waitingLabel;

  @override
  Widget build(BuildContext context) {
    final text = waiting
        ? waitingLabel ?? context.l10n.checkingStatus
        : enabled
        ? enabledLabel ?? context.l10n.enabledStatus
        : disabledLabel ?? context.l10n.disabledStatus;
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
                  context.l10n.backendDiagnosticsTitle,
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
                label: Text(context.l10n.readAction),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (error != null)
            Text(
              context.l10n.readFailedMessage(error!),
              style: mono(c, 10.5, color: c.danger),
            )
          else if (d == null)
            Text(
              context.l10n.backendDiagnosticsEmpty,
              style: mono(c, 10.5, color: c.ink3),
            )
          else ...[
            // ── 最重要：后端节点 + 数据目录 ────────────────────────────
            _highlightRow(
              label: context.l10n.diagnosticBackendNode,
              value: d.backendBase,
              highlight: false,
            ),
            if (d.dataPathForbidden)
              _infoRow(
                context.l10n.diagnosticDataPath,
                context.l10n.diagnosticNoPermission,
              )
            else if (d.dataPathError != null)
              _errorRow(
                context,
                context.l10n.diagnosticDataPath,
                d.dataPathError!,
              )
            else
              _highlightRow(
                label: context.l10n.diagnosticDataPath,
                value: d.dataPath ?? '—',
                highlight: d.dataPathIsSandbox,
                highlightSuffix: d.dataPathIsSandbox
                    ? context.l10n.sandboxSuffix
                    : null,
              ),
            const SizedBox(height: 6),
            // ── 元模式 ──────────────────────────────────────────────────
            if (d.metaModeError != null)
              _errorRow(
                context,
                context.l10n.diagnosticMetaMode,
                d.metaModeError!,
              )
            else if (d.metaMode != null)
              _infoRow(
                context.l10n.diagnosticMetaMode,
                d.metaMode!.isDanger
                    ? context.l10n.diagnosticDangerMode
                    : context.l10n.diagnosticSafeMode,
                danger: d.metaMode!.isDanger,
              ),
            // ── 模型 ─────────────────────────────────────────────────────
            if (d.statusSummaryError != null)
              _errorRow(
                context,
                context.l10n.diagnosticModel,
                d.statusSummaryError!,
              )
            else if (d.statusSummary != null) ...[
              if (d.statusSummary!.llmModel != null)
                _infoRow(
                  context.l10n.diagnosticModel,
                  [
                    d.statusSummary!.llmModel!,
                    if (d.statusSummary!.llmProvider != null)
                      d.statusSummary!.llmProvider!,
                  ].join(' · '),
                ),
              if (d.statusSummary!.shortTermRounds != null)
                _infoRow(
                  context.l10n.diagnosticShortTermRounds,
                  '${d.statusSummary!.shortTermRounds}',
                ),
            ],
            // ── 角色卡 ───────────────────────────────────────────────────
            if (d.activeCharacterError != null)
              _errorRow(
                context,
                context.l10n.diagnosticCharacterCard,
                d.activeCharacterError!,
              )
            else if (d.activeCharacter != null)
              _infoRow(
                context.l10n.diagnosticCharacterCard,
                d.activeCharacter!.display,
              ),
            // ── 世界书 / 破限 ────────────────────────────────────────────
            if (d.lorebookError != null)
              _errorRow(
                context,
                context.l10n.diagnosticLorebook,
                d.lorebookError!,
              )
            else if (d.lorebookCount != null)
              _infoRow(
                context.l10n.diagnosticLorebook,
                context.l10n.diagnosticEntries(d.lorebookCount ?? 0),
              ),
            if (d.jailbreakError != null)
              _errorRow(
                context,
                context.l10n.diagnosticJailbreak,
                d.jailbreakError!,
              )
            else if (d.jailbreakCount != null)
              _infoRow(
                context.l10n.diagnosticJailbreak,
                context.l10n.diagnosticEntries(d.jailbreakCount ?? 0),
              ),
            // ── 梦境配置 ─────────────────────────────────────────────────
            if (d.dreamSettingsError != null)
              _errorRow(
                context,
                context.l10n.diagnosticDream,
                d.dreamSettingsError!,
              )
            else if (d.dreamSettings != null) ...[
              _infoRow(
                context.l10n.diagnosticDreamLorebook,
                d.dreamSettings!.enableDreamLorebook == true
                    ? context.l10n.enabledShortStatus
                    : context.l10n.disabledShortStatus,
              ),
              if (d.dreamSettings!.worldLayer != null)
                _infoRow(
                  context.l10n.diagnosticDreamLayer,
                  d.dreamSettings!.worldLayer!,
                ),
              if (d.dreamSettings!.jailbreakPreset != null)
                _infoRow(
                  context.l10n.diagnosticDreamJailbreak,
                  d.dreamSettings!.jailbreakPreset!,
                ),
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

  Widget _errorRow(BuildContext context, String label, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        context.l10n.diagnosticReadError(label, message),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: mono(c, 10.5, color: c.danger),
      ),
    );
  }
}
