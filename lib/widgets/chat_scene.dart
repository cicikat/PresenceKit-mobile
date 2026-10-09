import 'reverie_scene.dart';
import '../models/ui_layout.dart';
import 'conversation_presentation.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/chat_controller.dart';
import '../controllers/voice_input_controller.dart';
import '../models/app_models.dart';
import '../l10n/l10n.dart';
import 'chat_widgets.dart';
import 'common_widgets.dart';
import 'edge_refresh.dart';
import 'reasoning_widgets.dart';
import 'tool_activity_widgets.dart';
import 'chat_artifact_widgets.dart';

class ChatScene extends StatelessWidget {
  const ChatScene({
    super.key,
    required this.c,
    this.layout = DailyLayout.classic,
    this.onRoute,
    required this.dark,
    required this.prefs,
    required this.profileDisplayName,
    required this.profileAvatarBytes,
    required this.controller,
    required this.onOpenDrawer,
    required this.onOpenSettings,
    required this.onOpenAttach,
    required this.onToggleTheme,
    required this.onLockNow,
    required this.onOpenOrderAccessibility,
    required this.onOpenMeituan,
    required this.onOpenTaobao,
    required this.onShowOrderBubble,
    required this.onVoiceRecordStart,
    required this.onVoiceRecordStop,
    required this.onVoiceRecordCancel,
  });

  final DailyLayout layout;
  final ValueChanged<AppRoute>? onRoute;
  final YxPalette c;
  final bool dark;
  final YxPrefs prefs;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;
  final ChatController controller;
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAttach;
  final VoidCallback onToggleTheme;
  final VoidCallback onLockNow;
  final VoidCallback onOpenOrderAccessibility;
  final VoidCallback onOpenMeituan;
  final VoidCallback onOpenTaobao;
  final VoidCallback onShowOrderBubble;
  final Future<String?> Function() onVoiceRecordStart;
  final Future<VoiceInputResult> Function() onVoiceRecordStop;
  final VoidCallback onVoiceRecordCancel;

  @override
  Widget build(BuildContext context) {
    return ConversationPresentation(
      daily: layout,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _build(context),
      ),
    );
  }

  Widget _build(BuildContext context) {
    final l10n = context.l10n;
    final backendBusy = controller.sending;
    final himTyping = controller.himTyping;
    final backendError = controller.backendError;
    final loadingHistory = controller.loadingHistory;
    final loadingMoreHistory = controller.loadingMoreHistory;
    final historyLoaded = controller.historyLoaded;
    final historyError = controller.historyError;
    final lastBackendReply = controller.lastBackendReply;
    final mobileReceivedCount = controller.mobileReceivedCount;
    final historyMessages = controller.history;
    final sentMessages = controller.sent;
    final visibleMessageLimit = controller.visibleMessageLimit;
    final scrollController = controller.scrollController;
    final showJumpToLatest = controller.showJumpToLatest;
    final unreadHimCount = controller.unreadHimCount;
    final presence = PresenceSnapshot.current(l10n);
    final totalMessageCount = historyMessages.length + sentMessages.length;
    final hiddenMessageCount = math.max(
      0,
      totalMessageCount - visibleMessageLimit,
    );
    final visibleMessageCount = totalMessageCount - hiddenMessageCount;
    final now = DateTime.now();
    final todayLine = l10n.chatTodayLine(
      MaterialLocalizations.of(context).formatFullDate(now),
      TimeOfDay.fromDateTime(now).format(context),
    );
    final topInset = MediaQuery.paddingOf(context).top;
    final classic = layout == DailyLayout.classic;
    final window = layout == DailyLayout.reverie || layout == DailyLayout.noir;
    final metaItems = <Widget>[
      if (window && onRoute != null)
        ReveriePortal(c: c, onOpen: () => onRoute!(AppRoute.dream)),
      if (loadingMoreHistory) MetaLine(c: c, text: l10n.chatLoadingOlder),
      if (hiddenMessageCount > 0)
        MetaLine(c: c, text: l10n.chatHiddenOlder(hiddenMessageCount)),
      if (classic) MetaLine(c: c, text: todayLine),
      if (loadingHistory) MetaLine(c: c, text: l10n.chatLoadingHistory),
      if (historyLoaded && historyMessages.isEmpty)
        MetaLine(c: c, text: l10n.chatEmptyHistory),
      if (historyError != null)
        MetaLine(
          c: c,
          text: l10n.chatHistoryError(
            localizeSessionScopeError(l10n, historyError),
          ),
        ),
      if (backendBusy) MetaLine(c: c, text: l10n.chatWaitingReply),
      if (backendError != null)
        MetaLine(
          c: c,
          text: l10n.chatBackendError(
            localizeSessionScopeError(l10n, backendError),
          ),
        ),
      if (controller.mobileError != null)
        MetaLine(c: c, text: l10n.chatBackendError(controller.mobileError!)),
      if (classic && lastBackendReply != null && backendError == null)
        MetaLine(c: c, text: l10n.chatBackendStatus(lastBackendReply.emotion)),
      if (classic && mobileReceivedCount > 0)
        MetaLine(c: c, text: l10n.chatMobileReceived(mobileReceivedCount)),
      const SizedBox(height: 14),
    ];
    final itemCount =
        metaItems.length + visibleMessageCount + (himTyping ? 1 : 0);
    return Stack(
      children: [
        Column(
          children: [
            if (!classic)
              ConversationHeader(
                c: c,
                name: profileDisplayName,
                layout: layout,
                onMenu: onOpenDrawer,
                onSettings: onOpenSettings,
                onRoute: onRoute,
              )
            else if (prefs.infoStrip)
              ChatTopBar(
                c: dark
                    ? c.copyWith(
                        characterDeep: const Color(0xFF090A09),
                        characterOn: const Color(0xFFF0E9DD),
                      )
                    : c,
                dark: dark,
                presence: presence,
                prefs: prefs,
                profileDisplayName: profileDisplayName,
                profileAvatarBytes: profileAvatarBytes,
                onToggleTheme: onToggleTheme,
                onOpenDrawer: onOpenDrawer,
                onOpenSettings: onOpenSettings,
              ),
            Expanded(
              key: const ValueKey('daily-timeline'),
              child: EdgeRefresh(
                onRefresh: () async {
                  await controller.refreshConnection();
                  if (!context.mounted) return;
                  final error =
                      controller.mobileError ?? controller.historyError;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error != null
                            ? l10n.chatBackendError(error)
                            : controller.mobileActive
                            ? l10n.chatRefreshComplete
                            : l10n.chatRefreshUnavailable,
                      ),
                    ),
                  );
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  controller: scrollController,
                  cacheExtent: 720,
                  padding: EdgeInsets.fromLTRB(
                    classic
                        ? 12
                        : window
                        ? 18
                        : 24,
                    !classic || prefs.infoStrip ? 14 : topInset + 58,
                    classic
                        ? 12
                        : window
                        ? 18
                        : 24,
                    92,
                  ),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index < metaItems.length) return metaItems[index];
                    final messageIndex = index - metaItems.length;
                    if (messageIndex >= visibleMessageCount) {
                      return TypingHimMessage(
                        c: c,
                        time: l10n.chatTyping,
                        prefs: prefs,
                        profileDisplayName: profileDisplayName,
                        profileAvatarBytes: profileAvatarBytes,
                      );
                    }
                    final globalMessageIndex =
                        hiddenMessageCount + messageIndex;
                    final m = globalMessageIndex < historyMessages.length
                        ? historyMessages[globalMessageIndex]
                        : sentMessages[globalMessageIndex -
                              historyMessages.length];
                    final previous = globalMessageIndex > 0
                        ? (globalMessageIndex - 1 < historyMessages.length
                              ? historyMessages[globalMessageIndex - 1]
                              : sentMessages[globalMessageIndex -
                                    1 -
                                    historyMessages.length])
                        : null;
                    final showDateDivider =
                        m.dateKey != null && m.dateKey != previous?.dateKey;
                    if (m.role == 'tool') {
                      if (!prefs.showToolActivity || m.toolActivity == null) {
                        return const SizedBox.shrink();
                      }
                      final nextIndex = globalMessageIndex + 1;
                      final next = nextIndex < historyMessages.length
                          ? historyMessages[nextIndex]
                          : nextIndex < totalMessageCount
                          ? sentMessages[nextIndex - historyMessages.length]
                          : null;
                      return ToolActivityRow(
                        key: ValueKey('tool-${m.toolActivity!.eventId}'),
                        c: c,
                        activity: m.toolActivity!,
                        connectBefore: m.toolActivity!.sameChain(
                          previous?.toolActivity,
                        ),
                        connectAfter: m.toolActivity!.sameChain(
                          next?.toolActivity,
                        ),
                      );
                    }
                    if (m.role == 'narration') {
                      return prefs.showToolActivity
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 3,
                              ),
                              child: Text(
                                m.text,
                                textAlign: TextAlign.center,
                                style: mono(c, 9.5, color: c.ink2),
                              ),
                            )
                          : const SizedBox.shrink();
                    }
                    if (m.role == 'reasoning') {
                      if (!prefs.showReasoning) return const SizedBox.shrink();
                      return ReasoningPanel(
                        key: ValueKey('reasoning-${m.id}'),
                        c: c,
                        turnId: m.text,
                        unavailable: m.failed,
                        name: profileDisplayName,
                        initiallyExpanded: prefs.expandReasoning,
                        opacity: prefs.reasoningOpacity,
                        load: controller.loadReasoning,
                      );
                    }
                    if (m.role == 'him' &&
                        m.artifacts.isNotEmpty &&
                        m.text.isEmpty &&
                        m.sticker == null) {
                      return ArtifactMessage(
                        key: ValueKey('chat-${m.id}'),
                        c: c,
                        artifacts: m.artifacts,
                        fetch: controller.fetchArtifactBytes,
                        bubbleOpacity: prefs.chatBubbleOpacity,
                      );
                    }
                    return RepaintBoundary(
                      key: ValueKey('chat-${m.id}'),
                      child: m.role == 'you'
                          ? YouMessage(
                              c: c,
                              time: m.time,
                              prefs: prefs,
                              text: m.text,
                              attachments: m.attachments,
                              mediaRefs: m.mediaRefs,
                              loadCanonicalMedia: controller.loadCanonicalMedia,
                              uploadNote: m.uploadNote,
                              quotedText: m.quotedText,
                              failed: m.failed,
                              uncertain: m.uncertain,
                              onRetry: () => controller.retryMessage(m),
                              onReply: () => controller.setReplyTarget(m),
                              showDateDivider: showDateDivider,
                              dateKey: m.dateKey,
                            )
                          : HimMessage(
                              c: c,
                              time: m.time,
                              prefs: prefs,
                              profileDisplayName: profileDisplayName,
                              profileAvatarBytes: profileAvatarBytes,
                              text: m.text,
                              displayText: m.displayText,
                              quotedText: m.quotedText,
                              showDateDivider: showDateDivider,
                              dateKey: m.dateKey,
                              onReply: () => controller.setReplyTarget(m),
                              sticker: m.sticker,
                              animate: m.animate,
                              onRevealStarted: m.animate
                                  ? () => controller.markRevealStarted(m)
                                  : null,
                              onRevealSkipped: m.animate
                                  ? controller.skipReveal
                                  : null,
                            ),
                    );
                  },
                ),
              ),
            ),
            if (controller.replyTarget != null)
              ReplyPreviewBar(
                c: c,
                text: controller.replyTarget!.text,
                label: l10n.chatReplyTo(
                  controller.replyTarget!.role == 'you'
                      ? l10n.chatRoleYou
                      : profileDisplayName,
                ),
                onCancel: controller.clearReplyTarget,
              ),
            Composer(
              key: const ValueKey('daily-composer'),
              c: c,
              bubbleOpacity: prefs.chatBubbleOpacity,
              fontSize: prefs.fontSize,
              sending: backendBusy,
              onOpenAttach: onOpenAttach,
              onSend: controller.send,
              onVoiceRecordStart: onVoiceRecordStart,
              onVoiceRecordStop: onVoiceRecordStop,
              onVoiceRecordCancel: onVoiceRecordCancel,
            ),
          ],
        ),
        if (classic && !prefs.infoStrip)
          Positioned(
            top: topInset + 10,
            left: 12,
            child: FloatingDrawerButton(c: c, onOpenDrawer: onOpenDrawer),
          ),
        if (showJumpToLatest)
          Positioned(
            left: 0,
            right: 0,
            bottom: 92,
            child: Center(
              child: JumpToLatestButton(
                c: c,
                unreadCount: unreadHimCount,
                onPressed: controller.scrollToBottom,
              ),
            ),
          ),
      ],
    );
  }
}
