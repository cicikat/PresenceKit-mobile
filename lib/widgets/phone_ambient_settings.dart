import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import 'common_widgets.dart';
import 'settings_editor_widgets.dart';

class PhoneAmbientSettings extends StatefulWidget {
  const PhoneAmbientSettings({
    super.key,
    required this.c,
    required this.load,
    required this.save,
    this.readOnly = false,
  });
  final YxPalette c;
  final Future<Map<String, dynamic>> Function() load;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>, String?)
  save;
  final bool readOnly;
  @override
  State<PhoneAmbientSettings> createState() => _PhoneAmbientSettingsState();
}

class _PhoneAmbientSettingsState extends State<PhoneAmbientSettings>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  bool _busy = false, _failed = false;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _epoch++;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final data = await widget.load();
      if (mounted && epoch == _epoch) setState(() => _data = data);
    } catch (_) {
      if (mounted && epoch == _epoch) setState(() => _failed = true);
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _save(String key, bool value) async {
    final epoch = ++_epoch;
    final character = _data?['char_id'] as String?;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final data = await widget.save({key: value}, character);
      if (mounted && epoch == _epoch) setState(() => _data = data);
    } catch (_) {
      if (mounted && epoch == _epoch) setState(() => _failed = true);
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final configured = (_data?['configured'] as Map?) ?? const {};
    final effective = (_data?['effective'] as Map?) ?? const {};
    final reasons = (_data?['reason_codes'] as Map?) ?? const {};
    final any = effective.values.any((value) => value == true);
    String state(String key) => effective[key] == true
        ? l10n.phoneAmbientReady
        : reasons[key] == 'autonomy_disabled'
        ? l10n.phoneAmbientAutonomyOff
        : configured[key] == false || configured['enabled'] != true
        ? l10n.disabledStatus
        : l10n.phoneAmbientPending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsRow(
          c: widget.c,
          title: l10n.phoneAmbientTitle,
          subtitle: l10n.phoneAmbientHint,
          child: _data == null || widget.readOnly
              ? Text(
                  _data == null
                      ? l10n.ambientStateUnknown
                      : any
                      ? l10n.phoneAmbientReady
                      : configured['enabled'] == true
                      ? l10n.phoneAmbientPending
                      : l10n.disabledStatus,
                  style: mono(widget.c, 11, color: widget.c.ink3),
                )
              : Switch(
                  value: configured['enabled'] == true,
                  onChanged: _busy ? null : (value) => _save('enabled', value),
                ),
        ),
        if (_data != null)
          for (final (key, title) in [
            ('light', l10n.ambientLightTitle),
            ('motion', l10n.ambientMotionTitle),
            ('usage', l10n.ambientUsageTitle),
          ])
            SettingsRow(
              c: widget.c,
              title: title,
              subtitle: state(key),
              child: widget.readOnly
                  ? const SizedBox.shrink()
                  : Switch(
                      value: configured[key] == true,
                      onChanged: _busy ? null : (value) => _save(key, value),
                    ),
            ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.phoneAmbientLoadFailed,
              style: mono(widget.c, 12, color: widget.c.danger),
            ),
          ),
        if (_data == null || _failed)
          TextButton(
            onPressed: _busy ? null : _load,
            child: Text(l10n.retryAction),
          ),
      ],
    );
  }
}
