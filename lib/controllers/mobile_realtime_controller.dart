import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../models/session_scope.dart';
import '../services/backend_client.dart';
import '../services/mobile_realtime_socket.dart';

/// Foreground subscription only. Existing HTTP/inbox owns all delivery ACKs.
class MobileRealtimeController {
  MobileRealtimeController({
    required this.backend,
    required this.token,
    required this.grant,
    required this.apply,
    required this.isLive,
  });
  final BackendClient Function() backend;
  final String? Function() token;
  final Future<PresenceSessionGrant?> Function() grant;
  final void Function(Map<String, dynamic>) apply;
  final bool Function() isLive;
  final String _clientId = mintRequestId();
  MobileRealtimeSocket? _socket;
  Timer? _retry;
  int _epoch = 0;
  int _failures = 0;
  bool _active = false;
  bool _starting = false;
  String state = 'http';
  int reconnects = 0;
  int historyPages = 0;
  int finalFrames = 0;
  int? _newestRecovered;
  Future<void>? _recovery;
  BackendClient? _openingBackend;
  BackendClient? _workBackend;

  void start() {
    if (_active) return;
    _active = true;
    unawaited(_connect(_epoch));
  }

  void stop({bool reset = false}) {
    _active = false;
    _epoch++;
    _retry?.cancel();
    _retry = null;
    _socket?.close();
    _socket = null;
    _openingBackend?.cancelMobileRealtime();
    _openingBackend = null;
    _workBackend?.cancelMobileReceive();
    _workBackend = null;
    _starting = false;
    _recovery = null;
    if (reset) _newestRecovered = null;
    state = 'http';
  }

  bool _live(int epoch) => _active && epoch == _epoch && isLive();

  Future<void> _connect(int epoch) async {
    if (!_live(epoch) || _starting) return;
    _starting = true;
    final access = token();
    final client = backend();
    _workBackend = client;
    var delay = const Duration(seconds: 30);
    try {
      if (access == null) return;
      final scope = await grant();
      if (!_live(epoch) || scope == null) return;
      final capability = await client.mobileRealtimeCapability(token: access);
      if (!_live(epoch)) return;
      // Recover even when the server operator disables WS.
      await _recover(client, access, scope, epoch);
      if (!_live(epoch)) return;
      if (capability['enabled'] != true ||
          capability['protocol'] != 'mobile-final-v1') {
        state = 'http_disabled';
        return;
      }
      _openingBackend = client;
      final connectClock = Stopwatch()..start();
      final socket = await client.openMobileRealtime(
        token: access,
        sessionId: scope.sessionId,
        clientId: _clientId,
      );
      if (epoch == _epoch) _openingBackend = null;
      if (!_live(epoch)) {
        socket.close();
        return;
      }
      _socket = socket;
      String? generation;
      await for (final raw in socket.frames.timeout(
        const Duration(seconds: 45),
      )) {
        if (!_live(epoch) ||
            token() != access ||
            !identical(backend(), client)) {
          break;
        }
        if (raw is! String || raw.length > 2 * 1024 * 1024) {
          throw const FormatException('frame');
        }
        final frame = jsonDecode(raw);
        if (frame is! Map ||
            frame['char_id'] != scope.charId ||
            frame['domain'] != 'reality' ||
            frame['client_type'] != 'mobile') {
          throw const FormatException('scope');
        }
        if (frame['type'] == 'ready') {
          if (generation != null ||
              frame['session_id'] != scope.sessionId ||
              frame['mode'] != 'final_only' ||
              frame['generation'] is! String) {
            throw const FormatException('ready');
          }
          generation = frame['generation'] as String;
          _failures = 0;
          state = 'final_only';
          reconnects++;
          _metric(
            client,
            access,
            'connect_ms',
            connectClock.elapsedMilliseconds,
          );
          socket.pong(generation);
          // Close the history -> handshake race, without blocking frame receive.
          unawaited(
            _recover(client, access, scope, epoch).catchError((Object _) {}),
          );
        } else if (generation == null || frame['generation'] != generation) {
          throw const FormatException('generation');
        } else if (frame['type'] == 'ping') {
          socket.pong(generation);
        } else if (frame['type'] == 'final' && frame['message'] is Map) {
          final message = Map<String, dynamic>.from(frame['message'] as Map);
          if (_accept(message, scope)) {
            finalFrames++;
            apply(message);
          }
        } else {
          throw const FormatException('unsupported frame');
        }
      }
      if (_live(epoch)) await _recover(client, access, scope, epoch);
    } on BackendException catch (error) {
      if (_live(epoch)) state = 'http_fallback';
      // Old endpoints/auth failures do not trigger a fast reconnect loop.
      if (error.statusCode == 401 ||
          error.statusCode == 403 ||
          error.statusCode == 404) {
        delay = const Duration(minutes: 1);
      }
    } catch (_) {
      if (_live(epoch)) state = 'http_fallback';
      if (_live(epoch) && access != null) {
        _metric(client, access, 'fallback', 1);
      }
      _failures = math.min(_failures + 1, 5);
      delay = Duration(seconds: (1 << _failures) + math.Random().nextInt(3));
    } finally {
      if (epoch == _epoch) {
        _socket?.close();
        _socket = null;
        _starting = false;
        if (_live(epoch)) {
          _retry = Timer(delay, () => unawaited(_connect(epoch)));
        }
      }
    }
  }

  bool _accept(Map<String, dynamic> message, PresenceSessionGrant scope) =>
      message['critical_written'] == true &&
      message['domain'] == 'reality' &&
      message['char_id'] == scope.charId &&
      message['user_id'] == scope.ownerId &&
      message['turn_id'] is String &&
      (message['turn_id'] as String).isNotEmpty &&
      message['msg_id'] == message['turn_id'] &&
      message['id'] == message['turn_id'] &&
      !message.containsKey('seq');

  Future<void> _recover(
    BackendClient client,
    String access,
    PresenceSessionGrant scope,
    int epoch,
  ) {
    if (_recovery != null) return _recovery!;
    late final Future<void> work;
    work = _readHistory(client, access, scope, epoch).whenComplete(() {
      if (identical(_recovery, work)) _recovery = null;
    });
    _recovery = work;
    return work;
  }

  Future<void> _readHistory(
    BackendClient client,
    String access,
    PresenceSessionGrant scope,
    int epoch,
  ) async {
    int? before;
    int? newest;
    final pages = <Map<String, dynamic>>[];
    final prior = _newestRecovered;
    do {
      final page = await client.mobileFinalHistory(
        token: access,
        sessionId: scope.sessionId,
        before: before,
      );
      if (!_live(epoch) || token() != access || !identical(backend(), client)) {
        return;
      }
      historyPages++;
      final messages = (page['messages'] as List).cast<Map>();
      for (final item in messages) {
        final row = Map<String, dynamic>.from(item);
        final index = row['history_index'] as int;
        newest ??= index;
        if (prior != null && index <= prior) continue;
        if (_accept(row, scope)) pages.add(row);
      }
      final next = page['next_before'] as int?;
      if (next != null && before != null && next >= before) {
        throw const FormatException('history pagination');
      }
      before =
          (prior == null ||
              messages.any((m) => (m['history_index'] as int) <= prior))
          ? null
          : next;
    } while (before != null && _live(epoch));
    if (!_live(epoch)) return;
    for (final row in pages.reversed) {
      apply(row);
    }
    if (pages.isNotEmpty) {
      _metric(client, access, 'recovered_messages', pages.length);
    }
    if (newest != null) _newestRecovered = newest;
  }

  void _metric(BackendClient client, String access, String kind, int value) {
    unawaited(
      client
          .reportMobileRealtimeMetric(
            kind,
            value.clamp(0, 600000),
            token: access,
          )
          .catchError((Object _) {}),
    );
  }
}
