import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/app_models.dart';
import '../models/theme_models.dart';
import '../services/theme_web_bridge.dart';

typedef LoadThemeData = Future<String?> Function();
typedef SaveThemeData = Future<void> Function(String value);

enum AppThemeMode { light, dark, system }

class ThemeController extends ChangeNotifier {
  ThemeController({
    required LoadThemeData loadPersisted,
    required SaveThemeData savePersisted,
    Brightness Function()? systemBrightness,
  }) : _loadPersisted = loadPersisted,
       _savePersisted = savePersisted,
       _systemBrightness = systemBrightness ??
           (() => WidgetsBinding.instance.platformDispatcher.platformBrightness);

  final LoadThemeData _loadPersisted;
  final SaveThemeData _savePersisted;
  final Brightness Function() _systemBrightness;
  final List<ThemeColorPreset> _userPresets = [];
  final List<ThemeColorPreset> _bundledPresets = [];
  String? _lightThemePresetId;
  String? _darkThemePresetId;
  AppThemeMode _themeMode = AppThemeMode.system;

  List<ThemeColorPreset> get presets => List.unmodifiable([
    ..._userPresets,
    ..._bundledPresets.where(
      (bundled) => !_userPresets.any((user) => user.id == bundled.id),
    ),
  ]);
  int get userPresetCount => _userPresets.length;
  AppThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == AppThemeMode.dark ||
      (_themeMode == AppThemeMode.system && _systemBrightness() == Brightness.dark);
  String? get lightThemePresetId => _lightThemePresetId;
  String? get darkThemePresetId => _darkThemePresetId;
  String? get activeId => isDark ? _darkThemePresetId : _lightThemePresetId;
  ThemeColorPreset? get activePreset => _find(activeId);
  ThemeColorPreset? get lightThemePreset => _find(_lightThemePresetId);
  ThemeColorPreset? get darkThemePreset => _find(_darkThemePresetId);
  YxPalette? get activePalette => activePreset?.palette;

  Future<void> restore() async {
    await _loadBundledMods();
    final raw = kIsWeb ? await loadWebThemePresets() : await _loadPersisted();
    final snapshot = ThemePresetSnapshot.fromJsonString(raw);
    if (snapshot != null) {
      _userPresets
        ..clear()
        ..addAll(snapshot.presets);
      _lightThemePresetId = snapshot.lightThemePresetId;
      _darkThemePresetId = snapshot.darkThemePresetId;
      _themeMode = AppThemeMode.values.byName(snapshot.themeMode);
      // Rewrites legacy activeId snapshots into the dual-preset representation.
      if (raw != null && !raw.contains('lightThemePresetId')) await _persist();
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
        _lightThemePresetId = migrated.id;
        _darkThemePresetId = migrated.id;
        await _persist();
      }
    }
    if (_find(_lightThemePresetId) == null) _lightThemePresetId = null;
    if (_find(_darkThemePresetId) == null) _darkThemePresetId = null;
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _themeMode = mode;
    await _changed();
  }

  Future<void> toggleMode() => setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);

  void updateSystemBrightness() {
    if (_themeMode == AppThemeMode.system) notifyListeners();
  }

  Future<ThemeColorPreset> create({required String name, required String base}) async {
    final preset = ThemeColorPreset(
      id: _newId('user'), name: _cleanName(name), base: base,
      palette: base == 'dark' ? YxPalette.dark : YxPalette.light,
    );
    _userPresets.add(preset);
    _setSelected(preset.id, dark: base == 'dark');
    _themeMode = base == 'dark' ? AppThemeMode.dark : AppThemeMode.light;
    await _changed();
    return preset;
  }

  Future<ThemeColorPreset> duplicate(ThemeColorPreset source) async {
    final copy = ThemeColorPreset(
      id: _newId('user'), name: _cleanName('${source.name} copy'),
      base: source.base, palette: source.palette,
    );
    _userPresets.add(copy);
    _setSelected(copy.id, dark: isDark);
    await _changed();
    return copy;
  }

  Future<void> savePreset(ThemeColorPreset preset) async {
    final index = _userPresets.indexWhere((item) => item.id == preset.id);
    if (index < 0) return;
    _userPresets[index] = preset.copyWith(name: _cleanName(preset.name), bundled: false);
    _setSelected(preset.id, dark: isDark);
    await _changed();
  }

  Future<void> select(String? id, {bool? dark}) async {
    final targetDark = dark ?? isDark;
    _setSelected(_find(id) == null ? null : id, dark: targetDark);
    await _changed();
  }

  Future<void> delete(String id) async {
    _userPresets.removeWhere((preset) => preset.id == id);
    if (_lightThemePresetId == id) _lightThemePresetId = null;
    if (_darkThemePresetId == id) _darkThemePresetId = null;
    await _changed();
  }

  Future<void> reset(String id) async {
    final index = _userPresets.indexWhere((preset) => preset.id == id);
    if (index < 0) return;
    final current = _userPresets[index];
    _userPresets[index] = current.copyWith(
      palette: current.base == 'dark' ? YxPalette.dark : YxPalette.light,
    );
    _setSelected(id, dark: isDark);
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

  void _setSelected(String? id, {required bool dark}) {
    if (dark) {
      _darkThemePresetId = id;
    } else {
      _lightThemePresetId = id;
    }
  }

  ThemeColorPreset? _find(String? id) {
    if (id == null) return null;
    for (final preset in presets) { if (preset.id == id) return preset; }
    return null;
  }

  Future<void> _changed() async { notifyListeners(); await _persist(); }

  Future<void> _persist() async {
    final value = ThemePresetSnapshot(
      lightThemePresetId: _lightThemePresetId,
      darkThemePresetId: _darkThemePresetId,
      themeMode: _themeMode.name,
      presets: _userPresets,
    ).toJsonString();
    if (kIsWeb) { await saveWebThemePresets(value); } else { await _savePersisted(value); }
  }

  Future<void> _loadBundledMods() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final path in manifest.listAssets().where((path) => path.startsWith('mods/') && path.endsWith('.json'))) {
        try {
          final preset = ThemeColorPreset.fromModJson(jsonDecode(await rootBundle.loadString(path)), bundled: true);
          if (preset != null && !_bundledPresets.any((item) => item.id == preset.id)) _bundledPresets.add(preset);
        } catch (_) {}
      }
    } catch (_) {}
  }

  static String _newId(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  static String _cleanName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Untitled theme';
    return trimmed.length <= 40 ? trimmed : trimmed.substring(0, 40);
  }
  static String _safeFilename(String value) {
    final safe = value.replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fff_-]'), '_');
    return safe.isEmpty ? 'theme' : safe;
  }
}
