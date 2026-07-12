import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';
import '../services/character_naming.dart';
import '../widgets/common_widgets.dart';
class AvatarCropDialog extends StatefulWidget {
  const AvatarCropDialog({super.key, required this.c, required this.bytes});

  final YxPalette c;
  final Uint8List bytes;

  @override
  State<AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<AvatarCropDialog> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _controller = TransformationController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final cropContext = _cropKey.currentContext;
      final boundary =
          cropContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.4);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.pop(context, byteData?.buffer.asUint8List());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetView() {
    _controller.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Dialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('裁切头像', style: serif(c, 20, weight: FontWeight.w500)),
                const Spacer(),
                YxIconButton(
                  c: c,
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.pop(context),
                  tooltip: '取消',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RepaintBoundary(
                    key: _cropKey,
                    child: ClipOval(
                      child: SizedBox(
                        width: 236,
                        height: 236,
                        child: InteractiveViewer(
                          transformationController: _controller,
                          minScale: 1,
                          maxScale: 5,
                          boundaryMargin: const EdgeInsets.all(96),
                          child: Image.memory(
                            widget.bytes,
                            width: 236,
                            height: 236,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Container(
                      width: 236,
                      height: 236,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.character, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '拖动调整位置，双指或手势缩放。保存后只作为手机端本地头像。',
              style: mono(c, 11, color: c.ink3),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _resetView,
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                  label: const Text('重置'),
                ),
                const Spacer(),
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
    );
  }
}

class ThemePaletteSheet extends StatefulWidget {
  const ThemePaletteSheet({
    super.key,
    required this.c,
    required this.initial,
    required this.canDelete,
    required this.onSave,
    required this.onDelete,
  });

  final YxPalette c;
  final YxPalette initial;
  final bool canDelete;
  final Future<void> Function(YxPalette palette) onSave;
  final Future<void> Function() onDelete;

  @override
  State<ThemePaletteSheet> createState() => _ThemePaletteSheetState();
}

class _ThemePaletteSheetState extends State<ThemePaletteSheet> {
  late YxPalette _draft = widget.initial;
  String _selected = 'character';
  bool _saving = false;
  bool _deleting = false;

  static const List<_PaletteRole> _roles = [
    _PaletteRole('surface', '页面底色', Icons.layers_outlined),
    _PaletteRole('surfaceSoft', '输入栏底色', Icons.notes_outlined),
    _PaletteRole('surfaceDeep', '深一层底色', Icons.inbox_outlined),
    _PaletteRole('surfaceEdge', '边框线', Icons.border_outer_rounded),
    _PaletteRole('ink1', '主文字', Icons.title_rounded),
    _PaletteRole('ink2', '次文字', Icons.text_fields_rounded),
    _PaletteRole('ink3', '弱文字', Icons.short_text_rounded),
    _PaletteRole('ink4', '淡线条', Icons.linear_scale_rounded),
    _PaletteRole('character', '角色主色/焦点', Icons.spa_outlined),
    _PaletteRole('characterDeep', '顶部/侧边栏背景', Icons.view_sidebar_outlined),
    _PaletteRole('characterSoft', '选中项/柔底', Icons.select_all_rounded),
    _PaletteRole('characterOn', '侧边栏文字图标', Icons.text_format_rounded),
    _PaletteRole('danger', '危险提示', Icons.warning_amber_rounded),
    _PaletteRole('warn', '提醒提示', Icons.notifications_none_rounded),
    _PaletteRole('ok', '正常提示', Icons.check_circle_outline_rounded),
    _PaletteRole('send', '发送按钮', Icons.send_rounded),
    _PaletteRole('userBubble', '用户气泡', Icons.chat_bubble_outline_rounded),
    _PaletteRole('userBubbleText', '用户气泡文字', Icons.format_color_text),
  ];

  static const List<Color> _swatches = [
    Color(0xFFECE3D0),
    Color(0xFFF7F0E3),
    Color(0xFFD9C7A1),
    Color(0xFFBBA06F),
    Color(0xFF7B5E42),
    Color(0xFF2A1F18),
    Color(0xFF1B1410),
    Color(0xFFE8DCC0),
    Color(0xFF1F3A2E),
    Color(0xFF3F6F57),
    Color(0xFF88A589),
    Color(0xFFDCE3D6),
    Color(0xFF233A5A),
    Color(0xFF5A789B),
    Color(0xFFD9E6F2),
    Color(0xFF653D5D),
    Color(0xFFAA6F91),
    Color(0xFFF0D7E5),
    Color(0xFF8B3A2B),
    Color(0xFFC76851),
    Color(0xFFF2C0AE),
    Color(0xFFB8893A),
    Color(0xFFD4A256),
    Color(0xFFF3DC9B),
    Color(0xFF4A6B40),
    Color(0xFF6D8E5D),
    Color(0xFFCFE0C2),
    Color(0xFF101418),
    Color(0xFF2A3038),
    Color(0xFFF5F7FA),
  ];

  Color _roleColor(String key) {
    return switch (key) {
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
      _ => _draft.character,
    };
  }

  void _setRoleColor(String key, Color color) {
    setState(() {
      _draft = switch (key) {
        'surface' => _draft.copyWith(surface: color),
        'surfaceSoft' => _draft.copyWith(surfaceSoft: color),
        'surfaceDeep' => _draft.copyWith(surfaceDeep: color),
        'surfaceEdge' => _draft.copyWith(surfaceEdge: color),
        'ink1' => _draft.copyWith(ink1: color),
        'ink2' => _draft.copyWith(ink2: color),
        'ink3' => _draft.copyWith(ink3: color),
        'ink4' => _draft.copyWith(ink4: color),
        'character' => _draft.copyWith(character: color),
        'characterDeep' => _draft.copyWith(characterDeep: color),
        'characterSoft' => _draft.copyWith(characterSoft: color),
        'characterOn' => _draft.copyWith(characterOn: color),
        'danger' => _draft.copyWith(danger: color),
        'warn' => _draft.copyWith(warn: color),
        'ok' => _draft.copyWith(ok: color),
        'send' => _draft.copyWith(send: color),
        'userBubble' => _draft.copyWith(userBubble: color),
        'userBubbleText' => _draft.copyWith(userBubbleText: color),
        _ => _draft,
      };
    });
  }

  String _selectedLabel() {
    return _roles
        .firstWhere((role) => role.key == _selected, orElse: () => _roles.first)
        .label;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(_draft);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    await widget.onDelete();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.surfaceEdge)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: c.ink4.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.palette_outlined, color: c.ink2),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '自定义色盘',
                    style: serif(c, 22, weight: FontWeight.w500),
                  ),
                ),
                YxIconButton(
                  c: c,
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.pop(context),
                  tooltip: '关闭',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ThemePreview(c: _draft),
            const SizedBox(height: 14),
            Text('组件颜色', style: mono(c, 11, color: c.ink3)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final role in _roles) _roleChip(c, role)],
            ),
            const SizedBox(height: 16),
            Text('正在修改：${_selectedLabel()}', style: mono(c, 11, color: c.ink3)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final color in _swatches) _swatch(c, color)],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (widget.canDelete)
                  TextButton.icon(
                    onPressed: _saving || _deleting ? null : _delete,
                    icon: _deleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('删除'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _saving || _deleting
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving || _deleting ? null : _save,
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
    );
  }

  Widget _roleChip(YxPalette c, _PaletteRole role) {
    final selected = role.key == _selected;
    final color = _roleColor(role.key);
    return InkWell(
      onTap: () => setState(() => _selected = role.key),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 154,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.characterSoft : c.surfaceSoft,
          border: Border.all(color: selected ? c.character : c.surfaceEdge),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(role.icon, size: 16, color: selected ? c.character : c.ink3),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                role.label,
                overflow: TextOverflow.ellipsis,
                style: mono(c, 10.5, color: selected ? c.character : c.ink2),
              ),
            ),
            const SizedBox(width: 6),
            _ColorDot(color: color, border: c.surfaceEdge),
          ],
        ),
      ),
    );
  }

  Widget _swatch(YxPalette c, Color color) {
    final selected = color.toARGB32() == _roleColor(_selected).toARGB32();
    return InkWell(
      onTap: () => _setRoleColor(_selected, color),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? c.character : c.surfaceEdge,
            width: selected ? 2 : 1,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
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
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ColorDot(color: c.character, border: c.surfaceEdge, size: 26),
              const SizedBox(width: 8),
              Text(
                kFallbackCharacterDisplayName,
                style: serif(c, 17, weight: FontWeight.w500),
              ),
              const Spacer(),
              Container(
                width: 58,
                height: 24,
                decoration: BoxDecoration(
                  color: c.send,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
            decoration: BoxDecoration(
              color: c.characterSoft,
              border: Border.all(color: c.surfaceEdge),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('这套颜色会应用到聊天、抽屉和设置组件。', style: serif(c, 14)),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.characterDeep,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.view_sidebar_outlined,
                  size: 18,
                  color: c.characterOn.withValues(alpha: 0.78),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '侧边栏背景 / 文字图标 / 选中态',
                    style: mono(
                      c,
                      10.5,
                      color: c.characterOn.withValues(alpha: 0.82),
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 20,
                  decoration: BoxDecoration(
                    color: c.characterOn.withValues(alpha: 0.14),
                    border: Border(
                      left: BorderSide(color: c.characterOn, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 210),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              decoration: BoxDecoration(
                color: c.userBubble,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '用户气泡也会跟着变。',
                style: serif(c, 14, color: c.userBubbleText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteRole {
  const _PaletteRole(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.c,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final YxPalette c;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: serif(c, 16, weight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(subtitle, style: mono(c, 10.5, color: c.ink3)),
          ],
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.surfaceEdge)),
          ),
          child: constraints.maxWidth < 430
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: child),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: label),
                    const SizedBox(width: 12),
                    child,
                  ],
                ),
        );
      },
    );
  }
}

class PromptOptionChips extends StatelessWidget {
  const PromptOptionChips({
    super.key,
    required this.c,
    required this.options,
    required this.selected,
    required this.disabled,
    required this.onToggle,
  });

  final YxPalette c;
  final List<PromptAssetOption> options;
  final Set<String> selected;
  final bool disabled;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Text('暂无可用项', style: mono(c, 10.5, color: c.ink3));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        for (final option in options)
          FilterChip(
            label: Text(option.label),
            selected: selected.contains(option.id),
            onSelected: disabled ? null : (_) => onToggle(option.id),
          ),
      ],
    );
  }
}

class AttachSheet extends StatelessWidget {
  const AttachSheet({
    super.key,
    required this.c,
    required this.onUploadFile,
    required this.onUploadImages,
  });

  final YxPalette c;
  final VoidCallback onUploadFile;
  final VoidCallback onUploadImages;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        Icons.insert_drive_file_outlined,
        '文档',
        'txt / md / docx · 5MB 内',
        onUploadFile,
      ),
      (Icons.image_outlined, '图片', '可多选 · 走后端视觉识别', onUploadImages),
      (Icons.mic_none_rounded, '录音', '长按说话 · 转写 · 待接入', () {}),
    ];
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.surfaceEdge)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: c.ink4.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('附加内容', style: mono(c, 10, color: c.ink3)),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: Icon(option.$1, color: c.ink2),
                title: Text(
                  option.$2,
                  style: serif(c, 17, weight: FontWeight.w500),
                ),
                subtitle: Text(option.$3, style: mono(c, 10.5, color: c.ink3)),
                onTap: option.$4,
              ),
          ],
        ),
      ),
    );
  }
}
