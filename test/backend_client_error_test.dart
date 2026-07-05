import 'package:flutter_test/flutter_test.dart';
import 'package:yexuan_memery/services/backend_client.dart';

void main() {
  group('BackendClient.debugExtractError', () {
    test('401 reports an invalid token regardless of body', () {
      expect(
        BackendClient.debugExtractError('{}', 401),
        'token 无效，请检查系统设置里的 token',
      );
    });

    test('403 reports insufficient scope and includes the backend detail', () {
      final message = BackendClient.debugExtractError(
        '{"detail": "insufficient scope, need: hardware"}',
        403,
      );
      expect(message, 'token 权限不足：insufficient scope, need: hardware');
    });

    test('403 without a JSON body still reports insufficient scope', () {
      expect(
        BackendClient.debugExtractError('', 403),
        'token 权限不足：HTTP 403',
      );
    });

    test('429 reports the rate limit message regardless of body', () {
      expect(
        BackendClient.debugExtractError('{"detail": "ignored"}', 429),
        '认证失败过多，来源已被临时限制，稍后再试',
      );
    });

    test('other status codes fall back to the detail field', () {
      expect(
        BackendClient.debugExtractError('{"detail": "boom"}', 500),
        'boom',
      );
    });

    test('other status codes fall back to the HTTP line without a body', () {
      expect(BackendClient.debugExtractError('not json', 500), 'HTTP 500');
    });
  });
}
