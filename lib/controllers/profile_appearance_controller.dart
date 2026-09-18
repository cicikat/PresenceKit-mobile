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
/// execution authorization; chat/upload/history freeze uses a server-issued
/// [PresenceSessionGrant] after whoami discovery.
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
  SessionScopeCapability sessionScopeCapability =
      SessionScopeCapability.unsupported;
  PresenceSessionGrant? presenceGrant;
  String? sessionBindError;
  bool bindingPresenceSession = false;
  int _sessionBindGeneration = 0;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _assetsGeneration++;
    _sessionBindGeneration++;
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

  bool get sessionScopeSupported => sessionScopeCapability.supported;

  String? displayNameForCharacter(String? charId) {
    final id = SessionScope.normalize(charId);
    final assets = promptAssets;
    if (id == null || assets == null) return null;
    for (final character in assets.characters) {
      if (character.id == id) return character.label;
    }
    return null;
  }

  PresenceSessionGrant? grantFor(String? charId) {
    final expected = SessionScope.normalize(charId);
    final grant = presenceGrant;
    if (expected == null || grant == null) return null;
    if (SessionScope.normalize(grant.charId) != expected) return null;
    if (grant.isExpired) return null;
    return grant;
  }

  Future<void> restore({bool includeSessionCharacter = true}) async {
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
    if (includeSessionCharacter) {
      await restoreSessionCharacter();
      return;
    }
    notifyListeners();
  }

  /// Reloads the origin+owner session character after connection identity is known.
  Future<void> restoreSessionCharacter() async {
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
      await _refreshSessionScope(token);
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
      promptAssetsError = 'character_unavailable';
      notifyListeners();
      return;
    }
    sessionCharacterId = cleaned;
    presenceGrant = null;
    sessionBindError = null;
    await _settings.saveSessionCharacterId(
      cleaned,
      origin: _currentOrigin,
      owner: _currentOwner,
    );
    notifyListeners();
    await _cacheDisplayName();
    final token = _accessToken;
    if (token != null) await ensurePresenceSession(charId: cleaned);
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
    if (stored != null) {
      sessionCharacterId = stored;
      final knownIds = {for (final item in assets.characters) item.id};
      if (knownIds.isNotEmpty && !knownIds.contains(stored)) {
        promptAssetsError = 'character_unavailable';
      }
      return;
    }
    final serverActive = SessionScope.normalize(assets.activeCharacter);
    if (serverActive != null) {
      sessionCharacterId = serverActive;
      await _settings.saveSessionCharacterId(
        serverActive,
        origin: _currentOrigin,
        owner: _currentOwner,
      );
      return;
    }
  }

  Future<void> _refreshSessionScope(String token) async {
    try {
      sessionScopeCapability = await _backend().loadSessionScopeCapability(
        token: token,
      );
      sessionBindError = sessionScopeSupported ? null : 'session_scope_unsupported';
      if (!sessionScopeSupported) {
        presenceGrant = null;
        return;
      }
    } on BackendException catch (e) {
      sessionScopeCapability = SessionScopeCapability.unsupported;
      sessionBindError = e.message;
      presenceGrant = null;
      return;
    }
    final charId = currentCharacterId;
    if (charId == null) return;
    await ensurePresenceSession(charId: charId);
  }

  /// Discovers session_scope=v1 and binds a Reality grant for [charId].
  /// Missing capability is fail-loud: no silent fallback to live active.
  Future<PresenceSessionGrant?> ensurePresenceSession({
    String? charId,
    bool force = false,
  }) async {
    final token = _accessToken;
    final requested = SessionScope.normalize(charId) ?? currentCharacterId;
    if (token == null || requested == null) return null;
    if (!force) {
      final existing = grantFor(requested);
      if (existing != null) return existing;
    }
    final generation = ++_sessionBindGeneration;
    bindingPresenceSession = true;
    sessionBindError = null;
    notifyListeners();
    try {
      if (!sessionScopeSupported) {
        sessionScopeCapability = await _backend().loadSessionScopeCapability(
          token: token,
        );
      }
      if (_disposed || generation != _sessionBindGeneration) return null;
      if (!sessionScopeSupported) {
        sessionBindError = 'session_scope_unsupported';
        presenceGrant = null;
        return null;
      }
      final grant = await _backend().createPresenceSession(
        token: token,
        charId: requested,
      );
      if (_disposed || generation != _sessionBindGeneration) return null;
      if (SessionScope.normalize(grant.charId) != requested) {
        sessionBindError = 'character_unavailable';
        presenceGrant = null;
        return null;
      }
      presenceGrant = grant;
      sessionBindError = null;
      return grant;
    } on BackendException catch (e) {
      if (_disposed || generation != _sessionBindGeneration) return null;
      sessionBindError = e.message;
      presenceGrant = null;
      return null;
    } catch (e) {
      if (_disposed || generation != _sessionBindGeneration) return null;
      sessionBindError = e.toString();
      presenceGrant = null;
      return null;
    } finally {
      if (!_disposed && generation == _sessionBindGeneration) {
        bindingPresenceSession = false;
        notifyListeners();
      }
    }
  }

  void invalidatePresenceGrant() {
    presenceGrant = null;
  }

  /// Drops in-flight prompt/session work after a token, owner, or node change.
  /// Theme, fonts, and local user profile are not owned here and stay put.
  Future<void> invalidateForIdentityChange({
    required bool realmChanged,
  }) async {
    _assetsGeneration++;
    _sessionBindGeneration++;
    presenceGrant = null;
    sessionBindError = null;
    promptAssetsError = null;
    promptAssets = null;
    sessionScopeCapability = SessionScopeCapability.unsupported;
    loadingPromptAssets = false;
    savingPromptAssets = false;
    bindingPresenceSession = false;
    if (realmChanged) {
      activeCharacterId = null;
      sessionCharacterId = await _settings.loadSessionCharacterId(
        origin: _currentOrigin,
        owner: _currentOwner,
      );
    }
    notifyListeners();
  }

  Future<void> _cacheDisplayName() =>
      _settings.cacheCharacterDisplayName(profileDisplayName);
}
