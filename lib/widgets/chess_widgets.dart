import 'dart:async';

import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../l10n/l10n.dart';
import '../services/backend_client.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/common_widgets.dart';

const String _chessStartFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// FEN 的棋子摆放段解析成 8x8 网格；index [0][0] 是 a8（左上），[7][7] 是 h1（右下）。
List<List<String?>> _parseFenBoard(String fen) {
  final placement = fen.split(' ').firstOrNull ?? '';
  final ranks = placement.split('/');
  final board = List<List<String?>>.generate(
    8,
    (_) => List<String?>.filled(8, null),
  );
  for (var r = 0; r < ranks.length && r < 8; r++) {
    var col = 0;
    for (final ch in ranks[r].split('')) {
      final digit = int.tryParse(ch);
      if (digit != null) {
        col += digit;
      } else if (col < 8) {
        board[r][col] = ch;
        col++;
      }
    }
  }
  return board;
}

String _squareName(int row, int col) {
  final file = String.fromCharCode('a'.codeUnitAt(0) + col);
  final rank = 8 - row;
  return '$file$rank';
}

String _pieceGlyph(String piece) {
  const glyphs = {
    'P': '♙',
    'N': '♘',
    'B': '♗',
    'R': '♖',
    'Q': '♕',
    'K': '♔',
    'p': '♟',
    'n': '♞',
    'b': '♝',
    'r': '♜',
    'q': '♛',
    'k': '♚',
  };
  return glyphs[piece] ?? '';
}

class ChessScreen extends StatefulWidget {
  const ChessScreen({
    super.key,
    required this.c,
    required this.backend,
    required this.requireToken,
  });

  final YxPalette c;
  final BackendClient backend;
  final String Function() requireToken;

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  ChessState? _state;
  List<String> _legalMoves = const [];
  String? _selected;
  bool _loading = true;
  bool _busy = false;
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
      final state = await widget.backend.chessState(
        token: widget.requireToken(),
      );
      if (!mounted) return;
      final active = state.isActive;
      setState(() {
        _state = active ? state : null;
        _error = null;
      });
      if (active) {
        await _loadLegalMoves(state.sessionId!);
        if (state.pendingAiTurn) unawaited(_triggerAiMove());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLegalMoves(String sessionId) async {
    try {
      final moves = await widget.backend.chessLegalMoves(
        sessionId: sessionId,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() => _legalMoves = moves);
    } on BackendException {
      // 只读辅助信息，失败不阻塞棋局本身
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _selected = null;
    });
    try {
      final state = await widget.backend.chessStart(
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() {
        _state = state;
        _history.clear();
      });
      if (state.sessionId != null) await _loadLegalMoves(state.sessionId!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _triggerAiMove() async {
    final sessionId = _state?.sessionId;
    if (sessionId == null) return;
    try {
      final state = await widget.backend.chessAiMove(
        sessionId: sessionId,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() => _state = state);
      if (state.result == null) await _loadLegalMoves(sessionId);
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _submitMove(String uci) async {
    final state = _state;
    if (state == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _selected = null;
    });
    try {
      final newState = await widget.backend.chessMove(
        sessionId: state.sessionId!,
        uci: uci,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() => _state = newState);
      if (newState.result == null) {
        await _loadLegalMoves(state.sessionId!);
        if (newState.pendingAiTurn) await _triggerAiMove();
      } else {
        setState(() => _legalMoves = const []);
      }
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onSquareTap(int row, int col) {
    if (_busy || _state == null) return;
    final square = _squareName(row, col);
    final selected = _selected;
    if (selected == null) {
      final hasMoveFrom = _legalMoves.any((m) => m.startsWith(square));
      if (hasMoveFrom) setState(() => _selected = square);
      return;
    }
    if (selected == square) {
      setState(() => _selected = null);
      return;
    }
    final candidates = _legalMoves.where(
      (m) => m.startsWith(selected) && m.substring(2, 4) == square,
    );
    if (candidates.isEmpty) {
      // 点了别的己方棋子 → 重新选中；否则视为取消
      final hasMoveFrom = _legalMoves.any((m) => m.startsWith(square));
      setState(() => _selected = hasMoveFrom ? square : null);
      return;
    }
    // 兵到底线的升变默认走后（q），与桌面端一致的简化策略
    final uci = candidates.length == 1
        ? candidates.first
        : candidates.firstWhere(
            (m) => m.endsWith('q'),
            orElse: () => candidates.first,
          );
    unawaited(_submitMove(uci));
  }

  Future<void> _close() async {
    final sessionId = _state?.sessionId;
    if (sessionId == null) return;
    setState(() => _busy = true);
    try {
      await widget.backend.chessClose(
        sessionId: sessionId,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() {
        _state = null;
        _legalMoves = const [];
      });
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
    final l10n = context.l10n;
    try {
      final result = await widget.backend.chessChat(
        sessionId: sessionId,
        message: message,
        token: widget.requireToken(),
      );
      return result.reply;
    } on BackendException catch (e) {
      return l10n.sendFailedMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = widget.c;
    final state = _state;
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.ink1,
        title: Text(
          l10n.chessTitle,
          style: serif(c, 16, weight: FontWeight.w600),
        ),
        actions: [
          if (state != null)
            TextButton(
              onPressed: _busy ? null : () => unawaited(_close()),
              child: Text(l10n.endAction, style: mono(c, 11, color: c.danger)),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: c.character))
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Text(_error!, style: mono(c, 11, color: c.danger)),
                      const SizedBox(height: 12),
                    ],
                    if (state == null) ...[
                      Text(
                        l10n.chessIntro,
                        style: serif(
                          c,
                          13.5,
                          color: c.ink2,
                        ).copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : () => unawaited(_start()),
                        child: Text(l10n.startGameAction),
                      ),
                    ] else ...[
                      Text(
                        state.result != null
                            ? l10n.chessGameOver(state.result!)
                            : l10n.chessTurn(
                                state.turn == 'white'
                                    ? l10n.whiteSide
                                    : l10n.blackSide,
                              ),
                        style: mono(c, 11, color: c.ink3),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _ChessBoard(
                              c: c,
                              board: _parseFenBoard(
                                state.fen.isEmpty ? _chessStartFen : state.fen,
                              ),
                              selected: _selected,
                              legalTargets: _selected == null
                                  ? const {}
                                  : _legalMoves
                                        .where((m) => m.startsWith(_selected!))
                                        .map((m) => m.substring(2, 4))
                                        .toSet(),
                              onTap: _onSquareTap,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      floatingActionButton: state != null
          ? FloatingActionButton(
              backgroundColor: c.character,
              onPressed: () => unawaited(
                ActivityChatSheet.open(
                  context: context,
                  c: c,
                  title: l10n.gameChatTitle,
                  messages: _history,
                  onSend: _sendChat,
                ),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            )
          : null,
    );
  }
}

class _ChessBoard extends StatelessWidget {
  const _ChessBoard({
    required this.c,
    required this.board,
    required this.selected,
    required this.legalTargets,
    required this.onTap,
  });

  final YxPalette c;
  final List<List<String?>> board;
  final String? selected;
  final Set<String> legalTargets;
  final void Function(int row, int col) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.surfaceEdge, width: 2),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: 64,
        itemBuilder: (context, index) {
          final row = index ~/ 8;
          final col = index % 8;
          final square = _squareName(row, col);
          final isDark = (row + col) % 2 == 1;
          final isSelected = selected == square;
          final isTarget = legalTargets.contains(square);
          final piece = board[row][col];
          return GestureDetector(
            onTap: () => onTap(row, col),
            child: Container(
              color: isSelected
                  ? c.character.withValues(alpha: 0.45)
                  : isTarget
                  ? c.character.withValues(alpha: 0.22)
                  : isDark
                  ? const Color(0xFFB58863)
                  : const Color(0xFFF0D9B5),
              alignment: Alignment.center,
              child: piece == null
                  ? (isTarget
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.character.withValues(alpha: 0.6),
                            ),
                          )
                        : null)
                  : Text(
                      _pieceGlyph(piece),
                      style: const TextStyle(fontSize: 26),
                    ),
            ),
          );
        },
      ),
    );
  }
}
