// Appearance calendarPalette: local heatmap palette (jade/blue/rose/amber).
// Dream description opacity: local appearance float 0-1, default .65.
import 'dart:io';

import 'package:flutter/services.dart';

/// Profile display name/avatar accept optional characterId; missing id keeps the
/// legacy global slot, present id uses per-character prefs and avatar files.
/// Chat appearance bytes/nightBytes hold independent day/night images; null clears that slot.
/// Shared transport for the stable Android settings channel.
/// Appearance get/set includes local showToolActivity (default true).
/// Appearance get/set includes independent Dream sizes (12-28), ARGB colors,
/// showReasoning, expandReasoning and reasoningOpacity (0-1, default .85).
/// localPresentationDirectory returns the
/// private font/profile directory; exportThemeJson uses the system save dialog.
/// Appearance get/set includes local showToolActivity (default true).
/// Appearance get/set includes local showChatTime (default true).
/// Domain services depend on this holder instead of owning their own channel.
class PlatformSettingsChannel {
  static const MethodChannel channel = MethodChannel(
    'presence_mobile/settings',
  );

  static bool debugForceChannelAvailable = false;

  static bool get available => Platform.isAndroid || debugForceChannelAvailable;
}
