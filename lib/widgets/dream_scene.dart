import '../models/ui_layout.dart';
import 'conversation_presentation.dart';
import 'moonlit_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/dream_controller.dart';
import '../models/app_models.dart';
import '../l10n/l10n.dart';
import 'chat_widgets.dart';
import 'dream_widgets.dart';
import 'common_widgets.dart';

class DreamPage extends StatelessWidget {
  const DreamPage({
    super.key,
    required this.c,
    this.layout = DreamLayout.classic,
    this.onRoute,
    required this.prefs,
    required this.profileDisplayName,
    required this.profileAvatarBytes,
    required this.controller,
    required this.onOpenDrawer,
    required this.onWake,
  });

  final ValueChanged<AppRoute>? onRoute;
  final DreamLayout layout;
  final YxPalette c;
  final YxPrefs prefs;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;
  final DreamController controller;
  final VoidCallback onOpenDrawer;
  final VoidCallback onWake;

  @override
  Widget build(BuildContext context) {
    return ConversationPresentation(
      dream: layout,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _build(context),
      ),
    );
  }

  Widget _build(BuildContext context) {
    final moonlit = layout == DreamLayout.moonlit;
    final state = controller.state;
    final stats = controller.stats;
    final loadingState = controller.loadingState;
    final entering = controller.entering;
    final sending = controller.sending;
    final error = controller.error;
    final messages = controller.messages;
    final scrollController = controller.scrollController;
    final active = state?.isActive == true;
    return Stack(
      children: [
        Column(
          children: [
            if (moonlit)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(profileDisplayName, style: serif(c, 18)),
                ),
              )
            else
              Container(
                color: c.characterDeep,
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                child: Row(
                  children: [
                    YxIconButton(
                      c: c,
                      icon: Icons.menu_rounded,
                      onPressed: onOpenDrawer,
                      onDark: true,
                      tooltip: context.l10n.drawerTooltip,
                    ),
                    const SizedBox(width: 8),
                    YxAvatar(
                      c: c,
                      onDark: true,
                      size: 34,
                      imageBytes: profileAvatarBytes,
                      text: profileDisplayName.characters.first,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.dreamHeaderTitle(profileDisplayName),
                            style: serif(
                              c,
                              18,
                              color: c.characterOn,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              LiveDot(color: active ? c.ok : c.ink4),
                              const SizedBox(width: 6),
                              Text(
                                active
                                    ? context.l10n.dreamInProgress
                                    : context.l10n.dreamReady,
                                style: mono(
                                  c,
                                  9.5,
                                  color: c.characterOn.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.transitioning || entering
                          ? null
                          : onWake,
                      icon: const Icon(Icons.wb_sunny_outlined, size: 15),
                      label: Text(context.l10n.dreamWakeAction),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.characterOn,
                        side: BorderSide(
                          color: c.characterOn.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (controller.transitionFailed)
              MetaLine(c: c, text: context.l10n.dreamTransitionFailed),
            Expanded(
              key: const ValueKey('dream-timeline'),
              child: active
                  ? ListView(
                      controller: scrollController,
                      padding: moonlit
                          ? const EdgeInsets.fromLTRB(24, 14, 65, 22)
                          : const EdgeInsets.fromLTRB(12, 14, 12, 22),
                      children: [
                        if (moonlit) MoonlitTitle(c: c),
                        if (!moonlit) DreamStateStrip(c: c, state: state!),
                        if (error != null)
                          MetaLine(
                            c: c,
                            text: context.l10n.dreamConnectionError(error),
                          ),
                        const SizedBox(height: 14),
                        for (final message in messages)
                          if (message.role == 'system')
                            DreamSceneLine(
                              key: ValueKey(message.id),
                              c: c,
                              text: message.text,
                            )
                          else if (message.role == 'you')
                            YouMessage(
                              key: ValueKey(message.id),
                              c: c,
                              time: '',
                              showHeader: false,
                              prefs: prefs.copyWith(
                                fontSize: prefs.dreamChatSize,
                                showChatTime: false,
                              ),
                              text: message.text,
                            )
                          else if (message.segments != null &&
                              message.segments!.isNotEmpty)
                            DreamSegmentedMessage(
                              key: ValueKey(message.id),
                              onRevealStarted: () =>
                                  controller.markRevealStarted(message),
                              onRevealSkipped: () =>
                                  controller.finishReveal(message.id),
                              c: c,
                              time: message.time,
                              prefs: prefs,
                              profileDisplayName: profileDisplayName,
                              profileAvatarBytes: profileAvatarBytes,
                              segments: message.segments!,
                              animate: message.animate,
                            )
                          else
                            DreamSegmentedMessage(
                              key: ValueKey(message.id),
                              onRevealStarted: () =>
                                  controller.markRevealStarted(message),
                              onRevealSkipped: () =>
                                  controller.finishReveal(message.id),
                              c: c,
                              time: message.time,
                              prefs: prefs,
                              profileDisplayName: profileDisplayName,
                              profileAvatarBytes: profileAvatarBytes,
                              segments: [
                                NarrativeSegment(
                                  type: 'say',
                                  text: message.text,
                                ),
                              ],
                              animate: message.animate,
                            ),
                        if (sending)
                          TypingHimMessage(
                            c: c,
                            time: '',
                            showHeader: false,
                            prefs: prefs,
                            profileDisplayName: profileDisplayName,
                            profileAvatarBytes: profileAvatarBytes,
                          ),
                      ],
                    )
                  : DreamEntrance(
                      c: c,
                      loading: loadingState,
                      entering: entering,
                      error: error,
                      stats: stats,
                      onEnter: controller.enter,
                    ),
            ),
            DreamComposer(
              key: const ValueKey('dream-composer'),
              c: c,
              sending: sending,
              prefs: prefs,
              enabled: active && !controller.transitioning,
              onSend: controller.send,
            ),
          ],
        ),
        if (moonlit)
          Positioned(
            right: 12,
            top: 160,
            child: MoonlitHeader(
              c: c,
              name: profileDisplayName,
              onMenu: onOpenDrawer,
              onRoute: onRoute,
              onWake: controller.transitioning || entering ? null : onWake,
            ),
          ),
      ],
    );
  }
}
