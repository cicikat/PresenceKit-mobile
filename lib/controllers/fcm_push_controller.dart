import 'package:flutter/foundation.dart';

import '../services/platform_settings_channel.dart';

class FcmPushController extends ChangeNotifier {
  FcmPushController(this._character);

  final String? Function() _character;
  bool available = false;
  bool enabled = false;
  bool busy = false;
  String state = 'off';
  int? lastDelayMs;
  bool _disposed = false;

  Future<void> refresh() async {
    if (!PlatformSettingsChannel.available) return;
    try {
      final status = await PlatformSettingsChannel.deliveryCall<Map>(
        'getFcmPushStatus',
      );
      if (status == null || _disposed) return;
      available = true;
      enabled = status['enabled'] == true;
      state = status['state'] as String? ?? 'waiting';
      final delay = status['lastDelayMs'];
      lastDelayMs = delay is int && delay >= 0 ? delay : null;
    } catch (_) {
      state = 'waiting';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (busy || _disposed) return;
    busy = true;
    notifyListeners();
    try {
      await PlatformSettingsChannel.deliveryCall<void>('setFcmPushEnabled', {
        'enabled': value,
        'charId': _character(),
      });
      await refresh();
    } catch (_) {
      state = 'waiting';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
