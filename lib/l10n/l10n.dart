import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String themeRoleLabel(AppLocalizations l10n, String key) => switch (key) {
  'surface' => l10n.themeRoleSurface,
  'surfaceSoft' => l10n.themeRoleSurfaceSoft,
  'surfaceDeep' => l10n.themeRoleSurfaceDeep,
  'surfaceEdge' => l10n.themeRoleSurfaceEdge,
  'ink1' => l10n.themeRoleInk1,
  'ink2' => l10n.themeRoleInk2,
  'ink3' => l10n.themeRoleInk3,
  'ink4' => l10n.themeRoleInk4,
  'character' => l10n.themeRoleCharacter,
  'characterDeep' => l10n.themeRoleCharacterDeep,
  'characterSoft' => l10n.themeRoleCharacterSoft,
  'characterOn' => l10n.themeRoleCharacterOn,
  'danger' => l10n.themeRoleDanger,
  'warn' => l10n.themeRoleWarn,
  'ok' => l10n.themeRoleOk,
  'send' => l10n.themeRoleSend,
  'userBubble' => l10n.themeRoleUserBubble,
  'userBubbleText' => l10n.themeRoleUserBubbleText,
  'scrim' => l10n.themeRoleScrim,
  _ => key,
};

String localizeSessionScopeError(AppLocalizations l10n, String error) {
  return switch (error.trim()) {
    'session_scope_unsupported' || 'session_scope_required' =>
      l10n.sessionScopeUnsupported,
    'character_unavailable' || 'character_not_authorized' =>
      l10n.sessionCharacterUnavailable,
    'character_revoked' => l10n.sessionCharacterRevoked,
    'session_not_found' => l10n.sessionExpired,
    'in_flight' => l10n.sessionRequestInFlight,
    'execution_outcome_unknown' || 'request_payload_conflict' =>
      l10n.sessionRequestUnknown,
    _ => error,
  };
}

String moodLabel(AppLocalizations l10n, String key) => switch (key) {
  'neutral' => l10n.moodNeutral,
  'gentle' => l10n.moodGentle,
  'thinking' => l10n.moodThinking,
  'happy' => l10n.moodHappy,
  'sad' => l10n.moodSad,
  'surprised' => l10n.moodSurprised,
  'angry' => l10n.moodAngry,
  'sleepy' => l10n.moodSleepy,
  'yandere' => l10n.moodYandere,
  _ => key,
};
