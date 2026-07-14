import 'dart:convert';

import 'app_models.dart';

const mobileColorModSchema = 'presencekit-mobile-color-mod';
const mobileColorPresetStoreSchema = 'presencekit-mobile-color-presets';
const mobileColorModVersion = 1;

class ThemeColorPreset {
  const ThemeColorPreset({
    required this.id,
    required this.name,
    required this.base,
    required this.palette,
    this.bundled = false,
  });

  final String id;
  final String name;
  final String base;
  final YxPalette palette;
  final bool bundled;

  ThemeColorPreset copyWith({
    String? id,
    String? name,
    String? base,
    YxPalette? palette,
    bool? bundled,
  }) => ThemeColorPreset(
    id: id ?? this.id,
    name: name ?? this.name,
    base: base ?? this.base,
    palette: palette ?? this.palette,
    bundled: bundled ?? this.bundled,
  );

  Map<String, dynamic> toModJson() => {
    'schema': mobileColorModSchema,
    'version': mobileColorModVersion,
    'id': id,
    'name': name,
    'base': base,
    'colors': palette.toHexMap(),
  };

  String toModJsonString() =>
      const JsonEncoder.withIndent('  ').convert(toModJson());

  static ThemeColorPreset? fromModJson(Object? value, {bool bundled = false}) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    if (json['schema'] != mobileColorModSchema ||
        json['version'] != mobileColorModVersion) {
      return null;
    }
    final id = json['id']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    final base = json['base']?.toString() ?? '';
    if (!RegExp(r'^[a-zA-Z0-9._-]{1,80}$').hasMatch(id) ||
        name.isEmpty ||
        name.length > 80 ||
        (base != 'light' && base != 'dark') ||
        json['colors'] is! Map) {
      return null;
    }
    final colors = Map<String, dynamic>.from(json['colors'] as Map);
    final validHex = RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$');
    if (YxPalette.colorKeys.any(
      (key) =>
          colors[key] is! String || !validHex.hasMatch(colors[key] as String),
    )) {
      return null;
    }
    final palette = YxPalette.fromColorMap(
      colors,
      fallback: base == 'dark' ? YxPalette.dark : YxPalette.light,
      requireAll: true,
    );
    if (palette == null) return null;
    return ThemeColorPreset(
      id: id,
      name: name,
      base: base,
      palette: palette,
      bundled: bundled,
    );
  }
}

class ThemePresetSnapshot {
  const ThemePresetSnapshot({required this.activeId, required this.presets});

  final String? activeId;
  final List<ThemeColorPreset> presets;

  String toJsonString() => jsonEncode({
    'schema': mobileColorPresetStoreSchema,
    'version': mobileColorModVersion,
    'activeId': activeId,
    'presets': presets.map((preset) => preset.toModJson()).toList(),
  });

  static ThemePresetSnapshot? fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final json = Map<String, dynamic>.from(decoded);
      if (json['schema'] != mobileColorPresetStoreSchema ||
          json['version'] != mobileColorModVersion ||
          json['presets'] is! List) {
        return null;
      }
      final presets = (json['presets'] as List)
          .map(ThemeColorPreset.fromModJson)
          .whereType<ThemeColorPreset>()
          .toList(growable: false);
      return ThemePresetSnapshot(
        activeId: json['activeId']?.toString(),
        presets: presets,
      );
    } catch (_) {
      return null;
    }
  }
}
