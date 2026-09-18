import 'package:flutter/foundation.dart';

import '../app_constants.dart';
import '../services/app_settings_store.dart';
import '../services/backend_client.dart';
import '../services/device_services.dart';

class ConnectionController extends ChangeNotifier {
  ConnectionController({
    required AppSettingsStore settingsStore,
    BackendClient? backendClient,
  }) : _settingsStore = settingsStore,
       _injectedBackend = backendClient,
       _backend =
           backendClient ??
           BackendClient(
             baseUrl: defaultBackendBaseUrl,
             settingsStore: settingsStore,
           );

  final AppSettingsStore _settingsStore;
  late final SettingsStore settings = SettingsStore(_settingsStore);
  late final RelayStatusService relay = RelayStatusService(_settingsStore);
  final BackendClient? _injectedBackend;
  BackendClient _backend;

  String baseUrl = defaultBackendBaseUrl;
  String token = '';
  String ownerUserId = '';
  Set<String> trustedCleartextOrigins = const {};
  String relayBaseUrl = '';
  String relayTopic = '';
  String relayToken = '';

  BackendClient get backend => _backend;
  bool get hasToken => token.trim().isNotEmpty;

  Future<void> restore() async {
    final values = await Future.wait<dynamic>([
      settings.loadBackendBaseUrl(),
      settings.loadToken(),
      settings.loadOwnerUserId(),
      _settingsStore.loadTrustedCleartextOrigins(),
      relay.loadBaseUrl(),
      relay.loadTopic(),
      relay.loadToken(),
    ]);
    final storedUrl = (values[0] as String?)?.trim();
    token = (values[1] as String?)?.trim() ?? '';
    ownerUserId = (values[2] as String?)?.trim() ?? '';
    trustedCleartextOrigins = values[3] as Set<String>;
    relayBaseUrl = (values[4] as String?)?.trim() ?? '';
    relayTopic = (values[5] as String?)?.trim() ?? '';
    relayToken = (values[6] as String?)?.trim() ?? '';
    if (storedUrl != null && storedUrl.isNotEmpty) baseUrl = storedUrl;
    _rebuildBackend();
    notifyListeners();
  }

  /// Persist first, then memory. Same value is a no-op. Failed writes leave
  /// the previous in-memory credential so native and Dart cannot diverge.
  Future<bool> saveToken(String value) async {
    final next = value.trim();
    if (next == token) return false;
    await settings.saveToken(next);
    token = next;
    notifyListeners();
    return true;
  }

  Future<bool> saveOwnerUserId(String value) async {
    final next = value.trim();
    if (next == ownerUserId) return false;
    await settings.saveOwnerUserId(next);
    ownerUserId = next;
    notifyListeners();
    return true;
  }

  Future<bool> saveBaseUrl(String value) async {
    final next = value.trim();
    if (next == baseUrl) return false;
    await settings.saveBackendBaseUrl(next);
    baseUrl = next;
    _rebuildBackend();
    notifyListeners();
    return true;
  }

  Future<String?> normalizeBaseUrl(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final withScheme =
        RegExp(r'^https?://', caseSensitive: false).hasMatch(value)
        ? value
        : 'http://$value';
    return _settingsStore.normalizeOrigin(withScheme);
  }

  Future<bool> isAllowedBaseUrl(String value) =>
      _settingsStore.isAllowedBaseUrl(value);
  Future<bool> canConfirmPrivateCleartextOrigin(String value) =>
      _settingsStore.isConfirmablePrivateCleartextOrigin(value);

  Future<bool> trustCleartextOrigin(String value) async {
    final added = await _settingsStore.addTrustedCleartextOrigin(value);
    if (added) {
      trustedCleartextOrigins = {...trustedCleartextOrigins, value};
      notifyListeners();
    }
    return added;
  }

  Future<void> saveRelay({
    required String baseUrl,
    required String topic,
    required String token,
  }) async {
    relayBaseUrl = baseUrl.trim();
    relayTopic = topic.trim();
    relayToken = token.trim();
    await Future.wait([
      relay.saveBaseUrl(relayBaseUrl),
      relay.saveTopic(relayTopic),
      relay.saveToken(relayToken),
    ]);
    notifyListeners();
  }

  void _rebuildBackend() {
    _backend =
        _injectedBackend ??
        BackendClient(baseUrl: baseUrl, settingsStore: _settingsStore);
  }
}
