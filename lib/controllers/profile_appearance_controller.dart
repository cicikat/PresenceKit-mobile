import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../models/session_scope.dart';
import '../services/backend_client.dart';
import '../services/character_naming.dart';
import '../services/device_services.dart';

/// Character-scoped profile and local appearance.
///
/// Does not own theme presets ([ThemeController]), user identity/fonts
/// ([PersonalizationController]), or activity/mood ([ProfileStatusController]).
///
/// Reality session character is a local preference keyed by origin+owner and is
/// independent of server `active_character`. Display names/avatars are not
/// execution authorization; chat wire freeze still awaits backend B/C.
class ProfileAppearanceController extends ChangeNotifier {
  ProfileAppearanceController({
    required SettingsStore settings,
    required BackendClient Function() backend,
    required String? Function() token,
    String? Function()? origin,
    String? Function()? owner,
  }) : _settings = settings,
       _backend = backend,
       _token = token,
       _origin = origin ?? _alwaysNull,
       _owner = owner ?? _alwaysNull;

  static String? _alwaysNull() => null;

  final SettingsStore _settings;
  final BackendClient Function() _backend;
  final String? Function() _token;
  final String? Function() _origin;
  final String? Function() _owner;

  bool _disposed = false;
  int _assetsGeneration = 0;
  YxPrefs prefs = const YxPrefs();
  String? profileNameOverride;
  Uint8List? profileAvatarBytes;
  String? activeCharacterId;
  String? sessionCharacterId;
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

  String? get _currentOrigin => SessionScope.normalize(_origin());
  String? get _currentOwner => SessionScope.normalize(_owner());

  /// Local session character when set; otherwise falls back to server active
  /// for bootstrap until the user picks a fixed role on this device.
  String? get currentCharacterId {
    final session = SessionScope.normalize(sessionCharacterId);
    if (session != null) return session;
    final id = promptAssets?.activeCharacter.trim();
    return (id == null || id.isEmpty) ? null : id;
  }

  String? get serverActiveCharacterId {
    final id = promptAssets?.activeCharacter.trim();
    return (id == null || id.isEmpty) ? null : id;
  }

  String? get backendCharacterDisplayName {
    final assets = promptAssets;
    final id = currentCharacterId;
    if (assets == null || id == null) return null;
    for (final character in assets.characters) {
      if (character.id == id) return character.label;
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
    sessionCharacterId = await _settings.loadSessionCharacterId(
      origin: _currentOrigin,
      owner: _currentOwner,
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
    if (token == null) return;
    final generation = ++_assetsGeneration;
    loadingPromptAssets = true;
    promptAssetsError = null;
    notifyListeners();
    try {
      final assets = await _backend().loadPromptAssets(token: token);
      if (_disposed || generation != _assetsGeneration) return;
      promptAssets = assets;
      await _reconcileSessionCharacter(assets);
      if (_disposed || generation != _assetsGeneration) return;
    } on BackendException catch (e) {
      if (_disposed || generation != _assetsGeneration) return;
      promptAssetsError = e.message;
    } finally {
      if (!_disposed && generation == _assetsGeneration) {
        loadingPromptAssets = false;
        notifyListeners();
      }
    }
  }

  /// Pins this device's Reality session character without changing server
  /// `active_character`. Other devices / admin active changes stay separate.
  Future<void> selectSessionCharacter(String id) async {
    final cleaned = SessionScope.normalize(id);
    if (cleaned == null) return;
    final assets = promptAssets;
    if (assets != null &&
        assets.characters.isNotEmpty &&
        !assets.characters.any((item) => item.id == cleaned)) {
      promptAssetsError = 'character unavailable';
      notifyListeners();
      return;
    }
    sessionCharacterId = cleaned;
    await _settings.saveSessionCharacterId(
      cleaned,
      origin: _currentOrigin,
      owner: _currentOwner,
    );
    notifyListeners();
  }

  /// Admin/server active character write. Not used for this-device session
  /// switching; retained for explicit persona scope operations.
  Future<void> updateActiveCharacter(String id) async {
    final token = _accessToken;
    if (token == null) return;
    final generation = ++_assetsGeneration;
    savingPromptAssets = true;
    promptAssetsError = null;
    notifyListeners();
    try {
      final assets = await _backend().updatePromptAssets(
        token: token,
        activeCharacter: id,
      );
      if (_disposed || generation != _assetsGeneration) return;
      promptAssets = assets;
    } on BackendException catch (e) {
      if (_disposed || generation != _assetsGeneration) return;
      promptAssetsError = e.message;
    } finally {
      if (!_disposed && generation == _assetsGeneration) {
        savingPromptAssets = false;
        notifyListeners();
      }
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

  Future<void> _reconcileSessionCharacter(PromptAssets assets) async {
    final stored = SessionScope.normalize(
      await _settings.loadSessionCharacterId(
        origin: _currentOrigin,
        owner: _currentOwner,
      ),
    );
    final knownIds = {for (final item in assets.characters) item.id};
    if (stored != null && (knownIds.isEmpty || knownIds.contains(stored))) {
      sessionCharacterId = stored;
      return;
    }
    final serverActive = SessionScope.normalize(assets.activeCharacter);
    if (serverActive != null &&
        (knownIds.isEmpty || knownIds.contains(serverActive))) {
      sessionCharacterId = serverActive;
      await _settings.saveSessionCharacterId(
        serverActive,
        origin: _currentOrigin,
        owner: _currentOwner,
      );
      return;
    }
    sessionCharacterId = knownIds.isEmpty ? null : knownIds.first;
    if (sessionCharacterId != null) {
      await _settings.saveSessionCharacterId(
        sessionCharacterId,
        origin: _currentOrigin,
        owner: _currentOwner,
      );
    }
  }

  Future<void> _cacheDisplayName() =>
      _settings.cacheCharacterDisplayName(profileDisplayName);
}
