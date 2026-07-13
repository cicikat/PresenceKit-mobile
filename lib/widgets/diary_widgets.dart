import 'dart:async';

import 'package:flutter/material.dart';
import '../controllers/diary_controller.dart';
import '../models/app_models.dart';

import '../widgets/common_widgets.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({
    super.key,
    required this.c,
    required this.profileDisplayName,
    required this.controller,
    required this.onBack,
  });

  final YxPalette c;
  final String profileDisplayName;
  final DiaryController controller;
  List<DiaryListItem> get entries => controller.entries;
  bool get loading => controller.loading;
  bool get loaded => controller.loaded;
  String? get error => controller.error;
  Future<void> onRefresh({bool silent = false}) =>
      controller.load(silent: silent);
  Future<DiaryDetail> onLoadEntry(String date) => controller.loadEntry(date);
  final VoidCallback onBack;

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  String _query = '';
  String _filter = '全部';

  @override
  void initState() {
    super.initState();
    if (!widget.loaded && !widget.loading) {
      unawaited(widget.onRefresh(silent: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final emotions = [
      '全部',
      ...{
        for (final entry in widget.entries)
          if (entry.emotion != null && entry.emotion!.trim().isNotEmpty)
            entry.emotion!,
      },
    ];
    if (!emotions.contains(_filter)) _filter = '全部';
    final filtered = widget.entries.where((entry) {
      if (_filter != '全部' && entry.emotion != _filter) return false;
      if (_query.trim().isEmpty) return true;
      final blob = '${entry.title} ${entry.date} ${entry.emotion ?? ''}'
          .toLowerCase();
      return blob.contains(_query.trim().toLowerCase());
    }).toList();
    return Column(
      children: [
        PageHeader(
          c: widget.c,
          title: '日记',
          eyebrow: '${widget.profileDisplayName} · 私写',
          onBack: widget.onBack,
          trailing: widget.loading
              ? '同步中'
              : widget.loaded
              ? '${filtered.length}/${widget.entries.length}'
              : '日记',
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          color: widget.c.surfaceSoft,
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            style: mono(widget.c, 12),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search_rounded, color: widget.c.ink3),
              hintText: '搜索 · 关键词 / 日期 / 心情',
              hintStyle: mono(widget.c, 12, color: widget.c.ink3),
              border: InputBorder.none,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          width: double.infinity,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final mood in emotions)
                ChoiceChip(
                  label: Text(mood),
                  selected: _filter == mood,
                  onSelected: (_) => setState(() => _filter = mood),
                ),
              ActionChip(
                avatar: widget.loading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.c.character,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('刷新'),
                onPressed: widget.loading
                    ? null
                    : () => unawaited(widget.onRefresh()),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody(filtered)),
      ],
    );
  }

  Widget _buildBody(List<DiaryListItem> filtered) {
    if (widget.error != null && !widget.loaded) {
      return DiaryEmptyState(
        c: widget.c,
        icon: Icons.cloud_off_outlined,
        text: widget.error!,
        actionLabel: '重试',
        onAction: () => unawaited(widget.onRefresh()),
      );
    }
    if (widget.loading && !widget.loaded) {
      return DiaryEmptyState(
        c: widget.c,
        icon: Icons.hourglass_empty_rounded,
        text: '正在从后端读取日记列表…',
      );
    }
    if (filtered.isEmpty) {
      return DiaryEmptyState(
        c: widget.c,
        icon: Icons.menu_book_outlined,
        text: widget.entries.isEmpty ? '他还没开始写日记。' : '找不到对应的日记。',
      );
    }
    return RefreshIndicator(
      color: widget.c.character,
      onRefresh: widget.onRefresh,
      child: ListView(
        children: [
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                '最近刷新失败：${widget.error}',
                style: mono(widget.c, 10.5, color: widget.c.danger),
              ),
            ),
          for (final entry in filtered)
            DiaryCard(
              c: widget.c,
              entry: entry,
              onTap: () => _openEntry(entry),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'END OF JOURNAL',
                  style: mono(widget.c, 10, color: widget.c.ink4),
                ),
                const SizedBox(height: 6),
                Text(
                  '点开条目后再读取正文。',
                  style: serif(
                    widget.c,
                    13,
                    color: widget.c.ink3,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openEntry(DiaryListItem entry) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          DiaryDialog(c: widget.c, item: entry, loadEntry: widget.onLoadEntry),
    );
  }
}

class DiaryCard extends StatelessWidget {
  const DiaryCard({
    super.key,
    required this.c,
    required this.entry,
    required this.onTap,
  });

  final YxPalette c;
  final DiaryListItem entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: _emotionColor(c, entry.emotion), width: 3),
            bottom: BorderSide(color: c.ink4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDiaryDate(entry.date),
                    style: mono(c, 11, color: c.ink3),
                  ),
                ),
                if (entry.emotion != null) ...[
                  const SizedBox(width: 6),
                  YxTag(c: c, text: entry.emotion!, variant: 'warm'),
                ],
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: c.ink4, size: 20),
              ],
            ),
            Text(entry.title, style: serif(c, 17, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              '点击读取正文',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: serif(c, 13.5, color: c.ink2),
            ),
            const SizedBox(height: 8),
            Text('READ FULL ENTRY →', style: mono(c, 9, color: c.ink4)),
          ],
        ),
      ),
    );
  }
}

class DiaryDialog extends StatelessWidget {
  const DiaryDialog({
    super.key,
    required this.c,
    required this.item,
    required this.loadEntry,
  });

  final YxPalette c;
  final DiaryListItem item;
  final Future<DiaryDetail> Function(String date) loadEntry;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: c.ink1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: c.characterDeep,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDiaryDate(item.date),
                      style: mono(
                        c,
                        10,
                        color: c.characterOn.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                  IconButton(
                    color: c.characterOn,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<DiaryDetail>(
                future: loadEntry(item.date),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('加载中…', style: mono(c, 12, color: c.ink3)),
                    );
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '加载失败：${snapshot.error ?? '无数据'}',
                        style: serif(c, 14, color: c.danger),
                      ),
                    );
                  }
                  final entry = snapshot.data!;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry.emotion != null)
                          YxTag(c: c, text: entry.emotion!, variant: 'warm'),
                        const SizedBox(height: 12),
                        Text(
                          entry.title,
                          style: serif(c, 22, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        for (final block in _diaryBodyBlocks(entry.body))
                          DiaryBodyBlock(c: c, text: block),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DiaryBodyBlock extends StatelessWidget {
  const DiaryBodyBlock({super.key, required this.c, required this.text});

  final YxPalette c;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Text(
          text.substring(3),
          style: serif(c, 17, weight: FontWeight.w600),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: serif(c, 15.5)),
    );
  }
}

class DiaryEmptyState extends StatelessWidget {
  const DiaryEmptyState({
    super.key,
    required this.c,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final YxPalette c;
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c.ink4, size: 30),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: serif(
                c,
                14,
                color: c.ink3,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDiaryDate(String date) {
  final parts = date.split('-');
  if (parts.length != 3) return date;
  final month = int.tryParse(parts[1]) ?? 0;
  final day = int.tryParse(parts[2]) ?? 0;
  if (month <= 0 || day <= 0) return date;
  return '${parts[0]}年$month月$day日';
}

List<String> _diaryBodyBlocks(String body) {
  return body
      .split(RegExp(r'\n\s*\n+'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty)
      .toList(growable: false);
}

Color _emotionColor(YxPalette c, String? emotion) {
  if (emotion == null) return Colors.transparent;
  return switch (emotion) {
    '日常' => c.ok,
    '心情' => c.warn,
    '私语' => c.character,
    '梦境' => const Color(0xFF5B7BA0),
    '杂记' => c.send,
    _ => c.character,
  };
}
