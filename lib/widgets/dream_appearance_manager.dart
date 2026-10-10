import 'package:flutter/material.dart';
import '../controllers/theme_controller.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../models/dream_appearance.dart';
import '../models/ui_layout.dart';
import 'common_widgets.dart';
import 'layout_settings.dart';
import 'dream_appearance_settings.dart';
import 'dream_flow_surface.dart';
import 'dream_flow_chrome.dart';
import 'theme_widgets.dart';
import 'settings_editor_widgets.dart';

class DreamAppearanceManager extends StatefulWidget {
  const DreamAppearanceManager({
    super.key,
    required this.c,
    required this.controller,
    required this.prefs,
    required this.onPrefs,
    this.onImportBackground,
    this.onResetBackground,
  });
  final YxPalette c;
  final ThemeController controller;
  final YxPrefs prefs;
  final ValueChanged<YxPrefs> onPrefs;
  final Future<void> Function()? onImportBackground, onResetBackground;
  @override
  State<DreamAppearanceManager> createState() => _DreamAppearanceManagerState();
}

class _DreamAppearanceManagerState extends State<DreamAppearanceManager> {
  late DreamLayout _layout;
  late DreamAppearancePreset _draft;
  late YxPrefs _prefs;
  late bool _dark;
  final _name = TextEditingController();
  final Map<DreamLayout, DreamAppearancePreset> _drafts = {};
  final Map<DreamLayout, bool> _dirtyDrafts = {};
  bool _busy = false, _dirty = false, _initialized = false;
  @override
  void initState() {
    super.initState();
    _layout = isFlowDream(widget.controller.dreamLayout)
        ? widget.controller.dreamLayout
        : DreamLayout.theatre;
    _draft = widget.controller.dreamAppearance.active(_layout);
    _prefs = widget.prefs;
    _dark = widget.controller.isDark;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _setName();
    }
  }

  @override
  void didUpdateWidget(DreamAppearanceManager old) {
    super.didUpdateWidget(old);
    _prefs = widget.prefs;
  }

  void _setName() {
    _name.text = _draft.builtIn
        ? context.l10n.dreamDefaultPreset(
            dreamLayoutLabel(context.l10n, _layout),
          )
        : _draft.name;
  }

  void _change(DreamFlowSettings value) {
    setState(() {
      _draft = _draft.copyWith(flow: value);
      _dirty = true;
    });
  }

  void _switch(DreamLayout value) {
    setState(() {
      _drafts[_layout] = _draft.copyWith(name: _name.text);
      _dirtyDrafts[_layout] = _dirty;
      _layout = value;
      _draft =
          _drafts[value] ?? widget.controller.dreamAppearance.active(value);
      _dirty = _dirtyDrafts[value] ?? false;
      _setName();
    });
  }

  Future<DreamAppearancePreset?> _save({bool asNew = false}) async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.dreamPresetNameRequired)),
      );
      return null;
    }
    setState(() => _busy = true);
    try {
      final saved = await widget.controller.dreamAppearance.save(
        _draft.copyWith(name: _name.text),
        asNew: asNew,
      );
      if (mounted) {
        setState(() {
          _draft = saved;
          _dirty = false;
          _setName();
        });
      }
      return saved;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dreamAppearanceSaveFailed)),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final preset = _dirty ? await _save() : _draft;
    if (preset == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.controller.dreamAppearance.select(preset);
      await widget.controller.setDreamLayout(preset.layout);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dreamAppearanceApplied)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dreamAppearanceSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _updatePrefs(YxPrefs prefs) {
    setState(() => _prefs = prefs);
    widget.onPrefs(prefs);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c, l = context.l10n;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .94,
        ),
        color: c.surface,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l.dreamAppearanceTheme, style: serif(c, 20)),
                    ),
                    IconButton(
                      key: const ValueKey('close-dream-appearance'),
                      onPressed: () => Navigator.pop(context),
                      tooltip: l.closeAction,
                      icon: Icon(Icons.close, color: c.ink2),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<DreamLayout>(
                        segments: [
                          for (final layout in [
                            DreamLayout.theatre,
                            DreamLayout.orbit,
                          ])
                            ButtonSegment(
                              value: layout,
                              label: Text(dreamLayoutLabel(l, layout)),
                            ),
                        ],
                        selected: {_layout},
                        onSelectionChanged: _busy
                            ? null
                            : (v) => _switch(v.first),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                            value: false,
                            icon: const Icon(Icons.light_mode_outlined),
                            label: Text(l.dreamPreviewDay),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: const Icon(Icons.dark_mode_outlined),
                            label: Text(l.dreamPreviewNight),
                          ),
                        ],
                        selected: {_dark},
                        onSelectionChanged: (v) =>
                            setState(() => _dark = v.first),
                      ),
                      const SizedBox(height: 14),
                      _preview(430, _dark),
                      const SizedBox(height: 14),
                      Text(
                        l.dreamCurrentPreset(
                          widget.controller.dreamAppearance
                                  .active(_layout)
                                  .builtIn
                              ? l.dreamDefaultPreset(
                                  dreamLayoutLabel(l, _layout),
                                )
                              : widget.controller.dreamAppearance
                                    .active(_layout)
                                    .name,
                        ),
                        style: mono(c, 11, color: c.ink3),
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'dream-presets-${_layout.name}-${_draft.id}',
                        ),
                        value: _draft.id,
                        decoration: InputDecoration(
                          labelText: l.themePresetsTitle,
                        ),
                        isExpanded: true,
                        items: [
                          for (final p
                              in widget.controller.dreamAppearance.forLayout(
                                _layout,
                              ))
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                p.builtIn
                                    ? l.dreamDefaultPreset(
                                        dreamLayoutLabel(l, _layout),
                                      )
                                    : p.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (id) {
                                setState(() {
                                  _draft = widget.controller.dreamAppearance
                                      .forLayout(_layout)
                                      .firstWhere((p) => p.id == id);
                                  _dirty = false;
                                  _setName();
                                });
                              },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('dream-preset-name'),
                        controller: _name,
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: l.themePresetNameLabel,
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            key: const ValueKey('apply-dream-preset'),
                            onPressed: _busy ? null : _apply,
                            icon: const Icon(Icons.check),
                            label: Text(l.dreamUsePreset),
                          ),
                          OutlinedButton(
                            onPressed: _busy ? null : () => _save(),
                            child: Text(l.saveAction),
                          ),
                          OutlinedButton(
                            onPressed: _busy ? null : () => _save(asNew: true),
                            child: Text(l.dreamSaveAsNewPreset),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _dark ? l.dreamNightFluidColors : l.dreamDayFluidColors,
                        style: serif(c, 16),
                      ),
                      for (var index = 0; index < 3; index++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            [
                              l.dreamFluidColorOne,
                              l.dreamFluidColorTwo,
                              l.dreamFluidColorThree,
                            ][index],
                            style: serif(c, 14),
                          ),
                          trailing: TextButton.icon(
                            icon: Icon(
                              Icons.circle,
                              color: _draft.flow.colors(_dark)[index],
                            ),
                            label: Text(
                              '#${(_dark ? _draft.flow.darkColors : _draft.flow.lightColors)[index].toRadixString(16).substring(2).toUpperCase()}',
                            ),
                            onPressed: () => _pickColor(index),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(l.dreamFluidParameters, style: serif(c, 16)),
                      _slider(
                        l.dreamFlowSpeed,
                        _draft.flow.speed,
                        0,
                        .6,
                        (v) => _change(_draft.flow.copyWith(speed: v)),
                      ),
                      _slider(
                        l.dreamFlowScale,
                        _draft.flow.scale,
                        .6,
                        1.8,
                        (v) => _change(_draft.flow.copyWith(scale: v)),
                      ),
                      _slider(
                        l.dreamFlowWarp,
                        _draft.flow.warp,
                        .2,
                        2,
                        (v) => _change(_draft.flow.copyWith(warp: v)),
                      ),
                      if (_layout == DreamLayout.orbit)
                        _slider(
                          l.dreamFlowSeed,
                          _draft.flow.seed,
                          0,
                          100,
                          (v) => _change(_draft.flow.copyWith(seed: v)),
                        ),
                      _slider(
                        l.dreamGlassThickness,
                        _draft.flow.thickness,
                        8,
                        45,
                        (v) => _change(_draft.flow.copyWith(thickness: v)),
                      ),
                      _slider(
                        l.dreamGlassReflection,
                        _draft.flow.reflection,
                        0,
                        1.5,
                        (v) => _change(_draft.flow.copyWith(reflection: v)),
                      ),
                      TextButton.icon(
                        onPressed: () => _change(const DreamFlowSettings()),
                        icon: const Icon(Icons.restore),
                        label: Text(l.dreamRestoreFlowDefaults),
                      ),
                      const Divider(),
                      ExpansionTile(
                        title: Text(l.dreamUi, style: serif(c, 16)),
                        children: [
                          ListTile(
                            title: Text(l.settingsDreamBackgroundTitle),
                            subtitle: Text(l.dreamImageBackgroundLegacy),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  onPressed: widget.onImportBackground,
                                  tooltip:
                                      l.settingsImportChatBackgroundTooltip,
                                  icon: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                  ),
                                ),
                                if (_prefs.dreamBackground != null)
                                  IconButton(
                                    onPressed: widget.onResetBackground,
                                    tooltip:
                                        l.settingsResetChatBackgroundTooltip,
                                    icon: const Icon(Icons.restore),
                                  ),
                              ],
                            ),
                          ),
                          DreamAppearanceSettings(
                            c: dreamFlowPalette(_layout, _dark),
                            prefs: _prefs,
                            onPrefs: _updatePrefs,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(double height, bool dark) => SizedBox(
    height: height,
    child: FittedBox(
      child: SizedBox(
        width: 360,
        height: 720,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: DreamFlowPreview(
            layout: _layout,
            settings: _draft.flow,
            dark: dark,
            prefs: _prefs,
          ),
        ),
      ),
    ),
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) => SettingsRow(
    c: widget.c,
    title: label,
    subtitle: value.toStringAsFixed(2),
    child: Slider(
      value: value,
      min: min,
      max: max,
      divisions: 100,
      onChanged: _busy ? null : onChanged,
    ),
  );
  Future<void> _pickColor(int index) async {
    final dark = _dark;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 240,
                    child: DreamFlowPreview(
                      layout: _layout,
                      settings: _draft.flow,
                      dark: dark,
                      prefs: _prefs,
                    ),
                  ),
                  FreeColorPicker(
                    c: widget.c,
                    color: _draft.flow.colors(dark)[index],
                    onChanged: (value) {
                      final colors = List<int>.from(
                        dark ? _draft.flow.darkColors : _draft.flow.lightColors,
                      );
                      colors[index] = value.toARGB32() | 0xff000000;
                      _change(
                        _draft.flow.copyWith(
                          lightColors: dark ? null : colors,
                          darkColors: dark ? colors : null,
                        ),
                      );
                      update(() {});
                    },
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.closeAction),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DreamFlowPreview extends StatelessWidget {
  const DreamFlowPreview({
    super.key,
    required this.layout,
    required this.settings,
    required this.dark,
    required this.prefs,
  });
  final DreamLayout layout;
  final DreamFlowSettings settings;
  final bool dark;
  final YxPrefs prefs;
  @override
  Widget build(BuildContext context) {
    final c = dreamFlowPalette(layout, dark), l = context.l10n;
    return DreamFlowSurface(
      layout: layout,
      settings: settings,
      dark: dark,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.dreamAppearancePreview,
              style: mono(c, 9, color: c.character),
            ),
            DreamFlowTitle(c: c, layout: layout),
            DreamFlowReply(
              c: c,
              layout: layout,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.dreamPreviewNarration,
                    style: contentSerif(
                      c,
                      prefs.dreamNarrationSize,
                      color: Color(
                        prefs.dreamNarrationColor ?? c.ink3.toARGB32(),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(8),
                    color: c.surfaceSoft.withValues(
                      alpha: prefs.dreamDescriptionOpacity,
                    ),
                    child: Text(
                      l.dreamPreviewAction,
                      style: contentSerif(
                        c,
                        prefs.dreamActionSize,
                        color: Color(
                          prefs.dreamActionColor ?? c.ink2.toARGB32(),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    l.dreamPreviewChat,
                    style: contentSerif(
                      c,
                      prefs.dreamChatSize,
                      color: Color(prefs.dreamChatColor ?? c.ink1.toARGB32()),
                    ),
                  ),
                ],
              ),
            ),
            DreamFlowGlass(
              radius: 28,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.dreamComposerHint,
                      style: serif(c, 12, color: c.ink3),
                    ),
                  ),
                  Icon(Icons.arrow_upward, color: c.character),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
