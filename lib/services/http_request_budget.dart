import 'dart:async';
import 'dart:io';

/// One request owns its sockets. Cancelling a poll cannot cancel a chat send.
class HttpRequestBudget {
  HttpRequestBudget(this.client, Duration total) {
    _timer = Timer(total, () => _stop(TimeoutException('request deadline')));
  }

  final HttpClient client;
  final Completer<void> _stopped = Completer<void>();
  late final Timer _timer;
  Object? _reason;
  bool _closed = false;

  void check() {
    if (_reason != null) throw _reason!;
  }

  Future<T> wait<T>(Future<T> pending) async {
    try {
      check();
      return await Future.any<T>([
        pending,
        _stopped.future.then<T>((_) => throw _reason!),
      ]);
    } catch (_) {
      check();
      rethrow;
    }
  }

  Future<T> open<T>(Future<T> pending) async {
    final timer = Timer(const Duration(seconds: 8), () {
      _stop(TimeoutException('connection deadline'));
    });
    try {
      return await wait(pending);
    } finally {
      timer.cancel();
    }
  }

  void cancel() => _stop(const HttpRequestCancelled());

  void _stop(Object reason) {
    if (_closed || _reason != null) return;
    _reason = reason;
    _stopped.complete();
    close();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _timer.cancel();
    client.close(force: true);
  }
}

class HttpRequestCancelled implements Exception {
  const HttpRequestCancelled();
}
