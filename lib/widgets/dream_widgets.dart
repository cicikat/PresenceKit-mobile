
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';

import '../widgets/chat_widgets.dart';
import '../widgets/common_widgets.dart';
class DreamPage extends StatelessWidget {
  const DreamPage({
    super.key,
    required this.c,
    required this.prefs,
    required this.profileDisplayName,
    required this.profileAvatarBytes,
    required this.state,
    required this.stats,
    required this.loadingState,
    required this.entering,
    required this.sending,
    required this.error,
    required this.messages,
    required this.scrollController,
    required this.onOpenDrawer,
    required this.onEnter,
    required this.onSend,
    required this.onWake,
  });

  final YxPalette c;
  final YxPrefs prefs;
  final String profileDisplayName;
  final Uint8List? profileAvatarBytes;
  final DreamState? state;
  final DreamStats? stats;
  final bool loadingState;
  final bool entering;
  final bool sending;
  final String? error;
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final VoidCallback onOpenDrawer;
  final VoidCallback onEnter;
  final ValueChanged<String> onSend;
  final VoidCallback onWake;

  @override
  Widget build(BuildContext context) {
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
                tooltip: '抽屉',
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
                      '梦 · $profileDisplayName',
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
                          active ? '进行中' : 'DREAM · READY',
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
                label: const Text('醒来'),
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
                    if (error != null) MetaLine(c: c, text: '梦境连接异常 · $error'),
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
                        time: '梦在回应',
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
                  onEnter: onEnter,
                ),
        ),
        DreamComposer(c: c, sending: sending, enabled: active, onSend: onSend),
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
              YxTag(c: c, text: metric('稳定度', state.dreamStability)),
              YxTag(c: c, text: metric('深度', state.dreamDepth)),
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
              loading ? '正在寻找梦境入口' : '梦境入口已经打开',
              textAlign: TextAlign.center,
              style: serif(c, 24, weight: FontWeight.w600),
            ),
            const SizedBox(height: 9),
            Text(
              '进入后，对话会暂时停在更轻、更慢的地方。这里与主对话消息流彼此独立。',
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
              YxTag(c: c, text: '已经做过 ${stats!.totalValid} 次有效的梦'),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: loading || entering ? null : onEnter,
              icon: Icon(
                entering ? Icons.hourglass_top_rounded : Icons.bedtime_rounded,
                size: 17,
              ),
              label: Text(entering ? '坠入中…' : '进入梦境'),
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
                hintText: widget.enabled ? '在这儿写点什么…' : '梦在门后等待',
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
            child: Text(widget.sending ? '等待' : '寄出'),
          ),
        ],
      ),
    );
  }
}
