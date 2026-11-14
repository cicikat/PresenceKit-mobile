import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import '../services/platform_settings_channel.dart';

class AmbientPermissions extends StatefulWidget {
  const AmbientPermissions({
    super.key,
    required this.onChanged,
    this.readOnly = false,
  });

  final Future<void> Function(String kind, bool enabled) onChanged;
  final bool readOnly;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(l10n.ambientLocalPermissionHint),
        ),
        if (settings == null)
          ListTile(
            title: Text(
              _loading
                  ? l10n.capabilityLoading
                  : _loadFailed
                  ? l10n.ambientReadFailed
                  : l10n.ambientPlatformUnavailable,
            ),
            trailing: _loading
                ? null
                : TextButton(onPressed: _load, child: Text(l10n.retryAction)),
          ),
        ListTile(
          title: Text(l10n.ambientBatteryTitle),
          subtitle: Text(
            _batteryPercent == null || settings == null
                ? l10n.ambientStateUnknown
                : l10n.ambientBatteryReading(_batteryPercent!),
          ),
        ),
        for (final (kind, title, detail) in [
          ('light', l10n.ambientLightTitle, l10n.ambientLightDescription),
          ('motion', l10n.ambientMotionTitle, l10n.ambientMotionDescription),
          ('usage', l10n.ambientUsageTitle, l10n.ambientUsageDescription),
        ])
          if (widget.readOnly || settings == null)
            ListTile(
              title: Text(title),
              subtitle: Text(
                settings == null
                    ? l10n.ambientStateUnknown
                    : settings['${kind}Supported'] != true
                    ? l10n.ambientUnsupported
                    : kind == 'usage' && settings['usageGranted'] != true
                    ? l10n.ambientUsagePermissionMissing
                    : settings[kind] == true
                    ? l10n.enabledStatus
                    : l10n.disabledStatus,
              ),
            )
          else
            SwitchListTile(
              title: Text(title),
              subtitle: Text(
                settings['${kind}Supported'] == true
                    ? kind == 'usage' && settings['usageGranted'] != true
                          ? l10n.ambientUsagePermissionMissing
                          : detail
                    : l10n.ambientUnsupported,
              ),
              value: settings[kind] == true,
              onChanged:
                  _busy ||
                      _loading ||
                      (settings[kind] != true &&
                          settings['${kind}Supported'] != true)
                  ? null
                  : (value) => _toggle(kind, value),
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
            child: Text(l10n.ambientOpenUsageAccess),
          ),
        if (_failed) Text(l10n.ambientSettingFailed),
      ],
    );
  }
}
