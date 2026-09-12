import 'conversation_calendar_widgets.dart';
import '../controllers/personalization_controller.dart';
import 'personalization_widgets.dart';
import 'screen_observation_settings.dart';
import 'package:flutter/material.dart';
import 'dream_appearance_settings.dart';
import 'package:flutter/services.dart';
import '../controllers/locale_controller.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';

import '../widgets/common_widgets.dart';
import '../widgets/settings_editor_widgets.dart';

TextStyle _settingsSectionTitleStyle(YxPalette c) =>
    TextStyle(fontSize: 16, color: c.ink1, fontWeight: FontWeight.w600);

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.personalization,
    this.profileContent,
    required this.c,
    required this.language,
    required this.dark,
    this.lightThemePresetName,
    this.darkThemePresetName,
    this.activeThemePresetName,
    required this.themePresetCount,
    required this.prefs,
    required this.profileDisplayName,
    required this.profileAvatarBytes,
    this.chatBackground,
    this.nightChatBackground,
    this.onImportNightChatBackground,
    this.onResetNightChatBackground,
    required this.dreamSettings,
    required this.settingsBusy,
    required this.settingsError,
    required this.onTheme,
    required this.onLanguage,
    required this.onManageThemes,
    this.onManageThemesForMode,
    required this.onPrefs,
    required this.onEditProfileName,
    required this.onImportProfileAvatar,
    required this.onResetProfileAvatar,
    this.onImportChatBackground,
    this.onResetChatBackground,
    this.onImportDreamBackground,
    this.onResetDreamBackground,
    required this.onDreamLorebook,
    required this.onDreamWorldLayer,
    required this.onDreamJailbreak,
    this.dreamWorlds = const [],
    this.dreamPresets = const [],
    this.onOpenSystemControls,
    this.onRetryDream,
    this.onDreamContext,
    this.dreamActive = false,
    required this.hasAdminToken,
    required this.backgroundNotifications,
    required this.backendBaseUrl,
    required this.ownerUserId,
    required this.notificationTestMode,
    required this.onEditCredential,
    required this.onEditBackend,
    required this.onEditRelay,
    required this.onBackgroundNotifications,
    required this.onNotificationTestMode,
    required this.onOpenCapabilities,
    required this.stickerEnabled,
    required this.autoPlayVoice,
    required this.onStickerEnabledChanged,
    required this.onAutoPlayVoiceChanged,
  });

  final Widget? profileContent;
  final PersonalizationController? personalization;
  final YxPalette c;
  final AppLanguage language;
  final bool dark;
  final String? lightThemePresetName;
  final String? darkThemePresetName;
  final String? activeThemePresetName;
  final int themePresetCount;
  final YxPrefs prefs;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;
  final Uint8List? chatBackground;
  final Uint8List? nightChatBackground;
  final VoidCallback? onImportNightChatBackground;
  final VoidCallback? onResetNightChatBackground;
  final DreamSettings? dreamSettings;
  final bool settingsBusy;
  final String? settingsError;
  final ValueChanged<bool> onTheme;
  final ValueChanged<AppLanguage> onLanguage;
  final VoidCallback onManageThemes;
  final ValueChanged<bool>? onManageThemesForMode;
  final ValueChanged<YxPrefs> onPrefs;
  final VoidCallback onEditProfileName;
  final VoidCallback onImportProfileAvatar;
  final VoidCallback onResetProfileAvatar;
  final VoidCallback? onImportChatBackground;
  final VoidCallback? onResetChatBackground;
  final VoidCallback? onImportDreamBackground;
  final VoidCallback? onResetDreamBackground;
  final ValueChanged<bool> onDreamLorebook;
  final ValueChanged<String> onDreamWorldLayer;
  final ValueChanged<String> onDreamJailbreak;
  final List<PromptAssetOption> dreamWorlds;
  final List<PromptAssetOption> dreamPresets;
  final VoidCallback? onOpenSystemControls;
  final VoidCallback? onRetryDream;
  final bool dreamActive;
  final void Function(String field, String value)? onDreamContext;
  final bool hasAdminToken;
  final bool backgroundNotifications;
  final String backendBaseUrl;
  final String ownerUserId;
  final bool notificationTestMode;
  final VoidCallback onEditCredential;
  final VoidCallback onEditBackend;
  final Future<void> Function() onEditRelay;
  final ValueChanged<bool> onBackgroundNotifications;
  final ValueChanged<bool> onNotificationTestMode;
  final VoidCallback onOpenCapabilities;
  final bool stickerEnabled;
  final bool autoPlayVoice;
  final ValueChanged<bool> onStickerEnabledChanged;
  final ValueChanged<bool> onAutoPlayVoiceChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageLabel = switch (language) {
      AppLanguage.system => l10n.languageSystem,
      AppLanguage.simplifiedChinese => l10n.languageSimplifiedChinese,
      AppLanguage.english => l10n.languageEnglish,
    };
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.ink1,
        elevation: 0,
        title: Text(
          l10n.settingsTitle,
          style: serif(c, 22, weight: FontWeight.w500),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsConnectionAccountSection,
                      style: serif(c, 18, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasAdminToken &&
                              backendBaseUrl.trim().isNotEmpty &&
                              ownerUserId.trim().isNotEmpty
                          ? l10n.settingsSetupComplete
                          : l10n.settingsSetupHelp,
                      style: TextStyle(
                        color: c.ink2,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              SettingsRow(
                c: c,
                title: l10n.settingsAccessTokenTitle,
                subtitle: hasAdminToken
                    ? l10n.settingsAccessTokenConfigured
                    : l10n.settingsAccessTokenMissing,
                child: FilledButton.icon(
                  onPressed: onEditCredential,
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: Text(
                    hasAdminToken
                        ? l10n.settingsReplaceAction
                        : l10n.settingsSetAction,
                  ),
                ),
              ),
              SettingsRow(
                c: c,
                title: l10n.settingsBackendNodeTitle,
                subtitle: l10n.settingsBackendNodeSubtitle(
                  backendBaseUrl,
                  ownerUserId,
                ),
                child: YxIconButton(
                  c: c,
                  icon: Icons.edit_location_alt_rounded,
                  onPressed: onEditBackend,
                  tooltip: l10n.settingsEditBackendTooltip,
                ),
              ),
              _SettingsModule(
                c: c,
                title: l10n.settingsSystemModule,
                icon: Icons.tune_rounded,
                children: [
                  SettingsRow(
                    c: c,
                    title: l10n.settingsLanguageTitle,
                    subtitle: l10n.settingsLanguageSubtitle,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AppLanguage>(
                        value: language,
                        alignment: AlignmentDirectional.centerEnd,
                        borderRadius: BorderRadius.circular(8),
                        selectedItemBuilder: (context) => [
                          for (final _ in AppLanguage.values)
                            Text(languageLabel, style: serif(c, 14)),
                        ],
                        items: [
                          DropdownMenuItem(
                            value: AppLanguage.system,
                            child: Text(l10n.languageSystem),
                          ),
                          DropdownMenuItem(
                            value: AppLanguage.simplifiedChinese,
                            child: Text(l10n.languageSimplifiedChinese),
                          ),
                          DropdownMenuItem(
                            value: AppLanguage.english,
                            child: Text(l10n.languageEnglish),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) onLanguage(value);
                        },
                      ),
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsBackgroundNotificationsTitle,
                    subtitle: l10n.settingsBackgroundNotificationsSubtitle,
                    child: Switch(
                      value: backgroundNotifications,
                      onChanged: onBackgroundNotifications,
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsRelayTitle,
                    subtitle: l10n.settingsRelaySubtitle,
                    child: YxIconButton(
                      c: c,
                      icon: Icons.cell_tower_outlined,
                      onPressed: () => onEditRelay(),
                      tooltip: l10n.settingsEditRelayTooltip,
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsStickerTitle,
                    subtitle: l10n.settingsStickerSubtitle,
                    child: Switch(
                      value: stickerEnabled,
                      onChanged: onStickerEnabledChanged,
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsAutoPlayVoiceTitle,
                    subtitle: l10n.settingsAutoPlayVoiceSubtitle,
                    child: Switch(
                      value: autoPlayVoice,
                      onChanged: onAutoPlayVoiceChanged,
                    ),
                  ),
                  ListTile(
                    title: Text(
                      l10n.settingsPermissionsTitle,
                      style: _settingsSectionTitleStyle(c),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: onOpenSystemControls,
                  ),
                  ScreenObservationSettings(c: c),
                  ExpansionTile(
                    title: Text(
                      l10n.settingsNotificationTestTitle,
                      style: _settingsSectionTitleStyle(c),
                    ),
                    children: [
                      SettingsRow(
                        c: c,
                        title: l10n.settingsNotificationTestTitle,
                        subtitle: l10n.settingsNotificationTestSubtitle,
                        child: Switch(
                          value: notificationTestMode,
                          onChanged: onNotificationTestMode,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _SettingsModule(
                c: c,
                title: l10n.settingsProfileTitle,
                icon: Icons.badge_outlined,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        YxAvatar(
                          c: c,
                          size: 38,
                          imageBytes: profileAvatarBytes,
                          text: profileDisplayName.isEmpty
                              ? '?'
                              : profileDisplayName.characters.first,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          profileDisplayName,
                          style: serif(c, 16, weight: FontWeight.w500),
                        ),
                        YxIconButton(
                          c: c,
                          icon: Icons.badge_outlined,
                          onPressed: onEditProfileName,
                          tooltip: l10n.settingsEditProfileNameTooltip,
                          size: 30,
                        ),
                        YxIconButton(
                          c: c,
                          icon: Icons.add_photo_alternate_outlined,
                          onPressed: onImportProfileAvatar,
                          tooltip: l10n.settingsImportAvatarTooltip,
                          size: 30,
                        ),
                        if (profileAvatarBytes != null)
                          YxIconButton(
                            c: c,
                            icon: Icons.restore_rounded,
                            onPressed: onResetProfileAvatar,
                            tooltip: l10n.settingsResetAvatarTooltip,
                            size: 30,
                          ),
                      ],
                    ),
                  ),
                  if (profileContent != null) profileContent!,
                ],
              ),
              _SettingsModule(
                c: c,
                title: l10n.settingsAppearanceSection,
                icon: Icons.palette_outlined,
                children: [
                  CalendarPaletteSetting(
                    c: c,
                    value: prefs.calendarPalette,
                    onChanged: (value) =>
                        onPrefs(prefs.copyWith(calendarPalette: value)),
                  ),
                  for (final night in [false, true])
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(
                        night
                            ? l10n.nightAppearanceTheme
                            : l10n.dayAppearanceTheme,
                        style: serif(c, 16),
                      ),
                      subtitle: Text(
                        night
                            ? (darkThemePresetName ?? l10n.themeNight)
                            : (lightThemePresetName ?? l10n.themePaper),
                        style: mono(c, 12),
                      ),
                      trailing: Icon(Icons.chevron_right, color: c.ink3),
                      onTap: () =>
                          (onManageThemesForMode ?? (_) => onManageThemes())(
                            night,
                          ),
                    ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsDayChatBackgroundTitle,
                    subtitle: l10n.settingsChatBackgroundSubtitle,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (chatBackground != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(
                              chatBackground!,
                              width: 64,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
                        YxIconButton(
                          c: c,
                          icon: Icons.add_photo_alternate_outlined,
                          onPressed: onImportChatBackground ?? () {},
                          tooltip: l10n.settingsImportChatBackgroundTooltip,
                          size: 30,
                        ),
                        if (chatBackground != null)
                          YxIconButton(
                            c: c,
                            icon: Icons.restore_rounded,
                            onPressed: onResetChatBackground ?? () {},
                            tooltip: l10n.settingsResetChatBackgroundTooltip,
                            size: 30,
                          ),
                      ],
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsNightChatBackgroundTitle,
                    subtitle: l10n.settingsChatBackgroundSubtitle,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (nightChatBackground != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(
                              nightChatBackground!,
                              width: 64,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
                        YxIconButton(
                          c: c,
                          icon: Icons.add_photo_alternate_outlined,
                          onPressed: onImportNightChatBackground ?? () {},
                          tooltip: l10n.settingsImportChatBackgroundTooltip,
                          size: 30,
                        ),
                        if (nightChatBackground != null)
                          YxIconButton(
                            c: c,
                            icon: Icons.restore_rounded,
                            onPressed: onResetNightChatBackground ?? () {},
                            tooltip: l10n.settingsResetChatBackgroundTooltip,
                            size: 30,
                          ),
                      ],
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsInfoStripTitle,
                    subtitle: l10n.settingsInfoStripSubtitle,
                    child: Switch(
                      value: prefs.infoStrip,
                      onChanged: (value) =>
                          onPrefs(prefs.copyWith(infoStrip: value)),
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsFontSizeTitle,
                    subtitle: l10n.settingsFontSizeSubtitle(
                      prefs.fontSize.round(),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Slider(
                        value: prefs.fontSize,
                        min: 14,
                        max: 20,
                        divisions: 6,
                        activeColor: c.character,
                        onChanged: (value) =>
                            onPrefs(prefs.copyWith(fontSize: value)),
                      ),
                    ),
                  ),
                  if (personalization != null)
                    FontSettings(c: c, controller: personalization!),
                  SettingsRow(
                    c: c,
                    title: l10n.showReasoning,
                    subtitle: l10n.reasoningLocal,
                    child: Switch(
                      value: prefs.showReasoning,
                      onChanged: (value) =>
                          onPrefs(prefs.copyWith(showReasoning: value)),
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.expandReasoning,
                    subtitle: l10n.reasoningLocal,
                    child: Switch(
                      value: prefs.expandReasoning,
                      onChanged: (value) =>
                          onPrefs(prefs.copyWith(expandReasoning: value)),
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.reasoningOpacity,
                    subtitle: '${(prefs.reasoningOpacity * 100).round()}%',
                    child: SizedBox(
                      width: double.infinity,
                      child: Slider(
                        value: prefs.reasoningOpacity,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        onChanged: (value) =>
                            onPrefs(prefs.copyWith(reasoningOpacity: value)),
                      ),
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsShowChatTimeTitle,
                    subtitle: l10n.settingsShowChatTimeSubtitle,
                    child: Switch(
                      value: prefs.showChatTime,
                      onChanged: (value) =>
                          onPrefs(prefs.copyWith(showChatTime: value)),
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsShowAvatarTitle,
                    subtitle: l10n.settingsShowAvatarSubtitle,
                    child: Switch(
                      value: prefs.showYouAvatar,
                      onChanged: (value) =>
                          onPrefs(prefs.copyWith(showYouAvatar: value)),
                    ),
                  ),
                ],
              ),
              _SettingsModule(
                c: c,
                title: l10n.settingsDreamModule,
                icon: Icons.nightlight_outlined,
                children: [
                  _SettingsModule(
                    c: c,
                    title: l10n.dreamUi,
                    icon: Icons.palette_outlined,
                    children: [
                      SettingsRow(
                        c: c,
                        title: l10n.settingsDreamBackgroundTitle,
                        subtitle: l10n.settingsChatBackgroundSubtitle,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            if (prefs.dreamBackground != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(
                                  prefs.dreamBackground!,
                                  width: 64,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            YxIconButton(
                              c: c,
                              icon: Icons.add_photo_alternate_outlined,
                              onPressed: onImportDreamBackground ?? () {},
                              tooltip: l10n.settingsImportChatBackgroundTooltip,
                              size: 30,
                            ),
                            if (prefs.dreamBackground != null)
                              YxIconButton(
                                c: c,
                                icon: Icons.restore_rounded,
                                onPressed: onResetDreamBackground ?? () {},
                                tooltip:
                                    l10n.settingsResetChatBackgroundTooltip,
                                size: 30,
                              ),
                          ],
                        ),
                      ),
                      DreamAppearanceSettings(
                        c: c,
                        prefs: prefs,
                        onPrefs: onPrefs,
                      ),
                    ],
                  ),
                  for (final entry
                      in <String, (String, String?, Map<String, String>)>{
                        'memory_access': (
                          l10n.settingsDreamMemory,
                          dreamSettings?.memoryAccess,
                          {
                            'card_only': l10n.settingsDreamCardOnly,
                            'relationship_summary':
                                l10n.settingsDreamRelationship,
                            'full_snapshot': l10n.settingsDreamSnapshot,
                          },
                        ),
                        'boundary_level': (
                          l10n.settingsDreamBoundary,
                          dreamSettings?.boundaryLevel,
                          {
                            'vague': l10n.settingsDreamVague,
                            'body_perceptible': l10n.settingsDreamBody,
                            'numbers_visible': l10n.settingsDreamNumbers,
                            'threshold_break': l10n.settingsDreamThreshold,
                          },
                        ),
                        'lucid_mode': (
                          l10n.settingsDreamLucidity,
                          dreamSettings?.lucidMode,
                          {
                            'lucid_shared': l10n.settingsDreamLucid,
                            'non_lucid': l10n.settingsDreamNonLucid,
                          },
                        ),
                      }.entries)
                    SettingsRow(
                      c: c,
                      title: entry.value.$1,
                      subtitle: l10n.settingsDreamNextEntry,
                      child: SizedBox(
                        width: 220,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: entry.value.$2,
                          items: [
                            for (final option in {
                              ...entry.value.$3,
                              if (entry.value.$2 != null &&
                                  !entry.value.$3.containsKey(entry.value.$2))
                                entry.value.$2!: entry.value.$2!,
                            }.entries)
                              DropdownMenuItem(
                                value: option.key,
                                child: Text(option.value),
                              ),
                          ],
                          onChanged:
                              settingsBusy ||
                                  dreamActive ||
                                  dreamSettings == null
                              ? null
                              : (v) {
                                  if (v != null) {
                                    onDreamContext?.call(entry.key, v);
                                  }
                                },
                        ),
                      ),
                    ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsDreamLorebookTitle,
                    subtitle: l10n.settingsDreamLorebookSubtitle,
                    child: Switch(
                      value: dreamSettings?.enableDreamLorebook ?? true,
                      onChanged:
                          settingsBusy || dreamActive || dreamSettings == null
                          ? null
                          : onDreamLorebook,
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsDreamWorldTitle,
                    subtitle: l10n.settingsDreamNextEntry,
                    child: SizedBox(
                      width: 220,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: dreamSettings?.worldLayer,
                        items: [
                          for (final option in {
                            for (final o in dreamWorlds) o.id: o.label,
                            if (dreamSettings != null &&
                                !dreamWorlds.any(
                                  (o) => o.id == dreamSettings!.worldLayer,
                                ))
                              dreamSettings!.worldLayer:
                                  dreamSettings!.worldLayer,
                          }.entries)
                            DropdownMenuItem(
                              value: option.key,
                              child: Text(
                                option.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged:
                            settingsBusy ||
                                dreamActive ||
                                dreamSettings == null ||
                                dreamWorlds.isEmpty
                            ? null
                            : (v) {
                                if (v != null) onDreamWorldLayer(v);
                              },
                      ),
                    ),
                  ),
                  SettingsRow(
                    c: c,
                    title: l10n.settingsDreamJailbreakTitle,
                    subtitle: l10n.settingsDreamNextEntry,
                    child: PromptOptionChips(
                      c: c,
                      options: [
                        for (final option in {
                          for (final o in dreamPresets) o.id: o.label,
                          for (final id
                              in dreamSettings?.jailbreakPresets ?? <String>[])
                            if (!dreamPresets.any((o) => o.id == id)) id: id,
                        }.entries)
                          PromptAssetOption(
                            id: option.key,
                            label: option.value,
                          ),
                      ],
                      selected: dreamSettings?.jailbreakPresets.toSet() ?? {},
                      disabled:
                          settingsBusy ||
                          dreamActive ||
                          dreamSettings == null ||
                          dreamPresets.isEmpty,
                      onToggle: onDreamJailbreak,
                    ),
                  ),
                  if (settingsBusy) const LinearProgressIndicator(),
                  if (settingsError != null ||
                      dreamSettings == null && !settingsBusy)
                    ListTile(
                      title: Text(
                        settingsError ?? l10n.settingsDreamUnavailable,
                      ),
                      trailing: IconButton(
                        onPressed: onRetryDream,
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: l10n.capabilityRefreshTooltip,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.health_and_safety_outlined,
                    color: c.character,
                  ),
                  title: Text(
                    l10n.settingsCapabilitiesTitle,
                    style: _settingsSectionTitleStyle(c),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: onOpenCapabilities,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsModule extends StatelessWidget {
  const _SettingsModule({
    required this.c,
    required this.title,
    required this.icon,
    required this.children,
  });
  final YxPalette c;
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
    child: Material(
      color: c.surfaceSoft,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icon, color: c.character),
        title: Text(title, style: _settingsSectionTitleStyle(c)),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        children: children,
      ),
    ),
  );
}
