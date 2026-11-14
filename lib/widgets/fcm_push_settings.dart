import 'package:flutter/material.dart';

import '../controllers/fcm_push_controller.dart';
import '../l10n/l10n.dart';

class FcmPushSettings extends StatefulWidget {
  const FcmPushSettings({
    super.key,
    required this.character,
    required this.onChanged,
  });

  final String? Function() character;
  final Future<void> Function(bool enabled) onChanged;

  @override
  State<FcmPushSettings> createState() => _FcmPushSettingsState();
}

class _FcmPushSettingsState extends State<FcmPushSettings>
    with WidgetsBindingObserver {
  late final FcmPushController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FcmPushController(widget.character);
    WidgetsBinding.instance.addObserver(this);
    _controller.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      if (!_controller.available) return const SizedBox.shrink();
      final l = context.l10n;
      final state = _controller.state;
      final delay = _controller.lastDelayMs;
      final detail = switch (state) {
        'unconfigured' => l.fcmUnconfigured,
        'play_services_unavailable' => l.fcmUnavailable,
        'permission_required' => l.fcmPermissionRequired,
        'registered' => l.fcmRegistered,
        'off' => l.fcmOff,
        _ => l.fcmWaiting,
      };
      return SwitchListTile(
        title: Text(l.fcmTitle),
        subtitle: Text(
          delay == null || !_controller.enabled
              ? detail
              : '$detail\n${l.fcmLastDelay((delay / 1000).round())}',
        ),
        value: _controller.enabled,
        onChanged:
            _controller.busy ||
                (!_controller.enabled &&
                    (state == 'unconfigured' ||
                        state == 'play_services_unavailable'))
            ? null
            : (value) async {
                await _controller.setEnabled(value);
                if (mounted) await widget.onChanged(_controller.enabled);
              },
      );
    },
  );
}
