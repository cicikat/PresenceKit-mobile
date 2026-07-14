import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import '../models/theme_models.dart';
import '../services/theme_web_bridge.dart';

typedef LoadThemeData = Future<String?> Function();
typedef SaveThemeData = Future<void> Function(String value);

class ThemeController extends ChangeNotifier {
  ThemeController({
    required LoadThemeData loadPersisted,
    required SaveThemeData savePersisted,
  }) : _loadPersisted = loadPersisted,
       _savePersisted = savePersisted;

  final LoadThemeData _loadPersisted;
  final SaveThemeData _savePersisted;
  final List<ThemeColorPreset> _userPresets = [];
  final List<ThemeColorPreset> _bundledPresets = [];
  String? _activeId;

  List<ThemeColorPreset> get presets => List.unmodifiable([
    ..._userPresets,
    ..._bundledPresets.where(
      (bundled) => !_userPresets.any((user) => user.id == bundled.id),
    ),
  ]);
  int get userPresetCount => _userPresets.length;
  String? get activeId => _activeId;
  ThemeColorPreset? get activePreset => _find(_activeId);
  YxPalette? get activePalette => activePreset?.palette;
  bool get hasActivePreset => activePreset != null;

  Future<void> restore() async {
    await _loadBundledMods();
    final raw = kIsWeb ? await loadWebThemePresets() : await _loadPersisted();
    final snapshot = ThemePresetSnapshot.fromJsonString(raw);
    if (snapshot != null) {
      _userPresets
        ..clear()
        ..addAll(snapshot.presets);
      _activeId = snapshot.activeId;
    } else {
      final legacy = YxPalette.fromJsonString(raw);
      if (legacy != null) {
        final migrated = ThemeColorPreset(
          id: _newId('legacy'),
          name: '旧版自定义',
          base: 'light',
          palette: legacy,
        );
        _userPresets.add(migrated);
        _activeId = migrated.id;
        await _persist();
      }
    }
    if (_find(_activeId) == null) _activeId = null;
    notifyListeners();
  }

  Future<ThemeColorPreset> create({
    required String name,
    required String base,
  }) async {
    final preset = ThemeColorPreset(
      id: _newId('user'),
      name: _cleanName(name),
      base: base,
      palette: base == 'dark' ? YxPalette.dark : YxPalette.light,
    );
    _userPresets.add(preset);
    _activeId = preset.id;
    await _changed();
    return preset;
  }

  Future<ThemeColorPreset> duplicate(ThemeColorPreset source) async {
    final copy = ThemeColorPreset(
      id: _newId('user'),
      name: _cleanName('${source.name} 副本'),
      base: source.base,
      palette: source.palette,
    );
    _userPresets.add(copy);
    _activeId = copy.id;
    await _changed();
    return copy;
  }

  Future<void> savePreset(ThemeColorPreset preset) async {
    final index = _userPresets.indexWhere((item) => item.id == preset.id);
    if (index < 0) return;
    _userPresets[index] = preset.copyWith(
      name: _cleanName(preset.name),
      bundled: false,
    );
    _activeId = preset.id;
    await _changed();
  }

  Future<void> select(String? id) async {
    _activeId = _find(id) == null ? null : id;
    await _changed();
  }

  Future<void> delete(String id) async {
    _userPresets.removeWhere((preset) => preset.id == id);
    if (_activeId == id) _activeId = null;
    await _changed();
  }

  Future<void> reset(String id) async {
    final index = _userPresets.indexWhere((preset) => preset.id == id);
    if (index < 0) return;
    final current = _userPresets[index];
    _userPresets[index] = current.copyWith(
      palette: current.base == 'dark' ? YxPalette.dark : YxPalette.light,
    );
    _activeId = id;
    await _changed();
  }

  Future<bool> exportPreset(String id) async {
    if (!kIsWeb) return false;
    final preset = _find(id);
    if (preset == null) return false;
    return exportThemeModFile(
      '${_safeFilename(preset.name)}.mobile-theme.json',
      preset.toModJsonString(),
    );
  }

  ThemeColorPreset? _find(String? id) {
    if (id == null) return null;
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  Future<void> _changed() async {
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final value = ThemePresetSnapshot(
      activeId: _activeId,
      presets: _userPresets,
    ).toJsonString();
    if (kIsWeb) {
      await saveWebThemePresets(value);
    } else {
      await _savePersisted(value);
    }
  }

  Future<void> _loadBundledMods() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final paths = manifest.listAssets().where(
        (path) => path.startsWith('mods/') && path.endsWith('.json'),
      );
      for (final path in paths) {
        try {
          final raw = await rootBundle.loadString(path);
          final preset = ThemeColorPreset.fromModJson(
            jsonDecode(raw),
            bundled: true,
          );
          if (preset != null &&
              !_bundledPresets.any((item) => item.id == preset.id)) {
            _bundledPresets.add(preset);
          }
        } catch (_) {
          // One invalid hand-edited mod must not block application startup.
        }
      }
    } catch (_) {
      // Asset manifests may be unavailable in narrow unit-test harnesses.
    }
  }

  static String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  static String _cleanName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '未命名配色';
    return trimmed.length <= 40 ? trimmed : trimmed.substring(0, 40);
  }

  static String _safeFilename(String value) {
    final safe = value.replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fff_-]'), '_');
    return safe.isEmpty ? 'theme' : safe;
  }
}
