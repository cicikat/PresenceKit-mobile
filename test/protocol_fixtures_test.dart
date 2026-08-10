import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/models/app_models.dart';

String _fixtureRoot() {
  final configured = Platform.environment['PRESENCEKIT_PROTOCOL_FIXTURES'];
  if (configured != null && configured.trim().isNotEmpty) return configured;
  final sibling = Directory.current.parent.path;
  return '$sibling${Platform.pathSeparator}Emerald-presence${Platform.pathSeparator}'
      'tests${Platform.pathSeparator}protocol_fixtures${Platform.pathSeparator}v1';
}

Map<String, dynamic> _load(String name) {
  final path = '${_fixtureRoot()}${Platform.pathSeparator}$name';
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  test('mobile consumer reads the canonical v1 fixture manifest', () {
    final manifest = _load('manifest.json');
    expect(manifest['fixture_version'], 'v1');
    expect(manifest['schema_version'], '1');
    expect(manifest['source_of_truth'], 'Emerald-presence');
    final cases = (manifest['cases'] as List).cast<Map>();
    expect(
      cases.map((item) => item['id']),
      containsAll(<String>['mobile-chat-success', 'mobile-poll-and-ack']),
    );
  });

  test('mobile chat fixture parses through the production response model', () {
    final fixture = _load('mobile_http.json');
    final body = Map<String, dynamic>.from(fixture['response']['body'] as Map);
    final response = BackendChatResponse.fromJson(body);
    expect(response.reply, 'fixture assistant reply');
    expect(response.msgId, 'turn-fixture-001');
    expect(response.turnId, 'turn-fixture-001');
  });

  test('mobile poll fixture parses after explicit timestamp normalization', () {
    final fixture = _load('mobile_queue.json');
    final poll = Map<String, dynamic>.from(fixture['poll_response']['body'] as Map);
    final message = Map<String, dynamic>.from((poll['messages'] as List).single as Map)
      ..['timestamp'] = 1700000000.0;
    poll['messages'] = <Map<String, dynamic>>[message];
    final result = MobilePollResult.fromJson(poll);
    expect(result.ok, isTrue);
    expect(result.cursor, 41);
    expect(result.messages.single.id, 'queue-fixture-001');
    expect(result.messages.single.seq, 41);
    expect(result.messages.single.content, 'fixture proactive message');
  });

  test('mobile valid chat body contains no forbidden caller-controlled fields', () {
    final fixture = _load('mobile_http.json');
    final security = _load('security.json');
    final forbidden = (security['forbidden_client_fields'] as List).cast<String>().toSet();
    final body = (fixture['request']['body'] as Map).keys.cast<String>();
    expect(body.any(forbidden.contains), isFalse);
  });
}
