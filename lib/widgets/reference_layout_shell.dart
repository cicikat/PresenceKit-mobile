import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../models/ui_layout.dart';
import 'common_widgets.dart';
import 'conversation_presentation.dart';

bool hasReferenceShell(DailyLayout layout) =>
    layout == DailyLayout.letter ||
    layout == DailyLayout.reverie ||
    layout == DailyLayout.noir;

class ReferenceLayoutShell extends StatelessWidget {
  const ReferenceLayoutShell({
    super.key,
    required this.layout,
    required this.route,
    required this.c,
    required this.name,
    required this.onRoute,
    required this.onMenu,
    required this.onSettings,
    required this.child,
  });
  final DailyLayout layout;
  final AppRoute route;
  final YxPalette c;
  final String name;
  final ValueChanged<AppRoute> onRoute;
  final VoidCallback onMenu;
  final VoidCallback onSettings;
  final Widget child;
  @override
  Widget build(BuildContext context) => ConversationPresentation(
    daily: layout,
    child: Column(
      children: [
        if (hasReferenceShell(layout) && route != AppRoute.dream)
          ReferenceHeader(
            c: c,
            layout: layout,
            route: route,
            name: name,
            onRoute: onRoute,
            onMenu: onMenu,
            onSettings: onSettings,
          ),
        Expanded(child: child),
      ],
    ),
  );
}

class ReferenceHeader extends StatelessWidget {
  const ReferenceHeader({
    super.key,
    required this.c,
    required this.layout,
    required this.route,
    required this.name,
    required this.onRoute,
    required this.onMenu,
    required this.onSettings,
  });
  final YxPalette c;
  final DailyLayout layout;
  final AppRoute route;
  final String name;
  final ValueChanged<AppRoute> onRoute;
  final VoidCallback onMenu;
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final paper = layout == DailyLayout.letter;
    final tabs = [
      (AppRoute.chat, l.referenceChatTab, Icons.favorite_border),
      (
        AppRoute.diary,
        paper ? l.diaryTitle : l.referenceDiaryTab,
        Icons.menu_book_outlined,
      ),
      (
        AppRoute.garden,
        paper ? l.gardenShortTitle : l.referenceGardenTab,
        Icons.local_florist_outlined,
      ),
    ];
    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              paper ? 23 : 20,
              paper ? 20 : 12,
              20,
              paper ? 14 : 15,
            ),
            child: Row(
              children: [
                if (!paper)
                  IconButton(
                    onPressed: onMenu,
                    tooltip: l.layoutMenu,
                    icon: Icon(
                      Icons.auto_awesome_outlined,
                      color: c.character,
                      size: 26,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paper
                            ? l.referencePaperBrand
                            : layout == DailyLayout.noir
                            ? 'after.you'
                            : 'dear.you',
                        style:
                            serif(
                              c,
                              25,
                              color: paper
                                  ? c.ink1
                                  : layout == DailyLayout.noir
                                  ? c.ink1
                                  : c.character,
                            ).copyWith(
                              fontFamily: AppTypography.family ?? 'serif',
                              fontStyle: paper
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                              letterSpacing: paper ? 3 : -1,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        paper
                            ? l.referencePaperSubtitle
                            : l.referenceWindowSubtitle,
                        style: serif(
                          c,
                          paper ? 11 : 8,
                          color: c.ink3,
                        ).copyWith(letterSpacing: paper ? 1 : 1.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => onRoute(AppRoute.dream),
                  tooltip: l.drawerDreamTitle,
                  icon: Icon(
                    paper ? Icons.bedtime_outlined : Icons.favorite,
                    color: c.character,
                    size: paper ? 22 : 17,
                  ),
                ),
                if (paper)
                  IconButton(
                    onPressed: onMenu,
                    tooltip: l.layoutMenu,
                    icon: Icon(Icons.more_horiz, color: c.ink2, size: 20),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.surfaceEdge)),
              ),
              child: Row(
                children: [
                  for (final item in tabs)
                    Expanded(
                      child: _tab(
                        context,
                        item.$2,
                        item.$3,
                        route == item.$1,
                        () => onRoute(item.$1),
                        paper,
                      ),
                    ),
                  if (paper)
                    Expanded(
                      child: _tab(
                        context,
                        l.drawerSettingsTitle,
                        Icons.tune,
                        false,
                        onSettings,
                        true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
    bool paper,
  ) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: paper
          ? null
          : const BorderRadius.vertical(top: Radius.circular(8)),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: paper ? 12 : 10, horizontal: 3),
        decoration: BoxDecoration(
          color: !paper && selected ? c.surfaceSoft : null,
          borderRadius: paper
              ? null
              : const BorderRadius.vertical(top: Radius.circular(8)),
          border: paper
              ? Border(
                  bottom: BorderSide(
                    color: selected ? c.character : Colors.transparent,
                    width: 2,
                  ),
                )
              : Border.all(color: selected ? c.surfaceEdge : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!paper) ...[
              Icon(icon, size: 11, color: selected ? c.character : c.ink3),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: serif(
                  c,
                  paper ? 11 : 10,
                  color: selected ? c.character : c.ink2,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
