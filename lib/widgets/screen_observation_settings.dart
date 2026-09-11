import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import 'settings_editor_widgets.dart';
import 'capability_widgets.dart';

class ScreenObservationSettings extends StatefulWidget {
  const ScreenObservationSettings({super.key, required this.c, this.accessibilityEnabled = true, this.readOnly = false});
  final YxPalette c;
  final bool accessibilityEnabled;
  final bool readOnly;
  @override
  State<ScreenObservationSettings> createState() => _ScreenObservationSettingsState();
}

class _ScreenObservationSettingsState extends State<ScreenObservationSettings> {
  static const _channel = MethodChannel('presence_mobile/screen_observation');
  bool _enabled = false;
  bool _supported = false;
  bool _busy = true;
  bool _failed = false;
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load([bool? enabled]) async {
    setState(() { _busy = true; _failed = false; });
    try {
      final state = await _channel.invokeMapMethod<String, dynamic>(enabled == null ? 'get' : 'set',
          enabled == null ? null : {'enabled': enabled});
      if (mounted) setState(() { _enabled = state?['enabled'] == true; _supported = state?['supported'] == true; });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _failed ? context.l10n.screenObservationFailed :
      !_supported || !widget.accessibilityEnabled ? context.l10n.screenObservationRequirements : context.l10n.screenObservationHint;
    if (widget.readOnly) {
      return CapabilityRow(c: widget.c, icon: Icons.screenshot_rounded,
        title: context.l10n.screenObservationTitle, subtitle: subtitle,
        enabled: !_busy && !_failed && _enabled && _supported && widget.accessibilityEnabled,
        actionLabel: '', onPressed: null);
    }
    return SettingsRow(c: widget.c, title: context.l10n.screenObservationTitle,
      subtitle: subtitle, child: Switch(value: _enabled,
        onChanged: _busy || _failed || (!_enabled && !_supported) ? null : _load));
  }
}
