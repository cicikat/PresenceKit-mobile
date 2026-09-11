import 'dart:io';

import 'package:flutter/services.dart';

/// Shared transport for the stable Android settings channel.
/// Appearance get/set includes local showChatTime (default true).
/// Domain services depend on this holder instead of owning their own channel.
class PlatformSettingsChannel {
  static const MethodChannel channel = MethodChannel(
    'presence_mobile/settings',
  );

  static bool debugForceChannelAvailable = false;

  static bool get available => Platform.isAndroid || debugForceChannelAvailable;
}
