import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/profile_appearance_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Store extends AppSettingsStore {
  final Map<String?, String> names = {};
  final Map<String?, Uint8List> avatars = {};
  ChatAppearanceSettings appearance = const ChatAppearanceSettings();
  YxPrefs prefs = const YxPrefs();
  Uint8List? dreamBackground;
  String? cachedName;
  Uint8List? pickedProfile;
  Uint8List? pickedBackground;
  bool failAvatarSave = false;
  bool failAppearanceSave = false;

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

  @override
  Future<PromptAssets> loadPromptAssets({required String token}) async {
    loads += 1;
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

      await controller.updateActiveCharacter('char-b');
      expect(await controller.applyActiveCharacterPresentation(), isTrue);
      expect(controller.profileNameOverride, 'LocalB');
      expect(controller.profileDisplayName, 'LocalB');
      expect(controller.profileAvatarBytes, isNull);
      expect(store.names['char-a'], 'NewA');
    },
  );

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
}
