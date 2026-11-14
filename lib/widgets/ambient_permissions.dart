import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/app_models.dart';
import 'common_widgets.dart';
import 'capability_widgets.dart';
import 'settings_editor_widgets.dart';

import '../services/platform_settings_channel.dart';

class AmbientPermissions extends StatefulWidget {
  const AmbientPermissions({
    super.key,
    required this.onChanged,
    this.readOnly = false,
    this.c,
  });

  final Future<void> Function(String kind, bool enabled) onChanged;
  final bool readOnly;
  final YxPalette? c;

  @override
  State<AmbientPermissions> createState() => _AmbientPermissionsState();
}

class _AmbientPermissionsState extends State<AmbientPermissions>
    with WidgetsBindingObserver {
  Map<dynamic, dynamic>? _settings;
  int? _batteryPercent;
  bool _busy = false;
  bool _failed = false;
  bool _loading = true;
  bool _loadFailed = false;
  int _loadEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    if (!PlatformSettingsChannel.available) {
      if (mounted) {
        setState(() {
          _settings = null;
          _loading = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final settings = await PlatformSettingsChannel.deliveryCall<Map>(
        'getAmbientSettings',
      );
      if (settings == null) throw const FormatException('missing settings');
      if (mounted && epoch == _loadEpoch) setState(() => _settings = settings);
      // A local reading is not evidence of backend receipt. Failure of this
      // independent capability must not hide the consent controls above.
      Object? percent;
      try {
        final battery = await PlatformSettingsChannel.deliveryCall<Map>(
          'readBatteryStatus',
        );
        percent = battery?['percent'];
      } catch (_) {
        // Keep the independently loaded consent settings visible.
      }
      if (mounted && epoch == _loadEpoch) {
        setState(() {
          _batteryPercent = percent is num && percent >= 0 && percent <= 100
              ? percent.toInt()
              : null;
        });
      }
    } catch (_) {
      if (mounted && epoch == _loadEpoch) {
        setState(() {
          _settings = null;
          _loadFailed = true;
        });
      }
    } finally {
      if (mounted && epoch == _loadEpoch) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String kind, bool enabled) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await PlatformSettingsChannel.deliveryCall<void>('setAmbientEnabled', {
        'kind': kind,
        'enabled': enabled,
      });
      await _load();
      if (mounted) await widget.onChanged(kind, enabled);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final l10n = context.l10n;
    final c =
        widget.c ??
        (Theme.of(context).brightness == Brightness.dark
            ? YxPalette.dark
            : YxPalette.light);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.ambientLocalPermissionHint,
            style: mono(c, 10.5, color: c.ink3),
          ),
        ),
        if (settings == null)
          CapabilityRow(
            c: c,
            icon: Icons.sensors_rounded,
            enabled: false,
            actionLabel: '',
            subtitle: '',
            title: _loading
                ? l10n.capabilityLoading
                : _loadFailed
                ? l10n.ambientReadFailed
                : l10n.ambientPlatformUnavailable,
            trailing: _loading
                ? const SizedBox.shrink()
                : YxIconButton(
                    c: c,
                    icon: Icons.refresh_rounded,
                    onPressed: _load,
                    tooltip: l10n.retryAction,
                  ),
          ),
        CapabilityRow(
          c: c,
          icon: Icons.battery_std_rounded,
          enabled: _batteryPercent != null,
          actionLabel: '',
          trailing: const SizedBox.shrink(),
          title: l10n.ambientBatteryTitle,
          subtitle: _batteryPercent == null || settings == null
              ? l10n.ambientStateUnknown
              : l10n.ambientBatteryReading(_batteryPercent!),
        ),
        for (final (kind, title, detail) in [
          ('light', l10n.ambientLightTitle, l10n.ambientLightDescription),
          ('motion', l10n.ambientMotionTitle, l10n.ambientMotionDescription),
          ('usage', l10n.ambientUsageTitle, l10n.ambientUsageDescription),
        ])
          if (widget.readOnly || settings == null)
            CapabilityRow(
              c: c,
              icon: switch (kind) {
                'light' => Icons.light_mode_outlined,
                'motion' => Icons.directions_walk_rounded,
                _ => Icons.phone_android_rounded,
              },
              enabled: settings?[kind] == true,
              actionLabel: '',
              trailing: const SizedBox.shrink(),
              title: title,
              subtitle: settings == null
                  ? l10n.ambientStateUnknown
                  : settings['${kind}Supported'] != true
                  ? l10n.ambientUnsupported
                  : kind == 'usage' && settings['usageGranted'] != true
                  ? l10n.ambientUsagePermissionMissing
                  : settings[kind] == true
                  ? l10n.enabledStatus
                  : l10n.disabledStatus,
            )
          else
            SettingsRow(
              c: c,
              title: title,
              subtitle: settings['${kind}Supported'] == true
                  ? kind == 'usage' && settings['usageGranted'] != true
                        ? l10n.ambientUsagePermissionMissing
                        : detail
                  : l10n.ambientUnsupported,
              child: Switch(
                value: settings[kind] == true,
                onChanged:
                    _busy ||
                        _loading ||
                        (settings[kind] != true &&
                            settings['${kind}Supported'] != true)
                    ? null
                    : (value) => _toggle(kind, value),
              ),
            ),
        if (!widget.readOnly &&
            settings != null &&
            settings['usageSupported'] == true &&
            settings['usageGranted'] != true)
          TextButton(
            onPressed: () async {
              try {
                await PlatformSettingsChannel.deliveryCall<void>(
                  'openUsageAccess',
                );
              } catch (_) {
                if (mounted) setState(() => _failed = true);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: c.character,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(l10n.ambientOpenUsageAccess),
          ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.ambientSettingFailed,
              style: mono(c, 12, color: c.danger),
            ),
          ),
      ],
    );
  }
}
