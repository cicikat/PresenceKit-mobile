import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import '../services/platform_settings_channel.dart';

class AmbientPermissions extends StatefulWidget {
  const AmbientPermissions({super.key, required this.onChanged});

  final Future<void> Function(String kind, bool enabled) onChanged;

  @override
  State<AmbientPermissions> createState() => _AmbientPermissionsState();
}

class _AmbientPermissionsState extends State<AmbientPermissions>
    with WidgetsBindingObserver {
  Map<dynamic, dynamic>? _settings;
  bool _busy = false;
  bool _failed = false;

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
    if (!PlatformSettingsChannel.available) return;
    try {
      final settings = await PlatformSettingsChannel.deliveryCall<Map>(
        'getAmbientSettings',
      );
      if (mounted) setState(() => _settings = settings);
    } catch (_) {
      if (mounted) setState(() => _settings = null);
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
    if (settings == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (kind, title, detail) in [
          ('light', l10n.ambientLightTitle, l10n.ambientLightDescription),
          ('motion', l10n.ambientMotionTitle, l10n.ambientMotionDescription),
          ('usage', l10n.ambientUsageTitle, l10n.ambientUsageDescription),
        ])
          SwitchListTile(
            title: Text(title),
            subtitle: Text(
              settings['${kind}Supported'] == true
                  ? detail
                  : l10n.ambientUnsupported,
            ),
            value: settings[kind] == true,
            onChanged: _busy || settings['${kind}Supported'] != true
                ? null
                : (value) => _toggle(kind, value),
          ),
        if (settings['usage'] == true && settings['usageGranted'] != true)
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
