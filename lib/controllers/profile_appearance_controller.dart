import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../services/backend_client.dart';
import '../services/character_naming.dart';
import '../services/device_services.dart';

/// Character-scoped profile and local appearance.
///
/// Does not own theme presets ([ThemeController]), user identity/fonts
/// ([PersonalizationController]), or activity/mood ([ProfileStatusController]).
class ProfileAppearanceController extends ChangeNotifier {
  ProfileAppearanceController({
    required SettingsStore settings,
    required BackendClient Function() backend,
    required String? Function() token,
  }) : _settings = settings,
       _backend = backend,
       _token = token;

  final SettingsStore _settings;
  final BackendClient Function() _backend;
  final String? Function() _token;

  bool _disposed = false;
  YxPrefs prefs = const YxPrefs();
  String? profileNameOverride;
  Uint8List? profileAvatarBytes;
  String? activeCharacterId;
  PromptAssets? promptAssets;
  bool loadingPromptAssets = false;
  bool savingPromptAssets = false;
  String? promptAssetsError;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String? get _accessToken {
    final value = _token()?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get currentCharacterId {
    final id = promptAssets?.activeCharacter.trim();
    return (id == null || id.isEmpty) ? null : id;
  }

  String? get backendCharacterDisplayName {
    final assets = promptAssets;
    if (assets == null) return null;
    for (final character in assets.characters) {
      if (character.id == assets.activeCharacter) return character.label;
    }
    return null;
  }

  String get profileDisplayName => resolveCharacterDisplayName(
    localOverride: profileNameOverride,
    backendName: backendCharacterDisplayName,
  );

  Future<void> restore() async {
    final chatAppearance = await _settings.loadChatAppearance();
    final dreamBackground = await _settings.loadDreamBackground();
    final appearancePrefs = await _settings.loadAppearancePrefs();
    prefs = appearancePrefs.copyWith(
      chatBackground: chatAppearance.background,
      nightChatBackground: chatAppearance.nightBackground,
      chatBackgroundBlur: chatAppearance.blur,
      chatBubbleOpacity: chatAppearance.opacity,
      dreamBackground: dreamBackground,
    );
    notifyListeners();
  }

  Future<void> savePrefs(YxPrefs value) async {
    prefs = value;
    notifyListeners();
    await _settings.saveAppearancePrefs(value);
  }

  Future<void> saveProfileName(String? cleaned) async {
    await _settings.saveProfileName(
      cleaned ?? '',
      characterId: currentCharacterId,
    );
    profileNameOverride = cleaned;
    notifyListeners();
    await _cacheDisplayName();
  }

  Future<Uint8List?> pickProfileImage() => _settings.pickProfileImage();

  Future<bool> saveAvatar(Uint8List bytes) async {
    final saved = await _settings.saveAvatar(
      bytes,
      characterId: currentCharacterId,
    );
    if (saved) {
      profileAvatarBytes = bytes;
      notifyListeners();
    }
    return saved;
  }

  Future<void> deleteAvatar() async {
    await _settings.deleteAvatar(characterId: currentCharacterId);
    profileAvatarBytes = null;
    notifyListeners();
  }

  Future<Uint8List?> pickBackgroundImage() =>
      _settings.pickChatBackgroundImage();

  Future<bool> saveChatBackground({
    required bool night,
    required Uint8List bytes,
    required double blur,
    required double opacity,
  }) async {
    final saved = await _settings.saveChatAppearance(
      ChatAppearanceSettings(
        background: night ? prefs.chatBackground : bytes,
        nightBackground: night ? bytes : prefs.nightChatBackground,
        blur: blur,
        opacity: opacity,
      ),
    );
    if (saved) {
      prefs = prefs.copyWith(
        chatBackground: night ? null : bytes,
        nightChatBackground: night ? bytes : null,
        chatBackgroundBlur: blur,
        chatBubbleOpacity: opacity,
      );
      notifyListeners();
    }
    return saved;
  }

  Future<bool> resetChatBackground({required bool night}) async {
    final saved = await _settings.saveChatAppearance(
      ChatAppearanceSettings(
        background: night ? prefs.chatBackground : null,
        nightBackground: night ? null : prefs.nightChatBackground,
        blur: prefs.chatBackgroundBlur,
        opacity: prefs.chatBubbleOpacity,
      ),
    );
    if (saved) {
      prefs = prefs.copyWith(
        clearChatBackground: !night,
        clearNightChatBackground: night,
      );
      notifyListeners();
    }
    return saved;
  }

  Future<bool> saveDreamBackground(Uint8List bytes) async {
    final saved = await _settings.saveDreamBackground(bytes);
    if (saved) {
      prefs = prefs.copyWith(dreamBackground: bytes);
      notifyListeners();
    }
    return saved;
  }

  Future<void> resetDreamBackground() async {
    await _settings.deleteDreamBackground();
    prefs = prefs.copyWith(clearDreamBackground: true);
    notifyListeners();
  }

  Future<void> loadPromptAssets() async {
    final token = _accessToken;
    if (loadingPromptAssets || token == null) return;
    loadingPromptAssets = true;
    promptAssetsError = null;
    notifyListeners();
    try {
      promptAssets = await _backend().loadPromptAssets(token: token);
    } on BackendException catch (e) {
      promptAssetsError = e.message;
    } finally {
      loadingPromptAssets = false;
      notifyListeners();
    }
  }

  Future<void> updateActiveCharacter(String id) async {
    final token = _accessToken;
    if (savingPromptAssets || token == null) return;
    savingPromptAssets = true;
    promptAssetsError = null;
    notifyListeners();
    try {
      promptAssets = await _backend().updatePromptAssets(
        token: token,
        activeCharacter: id,
      );
    } on BackendException catch (e) {
      promptAssetsError = e.message;
    } finally {
      savingPromptAssets = false;
      notifyListeners();
    }
  }

  /// Loads the character-scoped nickname and avatar.
  /// Returns true when the active character id changed.
  Future<bool> applyActiveCharacterPresentation() async {
    final id = currentCharacterId;
    final switched = id != activeCharacterId;
    final name = await _settings.loadProfileName(characterId: id);
    final avatar = await _settings.loadAvatar(characterId: id);
    activeCharacterId = id;
    profileNameOverride = name;
    profileAvatarBytes = avatar;
    notifyListeners();
    await _cacheDisplayName();
    return switched;
  }

  Future<void> _cacheDisplayName() =>
      _settings.cacheCharacterDisplayName(profileDisplayName);
}
