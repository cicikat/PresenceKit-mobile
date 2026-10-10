import 'package:flutter/material.dart';
import 'ui_layout.dart';

bool isFlowDream(DreamLayout layout) =>
    layout == DreamLayout.theatre || layout == DreamLayout.orbit;

class DreamFlowSettings {
  const DreamFlowSettings({
    this.lightColors = const [0xffadb7ee, 0xffb9dcfa, 0xffffffff],
    this.darkColors = const [0xff252264, 0xff6658ba, 0xff99b8eb],
    this.speed = .24,
    this.scale = 1,
    this.warp = 1.15,
    this.seed = 13.7,
    this.thickness = 24,
    this.reflection = .95,
  });
  final List<int> lightColors, darkColors;
  final double speed, scale, warp, seed, thickness, reflection;
  List<Color> colors(bool dark) =>
      (dark ? darkColors : lightColors).map(Color.new).toList();
  DreamFlowSettings copyWith({
    List<int>? lightColors,
    List<int>? darkColors,
    double? speed,
    double? scale,
    double? warp,
    double? seed,
    double? thickness,
    double? reflection,
  }) => DreamFlowSettings(
    lightColors: List.unmodifiable(lightColors ?? this.lightColors),
    darkColors: List.unmodifiable(darkColors ?? this.darkColors),
    speed: speed ?? this.speed,
    scale: scale ?? this.scale,
    warp: warp ?? this.warp,
    seed: seed ?? this.seed,
    thickness: thickness ?? this.thickness,
    reflection: reflection ?? this.reflection,
  );
  Map<String, Object> toJson() => {
    'lightColors': lightColors,
    'darkColors': darkColors,
    'speed': speed,
    'scale': scale,
    'warp': warp,
    'seed': seed,
    'thickness': thickness,
    'reflection': reflection,
  };
  factory DreamFlowSettings.fromJson(Map value) {
    const defaults = DreamFlowSettings();
    List<int> colors(String key, List<int> fallback) {
      final v = value[key];
      if (v is! List ||
          v.length != 3 ||
          v.any((c) => c is! int || c < 0 || c > 0xffffffff)) {
        return fallback;
      }
      return List.unmodifiable(v.cast<int>().map((c) => c | 0xff000000));
    }

    double number(String key, double fallback, double min, double max) {
      final n = value[key];
      return n is num && n.isFinite ? n.toDouble().clamp(min, max) : fallback;
    }

    return DreamFlowSettings(
      lightColors: colors('lightColors', defaults.lightColors),
      darkColors: colors('darkColors', defaults.darkColors),
      speed: number('speed', .24, 0, .6),
      scale: number('scale', 1, .6, 1.8),
      warp: number('warp', 1.15, .2, 2),
      seed: number('seed', 13.7, 0, 100),
      thickness: number('thickness', 24, 8, 45),
      reflection: number('reflection', .95, 0, 1.5),
    );
  }
}

class DreamAppearancePreset {
  const DreamAppearancePreset({
    required this.id,
    required this.name,
    required this.layout,
    this.flow = const DreamFlowSettings(),
    this.builtIn = false,
  });
  final String id, name;
  final DreamLayout layout;
  final DreamFlowSettings flow;
  final bool builtIn;
  DreamAppearancePreset copyWith({
    String? id,
    String? name,
    DreamFlowSettings? flow,
    bool? builtIn,
  }) => DreamAppearancePreset(
    id: id ?? this.id,
    name: name ?? this.name,
    layout: layout,
    flow: flow ?? this.flow,
    builtIn: builtIn ?? this.builtIn,
  );
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'layout': layout.name,
    'flow': flow.toJson(),
  };
  static DreamAppearancePreset? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final layout = decodeLayout(
      raw['layout'],
      DreamLayout.values,
      DreamLayout.classic,
    );
    final id = raw['id'], name = raw['name'];
    if (!isFlowDream(layout) ||
        id is! String ||
        !RegExp(r'^dream-user-[a-zA-Z0-9-]{1,70}$').hasMatch(id) ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 80 ||
        raw['flow'] is! Map) {
      return null;
    }
    return DreamAppearancePreset(
      id: id,
      name: name.trim(),
      layout: layout,
      flow: DreamFlowSettings.fromJson(raw['flow']),
    );
  }
}

const builtInDreamPresets = [
  DreamAppearancePreset(
    id: 'dream-theatre',
    name: '',
    layout: DreamLayout.theatre,
    builtIn: true,
  ),
  DreamAppearancePreset(
    id: 'dream-orbit',
    name: '',
    layout: DreamLayout.orbit,
    builtIn: true,
  ),
];

class DreamAppearanceSnapshot {
  const DreamAppearanceSnapshot({
    this.presets = const [],
    this.selected = const {},
  });
  final List<DreamAppearancePreset> presets;
  final Map<String, String> selected;
  Map<String, Object> toJson() => {
    'version': 1,
    'presets': presets.map((p) => p.toJson()).toList(),
    'selected': selected,
  };
  factory DreamAppearanceSnapshot.fromJson(Object? raw) {
    if (raw is! Map || raw['version'] != 1) {
      return const DreamAppearanceSnapshot();
    }
    final presets = raw['presets'] is List
        ? (raw['presets'] as List)
              .map(DreamAppearancePreset.fromJson)
              .whereType<DreamAppearancePreset>()
              .toList()
        : <DreamAppearancePreset>[];
    final unique = <String, DreamAppearancePreset>{
      for (final p in presets) p.id: p,
    };
    final all = [...builtInDreamPresets, ...unique.values];
    final selected = <String, String>{};
    if (raw['selected'] is Map) {
      for (final entry in (raw['selected'] as Map).entries) {
        if (all.any((p) => p.id == entry.value && p.layout.name == entry.key)) {
          selected[entry.key as String] = entry.value as String;
        }
      }
    }
    return DreamAppearanceSnapshot(
      presets: List.unmodifiable(unique.values),
      selected: Map.unmodifiable(selected),
    );
  }
}
