import 'dart:async';

import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/app_settings_store.dart';
import '../services/backend_client.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/common_widgets.dart';
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({
    super.key,
    required this.c,
    required this.backend,
    required this.requireToken,
    this.settingsStore = const AppSettingsStore(),
  });

  final YxPalette c;
  final BackendClient backend;
  final String Function() requireToken;
  final AppSettingsStore settingsStore;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  ReadingState? _state;
  ReadingPageResult? _page;
  List<ReadingLibraryBook> _books = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final List<ActivityChatMessage> _history = [];

  @override
  void initState() {
    super.initState();
    unawaited(_refreshAll());
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    try {
      final state = await widget.backend.readingState(
        token: widget.requireToken(),
      );
      ReadingPageResult? page;
      if (state.isActive) {
        page = await widget.backend.readingPage(
          sessionId: state.sessionId!,
          page: state.currentPage,
          token: widget.requireToken(),
        );
      }
      final books = await widget.backend.readingLibrary(
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() {
        _state = state;
        _page = page;
        _books = books;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addBook() async {
    final picked = await widget.settingsStore.pickPdfFile();
    if (picked == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.backend.readingAddBook(
        bytes: picked.bytes,
        filename: picked.name,
        token: widget.requireToken(),
      );
      final books = await widget.backend.readingLibrary(
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() => _books = books);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBook(ReadingLibraryBook book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除《${book.title}》？'),
        content: const Text('此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.backend.readingDeleteBook(
        bookId: book.bookId,
        token: widget.requireToken(),
      );
      final books = await widget.backend.readingLibrary(
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() => _books = books);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startReading(ReadingLibraryBook book) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = await widget.backend.readingStartFromLibrary(
        bookId: book.bookId,
        token: widget.requireToken(),
      );
      ReadingPageResult? page;
      if (state.isActive) {
        page = await widget.backend.readingPage(
          sessionId: state.sessionId!,
          page: state.currentPage,
          token: widget.requireToken(),
        );
      }
      if (!mounted) return;
      setState(() {
        _state = state;
        _page = page;
        _history.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnPage(String direction) async {
    final sessionId = _state?.sessionId;
    if (sessionId == null) return;
    setState(() => _busy = true);
    try {
      final page = await widget.backend.readingTurnPage(
        sessionId: sessionId,
        direction: direction,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        _state = _state == null
            ? null
            : ReadingState(
                sessionId: _state!.sessionId,
                title: _state!.title,
                currentPage: page.page,
                totalPages: page.totalPages,
                status: _state!.status,
              );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeReading() async {
    final sessionId = _state?.sessionId;
    if (sessionId == null) return;
    setState(() => _busy = true);
    try {
      await widget.backend.readingClose(
        sessionId: sessionId,
        token: widget.requireToken(),
      );
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _sendChat(String message) async {
    final sessionId = _state?.sessionId;
    if (sessionId == null) return null;
    try {
      final result = await widget.backend.readingChat(
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
    final active = _state?.isActive == true;
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.ink1,
        title: Text(
          active ? (_state?.title ?? '阅读中') : '一起看书',
          style: serif(c, 16, weight: FontWeight.w600),
        ),
        actions: [
          if (active)
            TextButton(
              onPressed: _busy ? null : () => unawaited(_closeReading()),
              child: Text('关闭', style: mono(c, 11, color: c.danger)),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: c.character))
            : active
            ? _buildReadingView(c)
            : _buildLibraryView(c),
      ),
      floatingActionButton: active
          ? FloatingActionButton(
              backgroundColor: c.character,
              onPressed: () => unawaited(
                ActivityChatSheet.open(
                  context: context,
                  c: c,
                  title: '看书聊天',
                  messages: _history,
                  onSend: _sendChat,
                ),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            )
          : null,
    );
  }

  Widget _buildLibraryView(YxPalette c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_error!, style: mono(c, 11, color: c.danger)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '书库',
                  style: mono(c, 11, color: c.ink3).copyWith(letterSpacing: 1.2),
                ),
              ),
              TextButton.icon(
                onPressed: _busy ? null : () => unawaited(_addBook()),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(_busy ? '添加中…' : '添加 PDF'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _books.isEmpty
              ? Center(
                  child: Text(
                    '书库还是空的，先添加一本 PDF 吧',
                    style: serif(c, 13, color: c.ink3).copyWith(fontStyle: FontStyle.italic),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _books.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    return InkWell(
                      onTap: _busy ? null : () => unawaited(_startReading(book)),
                      onLongPress: _busy ? null : () => unawaited(_deleteBook(book)),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title.isNotEmpty
                                        ? book.title
                                        : book.filename,
                                    style: serif(c, 14, weight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${book.totalPages ?? '?'} 页 · 长按删除',
                                    style: mono(c, 9.5, color: c.ink3),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: c.ink3),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReadingView(YxPalette c) {
    final page = _page;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '第 ${_state?.currentPage ?? '?'} 页 / 共 ${_state?.totalPages ?? '?'} 页',
            style: mono(c, 10.5, color: c.ink3),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              page?.text ?? '加载页面内容…',
              style: serif(c, 15, color: c.ink1).copyWith(height: 1.75),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy || (_state?.currentPage ?? 1) <= 1
                      ? null
                      : () => unawaited(_turnPage('prev')),
                  child: const Text('← 上一页'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _busy ||
                          (_state?.currentPage ?? 0) >=
                              (_state?.totalPages ?? 0)
                      ? null
                      : () => unawaited(_turnPage('next')),
                  child: const Text('下一页 →'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
