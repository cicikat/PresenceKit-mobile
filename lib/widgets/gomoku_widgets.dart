import 'dart:async';

import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/backend_client.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/common_widgets.dart';
class GomokuScreen extends StatefulWidget {
  const GomokuScreen({
    super.key,
    required this.c,
    required this.backend,
    required this.requireToken,
  });

  final YxPalette c;
  final BackendClient backend;
  final String Function() requireToken;

  @override
  State<GomokuScreen> createState() => _GomokuScreenState();
}

class _GomokuScreenState extends State<GomokuScreen> {
  GomokuState? _state;
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
      final state = await widget.backend.gomokuState(
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() {
        _state = state.isActive ? state : null;
        _error = null;
      });
      if (state.isActive && state.pendingAiTurn) {
        unawaited(_triggerAiMove());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = await widget.backend.gomokuStart(
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _triggerAiMove() async {
    final sessionId = _state?.sessionId;
    if (sessionId == null) return;
    try {
      final state = await widget.backend.gomokuAiMove(
        sessionId: sessionId,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() => _state = state);
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _place(int x, int y) async {
    final state = _state;
    if (state == null || _busy) return;
    if (state.winner != null) return;
    if (y >= state.board.length || x >= state.board[y].length) return;
    if (state.board[y][x] != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final newState = await widget.backend.gomokuMove(
        sessionId: state.sessionId!,
        x: x,
        y: y,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() => _state = newState);
      if (newState.pendingAiTurn && newState.winner == null) {
        await _triggerAiMove();
      }
    } on BackendException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    final sessionId = _state?.sessionId;
    if (sessionId == null) return;
    setState(() => _busy = true);
    try {
      await widget.backend.gomokuClose(
        sessionId: sessionId,
        token: widget.requireToken(),
      );
      if (!mounted) return;
      setState(() => _state = null);
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
      final result = await widget.backend.gomokuChat(
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
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.ink1,
        title: Text('五子棋', style: serif(c, 16, weight: FontWeight.w600)),
        actions: [
          if (state != null)
            TextButton(
              onPressed: _busy ? null : () => unawaited(_close()),
              child: Text('结束', style: mono(c, 11, color: c.danger)),
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
                        '和他下一局五子棋。你先手，触屏落子。',
                        style: serif(c, 13.5, color: c.ink2).copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : () => unawaited(_start()),
                        child: const Text('开局'),
                      ),
                    ] else ...[
                      Text(
                        state.winner != null
                            ? (state.winner == 'draw'
                                  ? '平局'
                                  : '${state.winner == 'black' ? '黑棋' : '白棋'} 获胜')
                            : '当前落子方：${state.currentTurn == 'black' ? '黑棋' : '白棋'}',
                        style: mono(c, 11, color: c.ink3),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _GomokuBoard(
                              c: c,
                              board: state.board,
                              onTap: _place,
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
                  title: '棋局闲聊',
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

class _GomokuBoard extends StatelessWidget {
  const _GomokuBoard({
    required this.c,
    required this.board,
    required this.onTap,
  });

  final YxPalette c;
  final List<List<String?>> board;
  final void Function(int x, int y) onTap;

  @override
  Widget build(BuildContext context) {
    final size = board.length;
    if (size == 0) {
      return Center(
        child: Text('棋盘加载中…', style: mono(c, 11, color: c.ink3)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE4C48C),
        border: Border.all(color: c.surfaceEdge, width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / size;
          return Stack(
            children: [
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _GomokuGridPainter(size: size),
              ),
              for (var y = 0; y < size; y++)
                for (var x = 0; x < board[y].length; x++)
                  if (board[y][x] != null)
                    Positioned(
                      left: x * cell,
                      top: y * cell,
                      width: cell,
                      height: cell,
                      child: Center(
                        child: Container(
                          width: cell * 0.82,
                          height: cell * 0.82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: board[y][x] == 'black'
                                ? Colors.black87
                                : Colors.white,
                            border: board[y][x] == 'white'
                                ? Border.all(color: Colors.black26)
                                : null,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final x = (details.localPosition.dx / cell).floor().clamp(
                    0,
                    size - 1,
                  );
                  final y = (details.localPosition.dy / cell).floor().clamp(
                    0,
                    size - 1,
                  );
                  onTap(x, y);
                },
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GomokuGridPainter extends CustomPainter {
  const _GomokuGridPainter({required this.size});

  final int size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..color = Colors.black45
      ..strokeWidth = 1;
    final cell = canvasSize.width / size;
    for (var i = 0; i < size; i++) {
      final pos = cell * i + cell / 2;
      canvas.drawLine(
        Offset(pos, cell / 2),
        Offset(pos, canvasSize.height - cell / 2),
        paint,
      );
      canvas.drawLine(
        Offset(cell / 2, pos),
        Offset(canvasSize.width - cell / 2, pos),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GomokuGridPainter oldDelegate) =>
      oldDelegate.size != size;
}
