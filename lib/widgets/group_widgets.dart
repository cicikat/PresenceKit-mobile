import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../l10n/l10n.dart';
import '../services/backend_client.dart';

import '../widgets/common_widgets.dart';
// W8：群聊 Stage。桌面端用 WebSocket 做逐字流式（message_stream_start/delta/end +
// group_round_start/end）；手机端和其余功能一样走 HTTP 轮询（沿用 /mobile/poll 的
// 既有节奏），发送后每 2 秒拉一次 GET /group/{id} 直到拿到新回复或超时，不做逐字
// 流式——手机屏幕小、逐字动效收益不大，轮询也更省电。

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({
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
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  List<GroupSummary> _groups = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final groups = await widget.backend.groupList(
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(GroupSummary group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.groupDeleteTitle(group.displayTitle)),
        content: Text(context.l10n.groupDeleteWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.backend.groupDelete(
        groupId: group.groupId,
        token: widget.requireToken(),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _openCreate() async {
    final c = widget.c;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _CreateGroupSheet(
          c: c,
          backend: widget.backend,
          requireToken: widget.requireToken,
        ),
      ),
    );
    if (created == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = widget.c;
    return Container(
      color: c.characterDeep,
      child: Column(
        children: [
          PageHeader(
            c: c,
            title: l10n.groupTitle,
            eyebrow: l10n.groupEyebrow,
            onBack: widget.onBack,
            trailing: '',
            darkHeader: true,
          ),
          Expanded(
            child: Container(
              color: c.surface,
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: c.character))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        if (_error != null) ...[
                          Text(_error!, style: mono(c, 11, color: c.danger)),
                          const SizedBox(height: 12),
                        ],
                        OutlinedButton.icon(
                          onPressed: () => unawaited(_openCreate()),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l10n.groupCreateAction),
                        ),
                        const SizedBox(height: 16),
                        if (_groups.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                l10n.groupEmpty,
                                style: serif(
                                  c,
                                  13,
                                  color: c.ink3,
                                ).copyWith(fontStyle: FontStyle.italic),
                              ),
                            ),
                          )
                        else
                          for (final group in _groups)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => GroupChatScreen(
                                      c: c,
                                      backend: widget.backend,
                                      requireToken: widget.requireToken,
                                      groupId: group.groupId,
                                    ),
                                  ),
                                ),
                                onLongPress: () => unawaited(_delete(group)),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: c.surfaceSoft,
                                    border: Border.all(color: c.surfaceEdge),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              group.displayTitle,
                                              style: serif(
                                                c,
                                                14,
                                                weight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              l10n.groupRosterDeleteHint(
                                                group.roster
                                                    .map((m) => m.label)
                                                    .join(' · '),
                                              ),
                                              style: mono(
                                                c,
                                                9.5,
                                                color: c.ink3,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: c.ink3,
                                      ),
                                    ],
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

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({
    required this.c,
    required this.backend,
    required this.requireToken,
  });

  final YxPalette c;
  final BackendClient backend;
  final String Function() requireToken;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  List<PromptAssetOption> _characters = const [];
  final Set<String> _selected = {};
  int _minR = 1;
  int _maxR = 2;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final assets = await widget.backend.loadPromptAssets(
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() {
        _characters = assets.characters;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    if (_selected.isEmpty) {
      setState(() => _error = context.l10n.groupSelectAtLeastOne);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.backend.groupCreate(
        roster: _selected.toList(growable: false),
        minResponders: _minR,
        maxResponders: math.max(_minR, _maxR),
        token: widget.requireToken(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
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
                      context.l10n.groupCreateAction,
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
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: c.character))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Text(
                          context.l10n.groupSelectedCount(_selected.length),
                          style: mono(c, 10.5, color: c.ink3),
                        ),
                        const SizedBox(height: 10),
                        if (_characters.isEmpty)
                          Text(
                            context.l10n.groupNoCharacters,
                            style: serif(
                              c,
                              13,
                              color: c.ink3,
                            ).copyWith(fontStyle: FontStyle.italic),
                          )
                        else
                          for (final ch in _characters)
                            CheckboxListTile(
                              value: _selected.contains(ch.id),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selected.add(ch.id);
                                } else {
                                  _selected.remove(ch.id);
                                }
                                if (_minR > math.max(_selected.length, 1)) {
                                  _minR = math.max(_selected.length, 1);
                                }
                              }),
                              title: Text(ch.label, style: serif(c, 14)),
                              subtitle: Text(
                                ch.id,
                                style: mono(c, 10, color: c.ink3),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                            ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.groupMinResponders(_minR),
                          style: serif(c, 13, weight: FontWeight.w500),
                        ),
                        Slider(
                          value: _minR.toDouble(),
                          min: 1,
                          max: math.max(_selected.length, 1).toDouble(),
                          divisions: math.max(_selected.length - 1, 1),
                          onChanged: (v) => setState(() {
                            _minR = v.round();
                            if (_maxR < _minR) _maxR = _minR;
                          }),
                        ),
                        Text(
                          context.l10n.groupMaxResponders(_maxR),
                          style: serif(c, 13, weight: FontWeight.w500),
                        ),
                        Slider(
                          value: _maxR.toDouble().clamp(
                            _minR.toDouble(),
                            math.max(_selected.length, 1).toDouble(),
                          ),
                          min: _minR.toDouble(),
                          max: math.max(_selected.length, 1).toDouble(),
                          divisions: math.max(_selected.length - _minR, 1),
                          onChanged: (v) => setState(() => _maxR = v.round()),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: mono(c, 11, color: c.danger)),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _saving
                              ? null
                              : () => unawaited(_create()),
                          child: Text(
                            _saving
                                ? context.l10n.groupCreating
                                : context.l10n.groupConfirmCreate,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.c,
    required this.backend,
    required this.requireToken,
    required this.groupId,
  });

  final YxPalette c;
  final BackendClient backend;
  final String Function() requireToken;
  final String groupId;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  GroupDetail? _detail;
  bool _loading = true;
  bool _sending = false;
  bool _waitingReply = false;
  bool _dreamBlocked = false;
  String? _error;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;
  Timer? _dreamGuardTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    unawaited(_checkDreamBlock());
    _dreamGuardTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_checkDreamBlock()),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _dreamGuardTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 群聊梦境进行中时，现实群聊后端会硬拒发言（409）——这里轮询同一个只读
  /// 状态字段提前锁住输入框，避免用户发出去才收到拒绝。静默失败：老后端没有
  /// 这个字段/端点时，`blocksChat` 落回 false，现实群聊照常可用。
  Future<void> _checkDreamBlock() async {
    try {
      final state = await widget.backend.groupDreamGetState(
        groupId: widget.groupId,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() => _dreamBlocked = state.blocksChat);
    } catch (_) {
      // 静默：不用因为这个后台检查弹错误打断现实聊天。
    }
  }

  Future<void> _openGroupDream() async {
    final detail = _detail;
    if (detail == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupDreamChatScreen(
          c: widget.c,
          backend: widget.backend,
          requireToken: widget.requireToken,
          groupId: widget.groupId,
          groupTitle: detail.summary.displayTitle,
          roster: detail.summary.roster,
        ),
      ),
    );
    unawaited(_checkDreamBlock());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final detail = await widget.backend.groupGet(
        groupId: widget.groupId,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _error = null;
      });
      _scrollToBottomSoon();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _dreamBlocked) return;
    _controller.clear();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.backend.groupSend(
        groupId: widget.groupId,
        message: text,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() => _waitingReply = true);
      await _refresh();
      unawaited(_pollForReplies());
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pollForReplies() async {
    _pollTimer?.cancel();
    final beforeCount = _detail?.recent.length ?? 0;
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      if (!mounted || attempts > 15) {
        timer.cancel();
        if (mounted) setState(() => _waitingReply = false);
        return;
      }
      try {
        final detail = await widget.backend.groupGet(
          groupId: widget.groupId,
          token: widget.requireToken(),
        );
        if (!mounted) return;
        setState(() => _detail = detail);
        if (detail.recent.length > beforeCount) {
          timer.cancel();
          setState(() => _waitingReply = false);
          _scrollToBottomSoon();
        }
      } catch (_) {
        // 轮询失败静默重试，直到超过 attempts 上限
      }
    });
  }

  Future<void> _openSettings() async {
    final detail = _detail;
    if (detail == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _GroupSettingsSheet(
          c: widget.c,
          backend: widget.backend,
          requireToken: widget.requireToken,
          groupId: widget.groupId,
          detail: detail,
        ),
      ),
    );
    if (changed == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final detail = _detail;
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.ink1,
        title: Text(
          detail?.summary.displayTitle ?? context.l10n.groupTitle,
          style: serif(c, 16, weight: FontWeight.w600),
        ),
        actions: [
          if (detail != null)
            IconButton(
              icon: const Icon(Icons.bedtime_outlined),
              tooltip: context.l10n.groupDreamEnterAction,
              onPressed: () => unawaited(_openGroupDream()),
            ),
          if (detail != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => unawaited(_openSettings()),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: c.character))
            : Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(_error!, style: mono(c, 11, color: c.danger)),
                    ),
                  if (_dreamBlocked)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        context.l10n.groupDreamBlockedHint,
                        style: mono(c, 10, color: c.ink3),
                      ),
                    ),
                  Expanded(
                    child: detail == null || detail.recent.isEmpty
                        ? Center(
                            child: Text(
                              context.l10n.groupSendToStart,
                              style: serif(
                                c,
                                13,
                                color: c.ink3,
                              ).copyWith(fontStyle: FontStyle.italic),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            itemCount: detail.recent.length,
                            itemBuilder: (context, index) {
                              final msg = detail.recent[index];
                              final prevSpeaker = index > 0
                                  ? detail.recent[index - 1].speakerId
                                  : null;
                              final showLabel =
                                  !msg.isOwner && msg.speakerId != prevSpeaker;
                              final member = detail.summary.roster
                                  .where((m) => m.charId == msg.speakerId)
                                  .firstOrNull;
                              return _GroupBubble(
                                c: c,
                                message: msg,
                                showLabel: showLabel,
                                speakerLabel: member?.label ?? msg.speakerId,
                              );
                            },
                          ),
                  ),
                  if (_waitingReply)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        context.l10n.groupMembersResponding,
                        style: mono(c, 10, color: c.ink3),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !_dreamBlocked,
                            minLines: 1,
                            maxLines: 3,
                            style: serif(c, 14),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: context.l10n.groupSendHint,
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
                          onPressed: _sending || _dreamBlocked
                              ? null
                              : () => unawaited(_send()),
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

class _GroupBubble extends StatelessWidget {
  const _GroupBubble({
    required this.c,
    required this.message,
    required this.showLabel,
    required this.speakerLabel,
  });

  final YxPalette c;
  final GroupMessage message;
  final bool showLabel;
  final String speakerLabel;

  @override
  Widget build(BuildContext context) {
    if (message.isOwner) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          decoration: BoxDecoration(
            color: c.send,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(message.content, style: serif(c, 13.5, color: c.surface)),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLabel)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 2),
                child: Text(
                  speakerLabel,
                  style: mono(c, 9, color: c.ink3, weight: FontWeight.w600),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.surfaceSoft,
                border: Border(left: BorderSide(color: c.character, width: 3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                message.content,
                style: serif(c, 13.5, color: c.ink1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSettingsSheet extends StatefulWidget {
  const _GroupSettingsSheet({
    required this.c,
    required this.backend,
    required this.requireToken,
    required this.groupId,
    required this.detail,
  });

  final YxPalette c;
  final BackendClient backend;
  final String Function() requireToken;
  final String groupId;
  final GroupDetail detail;

  @override
  State<_GroupSettingsSheet> createState() => _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends State<_GroupSettingsSheet> {
  List<PromptAssetOption> _characters = const [];
  late final Set<String> _roster = widget.detail.summary.roster
      .map((m) => m.charId)
      .toSet();
  late int _minR = widget.detail.settings.minResponders;
  late int _maxR = widget.detail.settings.maxResponders;
  bool _loadingChars = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadChars());
  }

  Future<void> _loadChars() async {
    try {
      final assets = await widget.backend.loadPromptAssets(
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() {
        _characters = assets.characters;
        _loadingChars = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingChars = false;
      });
    }
  }

  Future<void> _save() async {
    if (_roster.isEmpty) {
      setState(() => _error = context.l10n.groupKeepAtLeastOne);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final origRoster = widget.detail.summary.roster
          .map((m) => m.charId)
          .toSet();
      final rosterChanged =
          origRoster.length != _roster.length ||
          !origRoster.containsAll(_roster);
      if (rosterChanged) {
        await widget.backend.groupPatchRoster(
          groupId: widget.groupId,
          roster: _roster.toList(growable: false),
          token: widget.requireToken(),
        );
      }
      final effectiveMax = math.max(_minR, _maxR);
      if (_minR != widget.detail.settings.minResponders ||
          effectiveMax != widget.detail.settings.maxResponders) {
        await widget.backend.groupPatchSettings(
          groupId: widget.groupId,
          minResponders: _minR,
          maxResponders: effectiveMax,
          token: widget.requireToken(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
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
                      context.l10n.groupSettingsTitle,
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
              child: _loadingChars
                  ? Center(child: CircularProgressIndicator(color: c.character))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Text(
                          context.l10n.groupManagingCount(_roster.length),
                          style: mono(c, 10.5, color: c.ink3),
                        ),
                        const SizedBox(height: 10),
                        for (final ch in _characters)
                          CheckboxListTile(
                            value: _roster.contains(ch.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _roster.add(ch.id);
                              } else {
                                _roster.remove(ch.id);
                              }
                            }),
                            title: Text(ch.label, style: serif(c, 14)),
                            subtitle: Text(
                              ch.id,
                              style: mono(c, 10, color: c.ink3),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.groupMinResponders(_minR),
                          style: serif(c, 13, weight: FontWeight.w500),
                        ),
                        Slider(
                          value: _minR.toDouble().clamp(
                            1,
                            math.max(_roster.length, 1).toDouble(),
                          ),
                          min: 1,
                          max: math.max(_roster.length, 1).toDouble(),
                          divisions: math.max(_roster.length - 1, 1),
                          onChanged: (v) => setState(() {
                            _minR = v.round();
                            if (_maxR < _minR) _maxR = _minR;
                          }),
                        ),
                        Text(
                          context.l10n.groupMaxResponders(_maxR),
                          style: serif(c, 13, weight: FontWeight.w500),
                        ),
                        Slider(
                          value: _maxR.toDouble().clamp(
                            _minR.toDouble(),
                            math.max(_roster.length, 1).toDouble(),
                          ),
                          min: _minR.toDouble(),
                          max: math.max(_roster.length, 1).toDouble(),
                          divisions: math.max(_roster.length - _minR, 1),
                          onChanged: (v) => setState(() => _maxR = v.round()),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: mono(c, 11, color: c.danger)),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _saving ? null : () => unawaited(_save()),
                          child: Text(
                            _saving
                                ? context.l10n.savingAction
                                : context.l10n.saveAction,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 群聊梦境（desktop Brief 38/100 的 mobile 追加）───────────────────────────
//
// 桌面端靠 WebSocket 逐字推送；手机端和现实群聊一样没有 WS，靠轮询——但群梦是
// 异步整轮（POST /dream/send 立刻 202 式返回 {round_id, status}，真正回复要后台
// 生成完才追加进共享 transcript），跟现实群聊「发送后 2 秒轮询 GroupDetail.recent
// 直到条数变化就停」的一次性轮询不同：这里整个梦境会话期间持续轮询
// GET /dream/transcript?after=<cursor>，因为梦里角色之间也可能互相搭话，不是
// 严格「发一条收一条」。

class GroupDreamChatScreen extends StatefulWidget {
  const GroupDreamChatScreen({
    super.key,
    required this.c,
    required this.backend,
    required this.requireToken,
    required this.groupId,
    required this.groupTitle,
    required this.roster,
  });

  final YxPalette c;
  final BackendClient backend;
  final String Function() requireToken;
  final String groupId;
  final String groupTitle;
  final List<GroupRosterMember> roster;

  @override
  State<GroupDreamChatScreen> createState() => _GroupDreamChatScreenState();
}

class _GroupDreamChatScreenState extends State<GroupDreamChatScreen> {
  static const _pollInterval = Duration(seconds: 3);
  static const _waitingTimeout = Duration(seconds: 45);

  final List<GroupDreamMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;
  int _cursor = 0;
  bool _entering = true;
  bool _active = false;
  bool _sending = false;
  bool _waitingReply = false;
  bool _exiting = false;
  DateTime? _waitingDeadline;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_enterAndStart());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _enterAndStart() async {
    setState(() {
      _entering = true;
      _error = null;
    });
    try {
      final ok = await widget.backend.groupDreamEnter(
        groupId: widget.groupId,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = context.l10n.groupDreamEnterFailed);
        return;
      }
      _active = true;
      _startPolling();
    } on BackendException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // 本群已有进行中的梦境（比如桌面端已经先入梦）——直接接上轮询，
        // 不当成错误：手机端和桌面端是同一份共享梦境状态。
        _active = true;
        _startPolling();
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _entering = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    unawaited(_pollTranscript());
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_pollTranscript()));
  }

  Future<void> _pollTranscript() async {
    if (!mounted) return;
    try {
      final page = await widget.backend.groupDreamTranscript(
        groupId: widget.groupId,
        after: _cursor,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      final hadNew = page.entries.isNotEmpty;
      setState(() {
        _messages.addAll(page.entries);
        _cursor = page.cursor;
        if (hadNew) _waitingReply = false;
        if (_waitingReply &&
            _waitingDeadline != null &&
            DateTime.now().isAfter(_waitingDeadline!)) {
          _waitingReply = false;
        }
        if (page.status != 'DREAM_ACTIVE' && page.status != 'DREAM_CLOSING') {
          // 梦境被别的端（多半是桌面）结束了：停止轮询，锁住输入，但保留已经
          // 看到的发言，不强行退出这个页面——用户自己按返回。
          _active = false;
          _pollTimer?.cancel();
        }
      });
      if (hadNew) _scrollToBottomSoon();
    } catch (_) {
      // 轮询失败静默重试，跟现实群聊一致——不用每次网络抖动都弹错误。
    }
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || !_active) return;
    _controller.clear();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.backend.groupDreamSend(
        groupId: widget.groupId,
        content: text,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() {
        _waitingReply = true;
        _waitingDeadline = DateTime.now().add(_waitingTimeout);
      });
      unawaited(_pollTranscript());
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.groupDreamExitConfirmTitle),
        content: Text(context.l10n.groupDreamExitConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.groupDreamExitAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    setState(() => _exiting = true);
    _pollTimer?.cancel();
    try {
      await widget.backend.groupDreamExit(
        groupId: widget.groupId,
        token: widget.requireToken(),
      );
    } catch (_) {
      // 后端离线也允许离开——跟单人 Dream 页一致。
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_active) {
          Navigator.of(context).pop();
          return;
        }
        final shouldPop = await _confirmExit();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          backgroundColor: c.characterDeep,
          foregroundColor: c.characterOn,
          title: Text(
            context.l10n.groupDreamTitle,
            style: serif(c, 16, weight: FontWeight.w600, color: c.characterOn),
          ),
          leading: IconButton(
            icon: Icon(_exiting ? Icons.hourglass_top_rounded : Icons.arrow_back_rounded),
            onPressed: _exiting
                ? null
                : () async {
                    if (!_active) {
                      Navigator.of(context).pop();
                      return;
                    }
                    final shouldPop = await _confirmExit();
                    if (shouldPop && context.mounted) Navigator.of(context).pop();
                  },
          ),
        ),
        body: SafeArea(
          child: _entering
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bedtime_outlined, size: 38, color: c.character),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.groupDreamEntering,
                        style: serif(c, 14, color: c.ink2),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(_error!, style: mono(c, 11, color: c.danger)),
                      ),
                    if (!_active)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          context.l10n.groupDreamBlockedHint,
                          style: mono(c, 10, color: c.ink3),
                        ),
                      ),
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Text(
                                context.l10n.groupDreamSendToStart,
                                style: serif(c, 13, color: c.ink3)
                                    .copyWith(fontStyle: FontStyle.italic),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final prevSpeaker = index > 0
                                    ? _messages[index - 1].speakerId
                                    : null;
                                final showLabel = !msg.isOwner &&
                                    msg.speakerId != prevSpeaker;
                                final member = widget.roster
                                    .where((m) => m.charId == msg.speakerId)
                                    .firstOrNull;
                                return _GroupDreamBubble(
                                  c: c,
                                  message: msg,
                                  showLabel: showLabel,
                                  speakerLabel: member?.label ?? msg.speakerId,
                                );
                              },
                            ),
                    ),
                    if (_waitingReply)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          context.l10n.groupDreamMembersResponding,
                          style: mono(c, 10, color: c.ink3),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              enabled: _active,
                              minLines: 1,
                              maxLines: 3,
                              style: serif(c, 14),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: context.l10n.groupDreamSendHint,
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
                            onPressed: _active && !_sending
                                ? () => unawaited(_send())
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GroupDreamBubble extends StatelessWidget {
  const _GroupDreamBubble({
    required this.c,
    required this.message,
    required this.showLabel,
    required this.speakerLabel,
  });

  final YxPalette c;
  final GroupDreamMessage message;
  final bool showLabel;
  final String speakerLabel;

  @override
  Widget build(BuildContext context) {
    if (message.isOwner) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          decoration: BoxDecoration(
            color: c.send,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(message.content, style: serif(c, 13.5, color: c.surface)),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLabel)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 2),
                child: Text(
                  speakerLabel,
                  style: mono(c, 9, color: c.character, weight: FontWeight.w600),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.characterSoft,
                border: Border(left: BorderSide(color: c.character, width: 3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                message.content,
                style: serif(c, 13.5, color: c.ink1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
