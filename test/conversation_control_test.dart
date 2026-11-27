import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/conversation_control.dart';
import 'package:presencekit_mobile/models/session_scope.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';

class _Store extends AppSettingsStore {
  @override
  Future<bool> isAllowedBaseUrl(String baseUrl) async => true;
}

class _RealHttp extends HttpOverrides {}

void main() {
  test('stop chooses only the running request, not later queued inputs', () {
    final control = ConversationControl(
      backend: () => throw UnimplementedError(),
      token: () => null,
      grant: () => throw UnimplementedError(),
      scopeKey: () => '',
      changed: (_) {},
    );
    final running = {
      'execution_id': 'current',
      'request_id': 'running_fixture',
      'state': 'running',
    };
    control.executions = [
      {
        'execution_id': 'later',
        'request_id': 'queued_fixture',
        'state': 'queued',
      },
      running,
    ];
    expect(control.stopTarget, same(running));
    control.executions = [
      {...running, 'state': 'committing'},
    ];
    expect(control.stopTarget, isNull);
  });

  test(
    'control HTTP uses frozen session, exact IDs and restores visibility without ACK',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final seen = <String>[];
      var revision = 1;
      var hidden = false;
      final completedOperations = <String>{};
      const grant = PresenceSessionGrant(
        sessionId: 'session_fixture',
        charId: 'character_fixture',
        ownerId: 'owner_fixture',
        domain: 'reality',
      );
      server.listen((request) async {
        expect(request.headers.value('authorization'), 'Bearer token_fixture');
        expect(request.headers.value('x-presence-session'), grant.sessionId);
        seen.add('${request.method} ${request.uri.path}');
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/conversation/state') {
          request.response.write(
            jsonEncode({
              'revision': revision,
              'executions': [],
              'visibility': [
                {
                  'turn_id': 'turn_fixture',
                  'hidden': hidden ? 1 : 0,
                  'revision': revision,
                },
              ],
            }),
          );
        } else {
          final body =
              jsonDecode(await utf8.decoder.bind(request).join()) as Map;
          final operation = body['operation_id'] as String;
          final fresh = completedOperations.add(operation);
          if (fresh) {
            hidden = true;
            revision++;
          }
          request.response.write(
            jsonEncode({'state': fresh ? 'completed' : 'restored'}),
          );
        }
        await request.response.close();
      });
      final backend = BackendClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        settingsStore: _Store(),
        httpClientFactory: () =>
            HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttp()),
      );
      var refreshes = 0;
      final control = ConversationControl(
        backend: () => backend,
        token: () => 'token_fixture',
        grant: () async => grant,
        scopeKey: () => 'fixture',
        changed: (refresh) {
          if (refresh) refreshes++;
        },
      );
      try {
        control.start();
        await control.sync();
        expect(control.hidden, isEmpty);
        control.operations['turn_fixture'] = 'operation_fixture';
        await control.action(
          'delete',
          'turn_fixture',
          body: {'operation_id': 'operation_fixture'},
        );
        expect(control.hidden, {'turn_fixture'});
        hidden = false;
        revision++;
        await control.sync();
        expect(control.hidden, isEmpty);
        // A restored round must accept a new delete in this same app session;
        // reusing the old retry identity returns its prior restored outcome.
        final nextOperation = control.operations.putIfAbsent(
          'turn_fixture',
          () => 'operation_second',
        );
        await control.action(
          'delete',
          'turn_fixture',
          body: {'operation_id': nextOperation},
        );
        expect(control.hidden, {'turn_fixture'});
        expect(completedOperations, {'operation_fixture', 'operation_second'});
        expect(refreshes, greaterThanOrEqualTo(2));
        expect(seen, contains('POST /conversation/turns/turn_fixture/delete'));
        expect(seen.any((path) => path.contains('/ack')), isFalse);
      } finally {
        control.stop();
        await server.close(force: true);
      }
    },
  );
}
