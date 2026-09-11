import 'package:flutter/material.dart';
import '../controllers/personalization_controller.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import 'common_widgets.dart';

class UserDrawerHeader extends StatelessWidget {
  const UserDrawerHeader({super.key, required this.c, this.controller});
  final YxPalette c;
  final PersonalizationController? controller;

  Future<void> edit(BuildContext context, bool signature) async {
    final input = TextEditingController(text: signature ? controller?.signature : controller?.name);
    final value = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: Text(signature ? context.l10n.userSignature : context.l10n.userDisplayName),
      content: TextField(controller: input, maxLength: signature ? 120 : 40, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancelAction)),
        TextButton(onPressed: () => Navigator.pop(context, input.text), child: Text(context.l10n.saveAction))],
    ));
    if (value != null) await controller?.save(userName: signature ? null : value, userSignature: signature ? value : null);
  }

  @override
  Widget build(BuildContext context) {
    final name = controller?.name.isNotEmpty == true ? controller!.name : context.l10n.userDisplayName;
    return Row(children: [
      GestureDetector(onTap: controller?.pickAvatar, child: YxAvatar(c: c, size: 56, onDark: true,
        imageBytes: controller?.avatar, text: name.characters.first)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(onTap: () => edit(context, false), child: Text(name, style: serif(c, 22, color: c.characterOn))),
        const SizedBox(height: 6),
        InkWell(onTap: () => edit(context, true), child: Text(controller?.signature.isNotEmpty == true ? controller!.signature : context.l10n.userSignature,
          style: serif(c, 12, color: c.characterOn.withValues(alpha: 0.65)))),
      ])),
    ]);
  }
}

class FontSettings extends StatelessWidget {
  const FontSettings({super.key, required this.controller});
  final PersonalizationController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: controller, builder: (context, _) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(context.l10n.themeFontSize),
      Slider(value: controller.themeSize, min: 12, max: 24, divisions: 12,
        label: '${controller.themeSize.round()}', onChanged: (value) => controller.save(size: value)),
      DropdownButton<String>(isExpanded: true, value: controller.family ?? '',
        items: [DropdownMenuItem(value: '', child: Text(context.l10n.systemFont)),
          for (final entry in controller.fonts.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis))],
        onChanged: (value) => controller.save(font: value, systemFont: value == ''),
      ),
      OutlinedButton.icon(onPressed: () async {
        final ok = await controller.importFont();
        if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.fontImportFailed)));
      }, icon: const Icon(Icons.file_upload_outlined), label: Text(context.l10n.importFont)),
    ],
  ));
}
