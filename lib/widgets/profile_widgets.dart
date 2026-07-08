part of '../main.dart';

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

  @override
  Widget build(BuildContext context) {
    final hasAvatar = profileAvatarBytes != null;
    return Column(
      children: [
        PageHeader(
          c: c,
          title: '角色资料',
          eyebrow: '$profileDisplayName · 本机显示',
          onBack: onBack,
          trailing: '本机',
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
                              hasAvatar ? '本机头像已设置' : '使用默认字母头像',
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
                                  label: const Text('备注名'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: onImportProfileAvatar,
                                  icon: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('头像'),
                                ),
                                if (hasAvatar)
                                  OutlinedButton.icon(
                                    onPressed: onResetProfileAvatar,
                                    icon: const Icon(
                                      Icons.restore_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('默认'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ProfileInfoRow(
                  c: c,
                  icon: Icons.drive_file_rename_outline_rounded,
                  title: '本机备注名',
                  value: hasProfileNameOverride
                      ? profileDisplayName
                      : '默认角色名',
                  body: '只影响这台手机里的显示：顶部栏、抽屉、偏好页和 HIM 聊天气泡。不会写回后端，也不会改核心人格配置。',
                  actionIcon: Icons.edit_rounded,
                  onAction: onEditProfileName,
                ),
                ProfileInfoRow(
                  c: c,
                  icon: Icons.image_outlined,
                  title: '头像作用域',
                  value: hasAvatar ? 'profile_avatar.png' : '默认头像',
                  body: '头像保存在 App 私有目录，只作为手机端本地头像源。当前不会上传到后端，也不会同步到桌宠或其他客户端。',
                  actionIcon: Icons.add_photo_alternate_outlined,
                  onAction: onImportProfileAvatar,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reality 角色卡',
                        style: serif(c, 16, weight: FontWeight.w500),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '切换后会影响主对话使用的人格卡；由后端保存并同步到其他客户端。',
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
                          decoration: const InputDecoration(labelText: '当前角色卡'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: loadingPromptAssets
                              ? null
                              : onReloadPromptAssets,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(loadingPromptAssets ? '正在读取…' : '读取角色卡'),
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
                  title: '同步边界',
                  value: '手机端覆盖显示',
                  body: '后续如果要同步备注名到后端，建议单独做确认按钮；现在资料页保持轻客户端边界，避免误改核心配置。',
                ),
                ProfileInfoRow(
                  c: c,
                  icon: Icons.visibility_outlined,
                  title: '显示位置',
                  value: 'UI 已跟随',
                  body: '顶部栏、抽屉、偏好页和$profileDisplayName消息头像都会读取这份本机资料。用户自己的头像设置仍独立处理。',
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
                      '这页只管理手机薄客户端的外观身份。$profileDisplayName的核心人格、记忆和调度仍然以后端为准。',
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
