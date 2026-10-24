import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';

class _AllowedStore extends AppSettingsStore {
  @override
  Future<bool> isAllowedBaseUrl(String raw) async => true;
}

void main() {
  test(
    'CONNECT black hole is bounded before request.close is reached',
    () async {
      final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      final connected = Completer<void>();
      final disconnected = Completer<void>();
      proxy.listen((socket) {
        sockets.add(socket);
        socket.listen(
          (data) {
            if (String.fromCharCodes(data).startsWith('CONNECT ') &&
                !connected.isCompleted) {
            connected.complete();
          }
          },
          onError: (Object _) {},
          onDone: () {
            if (!disconnected.isCompleted) disconnected.complete();
          },
        );
      });
      final backend = BackendClient(
        baseUrl: 'https://audit.invalid',
        settingsStore: _AllowedStore(),
        httpClientFactory: () =>
            HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:${proxy.port}',
      );
      try {
        final request = backend.downloadChatArtifact(
          '/chat/artifacts/${'a' * 32}',
          token: 'fixture',
          timeout: const Duration(milliseconds: 200),
        );
        final check = expectLater(
          request.timeout(const Duration(seconds: 2)),
          throwsA(isA<BackendException>()),
        );
        await connected.future.timeout(const Duration(seconds: 1));
        await check;
        await disconnected.future.timeout(const Duration(seconds: 1));
      } finally {
        for (final socket in sockets) {
          socket.destroy();
        }
        await proxy.close();
      }
    },
  );

  test(
    'cancelling receive closes the old poll, preserves send and permits a new poll',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final pollStarted = Completer<void>();
      final sendStarted = Completer<HttpRequest>();
      var polls = 0;
      server.listen((request) async {
        if (request.uri.path == '/mobile/chat') {
          sendStarted.complete(request);
        } else if (++polls == 1) {
          pollStarted.complete();
        } else {
          request.response.write('{"ok":true,"active":true,"messages":[]}');
          await request.response.close();
        }
      });
      final backend = BackendClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        settingsStore: _AllowedStore(),
      );
      try {
        final first = backend.pollMobile(token: 'fixture');
        final checked = expectLater(
          first,
          throwsA(isA<BackendRequestCancelled>()),
        );
        final send = backend.sendChat('fixture', token: 'fixture');
        await pollStarted.future;
        final incoming = await sendStarted.future;
        backend.cancelMobileReceive();
        await checked.timeout(const Duration(seconds: 1));
        incoming.response.write(
          '{"reply":"accepted","turn_id":"turn-fixture"}',
        );
        await incoming.response.close();
        expect((await send).reply, 'accepted');
        expect((await backend.pollMobile(token: 'fixture')).ok, isTrue);
        expect(polls, 2);
      } finally {
        await server.close(force: true);
      }
    },
  );

  test('canonical media body stall obeys the whole request deadline', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.contentLength = 100;
      request.response.add([1]);
      await request.response.flush();
    });
    final backend = BackendClient(
      baseUrl: 'http://127.0.0.1:${server.port}',
      settingsStore: _AllowedStore(),
    );
    try {
      await expectLater(
        backend
            .downloadChatMedia(
              'a' * 64,
              token: 'fixture',
              timeout: const Duration(milliseconds: 200),
            )
            .timeout(const Duration(seconds: 2)),
        throwsA(isA<BackendException>()),
      );
    } finally {
      await server.close(force: true);
    }
  });
}
