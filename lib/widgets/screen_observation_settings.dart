import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../services/platform_settings_channel.dart';
import 'settings_editor_widgets.dart';
import 'capability_widgets.dart';

class ScreenObservationSettings extends StatefulWidget {
  const ScreenObservationSettings({
    super.key,
    required this.c,
    this.accessibilityEnabled,
    this.readOnly = false,
  });
  final YxPalette c;
  final bool? accessibilityEnabled;
  final bool readOnly;
  @override
  State<ScreenObservationSettings> createState() =>
      _ScreenObservationSettingsState();
}

class _ScreenObservationSettingsState extends State<ScreenObservationSettings>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('presence_mobile/screen_observation');
  bool _enabled = false;
  bool _supported = false;
  bool _busy = true;
  bool _failed = false;
  bool _accessibilityEnabled = false;
  int _epoch = 0;
  final _deadlines = <Timer>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _deadlines) {
      timer.cancel();
    }
    _deadlines.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<Map<String, dynamic>?> _readState(bool? enabled) async {
    final state = await _channel.invokeMapMethod<String, dynamic>(
      enabled == null ? 'get' : 'set',
      enabled == null ? null : {'enabled': enabled},
    );
    if (state == null) return null;
    final access =
        widget.accessibilityEnabled ??
        (PlatformSettingsChannel.available &&
            await PlatformSettingsChannel.channel.invokeMethod<bool>(
                  'isAccessibilityServiceEnabled',
                ) ==
                true);
    return {...state, 'accessibilityEnabled': access};
  }

  Future<void> _load([bool? enabled]) async {
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final timeout = Completer<Map<String, dynamic>?>();
    final deadline = Timer(
      const Duration(seconds: 8),
      () => timeout.complete(null),
    );
    _deadlines.add(deadline);
    try {
      final state = await Future.any([_readState(enabled), timeout.future]);
      if (state == null) throw const FormatException('missing settings');
      if (mounted && epoch == _epoch) {
        setState(() {
          _enabled = state['enabled'] == true;
          _supported = state['supported'] == true;
          _accessibilityEnabled = state['accessibilityEnabled'] == true;
        });
      }
    } catch (_) {
      if (mounted && epoch == _epoch) setState(() => _failed = true);
    } finally {
      deadline.cancel();
      _deadlines.remove(deadline);
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _failed
        ? context.l10n.screenObservationFailed
        : !_supported || !_accessibilityEnabled
        ? context.l10n.screenObservationRequirements
        : context.l10n.screenObservationHint;
    if (_failed) {
      return ListTile(
        title: Text(context.l10n.screenObservationTitle),
        subtitle: Text(subtitle),
        trailing: TextButton(
          onPressed: _busy ? null : () => _load(),
          child: Text(context.l10n.retryAction),
        ),
      );
    }
    if (widget.readOnly) {
      return CapabilityRow(
        c: widget.c,
        icon: Icons.screenshot_rounded,
        title: context.l10n.screenObservationTitle,
        subtitle: subtitle,
        enabled:
            !_busy &&
            !_failed &&
            _enabled &&
            _supported &&
            _accessibilityEnabled,
        actionLabel: '',
        onPressed: null,
      );
    }
    return SettingsRow(
      c: widget.c,
      title: context.l10n.screenObservationTitle,
      subtitle: subtitle,
      child: Switch(
        value: _enabled,
        onChanged: _busy || _failed || (!_enabled && !_supported)
            ? null
            : _load,
      ),
    );
  }
}
