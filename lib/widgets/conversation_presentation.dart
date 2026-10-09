import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../models/ui_layout.dart';
import '../l10n/l10n.dart';
import 'common_widgets.dart';

class ConversationPresentation extends InheritedWidget {
  const ConversationPresentation({
    super.key,
    required super.child,
    this.daily = DailyLayout.classic,
    this.dream = DreamLayout.classic,
    this.userName = '',
    this.userAvatar,
  });
  final String userName;
  final Uint8List? userAvatar;
  final DailyLayout daily;
  final DreamLayout dream;
  static ConversationPresentation? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ConversationPresentation>();
  static DailyLayout dailyOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ConversationPresentation>()
          ?.daily ??
      DailyLayout.classic;
  static DreamLayout dreamOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ConversationPresentation>()
          ?.dream ??
      DreamLayout.classic;
  @override
  bool updateShouldNotify(ConversationPresentation oldWidget) =>
      daily != oldWidget.daily ||
      dream != oldWidget.dream ||
      userName != oldWidget.userName ||
      userAvatar != oldWidget.userAvatar;
}

YxPalette dailyLayoutPalette(DailyLayout layout, YxPalette base) {
  if (layout == DailyLayout.letter && base.surface.computeLuminance() > .2) {
    return base.copyWith(
      surface: const Color(0xFFF7F4EB),
      surfaceSoft: const Color(0xFFFCF9F0),
      surfaceDeep: const Color(0xFFECE7D9),
      surfaceEdge: const Color(0xFFD7D8C8),
      ink1: const Color(0xFF343D30),
      ink2: const Color(0xFF5C6653),
      ink3: const Color(0xFF737F66),
      ink4: const Color(0xFF9AA38D),
      character: const Color(0xFF64734D),
      characterDeep: const Color(0xFF46543A),
      characterOn: const Color(0xFFFCFAF3),
      send: const Color(0xFF64734D),
      userBubble: const Color(0xFFE7E9D9),
      userBubbleText: const Color(0xFF343D30),
    );
  }
  if (layout == DailyLayout.noir ||
      (layout == DailyLayout.reverie && base.surface.computeLuminance() < .2)) {
    return base.copyWith(
      surface: const Color(0xFF101116),
      surfaceSoft: const Color(0xFF202128),
      surfaceDeep: const Color(0xFF18191F),
      surfaceEdge: const Color(0xFF3D3542),
      ink1: const Color(0xFFE7E7EE),
      ink2: const Color(0xFFCCCCD6),
      ink3: const Color(0xFFA7A4B5),
      ink4: const Color(0xFF797685),
      character: const Color(0xFFFF4F9B),
      characterDeep: const Color(0xFF34212D),
      characterSoft: const Color(0xFF352731),
      characterOn: const Color(0xFFE7E7EE),
      send: const Color(0xFFFF4F9B),
      userBubble: const Color(0xFF392837),
      userBubbleText: const Color(0xFFE7E7EE),
    );
  }
  if (layout == DailyLayout.reverie) {
    return base.copyWith(
      surface: const Color(0xFFFBF0F5),
      surfaceSoft: const Color(0xFFFFFAFD),
      surfaceDeep: const Color(0xFFF1E2EC),
      surfaceEdge: const Color(0xFFDECBD9),
      ink1: const Color(0xFF574652),
      ink2: const Color(0xFF796270),
      ink3: const Color(0xFF92788B),
      ink4: const Color(0xFFAE94A4),
      character: const Color(0xFFAD658C),
      characterDeep: const Color(0xFF85516F),
      characterSoft: const Color(0xFFEBDCE7),
      characterOn: const Color(0xFFFFFAFD),
      send: const Color(0xFFAD658C),
      userBubble: const Color(0xFFEEDDE9),
      userBubbleText: const Color(0xFF574652),
    );
  }
  if (layout == DailyLayout.messenger) {
    final dark = base.surface.computeLuminance() < .2;
    return base.copyWith(
      surface: Color(dark ? 0xFF111111 : 0xFFEDEDED),
      surfaceSoft: Color(dark ? 0xFF252525 : 0xFFFFFFFF),
      surfaceDeep: Color(dark ? 0xFF191919 : 0xFFE7E7E7),
      surfaceEdge: Color(dark ? 0xFF383838 : 0xFFDADADA),
      ink1: Color(dark ? 0xFFEDEDED : 0xFF191919),
      ink2: Color(dark ? 0xFFBBBBBB : 0xFF555555),
      ink3: Color(dark ? 0xFF999999 : 0xFF767676),
      character: const Color(0xFF278B47),
      send: const Color(0xFF278B47),
      characterDeep: Color(dark ? 0xFF252525 : 0xFFEDEDED),
      characterOn: Color(dark ? 0xFFEDEDED : 0xFF191919),
      userBubble: Color(dark ? 0xFF65AA49 : 0xFF95EC69),
      userBubbleText: const Color(0xFF13210D),
    );
  }
  return base;
}

class ConversationHeader extends StatelessWidget {
  const ConversationHeader({
    super.key,
    required this.c,
    required this.name,
    required this.layout,
    required this.onMenu,
    required this.onSettings,
    this.onRoute,
  });
  final YxPalette c;
  final String name;
  final DailyLayout layout;
  final VoidCallback onMenu;
  final VoidCallback onSettings;
  final ValueChanged<AppRoute>? onRoute;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final messenger = layout == DailyLayout.messenger;
    final window = layout == DailyLayout.reverie || layout == DailyLayout.noir;
    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: onMenu,
                  icon: Icon(
                    messenger
                        ? Icons.chevron_left
                        : window
                        ? Icons.auto_awesome_outlined
                        : Icons.menu_rounded,
                    color: c.character,
                  ),
                  tooltip: l.drawerTooltip,
                ),
                Expanded(
                  child: Text(
                    name,
                    textAlign: messenger ? TextAlign.center : TextAlign.start,
                    style:
                        serif(
                          c,
                          messenger
                              ? 18
                              : window
                              ? 28
                              : 24,
                          weight: FontWeight.w500,
                        ).copyWith(
                          fontStyle: window
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: messenger ? onMenu : onSettings,
                  icon: Icon(
                    messenger ? Icons.more_horiz : Icons.tune_rounded,
                    color: c.ink2,
                  ),
                  tooltip: l.drawerSettingsTitle,
                ),
              ],
            ),
          ),
          if (onRoute != null && !messenger)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _tab(l.drawerChatTitle, AppRoute.chat, true),
                  _tab(l.drawerDiaryTitle(name), AppRoute.diary, false),
                  _tab(l.drawerGardenTitle, AppRoute.garden, false),
                  _tab(l.drawerDreamTitle, AppRoute.dream, false),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Divider(height: 1, color: c.surfaceEdge),
        ],
      ),
    );
  }

  Widget _tab(String title, AppRoute route, bool selected) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: TextButton(
      onPressed: () => onRoute!(route),
      style: TextButton.styleFrom(
        foregroundColor: selected ? c.character : c.ink2,
        shape: const RoundedRectangleBorder(),
        side: selected ? BorderSide(color: c.character) : BorderSide.none,
      ),
      child: Text(title),
    ),
  );
}
