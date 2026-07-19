import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/locale_controller.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';

import '../widgets/common_widgets.dart';
import '../widgets/settings_editor_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.c,
    required this.language,
    required this.dark,
    required this.activeThemePresetName,
    required this.themePresetCount,
    required this.prefs,
    required this.profileDisplayName,
    required this.profileAvatarBytes,
    required this.promptAssets,
    required this.loreEntries,
    required this.jailbreakEntries,
    required this.dreamSettings,
    required this.settingsBusy,
    required this.settingsError,
    required this.onTheme,
    required this.onLanguage,
    required this.onManageThemes,
    required this.onPrefs,
    required this.onEditProfileName,
    required this.onImportProfileAvatar,
    required this.onResetProfileAvatar,
    required this.onOpenProfile,
    required this.onToggleLorebook,
    required this.onToggleJailbreak,
    required this.onDreamLorebook,
    required this.onDreamWorldLayer,
    required this.onDreamJailbreak,
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
  });

  final YxPalette c;
  final AppLanguage language;
  final bool dark;
  final String? activeThemePresetName;
  final int themePresetCount;
  final YxPrefs prefs;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;
  final PromptAssets? promptAssets;
  final List<LoreEntry> loreEntries;
  final List<JailbreakEntry> jailbreakEntries;
  final DreamSettings? dreamSettings;
  final bool settingsBusy;
  final String? settingsError;
  final ValueChanged<bool> onTheme;
  final ValueChanged<AppLanguage> onLanguage;
  final VoidCallback onManageThemes;
  final ValueChanged<YxPrefs> onPrefs;
  final VoidCallback onEditProfileName;
  final VoidCallback onImportProfileAvatar;
  final VoidCallback onResetProfileAvatar;
  final VoidCallback onOpenProfile;
  final ValueChanged<String> onToggleLorebook;
  final ValueChanged<String> onToggleJailbreak;
  final ValueChanged<bool> onDreamLorebook;
  final ValueChanged<String> onDreamWorldLayer;
  final ValueChanged<String> onDreamJailbreak;
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
            children: [
              _SettingsSection(title: l10n.settingsGeneralSection),
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
              _SettingsSection(title: l10n.settingsConnectionAccountSection),
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
              _SettingsSection(title: l10n.settingsNotificationsSection),
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
                title: l10n.settingsNotificationTestTitle,
                subtitle: l10n.settingsNotificationTestSubtitle,
                child: Switch(
                  value: notificationTestMode,
                  onChanged: onNotificationTestMode,
                ),
              ),
              _SettingsSection(title: l10n.settingsAppearanceSection),
              SettingsRow(
                c: c,
                title: l10n.settingsProfileTitle,
                subtitle: l10n.settingsProfileSubtitle,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    YxAvatar(
                      c: c,
                      size: 38,
                      imageBytes: profileAvatarBytes,
                      text: profileDisplayName.characters.first,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      profileDisplayName,
                      style: serif(c, 16, weight: FontWeight.w500),
                    ),
                    YxIconButton(
                      c: c,
                      icon: Icons.open_in_new_rounded,
                      onPressed: onOpenProfile,
                      tooltip: l10n.settingsOpenProfileTooltip,
                      size: 30,
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
              SettingsRow(
                c: c,
                title: l10n.settingsThemeTitle,
                subtitle: activeThemePresetName == null
                    ? l10n.settingsThemeBuiltInSubtitle(themePresetCount)
                    : l10n.settingsThemePresetSubtitle(
                        activeThemePresetName!,
                        themePresetCount,
                      ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.themePaper),
                      selected: !dark && activeThemePresetName == null,
                      onSelected: (_) => onTheme(false),
                    ),
                    ChoiceChip(
                      label: Text(l10n.themeNight),
                      selected: dark && activeThemePresetName == null,
                      onSelected: (_) => onTheme(true),
                    ),
                    OutlinedButton.icon(
                      onPressed: onManageThemes,
                      icon: const Icon(Icons.palette_outlined, size: 17),
                      label: Text(
                        activeThemePresetName ??
                            l10n.settingsColorPresets(themePresetCount),
                      ),
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
                subtitle: l10n.settingsFontSizeSubtitle(prefs.fontSize.round()),
                child: SizedBox(
                  width: 130,
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
              SettingsRow(
                c: c,
                title: l10n.settingsProactiveRateTitle,
                subtitle: l10n.settingsProactiveRateSubtitle,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'low', label: Text(l10n.rateLow)),
                    ButtonSegment(value: 'mid', label: Text(l10n.rateMedium)),
                    ButtonSegment(value: 'high', label: Text(l10n.rateHigh)),
                  ],
                  selected: {prefs.proactiveRate},
                  onSelectionChanged: (value) =>
                      onPrefs(prefs.copyWith(proactiveRate: value.first)),
                ),
              ),
              SettingsRow(
                c: c,
                title: l10n.settingsNightSilentTitle,
                subtitle: l10n.settingsNightSilentSubtitle,
                child: Switch(
                  value: prefs.nightSilent,
                  onChanged: (value) =>
                      onPrefs(prefs.copyWith(nightSilent: value)),
                ),
              ),
              _SettingsSection(title: l10n.settingsChatContentSection),
              SettingsRow(
                c: c,
                title: l10n.settingsChatLorebookTitle,
                subtitle: l10n.settingsChatLorebookSubtitle,
                child: PromptOptionChips(
                  c: c,
                  options: [
                    for (final entry in loreEntries)
                      PromptAssetOption(
                        id: entry.id,
                        label: entry.displayLabel,
                      ),
                  ],
                  selected: {
                    for (final entry in loreEntries)
                      if (entry.enabled) entry.id,
                  },
                  disabled: settingsBusy,
                  onToggle: onToggleLorebook,
                ),
              ),
              SettingsRow(
                c: c,
                title: l10n.settingsChatJailbreakTitle,
                subtitle: l10n.settingsChatJailbreakSubtitle,
                child: PromptOptionChips(
                  c: c,
                  options: [
                    for (final entry in jailbreakEntries)
                      PromptAssetOption(
                        id: entry.id,
                        label: entry.displayLabel,
                      ),
                  ],
                  selected: {
                    for (final entry in jailbreakEntries)
                      if (entry.enabled) entry.id,
                  },
                  disabled: settingsBusy,
                  onToggle: onToggleJailbreak,
                ),
              ),
              SettingsRow(
                c: c,
                title: l10n.settingsDreamLorebookTitle,
                subtitle: l10n.settingsDreamLorebookSubtitle,
                child: Switch(
                  value: dreamSettings?.enableDreamLorebook ?? true,
                  onChanged: settingsBusy ? null : onDreamLorebook,
                ),
              ),
              SettingsRow(
                c: c,
                title: l10n.settingsDreamWorldTitle,
                subtitle: l10n.settingsDreamWorldSubtitle,
                child: DropdownButton<String>(
                  value: dreamSettings?.worldLayer ?? 'reality_derived',
                  onChanged: settingsBusy
                      ? null
                      : (value) {
                          if (value != null) onDreamWorldLayer(value);
                        },
                  items: [
                    DropdownMenuItem(
                      value: 'reality_derived',
                      child: Text(l10n.dreamWorldRealityDerived),
                    ),
                    DropdownMenuItem(
                      value: 'abo',
                      child: Text(l10n.dreamWorldAbo),
                    ),
                    DropdownMenuItem(
                      value: 'vampire',
                      child: Text(l10n.dreamWorldVampire),
                    ),
                    DropdownMenuItem(
                      value: 'cat',
                      child: Text(l10n.dreamWorldCat),
                    ),
                    DropdownMenuItem(
                      value: 'flower_bud',
                      child: Text(l10n.dreamWorldFlowerBud),
                    ),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text(l10n.customOption),
                    ),
                  ],
                ),
              ),
              SettingsRow(
                c: c,
                title: l10n.settingsDreamJailbreakTitle,
                subtitle: l10n.settingsDreamJailbreakSubtitle,
                child: DropdownButton<String>(
                  value: dreamSettings?.jailbreakPreset ?? 'default',
                  onChanged: settingsBusy
                      ? null
                      : (value) {
                          if (value != null) onDreamJailbreak(value);
                        },
                  items: [
                    DropdownMenuItem(
                      value: 'default',
                      child: Text(l10n.defaultOption),
                    ),
                    DropdownMenuItem(
                      value: 'abo',
                      child: Text(l10n.dreamWorldAbo),
                    ),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text(l10n.customOption),
                    ),
                  ],
                ),
              ),
              if (settingsError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.settingsBackendSaveError(settingsError!),
                    style: mono(c, 10, color: c.danger),
                  ),
                ),
              _SettingsSection(title: l10n.settingsDiagnosticsSection),
              SettingsRow(
                c: c,
                title: l10n.settingsCapabilitiesTitle,
                subtitle: l10n.settingsCapabilitiesSubtitle,
                child: FilledButton.icon(
                  onPressed: onOpenCapabilities,
                  icon: const Icon(Icons.health_and_safety_outlined, size: 18),
                  label: Text(l10n.openAction),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surfaceSoft,
                    border: Border.all(color: c.ink4),
                  ),
                  child: Text(
                    l10n.settingsThinClientNotice,
                    style: serif(
                      c,
                      13,
                      color: c.ink2,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
    child: Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

// Legacy layout retained temporarily for source compatibility while settings
// navigation moves to SettingsPage; it is no longer constructed by the app.
// ignore: unused_element
class _LegacySystemSettingsSheet extends StatelessWidget {
  const _LegacySystemSettingsSheet({
    required this.c,
    required this.hasAdminToken,
    required this.backgroundNotifications,
    required this.backendBaseUrl,
    required this.ownerUserId,
    required this.historyLoaded,
    required this.loadingHistory,
    required this.historyError,
    required this.gardenLoaded,
    required this.loadingGarden,
    required this.gardenError,
    required this.mobileActive,
    required this.pollingMobile,
    required this.mobileError,
    required this.mobileReceivedCount,
    required this.lastMobileContent,
    required this.backendBusy,
    required this.backendError,
    required this.lastBackendReply,
    required this.onEditCredential,
    required this.onOpenCapabilities,
    required this.onEditBackend,
    required this.onBackgroundNotifications,
  });

  final YxPalette c;
  final bool hasAdminToken;
  final bool backgroundNotifications;
  final String backendBaseUrl;
  final String ownerUserId;
  final bool historyLoaded;
  final bool loadingHistory;
  final String? historyError;
  final bool gardenLoaded;
  final bool loadingGarden;
  final String? gardenError;
  final bool mobileActive;
  final bool pollingMobile;
  final String? mobileError;
  final int mobileReceivedCount;
  final String? lastMobileContent;
  final bool backendBusy;
  final String? backendError;
  final BackendChatResponse? lastBackendReply;
  final VoidCallback onEditCredential;
  final VoidCallback onOpenCapabilities;
  final VoidCallback onEditBackend;
  final ValueChanged<bool> onBackgroundNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.surfaceEdge)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: c.ink4.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, color: c.ink2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '系统设置',
                      style: serif(c, 22, weight: FontWeight.w500),
                    ),
                  ),
                  YxIconButton(
                    c: c,
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.pop(context),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            SettingsRow(
              c: c,
              title: '访问 Token',
              subtitle: hasAdminToken
                  ? '已设置 · 保存在本机 Android 私有存储'
                  : '尚未设置 · 连接后端前必须填写',
              child: FilledButton.icon(
                onPressed: onEditCredential,
                icon: const Icon(Icons.key_rounded, size: 18),
                label: Text(hasAdminToken ? '更换' : '设置'),
              ),
            ),
            SettingsRow(
              c: c,
              title: '能力检查',
              subtitle: '权限状态 · 后端连通 · 后台服务',
              child: FilledButton.icon(
                onPressed: onOpenCapabilities,
                icon: const Icon(Icons.health_and_safety_outlined, size: 18),
                label: const Text('打开'),
              ),
            ),
            SettingsRow(
              c: c,
              title: '后端节点',
              subtitle: '$backendBaseUrl · 用户 $ownerUserId',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    backendBusy
                        ? '● 等待'
                        : backendError != null
                        ? '● 异常'
                        : lastBackendReply != null
                        ? '● 已接入'
                        : '● 待验证',
                    style: mono(
                      c,
                      11,
                      color: backendBusy
                          ? c.warn
                          : backendError != null
                          ? c.danger
                          : lastBackendReply != null
                          ? c.ok
                          : c.ink3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  YxIconButton(
                    c: c,
                    icon: Icons.edit_location_alt_rounded,
                    onPressed: onEditBackend,
                    tooltip: '修改后端地址',
                    size: 30,
                  ),
                ],
              ),
            ),
            SettingsRow(
              c: c,
              title: '聊天记录',
              subtitle: '向上滑动时加载更早的对话',
              child: Text(
                loadingHistory
                    ? '● 读取'
                    : historyError != null
                    ? '● 失败'
                    : historyLoaded
                    ? '● 已同步'
                    : '● 待同步',
                style: mono(
                  c,
                  11,
                  color: loadingHistory
                      ? c.warn
                      : historyError != null
                      ? c.danger
                      : historyLoaded
                      ? c.ok
                      : c.ink3,
                ),
              ),
            ),
            SettingsRow(
              c: c,
              title: '花园状态',
              subtitle: '自动同步今天的心境花园',
              child: Text(
                loadingGarden
                    ? '● 读取'
                    : gardenError != null
                    ? '● 失败'
                    : gardenLoaded
                    ? '● 已同步'
                    : '● 待同步',
                style: mono(
                  c,
                  11,
                  color: loadingGarden
                      ? c.warn
                      : gardenError != null
                      ? c.danger
                      : gardenLoaded
                      ? c.ok
                      : c.ink3,
                ),
              ),
            ),
            SettingsRow(
              c: c,
              title: '主动消息',
              subtitle: mobileReceivedCount > 0
                  ? '已接收 $mobileReceivedCount 条后台主动消息'
                  : '中继优先 · 不可用时每 5 秒检查补偿队列',
              child: Text(
                pollingMobile
                    ? '● 轮询'
                    : mobileError != null
                    ? '● 失败'
                    : mobileActive
                    ? '● 已激活'
                    : '● 待激活',
                style: mono(
                  c,
                  11,
                  color: pollingMobile
                      ? c.warn
                      : mobileError != null
                      ? c.danger
                      : mobileActive
                      ? c.ok
                      : c.ink3,
                ),
              ),
            ),
            SettingsRow(
              c: c,
              title: '后台通知',
              subtitle: '中继实时订阅 · 长时间断线周期补偿 · 静音/冷却',
              child: Switch(
                value: backgroundNotifications,
                onChanged: onBackgroundNotifications,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.warn.withValues(alpha: 0.08),
                  border: Border.all(color: c.warn.withValues(alpha: 0.45)),
                ),
                child: Text(
                  '隐私提示：中继只承载新消息信号，正文会从已鉴权后端回源读取。'
                  'topic 与访问 token 仍应保持私密。',
                  style: serif(c, 13, color: c.ink2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surfaceSoft,
                  border: Border.all(color: c.ink4),
                ),
                child: Text(
                  lastMobileContent != null
                      ? '最近一条主动消息：$lastMobileContent'
                      : '手机端负责聊天、通知、悬浮窗和本机显示；人格、记忆与调度仍由后端维护。',
                  style: serif(
                    c,
                    13,
                    color: c.ink2,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
