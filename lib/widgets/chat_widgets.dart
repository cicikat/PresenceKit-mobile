import 'letter_flow_text.dart';
import 'reference_typography.dart';
import 'reverie_scene.dart';
import '../models/ui_layout.dart';
import 'conversation_presentation.dart';
import 'dart:math' as math;
export 'chat_scene.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/chat_controller.dart';
import '../controllers/voice_input_controller.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../services/character_naming.dart';
import '../widgets/common_widgets.dart';
import 'chat_image.dart';
import 'inline_display_text.dart';
import '../models/inline_display.dart';
import '../models/screen_context.dart';

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
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: c.characterOn,
                    size: 24,
                  ),
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
                  YxTag(
                    c: c.copyWith(
                      ink2: c.characterOn,
                      ink4: c.characterOn.withValues(alpha: .35),
                    ),
                    text: presence.timeband,
                  ),
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
  FocusManager.instance.primaryFocus?.unfocus();
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return showMenu<ChatBubbleAction>(
    context: context,
    requestFocus: false,
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

class _ChatSelectionController extends TextEditingController {
  _ChatSelectionController(String text, this.displayText, this.accent)
    : super(text: text);
  final String? displayText;
  final Color accent;
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => inlineDisplaySpan(
    text: text,
    displayText: displayText,
    style: style ?? const TextStyle(),
    accent: accent,
  );
}

Future<void> showChatTextSelection(
  BuildContext context,
  String text, {
  String? displayText,
  Color accent = Colors.red,
}) async {
  final visible = validatedInlineDisplay(text, displayText).map((run) => run.text).join();
  final controller = _ChatSelectionController(visible, displayText ?? text, accent)
    ..selection = TextSelection(baseOffset: 0, extentOffset: visible.length);
  try {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            readOnly: true,
            autofocus: true,
            showCursor: false,
            minLines: 1,
            maxLines: 12,
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final selection = controller.selection;
              await Clipboard.setData(
                ClipboardData(
                  text: selection.isValid ? selection.textInside(text) : text,
                ),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(context.l10n.copyAction),
          ),
        ],
      ),
    );
  } finally {
    // The dialog reverse transition still owns the editable for one frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }
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
    final classic = ConversationPresentation.dailyOf(context) == DailyLayout.classic &&
        ConversationPresentation.dreamOf(context) == DreamLayout.classic;
    return Container(
      color: c.surfaceSoft,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: classic ? c.surface : null,
          border: classic ? Border(left: BorderSide(color: c.character, width: 3)) :
              Border(bottom: BorderSide(color: c.surfaceEdge)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: mono(c, 9.5, color: c.character)),
                  Text.rich(
                    inlineDisplaySpan(text: text, style: mono(c, 11, color: c.ink3), accent: c.character),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
  Widget build(BuildContext context) {
    final classic = ConversationPresentation.dailyOf(context) == DailyLayout.classic &&
        ConversationPresentation.dreamOf(context) == DreamLayout.classic;
    return Container(
    constraints: const BoxConstraints(maxWidth: 272),
    margin: const EdgeInsets.fromLTRB(6, 9, 6, 10),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: classic ? BoxDecoration(
      color: Colors.grey.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(4),
      border: Border(
        left: BorderSide(color: dark ? c.characterOn : c.character, width: 2),
      ),
    ) : null,
    child: Text.rich(
      inlineDisplaySpan(text: text, style: mono(c, 10, color: c.ink2), accent: c.character),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    );
  }
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
    this.displayText,
    this.letterIllustration = false,
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
  final String? displayText;
  final bool letterIllustration;
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
  Future<void> _handleLongPress(Offset globalPosition) async {
    final action = await showChatBubbleMenu(
      context: context,
      position: globalPosition,
      showReply: widget.onReply != null,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ChatBubbleAction.copy:
        await Clipboard.setData(ClipboardData(text: validatedInlineDisplay(widget.text, widget.displayText).map((run) => run.text).join()));
        break;
      case ChatBubbleAction.selectAll:
        await showChatTextSelection(
          context,
          widget.text,
          displayText: widget.displayText,
          accent: widget.c.danger,
        );
        break;
      case ChatBubbleAction.reply:
        widget.onReply?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final layout = ConversationPresentation.dailyOf(context);
    final messenger = layout == DailyLayout.messenger;
    final window = layout == DailyLayout.reverie || layout == DailyLayout.noir;
    final letter =
        ConversationPresentation.dailyOf(context) == DailyLayout.letter;
    return Padding(
      padding: EdgeInsets.only(
        bottom: letter
            ? 18
            : window
            ? 17
            : 14,
      ),
      child: MessageWindow(
        enabled: window,
        c: c,
        label: widget.profileDisplayName,
        time: widget.prefs.showChatTime ? widget.time : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!letter && !window)
              Padding(
                padding: EdgeInsets.only(top: messenger ? 4 : 18),
                child: YxAvatar(
                  c: c,
                  size: messenger ? 36 : 28,
                  cornerRadius: messenger ? 5 : null,
                  imageBytes: widget.profileAvatarBytes,
                  text: widget.profileDisplayName.characters.first,
                ),
              ),
            if (!letter && !window) const SizedBox(width: 8),
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
                  if (!letter &&
                      !window &&
                      (!messenger || widget.prefs.showChatTime))
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            messenger
                                ? widget.time
                                : widget.prefs.showChatTime
                                ? '${letter || window ? widget.profileDisplayName : context.l10n.chatRoleHim}  ${widget.time}'
                                : letter || window
                                ? widget.profileDisplayName
                                : context.l10n.chatRoleHim,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mono(c, 9.5, color: c.ink3),
                          ),
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
                  if (!letter &&
                      !window &&
                      (!messenger || widget.prefs.showChatTime))
                    const SizedBox(height: 4),
                  GestureDetector(
                    onLongPressStart: widget.sticker == null
                        ? (details) => unawaited(
                            _handleLongPress(details.globalPosition),
                          )
                        : null,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: letter || window ? double.infinity : 300,
                      ),
                      padding: letter
                          ? EdgeInsets.zero
                          : window
                          ? const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 14,
                            )
                          : const EdgeInsets.fromLTRB(14, 10, 14, 11),
                      decoration: letter || window
                          ? null
                          : BoxDecoration(
                              color: c.surfaceSoft.withValues(
                                alpha: widget.prefs.chatBubbleOpacity,
                              ),
                              border: Border.all(
                                color: widget.highlight
                                    ? c.warn
                                    : c.surfaceEdge,
                                width: widget.highlight ? 2 : 1,
                              ),
                              borderRadius: messenger
                                  ? BorderRadius.circular(4)
                                  : const BorderRadius.only(
                                      topRight: Radius.circular(6),
                                      bottomRight: Radius.circular(6),
                                      bottomLeft: Radius.circular(0),
                                      topLeft: Radius.circular(0),
                                    ),
                            ),
                      child: Container(
                        padding: EdgeInsets.only(
                          left: letter || window || messenger ? 0 : 10,
                        ),
                        decoration: letter || window || messenger
                            ? null
                            : BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: c.character,
                                    width: 3,
                                  ),
                                ),
                              ),
                        child: widget.sticker != null
                            ? StickerImage(sticker: widget.sticker!)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.quotedText != null)
                                    _QuoteBar(c: c, text: widget.quotedText!),
                                  AnimatedRevealText(
                                    text: widget.text,
                                    displayText: widget.displayText,
                                    accent: c.danger,
                                    animate: widget.animate,
                                    style: letter
                                        ? referenceSerif(
                                            c,
                                            14 * widget.prefs.fontSize / 16,
                                            height: 2.2,
                                          ).copyWith(
                                            fontSize:
                                                14 * widget.prefs.fontSize / 16,
                                          )
                                        : window
                                        ? referenceUiText(
                                            c,
                                            12 * widget.prefs.fontSize / 16,
                                            height: 2,
                                          ).copyWith(
                                            fontSize:
                                                12 * widget.prefs.fontSize / 16,
                                          )
                                        : contentSerif(
                                            c,
                                            widget.prefs.fontSize,
                                          ),
                                    spanBuilder:
                                        letter && widget.letterIllustration
                                        ? (span) =>
                                              LetterFlowText(span: span, c: c)
                                        : null,
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
    this.displayText,
    this.accent,
    required this.animate,
    required this.style,
    this.onRevealStarted,
    this.onRevealSkipped,
    this.spanBuilder,
  });

  final Widget Function(TextSpan)? spanBuilder;
  final String text;
  final String? displayText;
  final Color? accent;
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
        milliseconds: (inlinePlainText(widget.text).characters.length / _revealCps * 1000)
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
        final count = (_controller.value * inlinePlainText(widget.text).characters.length)
            .floor();
        final cursor = _animate && !_skipped && _controller.value < 1
            ? '▍'
            : '';
        final span = inlineDisplaySpan(
          text: widget.text,
          displayText: widget.displayText,
          style: widget.style,
          accent: widget.accent ?? Theme.of(context).colorScheme.primary,
          visibleCharacters: _skipped || !_animate ? null : count,
          cursor: cursor,
        );
        return widget.spanBuilder?.call(span) ?? Text.rich(span);
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
    this.showHeader = true,
  });

  final YxPalette c;
  final String time;
  final bool showHeader;
  final YxPrefs prefs;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;

  @override
  Widget build(BuildContext context) {
    final layout = ConversationPresentation.dailyOf(context);
    if (layout != DailyLayout.classic) {
      final window = layout == DailyLayout.reverie || layout == DailyLayout.noir;
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: MessageWindow(
          enabled: window, c: c, label: profileDisplayName,
          time: prefs.showChatTime ? time : null,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: JumpingDots(c: c, size: prefs.fontSize),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: showHeader ? 18 : 0),
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
                if (showHeader)
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

class CanonicalChatImage extends StatefulWidget {
  const CanonicalChatImage({super.key, required this.ref, this.load});

  final ChatMediaRef ref;
  final Future<Uint8List?> Function(ChatMediaRef ref)? load;

  @override
  State<CanonicalChatImage> createState() => _CanonicalChatImageState();
}

class _CanonicalChatImageState extends State<CanonicalChatImage> {
  Uint8List? _bytes;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant CanonicalChatImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ref.sha256 != widget.ref.sha256 ||
        oldWidget.ref.filename != widget.ref.filename ||
        oldWidget.ref.availability != widget.ref.availability) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final loader = widget.load;
    final digest = widget.ref.sha256;
    if (loader == null ||
        digest == null ||
        digest.isEmpty ||
        widget.ref.availability == 'unavailable') {
      if (!mounted || generation != _generation) return;
      setState(() {
        _bytes = Uint8List(0);
      });
      return;
    }
    try {
      final bytes = await loader(widget.ref);
      if (!mounted || generation != _generation) return;
      setState(() {
        _bytes = bytes ?? Uint8List(0);
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _bytes = Uint8List(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return const SizedBox(
        width: 100,
        height: 70,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ChatImage(
      bytes: bytes,
      missingLabel: widget.ref.filename.isEmpty ? null : widget.ref.filename,
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
    this.uncertain = false,
    this.onRetry,
    this.onReply,
    this.showDateDivider = false,
    this.dateKey,
    this.attachments = const [],
    this.mediaRefs = const [],
    this.uploadNote = '',
    this.showHeader = true,
    this.loadCanonicalMedia,
  });

  final YxPalette c;
  final String time;
  final String text;
  final YxPrefs prefs;
  final String? quotedText;
  final bool failed;
  final bool uncertain;
  final VoidCallback? onRetry;
  final VoidCallback? onReply;
  final bool showDateDivider;
  final String? dateKey;
  final List<PickedUploadFile> attachments;
  final List<ChatMediaRef> mediaRefs;
  final String uploadNote;
  final bool showHeader;
  final Future<Uint8List?> Function(ChatMediaRef ref)? loadCanonicalMedia;

  @override
  State<YouMessage> createState() => _YouMessageState();
}

class _YouMessageState extends State<YouMessage> {
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
        await showChatTextSelection(context, widget.text);
        break;
      case ChatBubbleAction.reply:
        widget.onReply?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentation = ConversationPresentation.of(context);
    final messenger = presentation?.daily == DailyLayout.messenger;
    final window =
        presentation?.daily == DailyLayout.reverie ||
        presentation?.daily == DailyLayout.noir;

    final c = widget.c;
    final moonlit = presentation?.dream == DreamLayout.moonlit;
    final letter =
        ConversationPresentation.dailyOf(context) == DailyLayout.letter;
    final text = widget.text;
    final prefs = widget.prefs;
    final messageStyle = letter
        ? referenceSerif(
            c,
            14 * prefs.fontSize / 16,
            height: 2.2,
          ).copyWith(fontSize: 14 * prefs.fontSize / 16)
        : window
        ? referenceUiText(
            c,
            12 * prefs.fontSize / 16,
            height: 1.9,
            color: c.userBubbleText,
          ).copyWith(fontSize: 12 * prefs.fontSize / 16)
        : moonlit
        ? referenceSerif(
            c,
            13 * prefs.fontSize / 16,
            height: 1.95,
            color: c.ink1,
          ).copyWith(fontSize: 13 * prefs.fontSize / 16)
        : contentSerif(c, prefs.fontSize, color: c.userBubbleText);
    final attachment = AttachmentPlaceholder.parse(text);
    final canonicalImages = widget.mediaRefs
        .where((ref) => ref.isImage)
        .toList(growable: false);
    final hasImages =
        widget.attachments.any((file) => file.isImage) ||
        attachment?.isImage == true ||
        (widget.attachments.isEmpty && canonicalImages.isNotEmpty);
    return Padding(
      padding: EdgeInsets.only(
        top: letter
            ? 4
            : window
            ? 14
            : 0,
        bottom: letter
            ? 22
            : window
            ? 18
            : 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: letter
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: letter
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                if (widget.showDateDivider && widget.dateKey != null)
                  _ChatDateDivider(
                    c: c,
                    dateKey: widget.dateKey!,
                    role: context.l10n.chatRoleYou,
                  ),
                if (widget.showHeader &&
                    !letter &&
                    !window &&
                    (!messenger || prefs.showChatTime))
                  Text(
                    letter
                        ? context.l10n.referenceYourReply
                        : messenger
                        ? widget.time
                        : widget.prefs.showChatTime
                        ? '${context.l10n.chatRoleYou}  ${widget.time}'
                        : context.l10n.chatRoleYou,
                    style: mono(c, 9.5, color: c.ink3),
                  ),
                if (widget.showHeader &&
                    !letter &&
                    !window &&
                    (!messenger || prefs.showChatTime))
                  const SizedBox(height: 4),
                GestureDetector(
                  onLongPressStart: attachment == null
                      ? (details) =>
                            unawaited(_handleLongPress(details.globalPosition))
                      : null,
                  child: Container(
                    margin: window
                        ? const EdgeInsets.only(left: 37)
                        : EdgeInsets.zero,
                    width: letter || window ? double.infinity : null,
                    constraints: BoxConstraints(
                      maxWidth: letter || window ? double.infinity : 280,
                    ),
                    padding: hasImages
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                    decoration: hasImages
                        ? null
                        : BoxDecoration(
                            color: (letter ? c.surfaceDeep : c.userBubble)
                                .withValues(
                                  alpha: moonlit
                                      ? .32
                                      : prefs.chatBubbleOpacity,
                                ),
                            border: window
                                ? Border.all(color: c.surfaceEdge)
                                : null,
                            borderRadius: window
                                ? const BorderRadius.only(
                                    topLeft: Radius.circular(13),
                                    topRight: Radius.circular(13),
                                    bottomLeft: Radius.circular(13),
                                    bottomRight: Radius.circular(2),
                                  )
                                : BorderRadius.circular(letter ? 0 : 6),
                          ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: letter
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        if (letter && widget.showHeader) ...[
                          Text(
                            context.l10n.referenceYourReply,
                            style: referenceUiText(
                              c,
                              9,
                              color: c.ink3,
                              spacing: 1,
                            ),
                          ),
                          const SizedBox(height: 5),
                        ],
                        widget.attachments.isNotEmpty
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: letter
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                children: [
                                  for (final file in widget.attachments)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: file.isImage
                                          ? ChatImage(bytes: file.bytes)
                                          : UserAttachmentCard(
                                              c: c,
                                              attachment: AttachmentPlaceholder(
                                                filename: file.name,
                                                note: '',
                                                kind: 'file',
                                              ),
                                              fontSize: prefs.fontSize,
                                            ),
                                    ),
                                  if (widget.uploadNote.isNotEmpty)
                                    hasImages
                                        ? _ImageCaptionBubble(
                                            c: c,
                                            text: widget.uploadNote,
                                            fontSize: prefs.fontSize,
                                            opacity: prefs.chatBubbleOpacity,
                                          )
                                        : Text(
                                            widget.uploadNote,
                                            style: messageStyle,
                                          ),
                                ],
                              )
                            : canonicalImages.isNotEmpty
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: letter
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                children: [
                                  for (final ref in canonicalImages)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: CanonicalChatImage(
                                        ref: ref,
                                        load: widget.loadCanonicalMedia,
                                      ),
                                    ),
                                ],
                              )
                            : attachment != null
                            ? UserAttachmentCard(
                                c: c,
                                attachment: attachment,
                                fontSize: prefs.fontSize,
                                bubbleOpacity: prefs.chatBubbleOpacity,
                              )
                            : Text(text, style: messageStyle),
                        if (window &&
                            widget.showHeader &&
                            prefs.showChatTime) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.time,
                            style: referenceUiText(c, 8, color: c.ink3),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.quotedText != null)
                  _QuoteBar(c: c, text: widget.quotedText!, dark: true),
                if (widget.uncertain && !widget.failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      context.l10n.chatConfirming,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.userBubbleText.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                if (widget.failed)
                  TextButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: Text(context.l10n.chatRetry),
                  ),
              ],
            ),
          ),
          if ((!letter && !window && !moonlit && prefs.showYouAvatar) ||
              messenger) ...[
            const SizedBox(width: 8),
            Padding(
              padding: EdgeInsets.only(
                top: messenger
                    ? 4
                    : widget.showHeader
                    ? 18
                    : 0,
              ),
              child: YxAvatar(
                c: c,
                text: messenger && presentation!.userName.isNotEmpty
                    ? presentation.userName.characters.first
                    : context.l10n.chatRoleYou.characters.first,
                imageBytes: messenger ? presentation?.userAvatar : null,
                size: messenger ? 36 : 28,
                cornerRadius: messenger ? 5 : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageCaptionBubble extends StatelessWidget {
  const _ImageCaptionBubble({
    required this.c,
    required this.text,
    required this.fontSize,
    required this.opacity,
  });
  final YxPalette c;
  final String text;
  final double fontSize;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('image-caption-bubble'),
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
    decoration: BoxDecoration(
      color: c.userBubble.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: contentSerif(c, fontSize, color: c.userBubbleText),
    ),
  );
}

class UserAttachmentCard extends StatelessWidget {
  const UserAttachmentCard({
    super.key,
    required this.c,
    required this.attachment,
    required this.fontSize,
    this.bubbleOpacity = .94,
  });

  final YxPalette c;
  final AttachmentPlaceholder attachment;
  final double fontSize;
  final double bubbleOpacity;

  @override
  Widget build(BuildContext context) {
    final imageBytes = attachment.isImage
        ? _decodeDataImage(attachment.filename)
        : null;
    if (imageBytes != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ChatImage(bytes: imageBytes),
          if (attachment.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _ImageCaptionBubble(
                c: c,
                text: attachment.note,
                fontSize: fontSize,
                opacity: bubbleOpacity,
              ),
            ),
        ],
      );
    }
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
                : ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.memory(imageBytes, fit: BoxFit.cover),
                  ),
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
                  attachment.filename.startsWith('data:')
                      ? context.l10n.imageDecodeFailed
                      : attachment.filename,
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
  try {
    return base64Decode(value.substring(i + 7));
  } catch (_) {
    return null;
  }
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
    final layout = ConversationPresentation.dailyOf(context);
    final window = layout == DailyLayout.reverie || layout == DailyLayout.noir;
    final reference = window || layout == DailyLayout.letter;
    final inputStyle = reference
        ? referenceUiText(
            widget.c,
            (window ? 11 : 12) * widget.fontSize / 16,
          ).copyWith(fontSize: (window ? 11 : 12) * widget.fontSize / 16)
        : contentSerif(widget.c, widget.fontSize);
    final placeholder = layout == DailyLayout.classic
        ? l10n.composerPlaceholder
        : null;
    return Container(
      margin: window
          ? const EdgeInsets.fromLTRB(14, 0, 14, 7)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: widget.c.surfaceSoft.withValues(alpha: widget.bubbleOpacity),
        border: window
            ? Border.all(color: widget.c.surfaceEdge)
            : reference
            ? Border(top: BorderSide(color: widget.c.surfaceEdge))
            : null,
        borderRadius: window ? BorderRadius.circular(8) : null,
      ),
      padding: window
          ? const EdgeInsets.fromLTRB(6, 8, 6, 6)
          : reference
          ? const EdgeInsets.fromLTRB(17, 9, 17, 9)
          : const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (window)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 3),
              child: Text(
                l10n.referenceChatTab,
                style: referenceUiText(
                  widget.c,
                  7,
                  color: widget.c.ink3,
                  spacing: 1,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              YxIconButton(
                c: widget.c,
                icon: Icons.add_rounded,
                borderless: reference,
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
                    color: reference
                        ? Colors.transparent
                        : widget.c.surface.withValues(
                            alpha: widget.bubbleOpacity,
                          ),
                    border: reference
                        ? null
                        : Border.all(color: widget.c.surfaceEdge),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    style: inputStyle,
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
                        borderless: reference,
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
                  if (reference) {
                    return SizedBox(
                      width: window ? 35 : 36,
                      height: window ? 35 : 36,
                      child: IconButton.filled(
                        tooltip: l10n.sendAction,
                        style: IconButton.styleFrom(
                          backgroundColor: widget.c.send,
                          foregroundColor: widget.c.surface,
                          shape: window
                              ? RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                )
                              : const CircleBorder(),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () {
                          widget.onSend(_controller.text);
                          _controller.clear();
                          _draft.value = '';
                        },
                        icon: const Icon(Icons.send_rounded, size: 19),
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
                      icon: Icon(Icons.send_rounded, size: 15),
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
          if (_voiceError != null) ...[
            const SizedBox(height: 6),
            Text(
              _voiceError!,
              style: mono(widget.c, 9.5, color: widget.c.danger),
            ),
            const SizedBox(height: 4),
          ],
          ValueListenableBuilder<String>(
            valueListenable: _draft,
            builder: (context, draft, _) =>
                draft.isEmpty || layout == DailyLayout.messenger || reference
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        l10n.characterCount(draft.length),
                        style: mono(widget.c, 9.5, color: widget.c.ink3),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
