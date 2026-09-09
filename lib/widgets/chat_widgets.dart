import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/chat_controller.dart';
import '../controllers/voice_input_controller.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../services/character_naming.dart';
import '../widgets/common_widgets.dart';

class ChatScene extends StatelessWidget {
  const ChatScene({
    super.key,
    required this.c,
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
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _build(context),
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
    final metaItems = <Widget>[
      if (loadingMoreHistory) MetaLine(c: c, text: l10n.chatLoadingOlder),
      if (hiddenMessageCount > 0)
        MetaLine(c: c, text: l10n.chatHiddenOlder(hiddenMessageCount)),
      MetaLine(c: c, text: todayLine),
      if (loadingHistory) MetaLine(c: c, text: l10n.chatLoadingHistory),
      if (historyLoaded && historyMessages.isEmpty)
        MetaLine(c: c, text: l10n.chatEmptyHistory),
      if (historyError != null)
        MetaLine(c: c, text: l10n.chatHistoryError(historyError)),
      if (backendBusy) MetaLine(c: c, text: l10n.chatWaitingReply),
      if (backendError != null)
        MetaLine(c: c, text: l10n.chatBackendError(backendError)),
      if (lastBackendReply != null && backendError == null)
        MetaLine(c: c, text: l10n.chatBackendStatus(lastBackendReply.emotion)),
      if (mobileReceivedCount > 0)
        MetaLine(c: c, text: l10n.chatMobileReceived(mobileReceivedCount)),
      const SizedBox(height: 14),
    ];
    final itemCount =
        metaItems.length + visibleMessageCount + (himTyping ? 1 : 0);
    return Stack(
      children: [
        if (prefs.chatBackground != null)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: prefs.chatBackgroundBlur,
                sigmaY: prefs.chatBackgroundBlur,
              ),
              child: Image.memory(
                prefs.chatBackground!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        Column(
          children: [
            if (prefs.infoStrip)
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
              child: ListView.builder(
                controller: scrollController,
                cacheExtent: 720,
                padding: EdgeInsets.fromLTRB(
                  12,
                  prefs.infoStrip ? 14 : topInset + 58,
                  12,
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
                  final globalMessageIndex = hiddenMessageCount + messageIndex;
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
                  return RepaintBoundary(
                    key: ValueKey('chat-${m.id}'),
                    child: m.role == 'you'
                        ? YouMessage(
                            c: c,
                            time: m.time,
                            prefs: prefs,
                            text: m.text,
                            quotedText: m.quotedText,
                            failed: m.failed,
                            onRetry: () => controller.retryMessage(m),
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
        if (!prefs.infoStrip)
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

class JumpToLatestButton extends StatelessWidget {
  const JumpToLatestButton({
    super.key,
    required this.c,
    required this.onPressed,
    this.unreadCount = 0,
  });

  final YxPalette c;
  final VoidCallback onPressed;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: c.characterDeep,
            shape: BoxShape.circle,
            border: Border.all(color: c.characterOn.withValues(alpha: 0.38)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Center(
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: c.characterOn, size: 24),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -18,
                  top: -12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.warn,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: mono(
                        c,
                        9,
                        color: c.characterOn,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatTopBar extends StatelessWidget {
  const ChatTopBar({
    super.key,
    required this.c,
    required this.dark,
    required this.presence,
    required this.prefs,
    required this.profileDisplayName,
    required this.profileAvatarBytes,
    required this.onToggleTheme,
    required this.onOpenDrawer,
    required this.onOpenSettings,
  });

  final YxPalette c;
  final bool dark;
  final PresenceSnapshot presence;
  final YxPrefs prefs;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: c.characterDeep,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        children: [
          Row(
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
                size: 32,
                imageBytes: profileAvatarBytes,
                text: profileDisplayName.characters.first,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profileDisplayName,
                      style: serif(
                        c,
                        18,
                        color: c.characterOn,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        LiveDot(color: presence.dotColor ?? c.characterOn),
                        const SizedBox(width: 6),
                        Text(
                          presence.status,
                          style: mono(
                            c,
                            10,
                            color: c.characterOn.withValues(alpha: 0.78),
                          ),
                        ),
                        Text(
                          ' · ',
                          style: mono(
                            c,
                            10,
                            color: c.characterOn.withValues(alpha: 0.5),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            presence.subline,
                            overflow: TextOverflow.ellipsis,
                            style: mono(
                              c,
                              10,
                              color: c.characterOn.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              YxIconButton(
                c: c,
                icon: Icons.tune_rounded,
                onPressed: onOpenSettings,
                onDark: true,
                tooltip: context.l10n.preferencesTooltip,
              ),
              const SizedBox(width: 6),
              YxIconButton(
                c: c,
                icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                onPressed: onToggleTheme,
                onDark: true,
                tooltip: dark
                    ? context.l10n.switchToLightTooltip
                    : context.l10n.switchToDarkTooltip,
              ),
            ],
          ),
          if (prefs.infoStrip) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  YxTag(c: c, text: presence.mood, variant: 'solid'),
                  YxTag(c: c, text: presence.activity, variant: 'warm'),
                  YxTag(c: c, text: presence.timeband),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FloatingDrawerButton extends StatelessWidget {
  const FloatingDrawerButton({
    super.key,
    required this.c,
    required this.onOpenDrawer,
  });

  final YxPalette c;
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceSoft.withValues(alpha: 0.94),
        border: Border.all(color: c.surfaceEdge),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: c.scrim.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: YxIconButton(
        c: c,
        icon: Icons.menu_rounded,
        onPressed: onOpenDrawer,
        tooltip: context.l10n.drawerTooltip,
      ),
    );
  }
}

class MetaLine extends StatelessWidget {
  const MetaLine({super.key, required this.c, required this.text});

  final YxPalette c;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: c.ink4, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: mono(c, 11, color: c.ink3),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

enum ChatBubbleAction { copy, selectAll, reply }

/// 长按气泡弹出的复制/全选/回复菜单；回复仅对角色气泡传 [showReply]=true。
Future<ChatBubbleAction?> showChatBubbleMenu({
  required BuildContext context,
  required Offset position,
  required bool showReply,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return showMenu<ChatBubbleAction>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem(
        value: ChatBubbleAction.copy,
        child: Text(context.l10n.copyAction),
      ),
      PopupMenuItem(
        value: ChatBubbleAction.selectAll,
        child: Text(context.l10n.selectAllAction),
      ),
      if (showReply)
        PopupMenuItem(
          value: ChatBubbleAction.reply,
          child: Text(context.l10n.replyAction),
        ),
    ],
  );
}

class ReplyPreviewBar extends StatelessWidget {
  const ReplyPreviewBar({
    super.key,
    required this.c,
    required this.text,
    required this.label,
    required this.onCancel,
  });

  final YxPalette c;
  final String text;
  final String label;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: c.surfaceSoft,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(left: BorderSide(color: c.character, width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: mono(c, 9.5, color: c.character)),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(c, 11, color: c.ink3),
                  ),
                ],
              ),
            ),
            YxIconButton(
              c: c,
              icon: Icons.close_rounded,
              size: 26,
              onPressed: onCancel,
              tooltip: context.l10n.cancelReplyTooltip,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteBar extends StatelessWidget {
  const _QuoteBar({required this.c, required this.text, this.dark = false});
  final YxPalette c;
  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.only(left: 7),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: dark ? c.characterOn : c.character, width: 2),
      ),
    ),
    child: Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: mono(
        c,
        10,
        color: dark ? c.userBubbleText.withValues(alpha: .7) : c.ink3,
      ),
    ),
  );
}

class _ChatDateDivider extends StatelessWidget {
  const _ChatDateDivider({
    required this.c,
    required this.dateKey,
    required this.role,
  });
  final YxPalette c;
  final String dateKey;
  final String role;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(dateKey);
    final now = DateTime.now();
    final label = parsed == null
        ? dateKey
        : (parsed.year == now.year &&
                  parsed.month == now.month &&
                  parsed.day == now.day
              ? context.l10n.chatTodayDivider
              : (parsed.year == now.year &&
                        parsed.month == now.month &&
                        parsed.day == now.day - 1
                    ? context.l10n.chatYesterdayDivider
                    : dateKey));
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 5),
      child: Center(
        child: Text(label, style: mono(c, 9.5, color: c.ink3)),
      ),
    );
  }
}

class HimMessage extends StatefulWidget {
  const HimMessage({
    super.key,
    required this.c,
    required this.time,
    required this.text,
    required this.prefs,
    this.sticker,
    this.profileDisplayName = kFallbackCharacterDisplayName,
    this.profileAvatarBytes,
    this.tag,
    this.tagVariant = 'solid',
    this.highlight = false,
    this.animate = false,
    this.onRevealStarted,
    this.onRevealSkipped,
    this.onReply,
    this.quotedText,
    this.showDateDivider = false,
    this.dateKey,
  });

  final YxPalette c;
  final String time;
  final String text;
  final StickerPayload? sticker;
  final String? tag;
  final String tagVariant;
  final bool highlight;
  final YxPrefs prefs;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;
  final bool animate;
  final VoidCallback? onRevealStarted;
  final VoidCallback? onRevealSkipped;

  /// 长按菜单「回复」;仅角色气泡传入,气泡分段场景下引用目标是这一段本身。
  final VoidCallback? onReply;
  final String? quotedText;
  final bool showDateDivider;
  final String? dateKey;

  @override
  State<HimMessage> createState() => _HimMessageState();
}

class _HimMessageState extends State<HimMessage> {
  bool _selectable = false;

  Future<void> _handleLongPress(Offset globalPosition) async {
    final action = await showChatBubbleMenu(
      context: context,
      position: globalPosition,
      showReply: widget.onReply != null,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ChatBubbleAction.copy:
        await Clipboard.setData(ClipboardData(text: widget.text));
        break;
      case ChatBubbleAction.selectAll:
        setState(() => _selectable = true);
        break;
      case ChatBubbleAction.reply:
        widget.onReply?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: YxAvatar(
              c: c,
              size: 28,
              imageBytes: widget.profileAvatarBytes,
              text: widget.profileDisplayName.characters.first,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showDateDivider && widget.dateKey != null)
                  _ChatDateDivider(
                    c: c,
                    dateKey: widget.dateKey!,
                    role: context.l10n.chatRoleHim,
                  ),
                Row(
                  children: [
                    Text(
                      '${context.l10n.chatRoleHim}  ${widget.time}',
                      style: mono(c, 9.5, color: c.ink3),
                    ),
                    if (widget.tag != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: YxTag(
                          c: c,
                          text: widget.tag!,
                          variant: widget.tagVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onLongPressStart: widget.sticker == null
                      ? (details) =>
                            unawaited(_handleLongPress(details.globalPosition))
                      : null,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                    decoration: BoxDecoration(
                      color: c.surfaceSoft.withValues(
                        alpha: widget.prefs.chatBubbleOpacity,
                      ),
                      border: Border.all(
                        color: widget.highlight ? c.warn : c.surfaceEdge,
                        width: widget.highlight ? 2 : 1,
                      ),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                        bottomLeft: Radius.circular(0),
                        topLeft: Radius.circular(0),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.only(left: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: c.character, width: 3),
                        ),
                      ),
                      child: widget.sticker != null
                          ? StickerImage(sticker: widget.sticker!)
                          : _selectable
                          ? SelectableText(
                              widget.text,
                              style: serif(c, widget.prefs.fontSize),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.quotedText != null)
                                  _QuoteBar(c: c, text: widget.quotedText!),
                                AnimatedRevealText(
                                  text: widget.text,
                                  animate: widget.animate,
                                  style: serif(c, widget.prefs.fontSize),
                                  onRevealStarted: widget.onRevealStarted,
                                  onRevealSkipped: widget.onRevealSkipped,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StickerImage extends StatelessWidget {
  const StickerImage({super.key, required this.sticker});

  final StickerPayload sticker;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeDataUrl(sticker.dataUrl);
    if (bytes == null) return Text(context.l10n.stickerLoadFailed);
    // Image.memory uses Flutter's multi-frame image pipeline, including GIF.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Text(context.l10n.stickerLoadFailed),
      ),
    );
  }

  Uint8List? _decodeDataUrl(String dataUrl) {
    final match = RegExp(
      r'^data:image/[a-z0-9.+-]+;base64,([A-Za-z0-9+/=_-]+)$',
      caseSensitive: false,
    ).firstMatch(dataUrl.trim());
    if (match == null) return null;
    try {
      return base64Decode(match.group(1)!);
    } on FormatException {
      return null;
    }
  }
}

class AnimatedRevealText extends StatefulWidget {
  const AnimatedRevealText({
    super.key,
    required this.text,
    required this.animate,
    required this.style,
    this.onRevealStarted,
    this.onRevealSkipped,
  });

  final String text;
  final bool animate;
  final TextStyle style;
  final VoidCallback? onRevealStarted;
  final VoidCallback? onRevealSkipped;

  @override
  State<AnimatedRevealText> createState() => _AnimatedRevealTextState();
}

class _AnimatedRevealTextState extends State<AnimatedRevealText>
    with SingleTickerProviderStateMixin {
  // Shared with ChatController.revealCps (mirrors
  // Emerald-client/src/windows/room/useVnPresenter.ts, 40 CPS).
  static const _revealCps = ChatController.revealCps;
  late final AnimationController _controller;
  late final bool _animate;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _animate = widget.animate;
    if (_animate) {
      _controller.duration = Duration(
        milliseconds: (widget.text.characters.length / _revealCps * 1000)
            .round()
            .clamp(1, 60000),
      );
      _controller.forward();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRevealStarted?.call();
      });
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() {
      _skipped = true;
      _controller.value = 1;
      widget.onRevealSkipped?.call();
    }),
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final count = (_controller.value * widget.text.characters.length)
            .floor();
        final visible = _skipped || !_animate
            ? widget.text
            : widget.text.characters.take(count).toString();
        final cursor = _animate && !_skipped && _controller.value < 1
            ? '▍'
            : '';
        return Text('$visible$cursor', style: widget.style);
      },
    ),
  );
}

class TypingHimMessage extends StatelessWidget {
  const TypingHimMessage({
    super.key,
    required this.c,
    required this.time,
    required this.prefs,
    this.profileDisplayName = kFallbackCharacterDisplayName,
    this.profileAvatarBytes,
  });

  final YxPalette c;
  final String time;
  final YxPrefs prefs;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: YxAvatar(
              c: c,
              size: 28,
              imageBytes: profileAvatarBytes,
              text: profileDisplayName.characters.first,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.l10n.chatRoleHim}  $time',
                  style: mono(c, 9.5, color: c.ink3),
                ),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                  decoration: BoxDecoration(
                    color: c.surfaceSoft.withValues(
                      alpha: prefs.chatBubbleOpacity,
                    ),
                    border: Border.all(color: c.surfaceEdge),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: c.character, width: 3),
                      ),
                    ),
                    child: JumpingDots(c: c, size: prefs.fontSize),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class JumpingDots extends StatefulWidget {
  const JumpingDots({super.key, required this.c, required this.size});

  final YxPalette c;
  final double size;

  @override
  State<JumpingDots> createState() => _JumpingDotsState();
}

class _JumpingDotsState extends State<JumpingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final active = (_controller.value * 3).floor().clamp(0, 2);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(
                  0,
                  i == active ? -3 : 0,
                  0,
                ),
                child: Text(
                  '.',
                  style: serif(
                    widget.c,
                    widget.size,
                    color: widget.c.ink2.withValues(
                      alpha: i == active ? 1 : 0.42,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class YouMessage extends StatefulWidget {
  const YouMessage({
    super.key,
    required this.c,
    required this.time,
    required this.text,
    required this.prefs,
    this.quotedText,
    this.failed = false,
    this.onRetry,
    this.showDateDivider = false,
    this.dateKey,
  });

  final YxPalette c;
  final String time;
  final String text;
  final YxPrefs prefs;
  final String? quotedText;
  final bool failed;
  final VoidCallback? onRetry;
  final bool showDateDivider;
  final String? dateKey;

  @override
  State<YouMessage> createState() => _YouMessageState();
}

class _YouMessageState extends State<YouMessage> {
  bool _selectable = false;

  Future<void> _handleLongPress(Offset globalPosition) async {
    final action = await showChatBubbleMenu(
      context: context,
      position: globalPosition,
      showReply: false,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ChatBubbleAction.copy:
        await Clipboard.setData(ClipboardData(text: widget.text));
        break;
      case ChatBubbleAction.selectAll:
        setState(() => _selectable = true);
        break;
      case ChatBubbleAction.reply:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final text = widget.text;
    final prefs = widget.prefs;
    final attachment = AttachmentPlaceholder.parse(text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.showDateDivider && widget.dateKey != null)
                  _ChatDateDivider(
                    c: c,
                    dateKey: widget.dateKey!,
                    role: context.l10n.chatRoleYou,
                  ),
                Text(
                  '${context.l10n.chatRoleYou}  ${widget.time}',
                  style: mono(c, 9.5, color: c.ink3),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onLongPressStart: attachment == null
                      ? (details) =>
                            unawaited(_handleLongPress(details.globalPosition))
                      : null,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                    decoration: BoxDecoration(
                      color: c.userBubble.withValues(
                        alpha: prefs.chatBubbleOpacity,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: attachment != null
                        ? UserAttachmentCard(
                            c: c,
                            attachment: attachment,
                            fontSize: prefs.fontSize,
                          )
                        : _selectable
                        ? SelectableText(
                            text,
                            style: serif(
                              c,
                              prefs.fontSize,
                              color: c.userBubbleText,
                            ),
                          )
                        : Text(
                            text,
                            style: serif(
                              c,
                              prefs.fontSize,
                              color: c.userBubbleText,
                            ),
                          ),
                  ),
                ),
                if (widget.quotedText != null)
                  _QuoteBar(c: c, text: widget.quotedText!, dark: true),
                if (widget.failed)
                  TextButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: Text(context.l10n.chatRetry),
                  ),
              ],
            ),
          ),
          if (prefs.showYouAvatar) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: YxAvatar(
                c: c,
                text: context.l10n.chatRoleYou.characters.first,
                size: 28,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class UserAttachmentCard extends StatelessWidget {
  const UserAttachmentCard({
    super.key,
    required this.c,
    required this.attachment,
    required this.fontSize,
  });

  final YxPalette c;
  final AttachmentPlaceholder attachment;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final imageBytes = attachment.isImage ? _decodeDataImage(attachment.filename) : null;
    final icon = attachment.isImage
        ? Icons.image_outlined
        : Icons.attach_file_rounded;
    final label = attachment.isImage
        ? context.l10n.imageAttachment
        : context.l10n.fileAttachment;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 188),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: c.userBubbleText.withValues(alpha: 0.18),
              ),
            ),
            child: imageBytes == null
                ? Icon(icon, color: c.userBubbleText, size: 19)
                : ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.memory(imageBytes, fit: BoxFit.cover)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: mono(
                    c,
                    9.5,
                    color: c.userBubbleText.withValues(alpha: 0.62),
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  imageBytes != null ? context.l10n.imageAttachment : attachment.filename,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: serif(
                    c,
                    fontSize,
                    color: c.userBubbleText,
                    weight: FontWeight.w600,
                  ),
                ),
                if (attachment.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    attachment.note,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: serif(
                      c,
                      math.max(12, fontSize - 1),
                      color: c.userBubbleText.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Uint8List? _decodeDataImage(String value) {
  final i = value.indexOf('base64,');
  if (i < 0) return null;
  try { return base64Decode(value.substring(i + 7)); } catch (_) { return null; }
}

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.c,
    required this.bubbleOpacity,
    required this.fontSize,
    required this.sending,
    required this.onOpenAttach,
    required this.onSend,
    required this.onVoiceRecordStart,
    required this.onVoiceRecordStop,
    required this.onVoiceRecordCancel,
  });

  final YxPalette c;
  final double bubbleOpacity;
  final double fontSize;
  final bool sending;
  final VoidCallback onOpenAttach;
  final ValueChanged<String> onSend;

  /// 开始录音；返回 false 表示启动失败（如无权限），composer 会回退到未录音态。
  final Future<String?> Function() onVoiceRecordStart;

  /// 停止录音并转写；返回识别文本（可能为空串），null 表示失败。
  final Future<VoiceInputResult> Function() onVoiceRecordStop;

  /// 中途放弃（如长按被系统手势打断），丢弃已录内容。
  final VoidCallback onVoiceRecordCancel;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final TextEditingController _controller = TextEditingController();
  final ValueNotifier<String> _draft = ValueNotifier<String>('');
  bool _recording = false;
  bool _transcribing = false;
  String? _voiceError;

  Future<void> _handleRecordStart() async {
    if (_recording || _transcribing) return;
    setState(() => _recording = true);
    final error = await widget.onVoiceRecordStart();
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _recording = false;
        _voiceError = error;
      });
    }
  }

  Future<void> _handleRecordEnd() async {
    if (!_recording) return;
    setState(() {
      _recording = false;
      _transcribing = true;
    });
    final result = await widget.onVoiceRecordStop();
    if (!mounted) return;
    setState(() {
      _transcribing = false;
      _voiceError = result.error;
    });
    final text = result.text;
    if (result.isSuccess && text != null && text.trim().isNotEmpty) {
      final trimmed = text.trim();
      _controller.text = _controller.text.isEmpty
          ? trimmed
          : '${_controller.text}$trimmed';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _draft.value = _controller.text;
    }
  }

  void _handleRecordCancel() {
    if (!_recording) return;
    setState(() {
      _recording = false;
      _voiceError = null;
    });
    widget.onVoiceRecordCancel();
  }

  @override
  void dispose() {
    _draft.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final placeholder = l10n.composerPlaceholder;
    return Container(
      color: widget.c.surfaceSoft.withValues(alpha: widget.bubbleOpacity),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              YxIconButton(
                c: widget.c,
                icon: Icons.add_rounded,
                size: 38,
                onPressed: widget.onOpenAttach,
                tooltip: l10n.attachmentTooltip,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 38,
                    maxHeight: 92,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: widget.c.surface.withValues(
                      alpha: widget.bubbleOpacity,
                    ),
                    border: Border.all(color: widget.c.surfaceEdge),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    style: serif(widget.c, widget.fontSize),
                    decoration: InputDecoration.collapsed(
                      hintText: placeholder,
                      hintStyle: serif(
                        widget.c,
                        widget.fontSize,
                        color: widget.c.ink3,
                      ),
                    ),
                    onChanged: (value) => _draft.value = value,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<String>(
                valueListenable: _draft,
                builder: (context, draft, _) {
                  if (draft.trim().isEmpty) {
                    if (_transcribing) {
                      return SizedBox(
                        width: 38,
                        height: 38,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.c.ink3,
                            ),
                          ),
                        ),
                      );
                    }
                    return GestureDetector(
                      onLongPressStart: (_) => unawaited(_handleRecordStart()),
                      onLongPressEnd: (_) => unawaited(_handleRecordEnd()),
                      onLongPressCancel: _handleRecordCancel,
                      child: YxIconButton(
                        c: widget.c,
                        icon: _recording
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        size: 38,
                        onPressed: () {},
                        onDark: _recording,
                        tooltip: _recording
                            ? l10n.releaseToSendTooltip
                            : l10n.holdToTalkTooltip,
                      ),
                    );
                  }
                  return SizedBox(
                    height: 38,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.c.send,
                        foregroundColor: widget.c.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      onPressed: () {
                              widget.onSend(_controller.text);
                              _controller.clear();
                              _draft.value = '';
                            },
                      icon: Icon(
                        Icons.send_rounded,
                        size: 15,
                      ),
                      label: Text(
                        l10n.sendAction,
                        style: mono(widget.c, 11, color: widget.c.surface),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_voiceError != null) ...[
            Text(
              _voiceError!,
              style: mono(widget.c, 9.5, color: widget.c.danger),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Text('', style: mono(widget.c, 9.5, color: widget.c.ink3)),
              Text('', style: mono(widget.c, 9.5, color: widget.c.ink3)),
              Text('', style: mono(widget.c, 9.5, color: widget.c.ink3)),
              const Spacer(),
              ValueListenableBuilder<String>(
                valueListenable: _draft,
                builder: (context, draft, _) {
                  return Text(
                    draft.isEmpty ? '—' : l10n.characterCount(draft.length),
                    style: mono(widget.c, 9.5, color: widget.c.ink3),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
