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
  });
  final DailyLayout daily;
  final DreamLayout dream;
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
      daily != oldWidget.daily || dream != oldWidget.dream;
}

YxPalette dailyLayoutPalette(DailyLayout layout, YxPalette base) =>
    layout == DailyLayout.letter
    ? base.copyWith(
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
      )
    : base;

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
                  icon: Icon(Icons.menu_rounded, color: c.ink2),
                  tooltip: l.drawerTooltip,
                ),
                Expanded(
                  child: Text(
                    name,
                    style: serif(c, 24, weight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onSettings,
                  icon: Icon(Icons.tune_rounded, color: c.ink2),
                  tooltip: l.drawerSettingsTitle,
                ),
              ],
            ),
          ),
          if (onRoute != null)
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
