import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/diary_controller.dart';
import 'package:presencekit_mobile/controllers/garden_controller.dart';
import 'package:presencekit_mobile/controllers/profile_appearance_controller.dart';
import 'package:presencekit_mobile/controllers/profile_status_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/session_scope.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Store extends AppSettingsStore {
  final Map<String, String> sessionCharacters = {};

  String _sessionKey({String? origin, String? owner}) =>
      '${origin ?? ''}|${owner ?? ''}';

  @override
  Future<String?> loadSessionCharacterId({
    String? origin,
    String? owner,
  }) async => sessionCharacters[_sessionKey(origin: origin, owner: owner)];

  @override
  Future<void> saveSessionCharacterId(
    String? characterId, {
    String? origin,
    String? owner,
  }) async {
    final key = _sessionKey(origin: origin, owner: owner);
    if (characterId == null || characterId.trim().isEmpty) {
      sessionCharacters.remove(key);
    } else {
      sessionCharacters[key] = characterId.trim();
    }
  }

  @override
  Future<ChatAppearanceSettings> loadChatAppearance() async =>
      const ChatAppearanceSettings();

  @override
  Future<YxPrefs> loadAppearancePrefs() async => const YxPrefs();

  @override
  Future<Uint8List?> loadDreamBackground() async => null;

  @override
  Future<String?> loadProfileDisplayName({String? characterId}) async => null;

  @override
  Future<Uint8List?> loadProfileAvatar({String? characterId}) async => null;

  @override
  Future<void> cacheCharacterDisplayName(String value) async {}
}

class _Backend extends BackendClient {
  _Backend()
    : super(
        baseUrl: 'http://127.0.0.1:8080',
        settingsStore: const AppSettingsStore(),
      );

  Completer<void>? diaryGate;
  Completer<void>? gardenGate;
  Completer<void>? statusGate;
  Completer<void>? assetsGate;
  int diaryLoads = 0;
  int gardenLoads = 0;
  int statusLoads = 0;
  int assetLoads = 0;
  DiaryListItem lateDiary = const DiaryListItem(
    date: '2026-01-01',
    title: 'stale',
    emotion: null,
  );
  GardenState lateGarden = const GardenState(
    slots: [],
    harvestCount: 9,
    vaseCount: 1,
  );

  @override
  Future<List<DiaryListItem>> loadDiaryList({required String token}) async {
    diaryLoads += 1;
    await diaryGate?.future;
    return [lateDiary];
  }

  @override
  Future<GardenState> loadGardenState({required String token}) async {
    gardenLoads += 1;
    await gardenGate?.future;
    return lateGarden;
  }

  @override
  Future<ActivityCurrentState> loadActivityCurrent({
    required String token,
  }) async {
    statusLoads += 1;
    await statusGate?.future;
    return const ActivityCurrentState(text: 'stale', arc: null);
  }

  @override
  Future<MoodStateSnapshot> loadMoodState({required String token}) async {
    await statusGate?.future;
    return const MoodStateSnapshot(current: 'stale', intensity: 0.1);
  }

  @override
  Future<PromptAssets> loadPromptAssets({required String token}) async {
    assetLoads += 1;
    await assetsGate?.future;
    return const PromptAssets(
      characters: [PromptAssetOption(id: 'char-a', label: 'Ava')],
      activeCharacter: 'char-a',
    );
  }

  @override
  Future<SessionScopeCapability> loadSessionScopeCapability({
    required String token,
  }) async => const SessionScopeCapability(supported: true, version: 'v1');

  @override
  Future<PresenceSessionGrant> createPresenceSession({
    required String token,
    required String charId,
  }) async => PresenceSessionGrant(
    sessionId: 'sess-$charId',
    charId: charId,
    ownerId: 'owner',
    domain: 'reality',
  );
}

void main() {
  test('late diary success cannot clear a newer generation busy flag', () async {
    final firstGate = Completer<void>();
    final backend = _Backend()..diaryGate = firstGate;
    final controller = DiaryController(
      backend: () => backend,
      token: () => 'token',
    );
    final first = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.loading, isTrue);
    controller.invalidateForIdentityChange();
    expect(controller.loading, isFalse);
    expect(controller.entries, isEmpty);
    final secondGate = Completer<void>();
    backend.diaryGate = secondGate;
    backend.lateDiary = const DiaryListItem(
      date: '2026-02-02',
      title: 'fresh',
      emotion: null,
    );
    final second = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.loading, isTrue);
    firstGate.complete();
    await first;
    expect(controller.loading, isTrue);
    expect(controller.entries, isEmpty);
    secondGate.complete();
    await second;
    expect(controller.loading, isFalse);
    expect(controller.entries.single.title, 'fresh');
    controller.dispose();
  });

  test('late garden success does not restore a cleared identity', () async {
    final backend = _Backend()..gardenGate = Completer<void>();
    final controller = GardenController(
      backend: () => backend,
      token: () => 'token',
    );
    final first = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.invalidateForIdentityChange();
    backend.gardenGate!.complete();
    await first;
    expect(controller.state, isNull);
    expect(controller.loading, isFalse);
    controller.dispose();
  });

  test('late profile status cannot overwrite a newer identity', () async {
    final backend = _Backend()..statusGate = Completer<void>();
    final controller = ProfileStatusController(
      backend: () => backend,
      token: () => 'token',
    );
    final first = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.invalidateForIdentityChange();
    backend.statusGate!.complete();
    await first;
    expect(controller.activityCurrent, isNull);
    expect(controller.loading, isFalse);
    controller.dispose();
  });

  test('identity change drops prompt assets and allows a later load', () async {
    final store = _Store()..sessionCharacters['http://a|owner-b'] = 'char-b';
    String origin = 'http://a';
    String owner = 'owner-a';
    final backend = _Backend()..assetsGate = Completer<void>();
    final controller = ProfileAppearanceController(
      settings: SettingsStore(store),
      backend: () => backend,
      token: () => 'token',
      origin: () => origin,
      owner: () => owner,
    );
    final first = controller.loadPromptAssets();
    await Future<void>.delayed(Duration.zero);
    expect(controller.loadingPromptAssets, isTrue);
    owner = 'owner-b';
    await controller.invalidateForIdentityChange(realmChanged: true);
    expect(controller.promptAssets, isNull);
    expect(controller.presenceGrant, isNull);
    expect(controller.loadingPromptAssets, isFalse);
    expect(controller.sessionCharacterId, 'char-b');
    backend.assetsGate!.complete();
    await first;
    expect(controller.promptAssets, isNull);
    backend.assetsGate = null;
    await controller.loadPromptAssets();
    expect(controller.promptAssets?.activeCharacter, 'char-a');
    expect(controller.loadingPromptAssets, isFalse);
    controller.dispose();
  });
}
