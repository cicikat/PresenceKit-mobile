import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controllers/theme_controller.dart';
import '../models/app_models.dart';
import '../models/theme_models.dart';
import '../l10n/l10n.dart';
import 'common_widgets.dart';

class ThemePresetManagerSheet extends StatelessWidget {
  const ThemePresetManagerSheet({
    super.key,
    required this.c,
    required this.controller,
  });

  final YxPalette c;
  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.surfaceEdge)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _SheetHeader(c: c, title: l10n.themePresetsTitle),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.themePresetsDescription,
                        style: mono(c, 10.5, color: c.ink3),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _create(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(l10n.newAction),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: controller.presets.isEmpty
                    ? Center(
                        child: Text(
                          l10n.themeNoCustomPresets,
                          style: serif(c, 15, color: c.ink3),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                        itemCount: controller.presets.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _presetCard(context, controller.presets[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetCard(BuildContext context, ThemeColorPreset preset) {
    final l10n = context.l10n;
    final selected = controller.activeId == preset.id;
    return Material(
      color: selected ? c.characterSoft : c.surfaceSoft,
      child: InkWell(
        onTap: () => controller.select(preset.id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? c.character : c.surfaceEdge),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Radio<String>(
                    value: preset.id,
                    groupValue: controller.activeId,
                    onChanged: controller.select,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.name,
                          style: serif(c, 16, weight: FontWeight.w600),
                        ),
                        Text(
                          preset.bundled
                              ? l10n.themeBundledReadOnly
                              : l10n.themeLocalPreset(
                                  preset.base == 'dark'
                                      ? l10n.themeNight
                                      : l10n.themePaper,
                                ),
                          style: mono(c, 9.5, color: c.ink3),
                        ),
                      ],
                    ),
                  ),
                  for (final color in [
                    preset.palette.surface,
                    preset.palette.character,
                    preset.palette.send,
                    preset.palette.ink1,
                  ])
                    _ColorDot(color: color, border: c.surfaceEdge),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _edit(context, preset),
                    icon: Icon(
                      preset.bundled ? Icons.copy_rounded : Icons.tune_rounded,
                      size: 16,
                    ),
                    label: Text(
                      preset.bundled ? l10n.themeCopyEdit : l10n.editAction,
                    ),
                  ),
                  if (!preset.bundled)
                    OutlinedButton.icon(
                      onPressed: () => controller.reset(preset.id),
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: Text(l10n.themeResetColors),
                    ),
                  if (kIsWeb)
                    OutlinedButton.icon(
                      onPressed: () => _export(context, preset),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: Text(l10n.themeExportMod),
                    ),
                  if (!preset.bundled)
                    TextButton.icon(
                      onPressed: () => _delete(context, preset),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: c.danger,
                      ),
                      label: Text(
                        l10n.deleteAction,
                        style: TextStyle(color: c.danger),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _NewPresetDialog(c: c),
    );
    if (result == null || !context.mounted) return;
    final preset = await controller.create(name: result.$1, base: result.$2);
    if (context.mounted) await _openEditor(context, preset);
  }

  Future<void> _edit(BuildContext context, ThemeColorPreset preset) async {
    final editable = preset.bundled
        ? await controller.duplicate(preset)
        : preset;
    if (context.mounted) await _openEditor(context, editable);
  }

  Future<void> _openEditor(
    BuildContext context,
    ThemeColorPreset preset,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ThemeColorEditorSheet(
        c: controller.activePalette ?? c,
        preset: preset,
        onSave: controller.savePreset,
      ),
    );
  }

  Future<void> _delete(BuildContext context, ThemeColorPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(context.l10n.themeDeleteTitle),
        content: Text(context.l10n.themeDeleteWarning(preset.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.delete(preset.id);
  }

  Future<void> _export(BuildContext context, ThemeColorPreset preset) async {
    final ok = await controller.exportPreset(preset.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? context.l10n.themeExportSuccess : context.l10n.exportFailed,
        ),
      ),
    );
  }
}

class ThemeColorEditorSheet extends StatefulWidget {
  const ThemeColorEditorSheet({
    super.key,
    required this.c,
    required this.preset,
    required this.onSave,
  });

  final YxPalette c;
  final ThemeColorPreset preset;
  final Future<void> Function(ThemeColorPreset preset) onSave;

  @override
  State<ThemeColorEditorSheet> createState() => _ThemeColorEditorSheetState();
}

class _ThemeColorEditorSheetState extends State<ThemeColorEditorSheet> {
  late YxPalette _draft = widget.preset.palette;
  late final TextEditingController _name = TextEditingController(
    text: widget.preset.name,
  );
  String _selected = 'character';
  bool _saving = false;

  static const roles = <(String, IconData)>[
    ('surface', Icons.layers_outlined),
    ('surfaceSoft', Icons.notes_outlined),
    ('surfaceDeep', Icons.inbox_outlined),
    ('surfaceEdge', Icons.border_outer_rounded),
    ('ink1', Icons.title_rounded),
    ('ink2', Icons.text_fields_rounded),
    ('ink3', Icons.short_text_rounded),
    ('ink4', Icons.linear_scale_rounded),
    ('character', Icons.spa_outlined),
    ('characterDeep', Icons.view_sidebar_outlined),
    ('characterSoft', Icons.select_all_rounded),
    ('characterOn', Icons.text_format_rounded),
    ('danger', Icons.warning_amber_rounded),
    ('warn', Icons.notifications_none_rounded),
    ('ok', Icons.check_circle_outline_rounded),
    ('send', Icons.send_rounded),
    ('userBubble', Icons.chat_bubble_outline_rounded),
    ('userBubbleText', Icons.format_color_text),
    ('scrim', Icons.gradient_rounded),
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Color get selectedColor => switch (_selected) {
    'surface' => _draft.surface,
    'surfaceSoft' => _draft.surfaceSoft,
    'surfaceDeep' => _draft.surfaceDeep,
    'surfaceEdge' => _draft.surfaceEdge,
    'ink1' => _draft.ink1,
    'ink2' => _draft.ink2,
    'ink3' => _draft.ink3,
    'ink4' => _draft.ink4,
    'character' => _draft.character,
    'characterDeep' => _draft.characterDeep,
    'characterSoft' => _draft.characterSoft,
    'characterOn' => _draft.characterOn,
    'danger' => _draft.danger,
    'warn' => _draft.warn,
    'ok' => _draft.ok,
    'send' => _draft.send,
    'userBubble' => _draft.userBubble,
    'userBubbleText' => _draft.userBubbleText,
    'scrim' => _draft.scrim,
    _ => _draft.character,
  };

  void _setColor(Color value) {
    setState(() {
      _draft = switch (_selected) {
        'surface' => _draft.copyWith(surface: value),
        'surfaceSoft' => _draft.copyWith(surfaceSoft: value),
        'surfaceDeep' => _draft.copyWith(surfaceDeep: value),
        'surfaceEdge' => _draft.copyWith(surfaceEdge: value),
        'ink1' => _draft.copyWith(ink1: value),
        'ink2' => _draft.copyWith(ink2: value),
        'ink3' => _draft.copyWith(ink3: value),
        'ink4' => _draft.copyWith(ink4: value),
        'character' => _draft.copyWith(character: value),
        'characterDeep' => _draft.copyWith(characterDeep: value),
        'characterSoft' => _draft.copyWith(characterSoft: value),
        'characterOn' => _draft.copyWith(characterOn: value),
        'danger' => _draft.copyWith(danger: value),
        'warn' => _draft.copyWith(warn: value),
        'ok' => _draft.copyWith(ok: value),
        'send' => _draft.copyWith(send: value),
        'userBubble' => _draft.copyWith(userBubble: value),
        'userBubbleText' => _draft.copyWith(userBubbleText: value),
        'scrim' => _draft.copyWith(scrim: value),
        _ => _draft,
      };
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(
      widget.preset.copyWith(name: _name.text, palette: _draft),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.96,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.surfaceEdge)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHeader(c: c, title: context.l10n.themeEditTitle),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: context.l10n.themePresetNameLabel,
                ),
              ),
              const SizedBox(height: 12),
              _ThemePreview(c: _draft),
              const SizedBox(height: 14),
              Text(
                context.l10n.themeComponentColors,
                style: mono(c, 11, color: c.ink3),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [for (final role in roles) _roleChip(c, role)],
              ),
              const SizedBox(height: 16),
              FreeColorPicker(
                key: ValueKey(_selected),
                c: c,
                color: selectedColor,
                onChanged: _setColor,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(context.l10n.cancelAction),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(context.l10n.saveAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleChip(YxPalette c, (String, IconData) role) {
    final selected = role.$1 == _selected;
    return ChoiceChip(
      avatar: Icon(role.$2, size: 15),
      label: Text(themeRoleLabel(context.l10n, role.$1)),
      selected: selected,
      onSelected: (_) => setState(() => _selected = role.$1),
    );
  }
}

class FreeColorPicker extends StatefulWidget {
  const FreeColorPicker({
    super.key,
    required this.c,
    required this.color,
    required this.onChanged,
  });

  final YxPalette c;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<FreeColorPicker> createState() => _FreeColorPickerState();
}

class _FreeColorPickerState extends State<FreeColorPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.color);
  late double _alpha = widget.color.a;
  late final List<TextEditingController> _rgb = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  late final TextEditingController _hex = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncFields(widget.color);
  }

  @override
  void dispose() {
    for (final controller in _rgb) {
      controller.dispose();
    }
    _hex.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor().withValues(alpha: _alpha);

  void _emit() {
    final color = _color;
    _syncFields(color);
    widget.onChanged(color);
  }

  void _syncFields(Color color) {
    final values = [
      color.r,
      color.g,
      color.b,
    ].map((value) => (value * 255).round().toString()).toList();
    for (var i = 0; i < 3; i++) {
      _rgb[i].text = values[i];
    }
    _hex.text =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  void _setSv(Offset position, Size size) {
    setState(() {
      _hsv = _hsv
          .withSaturation((position.dx / size.width).clamp(0, 1))
          .withValue((1 - position.dy / size.height).clamp(0, 1));
    });
    _emit();
  }

  void _applyRgb() {
    final values = _rgb.map((item) => int.tryParse(item.text)).toList();
    if (values.any((value) => value == null || value < 0 || value > 255)) {
      return;
    }
    final color = Color.fromARGB(
      (_alpha * 255).round(),
      values[0]!,
      values[1]!,
      values[2]!,
    );
    setState(() => _hsv = HSVColor.fromColor(color));
    _emit();
  }

  void _applyHex(String raw) {
    final value = raw.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(value)) {
      return;
    }
    final argb = value.length == 6
        ? int.parse('FF$value', radix: 16)
        : int.parse(value, radix: 16);
    final color = Color(argb);
    setState(() {
      _hsv = HSVColor.fromColor(color);
      _alpha = color.a;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.themeFreeColor, style: mono(c, 11, color: c.ink3)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const height = 180.0;
            return GestureDetector(
              onPanDown: (details) =>
                  _setSv(details.localPosition, Size(width, height)),
              onPanUpdate: (details) =>
                  _setSv(details.localPosition, Size(width, height)),
              child: CustomPaint(
                painter: _SvPainter(hue: _hsv.hue),
                foregroundPainter: _PickerMarkerPainter(
                  position: Offset(
                    _hsv.saturation * width,
                    (1 - _hsv.value) * height,
                  ),
                ),
                child: const SizedBox(height: height, width: double.infinity),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.themeHue(_hsv.hue.round()),
          style: mono(c, 10, color: c.ink3),
        ),
        Slider(
          value: _hsv.hue,
          min: 0,
          max: 360,
          onChanged: (value) {
            setState(() => _hsv = _hsv.withHue(value));
            _emit();
          },
        ),
        Text(
          context.l10n.themeOpacity((_alpha * 100).round()),
          style: mono(c, 10, color: c.ink3),
        ),
        Slider(
          value: _alpha,
          onChanged: (value) {
            setState(() => _alpha = value);
            _emit();
          },
        ),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Expanded(
                child: TextField(
                  controller: _rgb[i],
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _applyRgb(),
                  decoration: InputDecoration(labelText: ['R', 'G', 'B'][i]),
                ),
              ),
              if (i < 2) const SizedBox(width: 7),
            ],
            const SizedBox(width: 7),
            IconButton(
              onPressed: _applyRgb,
              tooltip: context.l10n.themeApplyRgbTooltip,
              icon: const Icon(Icons.check_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _hex,
          onSubmitted: _applyHex,
          decoration: const InputDecoration(
            labelText: 'HEX（#AARRGGBB）',
            suffixIcon: Icon(Icons.keyboard_return_rounded),
          ),
        ),
      ],
    );
  }
}

class _SvPainter extends CustomPainter {
  const _SvPainter({required this.hue});
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, HSVColor.fromAHSV(1, hue, 1, 1).toColor()],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SvPainter oldDelegate) => oldDelegate.hue != hue;
}

class _PickerMarkerPainter extends CustomPainter {
  const _PickerMarkerPainter({required this.position});
  final Offset position;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(position, 7, Paint()..color = Colors.white);
    canvas.drawCircle(
      position,
      6,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PickerMarkerPainter oldDelegate) =>
      oldDelegate.position != position;
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.c});
  final YxPalette c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        border: Border.all(color: c.surfaceEdge),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ColorDot(color: c.character, border: c.surfaceEdge, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.l10n.previewLabel, style: serif(c, 17)),
              ),
              Container(width: 54, height: 25, color: c.send),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(9),
              color: c.characterSoft,
              child: Text(
                context.l10n.themeCharacterPreview,
                style: serif(c, 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.all(9),
              color: c.userBubble,
              child: Text(
                context.l10n.themeUserPreview,
                style: serif(c, 14, color: c.userBubbleText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.c, required this.title});
  final YxPalette c;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, color: c.ink2),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: serif(c, 22))),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _NewPresetDialog extends StatefulWidget {
  const _NewPresetDialog({required this.c});
  final YxPalette c;

  @override
  State<_NewPresetDialog> createState() => _NewPresetDialogState();
}

class _NewPresetDialogState extends State<_NewPresetDialog> {
  late final TextEditingController _name;
  String _base = 'light';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!mounted || _nameInitialized) return;
    _name = TextEditingController(text: context.l10n.themeDefaultName);
    _nameInitialized = true;
  }

  bool _nameInitialized = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.c.surface,
      title: Text(context.l10n.themeNewTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(labelText: context.l10n.nameLabel),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'light',
                label: Text(context.l10n.themeLightBase),
              ),
              ButtonSegment(
                value: 'dark',
                label: Text(context.l10n.themeDarkBase),
              ),
            ],
            selected: {_base},
            onSelectionChanged: (value) => setState(() => _base = value.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancelAction),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_name.text, _base)),
          child: Text(context.l10n.createAction),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.border, this.size = 18});
  final Color color;
  final Color border;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(left: 3),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
    );
  }
}
