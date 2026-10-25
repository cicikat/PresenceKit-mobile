import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Owns both upgrade and transport resources. Closing never cancels chat HTTP.
class MobileRealtimeSocket {
  MobileRealtimeSocket(this.socket, this.client);
  final WebSocket socket;
  final HttpClient client;
  Stream<dynamic> get frames => socket;

  static Future<MobileRealtimeSocket> connect(
    Uri endpoint, {
    required String token,
    required String sessionId,
    required String clientId,
    required HttpClient client,
  }) async {
    client.connectionTimeout = const Duration(seconds: 8);
    var expired = false;
    final attempt = WebSocket.connect(
      endpoint.toString(),
      customClient: client,
      headers: {
        'Authorization': 'Bearer $token',
        'X-Presence-Session': sessionId,
        'X-Presence-Client': clientId,
      },
    );
    // Future.timeout alone would leak a late upgrade socket.
    unawaited(
      attempt.then<void>((socket) {
        if (expired) unawaited(socket.close());
      }, onError: (Object _) {}),
    );
    try {
      final socket = await attempt.timeout(const Duration(seconds: 10));
      socket.pingInterval = const Duration(seconds: 20);
      return MobileRealtimeSocket(socket, client);
    } catch (_) {
      expired = true;
      client.close(force: true);
      rethrow;
    }
  }

  void pong(String generation) =>
      socket.add(jsonEncode({'type': 'pong', 'generation': generation}));

  void close() {
    unawaited(socket.close());
    client.close(force: true);
  }
}
