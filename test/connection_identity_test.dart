import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/connection_controller.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';

class _Store extends AppSettingsStore {
  String token = 'old-token';
  String owner = 'owner-a';
  String baseUrl = 'http://127.0.0.1:8080';
  bool failToken = false;
  bool failOwner = false;
  bool failUrl = false;

  @override
  Future<String?> loadAdminToken() async => token;

  @override
  Future<void> saveAdminToken(String value) async {
    if (failToken) {
      throw PlatformException(code: 'credential_write_failed');
    }
    token = value;
  }

  @override
  Future<String?> loadOwnerUserId() async => owner;

  @override
  Future<void> saveOwnerUserId(String value) async {
    if (failOwner) {
      throw PlatformException(code: 'owner_write_failed');
    }
    owner = value;
  }

  @override
  Future<String?> loadBackendBaseUrl() async => baseUrl;

  @override
  Future<void> saveBackendBaseUrl(String value) async {
    if (failUrl) {
      throw PlatformException(code: 'untrusted_backend');
    }
    baseUrl = value;
  }

  @override
  Future<Set<String>> loadTrustedCleartextOrigins() async => const {};

  @override
  Future<String?> loadRelayBaseUrl() async => '';

  @override
  Future<String?> loadRelayTopic() async => '';

  @override
  Future<String?> loadRelayToken() async => '';
}

void main() {
  late _Store store;
  late ConnectionController controller;

  setUp(() {
    store = _Store();
    controller = ConnectionController(settingsStore: store);
  });

  test('same-value token save is idempotent', () async {
    await controller.restore();
    expect(await controller.saveToken('old-token'), isFalse);
    expect(controller.token, 'old-token');
    expect(store.token, 'old-token');
  });

  test('failed token persist leaves memory and native on the old value', () async {
    await controller.restore();
    store.failToken = true;
    await expectLater(
      controller.saveToken('new-token'),
      throwsA(isA<PlatformException>()),
    );
    expect(controller.token, 'old-token');
    expect(store.token, 'old-token');
  });

  test('successful token replace updates memory only after persist', () async {
    await controller.restore();
    expect(await controller.saveToken('new-token'), isTrue);
    expect(controller.token, 'new-token');
    expect(store.token, 'new-token');
  });

  test('owner and node persist failures do not half-switch', () async {
    await controller.restore();
    store.failOwner = true;
    await expectLater(
      controller.saveOwnerUserId('owner-b'),
      throwsA(isA<PlatformException>()),
    );
    expect(controller.ownerUserId, 'owner-a');
    expect(store.owner, 'owner-a');

    store.failUrl = true;
    await expectLater(
      controller.saveBaseUrl('http://127.0.0.1:9090'),
      throwsA(isA<PlatformException>()),
    );
    expect(controller.baseUrl, 'http://127.0.0.1:8080');
    expect(store.baseUrl, 'http://127.0.0.1:8080');
  });
}
