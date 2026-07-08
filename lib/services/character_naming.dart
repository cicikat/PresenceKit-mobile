import 'package:characters/characters.dart';

/// Neutral fallback shown when neither a local nickname override nor a
/// backend-provided character name is available.
const String kFallbackCharacterDisplayName = 'TA';

/// Trims and caps a raw display name, returning null for blank input.
String? cleanCharacterDisplayName(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value.characters.take(12).toString();
}

/// Single source of truth for the character display name shown across the
/// app: a user-set local nickname wins, then the backend's active character
/// name, then [kFallbackCharacterDisplayName].
String resolveCharacterDisplayName({
  String? localOverride,
  String? backendName,
}) {
  return cleanCharacterDisplayName(localOverride) ??
      cleanCharacterDisplayName(backendName) ??
      kFallbackCharacterDisplayName;
}
