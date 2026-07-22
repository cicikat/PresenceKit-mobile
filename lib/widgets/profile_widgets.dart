import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';

import '../widgets/common_widgets.dart';

class ProfileNameDialog extends StatefulWidget {
  const ProfileNameDialog({
    super.key,
    required this.c,
    required this.initialName,
  });

  final YxPalette c;
  final String initialName;

  @override
  State<ProfileNameDialog> createState() => _ProfileNameDialogState();
}

class _ProfileNameDialogState extends State<ProfileNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: widget.c.surface,
      scrollable: true,
      title: Text(l10n.profileLocalNameTitle, style: serif(widget.c, 20)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 12,
        decoration: InputDecoration(
          hintText: l10n.profileNameHint,
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: Text(l10n.restoreDefaultAction),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.c,
    required this.profileDisplayName,
    required this.hasProfileNameOverride,
    required this.profileAvatarBytes,
    required this.promptAssets,
    required this.onBack,
    required this.onEditProfileName,
    required this.onImportProfileAvatar,
    required this.onResetProfileAvatar,
    required this.loadingPromptAssets,
    required this.savingPromptAssets,
    required this.promptAssetsError,
    required this.onSelectCharacter,
    required this.onReloadPromptAssets,
    required this.activityCurrent,
    required this.moodState,
    required this.loadingStatusSnapshot,
    required this.onReloadStatusSnapshot,
  });

  final YxPalette c;
  final String profileDisplayName;
  final bool hasProfileNameOverride;
  final Uint8List? profileAvatarBytes;
  final VoidCallback onBack;
  final VoidCallback onEditProfileName;
  final VoidCallback onImportProfileAvatar;
  final VoidCallback onResetProfileAvatar;
  final PromptAssets? promptAssets;
  final bool loadingPromptAssets;
  final bool savingPromptAssets;
  final String? promptAssetsError;
  final ValueChanged<String> onSelectCharacter;
  final VoidCallback onReloadPromptAssets;
  final ActivityCurrentState? activityCurrent;
  final MoodStateSnapshot? moodState;
  final bool loadingStatusSnapshot;
  final VoidCallback onReloadStatusSnapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasAvatar = profileAvatarBytes != null;
    return Column(
      children: [
        PageHeader(
          c: c,
          title: l10n.profileTitle,
          eyebrow: l10n.profileEyebrow(profileDisplayName),
          onBack: onBack,
          trailing: l10n.localDeviceLabel,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                  color: c.surfaceSoft,
                  child: Row(
                    children: [
                      YxAvatar(
                        c: c,
                        size: 92,
                        imageBytes: profileAvatarBytes,
                        text: profileDisplayName.characters.first,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profileDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: serif(c, 28, weight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasAvatar
                                  ? l10n.profileAvatarConfigured
                                  : l10n.profileAvatarDefault,
                              style: mono(c, 11, color: c.ink3),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: onEditProfileName,
                                  icon: const Icon(
                                    Icons.badge_outlined,
                                    size: 18,
                                  ),
                                  label: Text(l10n.profileNameAction),
                                ),
                                OutlinedButton.icon(
                                  onPressed: onImportProfileAvatar,
                                  icon: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 18,
                                  ),
                                  label: Text(l10n.profileAvatarAction),
                                ),
                                if (hasAvatar)
                                  OutlinedButton.icon(
                                    onPressed: onResetProfileAvatar,
                                    icon: const Icon(
                                      Icons.restore_rounded,
                                      size: 18,
                                    ),
                                    label: Text(l10n.profileDefaultAction),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.profileNowSection,
                          style: serif(c, 16, weight: FontWeight.w500),
                        ),
                      ),
                      YxIconButton(
                        c: c,
                        icon: Icons.refresh_rounded,
                        onPressed: onReloadStatusSnapshot,
                        tooltip: l10n.refreshAction,
                        size: 28,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: loadingStatusSnapshot
                      ? Text(
                          l10n.loadingAction,
                          style: mono(c, 10.5, color: c.ink3),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            YxTag(
                              c: c,
                              text: activityCurrent?.text.isNotEmpty == true
                                  ? activityCurrent!.text
                                  : l10n.profileNoActivity,
                              variant: 'warm',
                            ),
                            if (moodState != null)
                              YxTag(
                                c: c,
                                text: l10n.profileMoodStatus(
                                  moodLabel(l10n, moodState!.current),
                                  (moodState!.intensity * 100).round(),
                                ),
                              ),
                          ],
                        ),
                ),
                ProfileInfoRow(
                  c: c,
                  icon: Icons.drive_file_rename_outline_rounded,
                  title: l10n.profileLocalNameTitle,
                  value: hasProfileNameOverride
                      ? profileDisplayName
                      : l10n.profileDefaultCharacterName,
                  body: l10n.profileLocalNameBody,
                  actionIcon: Icons.edit_rounded,
                  onAction: onEditProfileName,
                ),
                ProfileInfoRow(
                  c: c,
                  icon: Icons.image_outlined,
                  title: l10n.profileAvatarScopeTitle,
                  value: hasAvatar
                      ? 'profile_avatar.png'
                      : l10n.profileDefaultAvatar,
                  body: l10n.profileAvatarScopeBody,
                  actionIcon: Icons.add_photo_alternate_outlined,
                  onAction: onImportProfileAvatar,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.profileRealityCardTitle,
                        style: serif(c, 16, weight: FontWeight.w500),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        l10n.profileRealityCardBody,
                        style: serif(c, 13.5, color: c.ink2),
                      ),
                      const SizedBox(height: 10),
                      if (promptAssets != null)
                        DropdownButtonFormField<String>(
                          value:
                              promptAssets!.characters.any(
                                (item) =>
                                    item.id == promptAssets!.activeCharacter,
                              )
                              ? promptAssets!.activeCharacter
                              : null,
                          items: [
                            for (final item in promptAssets!.characters)
                              DropdownMenuItem(
                                value: item.id,
                                child: Text(item.label),
                              ),
                          ],
                          onChanged: savingPromptAssets
                              ? null
                              : (value) {
                                  if (value != null) onSelectCharacter(value);
                                },
                          decoration: InputDecoration(
                            labelText: l10n.profileCurrentCardLabel,
                          ),
                        )
                      else
                        FilledButton.icon(
                          onPressed: loadingPromptAssets
                              ? null
                              : onReloadPromptAssets,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            loadingPromptAssets
                                ? l10n.loadingAction
                                : l10n.profileLoadCards,
                          ),
                        ),
                      if (promptAssetsError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          promptAssetsError!,
                          style: mono(c, 10, color: c.danger),
                        ),
                      ],
                    ],
                  ),
                ),
                ProfileInfoRow(
                  c: c,
                  icon: Icons.sync_disabled_rounded,
                  title: l10n.profileSyncBoundaryTitle,
                  value: l10n.profileSyncBoundaryValue,
                  body: l10n.profileSyncBoundaryBody,
                ),
                ProfileInfoRow(
                  c: c,
                  icon: Icons.visibility_outlined,
                  title: l10n.profileDisplayLocationTitle,
                  value: l10n.profileDisplayLocationValue,
                  body: l10n.profileDisplayLocationBody(profileDisplayName),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.surfaceSoft,
                      border: Border.all(color: c.ink4),
                    ),
                    child: Text(
                      l10n.profileFooterNotice(profileDisplayName),
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
      ],
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    super.key,
    required this.c,
    required this.icon,
    required this.title,
    required this.value,
    required this.body,
    this.actionIcon,
    this.onAction,
  });

  final YxPalette c;
  final IconData icon;
  final String title;
  final String value;
  final String body;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.surfaceEdge)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.ink2, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: serif(c, 16, weight: FontWeight.w500),
                      ),
                    ),
                    YxTag(c: c, text: value, variant: 'warm'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(body, style: serif(c, 13.5, color: c.ink2)),
              ],
            ),
          ),
          if (actionIcon != null && onAction != null) ...[
            const SizedBox(width: 10),
            YxIconButton(
              c: c,
              icon: actionIcon!,
              onPressed: onAction!,
              tooltip: title,
              size: 30,
            ),
          ],
        ],
      ),
    );
  }
}
