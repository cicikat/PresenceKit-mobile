// Appearance calendarPalette: local heatmap palette (jade/blue/rose/amber).
// Dream description opacity: local appearance float 0-1, default .65.
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';

/// Profile display name/avatar accept optional characterId; missing id keeps the
/// legacy global slot, present id uses per-character prefs and avatar files.
/// Chat appearance bytes/nightBytes hold independent day/night images; null clears that slot.
/// Shared transport for the stable Android settings channel.
/// getBackgroundPollStatus includes optional pendingCount/pendingLimit observations.
/// Appearance get/set includes local showToolActivity (default true).
/// Appearance get/set includes independent Dream sizes (12-28), ARGB colors,
/// showReasoning, expandReasoning and reasoningOpacity (0-1, default .85).
/// localPresentationDirectory returns the
/// saveChatImage writes bounded PNG/JPEG/WebP bytes to a system-selected document URI.
/// private font/profile directory; exportThemeJson uses the system save dialog.
/// Appearance get/set includes local showToolActivity (default true).
/// Appearance get/set includes local showChatTime (default true).
/// Domain services depend on this holder instead of owning their own channel.
class PlatformSettingsChannel {
  // Inbox: peekPendingMobileEnvelopes reads without deletion. ackPendingMobileEnvelopes
  // confirms exact id+seq within origin/owner/charId after Dart accepts the rows.
  // Legacy consume methods retain their destructive ABI for older callers.
  // get/setCustomThemePalette carries the opaque theme JSON, including local
  // dreamAppearance v1 presets. Reads expose the saved selection and parameters.
  static const MethodChannel channel = MethodChannel(
    'presence_mobile/settings',
  );

  /// Delivery calls cannot leave the single receive task waiting forever.
  /// Unlike pickers/dialogs these calls never wait for user interaction.
  static Future<T?> deliveryCall<T>(String method, [Object? arguments]) =>
      channel
          .invokeMethod<T>(method, arguments)
          .timeout(const Duration(seconds: 8));

  static bool debugForceChannelAvailable = false;

  static bool get available =>
      (!kIsWeb && Platform.isAndroid) || debugForceChannelAvailable;
}
