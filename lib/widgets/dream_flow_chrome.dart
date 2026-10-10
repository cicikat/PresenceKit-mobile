import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../models/ui_layout.dart';
import 'common_widgets.dart';
import 'dream_flow_surface.dart';
import 'reference_typography.dart';

class DreamFlowHeader extends StatelessWidget {
  const DreamFlowHeader({
    super.key,
    required this.c,
    required this.name,
    required this.active,
    required this.onMenu,
    required this.onWake,
  });
  final YxPalette c;
  final String name;
  final bool active;
  final VoidCallback onMenu;
  final VoidCallback? onWake;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    child: Row(
      children: [
        IconButton(
          onPressed: onMenu,
          icon: Icon(Icons.menu_rounded, color: c.ink1),
          tooltip: context.l10n.drawerTooltip,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                context.l10n.dreamHeaderTitle(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: referenceUiText(c, 15),
              ),
              const SizedBox(height: 4),
              Text(
                active ? context.l10n.dreamInProgress : context.l10n.dreamReady,
                style: mono(c, 9, color: c.character),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onWake,
          child: Text(
            context.l10n.dreamWakeAction,
            style: mono(c, 11, color: c.character),
          ),
        ),
      ],
    ),
  );
}

class DreamFlowTitle extends StatelessWidget {
  const DreamFlowTitle({
    super.key,
    required this.c,
    required this.layout,
    this.scene,
  });
  final YxPalette c;
  final DreamLayout layout;
  final String? scene;
  @override
  Widget build(BuildContext context) {
    final orbit = layout == DreamLayout.orbit;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 24),
      child: Column(
        crossAxisAlignment: orbit
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            orbit
                ? context.l10n.dreamOrbitEyebrow
                : context.l10n.dreamTheatreEyebrow,
            style: mono(c, 9, color: c.character).copyWith(letterSpacing: 3),
          ),
          const SizedBox(height: 18),
          Text(
            orbit
                ? context.l10n.dreamOrbitTitle
                : context.l10n.dreamTheatreTitle,
            textAlign: orbit ? TextAlign.center : TextAlign.start,
            style: referenceSerif(c, orbit ? 30 : 38, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (scene != null && scene!.isNotEmpty)
            Text(scene!, style: referenceUiText(c, 12, color: c.ink2)),
          if (orbit) ...[
            const SizedBox(height: 20),
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.character.withValues(alpha: .45)),
              ),
              child: Center(
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 28,
                  color: c.character,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DreamFlowReply extends StatelessWidget {
  const DreamFlowReply({
    super.key,
    required this.c,
    required this.layout,
    required this.child,
    this.speaker,
    this.outgoing = false,
  });
  final YxPalette c;
  final DreamLayout layout;
  final String? speaker;
  final bool outgoing;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Align(
      alignment: layout == DreamLayout.orbit
          ? Alignment.center
          : outgoing
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: DreamFlowGlass(
          radius: layout == DreamLayout.orbit ? 28 : 14,
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (speaker != null) ...[
                Text(speaker!, style: mono(c, 9, color: c.character)),
                const SizedBox(height: 9),
              ],
              child,
            ],
          ),
        ),
      ),
    ),
  );
}
