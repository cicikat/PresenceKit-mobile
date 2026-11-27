import 'dart:async';
import '../services/backend_client.dart';
import '../models/session_scope.dart';

/// Independent from mobile ACK/seq. Polling recovers dropped control hints.
class ConversationControl {
  ConversationControl({
    required this.backend,
    required this.token,
    required this.grant,
    required this.scopeKey,
    required this.changed,
  });
  final BackendClient Function() backend;
  final String? Function() token;
  final Future<PresenceSessionGrant> Function() grant;
  final String Function() scopeKey;
  final void Function(bool refresh) changed;
  final Set<String> hidden = {};
  final Set<String> hiddenRequests = {};
  List<Map<String, dynamic>> executions = [];
  List<Map<String, dynamic>> terminals = [];
  Map<String, dynamic>? get stopTarget {
    for (final state in ['running', 'stop_requested', 'queued']) {
      for (final row in executions) {
        if (row['state'] == state) return row;
      }
    }
    return null;
  }

  Timer? _timer;
  Future<void>? _reading;
  bool _live = false;
  int? _revision;
  final Map<String, String> operations = {};
  void start() {
    _live = true;
    if (_timer != null) return;
    unawaited(sync().catchError((Object _) {}));
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(sync().catchError((Object _) {})),
    );
  }

  void stop({bool reset = false}) {
    _live = false;
    _timer?.cancel();
    _timer = null;
    if (reset) {
      hidden.clear();
      hiddenRequests.clear();
      executions = [];
      terminals = [];
      _revision = null;
      operations.clear();
    }
  }

  Future<void> sync() {
    final old = _reading;
    if (old != null) return old;
    final work = _sync();
    _reading = work;
    return work.whenComplete(() => _reading = null);
  }

  Future<void> _sync() async {
    final access = token();
    if (access == null || !_live) return;
    final key = scopeKey();
    final scope = await grant();
    if (!_live || key != scopeKey()) return;
    final state = await backend().conversationState(
      token: access,
      sessionId: scope.sessionId,
    );
    if (!_live || key != scopeKey()) return;
    final revision = state['revision'] as int;
    final refresh = _revision != null && _revision != revision;
    _revision = revision;
    hidden
      ..clear()
      ..addAll(
        (state['visibility'] as List)
            .whereType<Map>()
            .where((item) => item['hidden'] == 1)
            .map((item) => item['turn_id'] as String),
      );
    executions = (state['executions'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    hiddenRequests
      ..clear()
      ..addAll(
        (state['withdrawn_requests'] as List? ?? []).whereType<String>(),
      );
    terminals = (state['recent_terminal'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    changed(refresh);
  }

  Future<void> action(
    String action,
    String id, {
    Map<String, dynamic>? body,
  }) async {
    final key = scopeKey();
    final access = token();
    if (access == null) throw StateError('unavailable');
    final scope = await grant();
    if (key != scopeKey()) throw StateError('scope_changed');
    final result = await backend().conversationAction(
      action,
      id,
      token: access,
      sessionId: scope.sessionId,
      body: body,
    );
    if (key != scopeKey()) throw StateError('scope_changed');
    // Never treat repair_pending as a completed deletion.
    if (action == 'delete' && result['state'] != 'completed') {
      throw StateError('repair_pending');
    }
    if (action == 'delete') {
      hidden.add(id);
      operations.remove(id);
    }
    changed(true);
    await _reading;
    await sync();
  }
}
