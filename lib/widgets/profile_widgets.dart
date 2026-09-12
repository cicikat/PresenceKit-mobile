import 'package:flutter/material.dart';
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

class ProfileSettingsContent extends StatelessWidget {
  const ProfileSettingsContent({
    super.key,
    required this.c,
    required this.promptAssets,
    required this.loadingPromptAssets,
    required this.savingPromptAssets,
    required this.promptAssetsError,
    required this.onSelectCharacter,
    required this.onReloadPromptAssets,
    required this.activityCurrent,
    required this.moodState,
    required this.loadingStatusSnapshot,
    required this.statusSnapshotLastSuccessfulAt,
    required this.statusSnapshotError,
    required this.onReloadStatusSnapshot,
  });

  final YxPalette c;
  final PromptAssets? promptAssets;
  final bool loadingPromptAssets;
  final bool savingPromptAssets;
  final String? promptAssetsError;
  final ValueChanged<String> onSelectCharacter;
  final VoidCallback onReloadPromptAssets;
  final ActivityCurrentState? activityCurrent;
  final MoodStateSnapshot? moodState;
  final bool loadingStatusSnapshot;
  final DateTime? statusSnapshotLastSuccessfulAt;
  final String? statusSnapshotError;
  final VoidCallback onReloadStatusSnapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasStatusSnapshot = statusSnapshotLastSuccessfulAt != null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loadingStatusSnapshot)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l10n.profileStatusUpdating,
                    style: mono(c, 10.5, color: c.ink3),
                  ),
                ),
              if (hasStatusSnapshot)
                Wrap(
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
              if (statusSnapshotLastSuccessfulAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    l10n.profileStatusLastUpdated(
                      _formatStatusTime(
                        context,
                        statusSnapshotLastSuccessfulAt!,
                      ),
                    ),
                    style: mono(c, 10.5, color: c.ink3),
                  ),
                ),
              if (statusSnapshotError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    l10n.profileStatusLoadError(statusSnapshotError!),
                    style: mono(c, 10.5, color: c.danger),
                  ),
                ),
            ],
          ),
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
              const SizedBox(height: 10),
              if (promptAssets != null)
                DropdownButtonFormField<String>(
                  value:
                      promptAssets!.characters.any(
                        (item) => item.id == promptAssets!.activeCharacter,
                      )
                      ? promptAssets!.activeCharacter
                      : null,
                  items: [
                    for (final item in promptAssets!.characters)
                      DropdownMenuItem(value: item.id, child: Text(item.label)),
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
                  onPressed: loadingPromptAssets ? null : onReloadPromptAssets,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    loadingPromptAssets
                        ? l10n.loadingAction
                        : l10n.profileLoadCards,
                  ),
                ),
              if (promptAssetsError != null) ...[
                const SizedBox(height: 8),
                Text(promptAssetsError!, style: mono(c, 10, color: c.danger)),
              ],
            ],
          ),
        ),
      ],
    );
    return content;
  }

  String _formatStatusTime(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatShortDate(value)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }
}
