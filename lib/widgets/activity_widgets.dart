part of '../main.dart';

// W7：活动系统入口。每个子活动是自包含的 StatefulWidget，自己持有 backend/token
// 并管理本地状态（而不是像其余页面那样把状态提到 app_shell.dart）——这几个活动
// 涉及的动作太多（start/state/move/chat/close/ai_move/comment...），继续走"状态全提到
// app_shell.dart 再逐个传 callback"的既有惯例会把那个文件继续撑大，不划算。

class ActivityHomePage extends StatefulWidget {
  const ActivityHomePage({
    super.key,
    required this.c,
    required this.backend,
    required this.requireToken,
    required this.onBack,
  });

  final YxPalette c;
  final BackendClient backend;
  final String Function() requireToken;
  final VoidCallback onBack;

  @override
  State<ActivityHomePage> createState() => _ActivityHomePageState();
}

class _ActivityHomePageState extends State<ActivityHomePage> {
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      color: c.characterDeep,
      child: Column(
        children: [
          PageHeader(
            c: c,
            title: '活动',
            eyebrow: '和他一起做点什么',
            onBack: widget.onBack,
            trailing: '',
            darkHeader: true,
          ),
          Expanded(
            child: Container(
              color: c.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
            _ActivityCard(
              c: c,
              icon: Icons.menu_book_rounded,
              title: '一起看书',
              subtitle: '上传 PDF，翻页时聊两句',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReadingScreen(
                    c: c,
                    backend: widget.backend,
                    requireToken: widget.requireToken,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ActivityCard(
              c: c,
              icon: Icons.grid_4x4_rounded,
              title: '五子棋',
              subtitle: '对战角色 AI，触屏落子',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GomokuScreen(
                    c: c,
                    backend: widget.backend,
                    requireToken: widget.requireToken,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ActivityCard(
              c: c,
              icon: Icons.castle_rounded,
              title: '国际象棋',
              subtitle: '对战角色 AI',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChessScreen(
                    c: c,
                    backend: widget.backend,
                    requireToken: widget.requireToken,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
                  _ActivityCard(
                    c: c,
                    icon: Icons.nightlight_round,
                    title: '梦境预构',
                    subtitle: '出发前先聊聊今晚想做什么梦',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DreamSeedScreen(
                          c: c,
                          backend: widget.backend,
                          requireToken: widget.requireToken,
                        ),
                      ),
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
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.c,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final YxPalette c;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surfaceSoft,
          border: Border.all(color: c.surfaceEdge),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.character.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: c.character, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: serif(c, 16, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: mono(c, 10, color: c.ink3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.ink3),
          ],
        ),
      ),
    );
  }
}

// ── 通用：活动内简易对话（吸底输入 + 消息列表，弹层展示） ──────────────────────

class ActivityChatMessage {
  const ActivityChatMessage({required this.mine, required this.text});
  final bool mine;
  final String text;
}

class ActivityChatSheet extends StatefulWidget {
  const ActivityChatSheet({
    super.key,
    required this.c,
    required this.title,
    required this.messages,
    required this.onSend,
  });

  final YxPalette c;
  final String title;
  final List<ActivityChatMessage> messages;
  final Future<String?> Function(String message) onSend;

  static Future<void> open({
    required BuildContext context,
    required YxPalette c,
    required String title,
    required List<ActivityChatMessage> messages,
    required Future<String?> Function(String message) onSend,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: ActivityChatSheet(
          c: c,
          title: title,
          messages: messages,
          onSend: onSend,
        ),
      ),
    );
  }

  @override
  State<ActivityChatSheet> createState() => _ActivityChatSheetState();
}

class _ActivityChatSheetState extends State<ActivityChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<ActivityChatMessage> _local = [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _local.add(ActivityChatMessage(mine: true, text: text));
      _sending = true;
    });
    final reply = await widget.onSend(text);
    if (!mounted) return;
    setState(() {
      if (reply != null && reply.isNotEmpty) {
        _local.add(ActivityChatMessage(mine: false, text: reply));
      }
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final all = [...widget.messages, ..._local];
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: serif(c, 15, weight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: c.ink3),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: all.isEmpty
                  ? Center(
                      child: Text(
                        '说点什么，聊聊现在的进展',
                        style: mono(c, 11, color: c.ink3),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      itemCount: all.length,
                      itemBuilder: (context, index) {
                        final m = all[index];
                        return Align(
                          alignment: m.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.sizeOf(context).width * 0.72,
                            ),
                            decoration: BoxDecoration(
                              color: m.mine ? c.send : c.surfaceSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              m.text,
                              style: serif(
                                c,
                                13.5,
                                color: m.mine ? c.surface : c.ink1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      style: serif(c, 14),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '说点什么…',
                        hintStyle: serif(c, 14, color: c.ink3),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: c.surfaceEdge),
                        ),
                      ),
                      onSubmitted: (_) => unawaited(_send()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _sending
                          ? Icons.hourglass_top_rounded
                          : Icons.send_rounded,
                      color: c.character,
                    ),
                    onPressed: _sending ? null : () => unawaited(_send()),
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

// ── 梦境预构：纯对话流程，无棋盘/翻页 ────────────────────────────────────────

class DreamSeedScreen extends StatefulWidget {
  const DreamSeedScreen({
    super.key,
    required this.c,
    required this.backend,
    required this.requireToken,
  });

  final YxPalette c;
  final BackendClient backend;
  final String Function() requireToken;

  @override
  State<DreamSeedScreen> createState() => _DreamSeedScreenState();
}

class _DreamSeedScreenState extends State<DreamSeedScreen> {
  DreamSeedState? _state;
  bool _loading = true;
  String? _error;
  final List<ActivityChatMessage> _history = [];

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final state = await widget.backend.dreamSeedState(
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() {
        _state = state;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await widget.backend.dreamSeedStart(
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() {
        _state = state;
        _history.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _close() async {
    final sessionId = _state?.sessionId;
    if (sessionId == null) return;
    setState(() => _loading = true);
    try {
      await widget.backend.dreamSeedClose(
        sessionId: sessionId,
        token: widget.requireToken(),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _send(String message) async {
    final sessionId = _state?.sessionId;
    if (sessionId == null) return null;
    try {
      final result = await widget.backend.dreamSeedChat(
        sessionId: sessionId,
        message: message,
        token: widget.requireToken(),
      );
      return result.reply;
    } on BackendException catch (e) {
      return '（发送失败：${e.message}）';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final state = _state;
    final active = state?.active == true && state?.sessionId != null;
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.ink1,
        title: Text('梦境预构', style: serif(c, 16, weight: FontWeight.w600)),
        actions: [
          if (active)
            TextButton(
              onPressed: _loading ? null : () => unawaited(_close()),
              child: Text('结束', style: mono(c, 11, color: c.danger)),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading && state == null
              ? Center(
                  child: CircularProgressIndicator(color: c.character),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Text(_error!, style: mono(c, 11, color: c.danger)),
                      const SizedBox(height: 12),
                    ],
                    if (!active) ...[
                      Text(
                        '还没开始预构梦境。开始后可以先跟他聊聊今晚想梦到什么，'
                        '结束时会把这段对话浓缩成一个种子，供入梦时参考。',
                        style: serif(c, 13.5, color: c.ink2).copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : () => unawaited(_start()),
                        child: const Text('开始预构'),
                      ),
                    ] else ...[
                      if (state?.hasSeed == true)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.surfaceSoft,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: c.surfaceEdge),
                          ),
                          child: Text(
                            state?.seedPreview ?? '',
                            style: serif(c, 13, color: c.ink2),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => unawaited(
                          ActivityChatSheet.open(
                            context: context,
                            c: c,
                            title: '预构对话',
                            messages: _history,
                            onSend: _send,
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('打开对话'),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
