import 'reference_typography.dart';
import '../models/ui_layout.dart';
import 'conversation_presentation.dart';
export 'dream_scene.dart';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';
import '../services/character_naming.dart';

import '../widgets/chat_widgets.dart';
import '../widgets/common_widgets.dart';

class DreamLeaveDialog extends StatelessWidget {
  const DreamLeaveDialog({
    super.key,
    required this.c,
    required this.retentionText,
  });

  final YxPalette c;
  final String? retentionText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: c.surface,
      scrollable: true,
      title: Text(l10n.dreamLeaveTitle, style: serif(c, 18, color: c.ink1)),
      content: Text(
        retentionText ?? l10n.dreamStayFallback,
        style: serif(c, 14, color: c.ink2),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.dreamLeaveAction),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.dreamStayAction),
        ),
      ],
    );
  }
}

class DreamStateStrip extends StatelessWidget {
  const DreamStateStrip({super.key, required this.c, required this.state});

  final YxPalette c;
  final DreamState state;

  @override
  Widget build(BuildContext context) {
    String metric(String label, int? value) =>
        value == null ? label : '$label ${value.clamp(0, 100)}%';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.characterSoft,
        border: Border.all(color: c.character.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(state.sceneLabel, style: serif(c, 16, weight: FontWeight.w600)),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              YxTag(c: c, text: state.emotionLabel, variant: 'solid'),
              YxTag(
                c: c,
                text: metric(context.l10n.dreamStability, state.dreamStability),
              ),
              YxTag(
                c: c,
                text: metric(context.l10n.dreamDepth, state.dreamDepth),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DreamEntrance extends StatelessWidget {
  const DreamEntrance({
    super.key,
    required this.c,
    required this.loading,
    required this.entering,
    required this.error,
    required this.stats,
    required this.onEnter,
  });

  final YxPalette c;
  final bool loading;
  final bool entering;
  final String? error;
  final DreamStats? stats;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bedtime_outlined, size: 42, color: c.character),
            const SizedBox(height: 16),
            Text(
              loading
                  ? context.l10n.dreamFindingEntrance
                  : context.l10n.dreamEntranceOpen,
              textAlign: TextAlign.center,
              style: serif(c, 24, weight: FontWeight.w600),
            ),
            const SizedBox(height: 9),
            Text(
              context.l10n.dreamEntranceDescription,
              textAlign: TextAlign.center,
              style: serif(c, 14, color: c.ink2),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: mono(c, 10.5, color: c.danger),
              ),
            ],
            if (stats != null && stats!.totalValid > 0) ...[
              const SizedBox(height: 14),
              YxTag(
                c: c,
                text: context.l10n.dreamValidCount(stats!.totalValid),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: loading || entering ? null : onEnter,
              icon: Icon(
                entering ? Icons.hourglass_top_rounded : Icons.bedtime_rounded,
                size: 17,
              ),
              label: Text(
                entering
                    ? context.l10n.dreamEntering
                    : context.l10n.dreamEnterAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DreamSceneLine extends StatelessWidget {
  const DreamSceneLine({super.key, required this.c, required this.text});

  final YxPalette c;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.surfaceEdge)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              text,
              style: mono(c, 10, color: c.ink3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(child: Divider(color: c.surfaceEdge)),
        ],
      ),
    );
  }
}

/// 按 say/do/env/feel/narration 分段渲染一条梦境回复。
/// 视觉分层参考 Emerald-client 的 DreamChatPanel.tsx，不做像素级对齐。
class DreamSegmentedMessage extends StatelessWidget {
  const DreamSegmentedMessage({
    super.key,
    required this.c,
    required this.time,
    required this.prefs,
    required this.segments,
    this.profileDisplayName = kFallbackCharacterDisplayName,
    this.profileAvatarBytes,
    this.animate = false,
    this.onRevealStarted,
    this.onRevealSkipped,
  });

  final YxPalette c;
  final String time;
  final YxPrefs prefs;
  final List<NarrativeSegment> segments;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;
  final bool animate;
  final VoidCallback? onRevealStarted;
  final VoidCallback? onRevealSkipped;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final segment in segments)
            _buildSegment(
              segment,
              ConversationPresentation.dreamOf(context) == DreamLayout.moonlit,
            ),
        ],
      ),
    );
  }

  Widget _description({required Widget child, bool moonlit = false}) =>
      Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(
          horizontal: moonlit ? 0 : 22,
          vertical: moonlit ? 0 : 7,
        ),
        padding: EdgeInsets.fromLTRB(
          moonlit ? 0 : 14,
          moonlit ? 4 : 11,
          moonlit ? 0 : 14,
          moonlit ? 25 : 11,
        ),
        decoration: moonlit
            ? null
            : BoxDecoration(
                color: c.surfaceSoft.withValues(
                  alpha: prefs.dreamDescriptionOpacity * (moonlit ? .45 : 1),
                ),
                border: Border.all(
                  color: c.ink3.withValues(alpha: .3),
                  width: .7,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
        child: child,
      );

  Widget _buildSegment(NarrativeSegment segment, bool moonlit) {
    switch (segment.type) {
      case 'say':
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!moonlit)
                YxAvatar(
                  c: c,
                  size: 28,
                  imageBytes: profileAvatarBytes,
                  text: profileDisplayName.characters.first,
                ),
              if (!moonlit) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: moonlit
                      ? EdgeInsets.zero
                      : const EdgeInsets.fromLTRB(14, 10, 14, 11),
                  decoration: moonlit
                      ? null
                      : BoxDecoration(
                          color: c.surfaceSoft.withValues(
                            alpha: moonlit ? .55 : 1,
                          ),
                          border: Border.all(color: c.surfaceEdge),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                  child: Container(
                    padding: EdgeInsets.only(left: moonlit ? 0 : 10),
                    decoration: moonlit
                        ? null
                        : BoxDecoration(
                            border: Border(
                              left: BorderSide(color: c.character, width: 3),
                            ),
                          ),
                    child: AnimatedRevealText(
                      text: segment.text,
                      animate: animate,
                      onRevealStarted: onRevealStarted,
                      onRevealSkipped: onRevealSkipped,
                      style:
                          (moonlit
                                  ? referenceSerif(
                                      c,
                                      15 * prefs.dreamChatSize / 16,
                                      height: 1.95,
                                    ).copyWith(
                                      fontSize: 15 * prefs.dreamChatSize / 16,
                                    )
                                  : contentSerif(c, prefs.dreamChatSize))
                              .copyWith(
                                color: prefs.dreamChatColor == null
                                    ? c.ink1
                                    : Color(prefs.dreamChatColor!),
                              ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 'do':
      case 'feel':
        final weak = segment.type == 'feel';
        return _description(
          moonlit: moonlit,
          child: AnimatedRevealText(
            text: segment.text,
            animate: animate,
            onRevealStarted: onRevealStarted,
            onRevealSkipped: onRevealSkipped,
            style:
                (moonlit
                        ? referenceSerif(
                            c,
                            11 * prefs.dreamActionSize / 16,
                            height: 2.1,
                            spacing: 1,
                          ).copyWith(fontSize: 11 * prefs.dreamActionSize / 16)
                        : contentSerif(c, prefs.dreamActionSize))
                    .copyWith(
                      color: prefs.dreamActionColor == null
                          ? c.ink2
                          : Color(prefs.dreamActionColor!),
                    )
                    .copyWith(
                      fontStyle: FontStyle.normal,
                      letterSpacing: weak ? 0.4 : null,
                    ),
          ),
        );
      case 'env':
      case 'narration':
      default:
        return _description(
          moonlit: moonlit,
          child: AnimatedRevealText(
            text: segment.text,
            animate: animate,
            onRevealStarted: onRevealStarted,
            onRevealSkipped: onRevealSkipped,
            style:
                (moonlit
                        ? referenceSerif(
                            c,
                            11 * prefs.dreamNarrationSize / 16,
                            height: 2.1,
                            spacing: 1,
                          ).copyWith(
                            fontSize: 11 * prefs.dreamNarrationSize / 16,
                          )
                        : contentSerif(c, prefs.dreamNarrationSize))
                    .copyWith(
                      color: prefs.dreamNarrationColor == null
                          ? c.ink3
                          : Color(prefs.dreamNarrationColor!),
                    ),
          ),
        );
    }
  }
}

class DreamComposer extends StatefulWidget {
  const DreamComposer({
    super.key,
    required this.c,
    required this.sending,
    required this.enabled,
    required this.onSend,
    this.prefs = const YxPrefs(),
  });

  final YxPalette c;
  final bool sending;
  final bool enabled;
  final ValueChanged<String> onSend;
  final YxPrefs prefs;

  @override
  State<DreamComposer> createState() => _DreamComposerState();
}

class _DreamComposerState extends State<DreamComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final value = _controller.text.trim();
    if (value.isEmpty || !widget.enabled || widget.sending) return;
    widget.onSend(value);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final moonlit =
        ConversationPresentation.dreamOf(context) == DreamLayout.moonlit;
    return Container(
      color: moonlit
          ? c.surface.withValues(alpha: .35)
          : c.surfaceSoft.withValues(alpha: widget.prefs.chatBubbleOpacity),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 38, maxHeight: 92),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: moonlit
                    ? c.ink1.withValues(alpha: .06)
                    : c.surface.withValues(
                        alpha: widget.prefs.chatBubbleOpacity,
                      ),
                border: Border.all(color: c.surfaceEdge),
                borderRadius: BorderRadius.circular(moonlit ? 24 : 4),
              ),
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                style: moonlit
                    ? referenceUiText(
                        c,
                        12 * widget.prefs.dreamChatSize / 16,
                      ).copyWith(fontSize: 12 * widget.prefs.dreamChatSize / 16)
                    : contentSerif(c, widget.prefs.dreamChatSize),
                decoration: InputDecoration.collapsed(
                  hintText: moonlit
                      ? null
                      : widget.enabled
                      ? context.l10n.dreamComposerHint
                      : context.l10n.dreamWaitingBehindDoor,
                  hintStyle: serif(
                    c,
                    widget.prefs.dreamChatSize,
                    color: c.ink3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: c.send,
                foregroundColor: c.surface,
                disabledBackgroundColor: c.send.withValues(alpha: .45),
                disabledForegroundColor: c.surface.withValues(alpha: .8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              onPressed:
                  widget.enabled &&
                      !widget.sending &&
                      _controller.text.trim().isNotEmpty
                  ? _send
                  : null,
              icon: const Icon(Icons.send_rounded, size: 15),
              label: Text(
                context.l10n.sendAction,
                style: mono(c, 11, color: c.surface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
