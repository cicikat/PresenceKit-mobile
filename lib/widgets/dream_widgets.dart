import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:flutter/services.dart';
import '../controllers/dream_controller.dart';
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

class DreamPage extends StatelessWidget {
  const DreamPage({
    super.key,
    required this.c,
    required this.prefs,
    required this.profileDisplayName,
    required this.profileAvatarBytes,
    required this.controller,
    required this.onOpenDrawer,
    required this.onWake,
  });

  final YxPalette c;
  final YxPrefs prefs;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;
  final DreamController controller;
  final VoidCallback onOpenDrawer;
  final VoidCallback onWake;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final state = controller.state;
    final stats = controller.stats;
    final loadingState = controller.loadingState;
    final entering = controller.entering;
    final sending = controller.sending;
    final error = controller.error;
    final messages = controller.messages;
    final scrollController = controller.scrollController;
    final active = state?.isActive == true;
    return Column(
      children: [
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
                onPressed: onWake,
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
        Expanded(
          child: active
              ? ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 22),
                  children: [
                    DreamStateStrip(c: c, state: state!),
                    if (error != null)
                      MetaLine(
                        c: c,
                        text: context.l10n.dreamConnectionError(error),
                      ),
                    const SizedBox(height: 14),
                    for (final message in messages)
                      if (message.role == 'system')
                        DreamSceneLine(c: c, text: message.text)
                      else if (message.role == 'you')
                        YouMessage(
                          c: c,
                          time: message.time,
                          prefs: prefs,
                          text: message.text,
                        )
                      else if (message.segments != null &&
                          message.segments!.isNotEmpty)
                        DreamSegmentedMessage(
                          c: c,
                          time: message.time,
                          prefs: prefs,
                          profileDisplayName: profileDisplayName,
                          profileAvatarBytes: profileAvatarBytes,
                          segments: message.segments!,
                          animate: message.animate,
                        )
                      else
                        HimMessage(
                          c: c,
                          time: message.time,
                          prefs: prefs,
                          profileDisplayName: profileDisplayName,
                          profileAvatarBytes: profileAvatarBytes,
                          text: message.text,
                          animate: message.animate,
                        ),
                    if (sending)
                      TypingHimMessage(
                        c: c,
                        time: context.l10n.dreamResponding,
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
          c: c,
          sending: sending,
          enabled: active,
          onSend: controller.send,
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
            child: Text(text, style: mono(c, 10, color: c.ink3)),
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
  });

  final YxPalette c;
  final String time;
  final YxPrefs prefs;
  final List<NarrativeSegment> segments;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 4),
            child: Text('HIM · $time', style: mono(c, 9.5, color: c.ink3)),
          ),
          for (final segment in segments) _buildSegment(segment),
        ],
      ),
    );
  }

  Widget _buildSegment(NarrativeSegment segment) {
    switch (segment.type) {
      case 'say':
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YxAvatar(
                c: c,
                size: 28,
                imageBytes: profileAvatarBytes,
                text: profileDisplayName.characters.first,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                  decoration: BoxDecoration(
                    color: c.surfaceSoft,
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
                    child: AnimatedRevealText(
                      text: segment.text,
                      animate: animate,
                      style: serif(c, prefs.fontSize),
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(36, 2, 12, 2),
          child: Text(
            segment.text,
            style:
                serif(
                  c,
                  weak ? prefs.fontSize - 1 : prefs.fontSize,
                  color: weak ? c.ink3 : c.ink2,
                ).copyWith(
                  fontStyle: FontStyle.italic,
                  letterSpacing: weak ? 0.4 : null,
                ),
          ),
        );
      case 'env':
      case 'narration':
      default:
        return DreamSceneLine(c: c, text: segment.text);
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
  });

  final YxPalette c;
  final bool sending;
  final bool enabled;
  final ValueChanged<String> onSend;

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
    return Container(
      color: widget.c.surfaceSoft,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.enabled && !widget.sending,
              minLines: 1,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _send(),
              style: serif(widget.c, 15),
              decoration: InputDecoration(
                hintText: widget.enabled
                    ? context.l10n.dreamComposerHint
                    : context.l10n.dreamWaitingBehindDoor,
                filled: true,
                fillColor: widget.c.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: widget.c.surfaceEdge),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: widget.c.surfaceEdge),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed:
                widget.enabled &&
                    !widget.sending &&
                    _controller.text.trim().isNotEmpty
                ? _send
                : null,
            child: Text(
              widget.sending
                  ? context.l10n.waitAction
                  : context.l10n.sendAction,
            ),
          ),
        ],
      ),
    );
  }
}
