import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';

import '../widgets/common_widgets.dart';

class YxDrawer extends StatelessWidget {
  const YxDrawer({
    super.key,
    required this.c,
    required this.route,
    required this.profileDisplayName,
    required this.profileAvatarBytes,
    required this.onRoute,
    required this.onOpenSettings,
  });

  final YxPalette c;
  final AppRoute route;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;
  final ValueChanged<AppRoute> onRoute;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.84,
      backgroundColor: c.characterDeep,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                children: [
                  YxAvatar(
                    c: c,
                    size: 56,
                    onDark: true,
                    imageBytes: profileAvatarBytes,
                    text: profileDisplayName.characters.first,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profileDisplayName,
                          style: serif(
                            c,
                            22,
                            color: c.characterOn,
                            weight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          l10n.drawerClientSubtitle,
                          style: mono(
                            c,
                            10,
                            color: c.characterOn.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              color: c.characterOn.withValues(alpha: 0.18),
              indent: 18,
              endIndent: 18,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  children: [
                    _DrawerSectionLabel(c: c, label: l10n.drawerPagesSection),
                    DrawerItem(
                      c: c,
                      icon: Icons.chat_bubble_outline_rounded,
                      title: l10n.drawerChatTitle,
                      subtitle: l10n.drawerChatSubtitle,
                      active: route == AppRoute.chat,
                      onTap: () => onRoute(AppRoute.chat),
                    ),
                    DrawerItem(
                      c: c,
                      icon: Icons.bedtime_outlined,
                      title: l10n.drawerDreamTitle,
                      subtitle: l10n.drawerDreamSubtitle,
                      active: route == AppRoute.dream,
                      onTap: () => onRoute(AppRoute.dream),
                    ),
                    DrawerItem(
                      c: c,
                      icon: Icons.badge_outlined,
                      title: l10n.drawerProfileTitle,
                      subtitle: l10n.drawerProfileSubtitle,
                      active: route == AppRoute.profile,
                      onTap: () => onRoute(AppRoute.profile),
                    ),
                    DrawerItem(
                      c: c,
                      icon: Icons.menu_book_outlined,
                      title: l10n.drawerDiaryTitle(profileDisplayName),
                      subtitle: l10n.drawerDiarySubtitle,
                      active: route == AppRoute.diary,
                      onTap: () => onRoute(AppRoute.diary),
                    ),
                    DrawerItem(
                      c: c,
                      icon: Icons.sports_esports_outlined,
                      title: l10n.drawerActivityTitle,
                      subtitle: l10n.drawerActivitySubtitle,
                      active: route == AppRoute.activity,
                      onTap: () => onRoute(AppRoute.activity),
                    ),
                    DrawerItem(
                      c: c,
                      icon: Icons.groups_outlined,
                      title: l10n.drawerGroupTitle,
                      subtitle: l10n.drawerGroupSubtitle,
                      active: route == AppRoute.group,
                      onTap: () => onRoute(AppRoute.group),
                    ),
                    _DrawerSectionDivider(c: c),
                    _DrawerSectionLabel(c: c, label: l10n.drawerGrowthSection),
                    DrawerItem(
                      c: c,
                      icon: Icons.local_florist_outlined,
                      title: l10n.drawerGardenTitle,
                      subtitle: l10n.drawerGardenSubtitle,
                      active: route == AppRoute.garden,
                      onTap: () => onRoute(AppRoute.garden),
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              color: c.characterOn.withValues(alpha: 0.18),
              indent: 18,
              endIndent: 18,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
              child: Text(
                l10n.drawerSettingsTitle,
                style: mono(
                  c,
                  10,
                  color: c.characterOn.withValues(alpha: 0.55),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
              child: Column(
                children: [
                  DrawerItem(
                    c: c,
                    icon: Icons.settings_outlined,
                    title: l10n.drawerSettingsTitle,
                    subtitle: l10n.drawerSettingsSubtitle,
                    active: false,
                    onTap: onOpenSettings,
                  ),
                  const SizedBox(height: 6),
                  _DrawerVersion(c: c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerVersion extends StatelessWidget {
  const _DrawerVersion({required this.c});

  final YxPalette c;

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: PackageInfo.fromPlatform(),
    builder: (context, snapshot) {
      final packageInfo = snapshot.data;
      if (packageInfo == null) return const SizedBox.shrink();

      final buildNumber = packageInfo.buildNumber;
      final version = buildNumber.isEmpty
          ? packageInfo.version
          : '${packageInfo.version}+$buildNumber';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          context.l10n.drawerVersionLabel(version),
          style: mono(c, 9, color: c.characterOn.withValues(alpha: 0.45)),
        ),
      );
    },
  );
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel({required this.c, required this.label});

  final YxPalette c;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: mono(c, 10, color: c.characterOn.withValues(alpha: 0.55)),
      ),
    ),
  );
}

class _DrawerSectionDivider extends StatelessWidget {
  const _DrawerSectionDivider({required this.c});

  final YxPalette c;

  @override
  Widget build(BuildContext context) => Divider(
    color: c.characterOn.withValues(alpha: 0.18),
    indent: 12,
    endIndent: 12,
    height: 24,
  );
}

class DrawerItem extends StatelessWidget {
  const DrawerItem({
    super.key,
    required this.c,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  final YxPalette c;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: active
              ? c.characterOn.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active ? c.characterOn : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: c.characterOn.withValues(alpha: 0.75), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: serif(
                      c,
                      16,
                      color: c.characterOn,
                      weight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: mono(
                      c,
                      9.5,
                      color: c.characterOn.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            if (active)
              Text(
                context.l10n.drawerCurrent,
                style: mono(c, 9, color: c.characterOn.withValues(alpha: 0.7)),
              ),
          ],
        ),
      ),
    );
  }
}
