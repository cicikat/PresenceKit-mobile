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
