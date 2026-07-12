part of '../main.dart';

class YxDrawer extends StatelessWidget {
  const YxDrawer({
    super.key,
    required this.c,
    required this.route,
    required this.profileDisplayName,
    required this.profileAvatarBytes,
    required this.onRoute,
    required this.onOpenSystemSettings,
    required this.onOpenSettings,
  });

  final YxPalette c;
  final AppRoute route;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;
  final ValueChanged<AppRoute> onRoute;
  final VoidCallback onOpenSystemSettings;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
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
                          '手机薄客户端 · 本机显示',
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
                    DrawerItem(
                      c: c,
                      icon: Icons.chat_bubble_outline_rounded,
                      title: '主对话',
                      subtitle: '聊天窗口',
                      active: route == AppRoute.chat,
                      onTap: () => onRoute(AppRoute.chat),
                    ),
                    DrawerItem(
                      c: c,
                      icon: Icons.bedtime_outlined,
                      title: '梦境',
                      subtitle: '独立的 Dream 对话',
                      active: route == AppRoute.dream,
                      onTap: () => onRoute(AppRoute.dream),
                    ),
                    DrawerItem(
                      c: c,
                      icon: Icons.badge_outlined,
                      title: '角色资料',
                      subtitle: '本机备注和头像',
                      active: route == AppRoute.profile,
                      onTap: () => onRoute(AppRoute.profile),
                    ),
                    DrawerItem(
                      c: c,
                      icon: Icons.local_florist_outlined,
                      title: '状态花园',
                      subtitle: '他今天的心境',
                      active: route == AppRoute.garden,
                      onTap: () => onRoute(AppRoute.garden),
                    ),
                    DrawerItem(
                      c: c,
                      icon: Icons.menu_book_outlined,
                      title: '$profileDisplayName的日记',
                      subtitle: '他写给自己的',
                      active: route == AppRoute.diary,
                      onTap: () => onRoute(AppRoute.diary),
                    ),
                    DrawerItem(
                      c: c,
                      icon: Icons.sports_esports_outlined,
                      title: '活动',
                      subtitle: '看书 / 五子棋 / 国际象棋 / 梦境预构',
                      active: route == AppRoute.activity,
                      onTap: () => onRoute(AppRoute.activity),
                    ),
                    DrawerItem(
                      c: c,
                      icon: Icons.groups_outlined,
                      title: '群聊',
                      subtitle: '多角色一起聊',
                      active: route == AppRoute.group,
                      onTap: () => onRoute(AppRoute.group),
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
                '本机设置',
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
                    title: '系统设置',
                    subtitle: 'Token / 后端 / 权限与通知',
                    active: false,
                    onTap: onOpenSystemSettings,
                  ),
                  DrawerItem(
                    c: c,
                    icon: Icons.tune_rounded,
                    title: '偏好',
                    subtitle: '主题 / 字号 / 主动频率',
                    active: false,
                    onTap: onOpenSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                '当前',
                style: mono(c, 9, color: c.characterOn.withValues(alpha: 0.7)),
              ),
          ],
        ),
      ),
    );
  }
}
