// Request-layer tests for BackendClient. BackendClient talks to dart:io's
// HttpClient directly (no package:http), so these fakes implement just
// enough of the abstract dart:io HTTP interfaces (via `noSuchMethod`
// forwarding for the unused surface) to drive `_request` end to end without
// a real socket.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, String> values = {};
  ContentType? _contentType;

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) => _contentType = value;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value.toString();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this._client);

  final _FakeHttpClient _client;
  final BytesBuilder _body = BytesBuilder();

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  void write(Object? object) => _body.add(utf8.encode(object.toString()));

  @override
  void add(List<int> data) => _body.add(data);

  @override
  Future<HttpClientResponse> close() async {
    _client.lastRequestHeaders = (headers as _FakeHttpHeaders).values;
    _client.lastRequestBody = utf8.decode(_body.toBytes());
    final error = _client.errorOnClose;
    if (error != null) throw error;
    return _FakeHttpClientResponse(_client.statusCode, _client.responseBody);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, String body)
    : _bytes = utf8.encode(body);

  @override
  final int statusCode;
  final List<int> _bytes;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([
      _bytes,
    ]).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake dart:io [HttpClient]. Configure [statusCode]/[responseBody] for the
/// happy path, or [errorOnClose] to make the request fail as if the socket
/// itself misbehaved (network error, timeout, ...).
class _FakeHttpClient implements HttpClient {
  int statusCode = 200;
  String responseBody = '{}';
  Object? errorOnClose;

  String? method;
  Uri? requestedUri;
  Map<String, String> lastRequestHeaders = {};
  String lastRequestBody = '';

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    method = 'GET';
    requestedUri = url;
    return _FakeHttpClientRequest(this);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    method = 'POST';
    requestedUri = url;
    return _FakeHttpClientRequest(this);
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) async {
    method = 'PATCH';
    requestedUri = url;
    return _FakeHttpClientRequest(this);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AllowedSettingsStore extends AppSettingsStore {
  const _AllowedSettingsStore();

  @override
  Future<bool> isAllowedBaseUrl(String raw) async => true;
}

class _DisallowedSettingsStore extends AppSettingsStore {
  const _DisallowedSettingsStore();

  @override
  Future<bool> isAllowedBaseUrl(String raw) async => false;
}

void main() {
  const baseUrl = 'http://127.0.0.1:8080';
  late _FakeHttpClient fakeClient;
  late BackendClient backend;

  setUp(() {
    fakeClient = _FakeHttpClient();
    backend = BackendClient(
      baseUrl: baseUrl,
      settingsStore: const _AllowedSettingsStore(),
      httpClientFactory: () => fakeClient,
    );
  });

  group('base url 拼接与鉴权前置检查', () {
    test('GET requests hit baseUrl + path with a Bearer token header', () async {
      fakeClient.responseBody = jsonEncode({'entries': []});
      await backend.loadGardenState(token: 'tok-1');

      expect(fakeClient.method, 'GET');
      expect(fakeClient.requestedUri, Uri.parse('$baseUrl/garden/state'));
      expect(fakeClient.lastRequestHeaders['authorization'], 'Bearer tok-1');
    });

    test('POST requests send a JSON body to the expected path', () async {
      fakeClient.responseBody = jsonEncode({'reply': 'hi'});
      await backend.sendChat('hello', token: 'tok-1');

      expect(fakeClient.method, 'POST');
      expect(fakeClient.requestedUri, Uri.parse('$baseUrl/mobile/chat'));
      expect(jsonDecode(fakeClient.lastRequestBody), {'message': 'hello'});
    });

    test('an empty token is rejected before any request is made', () async {
      await expectLater(
        backend.loadGardenState(token: ''),
        throwsA(
          isA<BackendException>().having(
            (e) => e.message,
            'message',
            'Please enter an access credential first',
          ),
        ),
      );
      expect(fakeClient.requestedUri, isNull);
    });

    test('an untrusted base url is rejected before any request is made', () async {
      final untrusted = BackendClient(
        baseUrl: baseUrl,
        settingsStore: const _DisallowedSettingsStore(),
        httpClientFactory: () => fakeClient,
      );
      await expectLater(
        untrusted.loadGardenState(token: 'tok-1'),
        throwsA(
          isA<BackendException>().having(
            (e) => e.message,
            'message',
            'Backend origin is not trusted',
          ),
        ),
      );
      expect(fakeClient.requestedUri, isNull);
    });
  });

  group('正常 JSON 解析', () {
    test('a 200 response with a JSON object body parses into the model', () async {
      fakeClient.responseBody = jsonEncode({
        'entries': [
          {'date': '2026-07-01'},
        ],
      });
      final state = await backend.loadGardenState(token: 'tok-1');
      expect(state, isNotNull);
    });

    test('a 200 response whose body is not a JSON object is rejected', () async {
      fakeClient.responseBody = jsonEncode([1, 2, 3]);
      await expectLater(
        backend.loadGardenState(token: 'tok-1'),
        throwsA(
          isA<BackendException>().having(
            (e) => e.message,
            'message',
            '后端返回格式不是 JSON object',
          ),
        ),
      );
    });
  });

  group('非 200 走错误提取', () {
    test('a non-2xx response throws a BackendException carrying the status and detail', () async {
      fakeClient.statusCode = 403;
      fakeClient.responseBody = jsonEncode({
        'detail': 'insufficient scope, need: hardware',
      });
      await expectLater(
        backend.loadGardenState(token: 'tok-1'),
        throwsA(
          isA<BackendException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having(
                (e) => e.message,
                'message',
                'token 权限不足：insufficient scope, need: hardware',
              ),
        ),
      );
    });

    test('a 401 response reports the invalid-token message', () async {
      fakeClient.statusCode = 401;
      fakeClient.responseBody = '{}';
      await expectLater(
        backend.loadGardenState(token: 'tok-1'),
        throwsA(
          isA<BackendException>().having(
            (e) => e.message,
            'message',
            'token 无效，请检查系统设置里的 token',
          ),
        ),
      );
    });
  });

  group('超时/网络异常路径', () {
    test('a socket error surfaces as the "can\'t reach backend" message', () async {
      fakeClient.errorOnClose = const SocketException('connection refused');
      await expectLater(
        backend.loadGardenState(token: 'tok-1'),
        throwsA(
          isA<BackendException>().having(
            (e) => e.message,
            'message',
            '连不上后端：请确认后端已启动，或 adb reverse 已生效',
          ),
        ),
      );
    });

    test('a timeout surfaces as the timeout message', () async {
      fakeClient.errorOnClose = TimeoutException('mock timeout');
      await expectLater(
        backend.loadGardenState(token: 'tok-1'),
        throwsA(
          isA<BackendException>().having(
            (e) => e.message,
            'message',
            '后端响应超时',
          ),
        ),
      );
    });

    test('a body that is not valid JSON surfaces as the malformed-JSON message', () async {
      fakeClient.responseBody = 'not json';
      await expectLater(
        backend.loadGardenState(token: 'tok-1'),
        throwsA(
          isA<BackendException>().having(
            (e) => e.message,
            'message',
            '后端返回不是有效 JSON',
          ),
        ),
      );
    });
  });
}
