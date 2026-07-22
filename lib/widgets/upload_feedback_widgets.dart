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
