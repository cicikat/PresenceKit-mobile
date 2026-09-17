import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/profile_appearance_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/session_scope.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Store extends AppSettingsStore {
  final Map<String?, String> names = {};
  final Map<String?, Uint8List> avatars = {};
  final Map<String, String> sessionCharacters = {};
  ChatAppearanceSettings appearance = const ChatAppearanceSettings();
  YxPrefs prefs = const YxPrefs();
  Uint8List? dreamBackground;
  String? cachedName;
  Uint8List? pickedProfile;
  Uint8List? pickedBackground;
  bool failAvatarSave = false;
  bool failAppearanceSave = false;

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
  Future<String?> loadProfileDisplayName({String? characterId}) async =>
      names[characterId];

  @override
  Future<void> saveProfileDisplayName(
    String value, {
    String? characterId,
  }) async {
    names[characterId] = value;
  }

  @override
  Future<void> cacheCharacterDisplayName(String value) async {
    cachedName = value;
  }

  @override
  Future<Uint8List?> loadProfileAvatar({String? characterId}) async =>
      avatars[characterId];

  @override
  Future<bool> saveProfileAvatar(Uint8List bytes, {String? characterId}) async {
    if (failAvatarSave) return false;
    avatars[characterId] = bytes;
    return true;
  }

  @override
  Future<void> deleteProfileAvatar({String? characterId}) async {
    avatars.remove(characterId);
  }

  @override
  Future<ChatAppearanceSettings> loadChatAppearance() async => appearance;

  @override
  Future<bool> saveChatAppearance(ChatAppearanceSettings value) async {
    if (failAppearanceSave) return false;
    appearance = value;
    return true;
  }

  @override
  Future<YxPrefs> loadAppearancePrefs() async => prefs;

  @override
  Future<void> saveAppearancePrefs(YxPrefs value) async {
    prefs = value;
  }

  @override
  Future<Uint8List?> loadDreamBackground() async => dreamBackground;

  @override
  Future<bool> saveDreamBackground(Uint8List bytes) async {
    dreamBackground = bytes;
    return true;
  }

  @override
  Future<void> deleteDreamBackground() async {
    dreamBackground = null;
  }

  @override
  Future<Uint8List?> pickProfileImage() async => pickedProfile;

  @override
  Future<Uint8List?> pickChatBackgroundImage() async => pickedBackground;
}

class _Backend extends BackendClient {
  _Backend()
    : super(
        baseUrl: 'http://127.0.0.1:8080',
        settingsStore: const AppSettingsStore(),
      );

  PromptAssets assets = const PromptAssets(
    characters: [
      PromptAssetOption(id: 'char-a', label: 'Ava'),
      PromptAssetOption(id: 'char-b', label: 'Blair'),
    ],
    activeCharacter: 'char-a',
  );
  int loads = 0;
  int updates = 0;
  int sessionBinds = 0;
  bool sessionScopeSupported = true;
  String? lastBoundCharId;
  Future<void> Function()? loadHook;
  BackendException? sessionBindError;

  @override
  Future<PromptAssets> loadPromptAssets({required String token}) async {
    loads += 1;
    final hook = loadHook;
    if (hook != null) await hook();
    return assets;
  }

  @override
  Future<PromptAssets> updatePromptAssets({
    required String token,
    String? activeCharacter,
  }) async {
    updates += 1;
    assets = PromptAssets(
      characters: assets.characters,
      activeCharacter: activeCharacter ?? assets.activeCharacter,
    );
    return assets;
  }

  @override
  Future<SessionScopeCapability> loadSessionScopeCapability({
    required String token,
  }) async => sessionScopeSupported
      ? const SessionScopeCapability(supported: true, version: 'v1')
      : SessionScopeCapability.unsupported;

  @override
  Future<PresenceSessionGrant> createPresenceSession({
    required String token,
    required String charId,
  }) async {
    sessionBinds += 1;
    lastBoundCharId = charId;
    final error = sessionBindError;
    if (error != null) throw error;
    return PresenceSessionGrant(
      sessionId: 'sess-$charId',
      charId: charId,
      ownerId: 'owner',
      domain: 'reality',
    );
  }
}

void main() {
  late _Store store;
  late _Backend backend;
  late ProfileAppearanceController controller;

  setUp(() {
    store = _Store();
    backend = _Backend();
    controller = ProfileAppearanceController(
      settings: SettingsStore(store),
      backend: () => backend,
      token: () => 'token',
    );
  });

  tearDown(() => controller.dispose());

  test(
    'restore merges appearance prefs with chat and dream backgrounds',
    () async {
      store.prefs = const YxPrefs(fontSize: 18, showChatTime: false);
      store.appearance = ChatAppearanceSettings(
        background: Uint8List.fromList([1]),
        nightBackground: Uint8List.fromList([2]),
        blur: 4,
        opacity: 0.5,
      );
      store.dreamBackground = Uint8List.fromList([3]);

      await controller.restore();

      expect(controller.prefs.fontSize, 18);
      expect(controller.prefs.showChatTime, isFalse);
      expect(controller.prefs.chatBackground, Uint8List.fromList([1]));
      expect(controller.prefs.nightChatBackground, Uint8List.fromList([2]));
      expect(controller.prefs.chatBackgroundBlur, 4);
      expect(controller.prefs.chatBubbleOpacity, 0.5);
      expect(controller.prefs.dreamBackground, Uint8List.fromList([3]));
    },
  );

  test(
    'profile name save and cancel keep character-scoped isolation',
    () async {
      store.names['char-a'] = 'LocalA';
      store.names['char-b'] = 'LocalB';
      store.avatars['char-a'] = Uint8List.fromList([9]);
      await controller.loadPromptAssets();
      expect(await controller.applyActiveCharacterPresentation(), isTrue);
      expect(controller.profileNameOverride, 'LocalA');
      expect(controller.profileDisplayName, 'LocalA');
      expect(controller.profileAvatarBytes, Uint8List.fromList([9]));
      expect(store.cachedName, 'LocalA');

      await controller.saveProfileName('NewA');
      expect(store.names['char-a'], 'NewA');
      expect(store.names['char-b'], 'LocalB');
      expect(store.cachedName, 'NewA');

      await controller.selectSessionCharacter('char-b');
      expect(await controller.applyActiveCharacterPresentation(), isTrue);
      expect(controller.currentCharacterId, 'char-b');
      expect(controller.serverActiveCharacterId, 'char-a');
      expect(controller.profileNameOverride, 'LocalB');
      expect(controller.profileDisplayName, 'LocalB');
      expect(controller.profileAvatarBytes, isNull);
      expect(store.names['char-a'], 'NewA');
      expect(store.sessionCharacters['|'], 'char-b');
    },
  );

  test(
    'loadPromptAssets keeps local session when server active changes',
    () async {
      store.sessionCharacters['|'] = 'char-b';
      await controller.loadPromptAssets();
      expect(controller.currentCharacterId, 'char-b');
      expect(controller.serverActiveCharacterId, 'char-a');
      expect(backend.updates, 0);

      backend.assets = PromptAssets(
        characters: backend.assets.characters,
        activeCharacter: 'char-a',
      );
      await controller.loadPromptAssets();
      expect(controller.currentCharacterId, 'char-b');
      expect(controller.serverActiveCharacterId, 'char-a');
    },
  );

  test('late prompt asset results do not overwrite newer generation', () async {
    final gate = Completer<void>();
    backend.loadHook = () => gate.future;
    final first = controller.loadPromptAssets();
    await Future<void>.delayed(Duration.zero);
    backend.loadHook = null;
    backend.assets = PromptAssets(
      characters: backend.assets.characters,
      activeCharacter: 'char-b',
    );
    await controller.loadPromptAssets();
    expect(controller.serverActiveCharacterId, 'char-b');
    gate.complete();
    await first;
    expect(controller.serverActiveCharacterId, 'char-b');
    expect(controller.loadingPromptAssets, isFalse);
  });

  test('avatar cancel leaves the previous bytes', () async {
    store.avatars['char-a'] = Uint8List.fromList([1, 2]);
    await controller.loadPromptAssets();
    await controller.applyActiveCharacterPresentation();
    store.pickedProfile = Uint8List.fromList([3, 4]);
    expect(await controller.pickProfileImage(), Uint8List.fromList([3, 4]));
    expect(controller.profileAvatarBytes, Uint8List.fromList([1, 2]));
  });

  test('failed avatar save does not replace the current image', () async {
    store.avatars['char-a'] = Uint8List.fromList([1]);
    await controller.loadPromptAssets();
    await controller.applyActiveCharacterPresentation();
    store.failAvatarSave = true;
    expect(await controller.saveAvatar(Uint8List.fromList([8])), isFalse);
    expect(controller.profileAvatarBytes, Uint8List.fromList([1]));
  });

  test('chat background save, cancel, and reset keep the other slot', () async {
    await controller.restore();
    final day = Uint8List.fromList([11]);
    final night = Uint8List.fromList([22]);
    expect(
      await controller.saveChatBackground(
        night: false,
        bytes: day,
        blur: 2,
        opacity: 0.8,
      ),
      isTrue,
    );
    expect(controller.prefs.chatBackground, day);
    expect(controller.prefs.nightChatBackground, isNull);

    expect(
      await controller.saveChatBackground(
        night: true,
        bytes: night,
        blur: 3,
        opacity: 0.7,
      ),
      isTrue,
    );
    expect(controller.prefs.chatBackground, day);
    expect(controller.prefs.nightChatBackground, night);
    expect(controller.prefs.chatBackgroundBlur, 3);

    expect(await controller.resetChatBackground(night: false), isTrue);
    expect(controller.prefs.chatBackground, isNull);
    expect(controller.prefs.nightChatBackground, night);

    store.failAppearanceSave = true;
    expect(await controller.resetChatBackground(night: true), isFalse);
    expect(controller.prefs.nightChatBackground, night);
  });

  test('loadPromptAssets binds a Reality session for the local character', () async {
    await controller.loadPromptAssets();
    expect(controller.sessionScopeSupported, isTrue);
    expect(controller.presenceGrant?.sessionId, 'sess-char-a');
    expect(controller.presenceGrant?.charId, 'char-a');
    expect(controller.sessionBindError, isNull);
    expect(backend.sessionBinds, 1);
  });

  test('missing session_scope capability is fail-loud and does not bind', () async {
    backend.sessionScopeSupported = false;
    await controller.loadPromptAssets();
    expect(controller.sessionScopeSupported, isFalse);
    expect(controller.presenceGrant, isNull);
    expect(controller.sessionBindError, 'session_scope_unsupported');
    expect(backend.sessionBinds, 0);
  });

  test('selectSessionCharacter rebinds and keeps server active unchanged', () async {
    await controller.loadPromptAssets();
    await controller.selectSessionCharacter('char-b');
    expect(controller.currentCharacterId, 'char-b');
    expect(controller.serverActiveCharacterId, 'char-a');
    expect(controller.presenceGrant?.charId, 'char-b');
    expect(backend.lastBoundCharId, 'char-b');
    expect(backend.updates, 0);
  });

  test('character bind errors stay fail-loud', () async {
    backend.sessionBindError = const BackendException(
      'character_revoked',
      statusCode: 403,
    );
    await controller.loadPromptAssets();
    expect(controller.presenceGrant, isNull);
    expect(controller.sessionBindError, 'character_revoked');
  });
}
