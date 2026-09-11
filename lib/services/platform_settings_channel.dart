import 'dart:io';

import 'package:flutter/services.dart';

/// Shared transport for the stable Android settings channel.
/// Appearance get/set includes independent Dream sizes (12-28), ARGB colors,
/// showReasoning, expandReasoning and reasoningOpacity (0-1, default .85).
/// localPresentationDirectory returns the
/// private font/profile directory; exportThemeJson uses the system save dialog.
/// Appearance get/set includes local showChatTime (default true).
/// Domain services depend on this holder instead of owning their own channel.
class PlatformSettingsChannel {
  static const MethodChannel channel = MethodChannel(
    'presence_mobile/settings',
  );

  static bool debugForceChannelAvailable = false;

  static bool get available => Platform.isAndroid || debugForceChannelAvailable;
}
