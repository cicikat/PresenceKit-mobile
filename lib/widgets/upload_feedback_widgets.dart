import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

class UploadFeedback {
  const UploadFeedback._();

  static void fileTypeUnsupported(BuildContext context) =>
      _show(context, context.l10n.fileTypeUnsupported);

  static void fileTooLarge(BuildContext context) =>
      _show(context, context.l10n.fileTooLarge);

  static void imageTypeUnsupported(BuildContext context) =>
      _show(context, context.l10n.imageTypeUnsupported);

  static void imageTooLarge(BuildContext context) =>
      _show(context, context.l10n.imageTooLarge);

  static String filePreview(String name) => '📎 $name';

  static String imagePreview(
    BuildContext context, {
    required int count,
    required String names,
    required bool hasMore,
  }) => count == 1
      ? filePreview(names)
      : context.l10n.imageCountPreview(count, names, hasMore ? '…' : '');

  static String fileFailureLabel(BuildContext context) =>
      context.l10n.fileFailureLabel;

  static String imageFailureLabel(BuildContext context) =>
      context.l10n.imageFailureLabel;

  static void _show(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class ImageCaptionDialog extends StatefulWidget {
  const ImageCaptionDialog({super.key});
  @override
  State<ImageCaptionDialog> createState() => _ImageCaptionDialogState();
}

class _ImageCaptionDialogState extends State<ImageCaptionDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.imageCaptionTitle),
    content: TextField(
      controller: _controller,
      maxLines: 3,
      autofocus: true,
      decoration: InputDecoration(hintText: context.l10n.imageCaptionHint),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancelAction),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(context.l10n.sendAction),
      ),
    ],
  );
}
