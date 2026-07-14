import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controllers/theme_controller.dart';
import '../models/app_models.dart';
import '../models/theme_models.dart';
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
              _SheetHeader(c: c, title: '颜色预设'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '本机可保存多个预设；浏览器可导出颜色 mod。',
                        style: mono(c, 10.5, color: c.ink3),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _create(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('新建'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: controller.presets.isEmpty
                    ? Center(
                        child: Text(
                          '还没有自定义预设',
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
                              ? 'mods/ 内置 · 只读'
                              : '${preset.base == 'dark' ? '夜间' : '信纸'}底色 · 本机预设',
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
                    label: Text(preset.bundled ? '复制并编辑' : '编辑'),
                  ),
                  if (!preset.bundled)
                    OutlinedButton.icon(
                      onPressed: () => controller.reset(preset.id),
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('重置颜色'),
                    ),
                  if (kIsWeb)
                    OutlinedButton.icon(
                      onPressed: () => _export(context, preset),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('导出 mod'),
                    ),
                  if (!preset.bundled)
                    TextButton.icon(
                      onPressed: () => _delete(context, preset),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: c.danger,
                      ),
                      label: Text('删除', style: TextStyle(color: c.danger)),
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
        title: const Text('删除颜色预设？'),
        content: Text('“${preset.name}”会从本机删除，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
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
      SnackBar(content: Text(ok ? '已下载颜色 mod；请手动放进项目 mods/ 文件夹。' : '导出失败')),
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

  static const roles = <(String, String, IconData)>[
    ('surface', '页面底色', Icons.layers_outlined),
    ('surfaceSoft', '输入栏底色', Icons.notes_outlined),
    ('surfaceDeep', '深层底色', Icons.inbox_outlined),
    ('surfaceEdge', '边框线', Icons.border_outer_rounded),
    ('ink1', '主文字', Icons.title_rounded),
    ('ink2', '次文字', Icons.text_fields_rounded),
    ('ink3', '弱文字', Icons.short_text_rounded),
    ('ink4', '淡线条', Icons.linear_scale_rounded),
    ('character', '角色主色/焦点', Icons.spa_outlined),
    ('characterDeep', '顶部/侧边栏', Icons.view_sidebar_outlined),
    ('characterSoft', '选中项/柔底', Icons.select_all_rounded),
    ('characterOn', '侧边栏文字', Icons.text_format_rounded),
    ('danger', '危险提示', Icons.warning_amber_rounded),
    ('warn', '提醒提示', Icons.notifications_none_rounded),
    ('ok', '正常提示', Icons.check_circle_outline_rounded),
    ('send', '发送按钮', Icons.send_rounded),
    ('userBubble', '用户气泡', Icons.chat_bubble_outline_rounded),
    ('userBubbleText', '用户气泡文字', Icons.format_color_text),
    ('scrim', '遮罩颜色', Icons.gradient_rounded),
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
              _SheetHeader(c: c, title: '编辑颜色预设'),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '预设名称'),
              ),
              const SizedBox(height: 12),
              _ThemePreview(c: _draft),
              const SizedBox(height: 14),
              Text('组件颜色', style: mono(c, 11, color: c.ink3)),
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
                    child: const Text('取消'),
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
                    label: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleChip(YxPalette c, (String, String, IconData) role) {
    final selected = role.$1 == _selected;
    return ChoiceChip(
      avatar: Icon(role.$3, size: 15),
      label: Text(role.$2),
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
        Text('自由选色', style: mono(c, 11, color: c.ink3)),
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
        Text('色相 ${_hsv.hue.round()}°', style: mono(c, 10, color: c.ink3)),
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
          '透明度 ${(_alpha * 100).round()}%',
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
              tooltip: '应用 RGB',
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
              Expanded(child: Text('预览', style: serif(c, 17))),
              Container(width: 54, height: 25, color: c.send),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(9),
              color: c.characterSoft,
              child: Text('角色消息与正文颜色', style: serif(c, 14)),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.all(9),
              color: c.userBubble,
              child: Text(
                '用户消息颜色',
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
  final _name = TextEditingController(text: '我的配色');
  String _base = 'light';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.c.surface,
      title: const Text('新建颜色预设'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'light', label: Text('信纸底色')),
              ButtonSegment(value: 'dark', label: Text('夜间底色')),
            ],
            selected: {_base},
            onSelectionChanged: (value) => setState(() => _base = value.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_name.text, _base)),
          child: const Text('创建'),
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
