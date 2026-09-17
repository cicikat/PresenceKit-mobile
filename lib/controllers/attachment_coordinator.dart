import '../models/screen_context.dart';
import '../services/device_services.dart';

enum AttachmentValidationError { typeUnsupported, tooLarge }

/// Picks and validates chat attachments. Upload itself stays on ChatController.
class AttachmentCoordinator {
  AttachmentCoordinator({required SettingsStore settings})
    : _settings = settings;

  static const fileExtensions = ['.txt', '.md', '.docx'];
  static const imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.heic',
    '.heif',
    '.bmp',
  ];
  static const fileMaxBytes = 5 * 1024 * 1024;
  static const imageMaxBytes = 10 * 1024 * 1024;

  final SettingsStore _settings;

  Future<PickedUploadFile?> pickFile() => _settings.pickUploadFile();

  Future<List<PickedUploadFile>> pickImages() => _settings.pickUploadImages();

  AttachmentValidationError? validateFile(PickedUploadFile file) {
    if (!_hasExtension(file.name, fileExtensions)) {
      return AttachmentValidationError.typeUnsupported;
    }
    if (file.bytes.length > fileMaxBytes) {
      return AttachmentValidationError.tooLarge;
    }
    return null;
  }

  AttachmentValidationError? validateImages(List<PickedUploadFile> files) {
    if (files.any((file) => !_hasExtension(file.name, imageExtensions))) {
      return AttachmentValidationError.typeUnsupported;
    }
    if (files.any((file) => file.bytes.length > imageMaxBytes)) {
      return AttachmentValidationError.tooLarge;
    }
    return null;
  }

  String filePreview(PickedUploadFile file) => '📎 ${file.name}';

  String imageNamesPreview(List<PickedUploadFile> files) {
    if (files.length == 1) return files.first.name;
    return files.take(3).map((file) => file.name).join('、');
  }

  bool imagesHaveMore(List<PickedUploadFile> files) => files.length > 3;

  bool _hasExtension(String name, List<String> extensions) {
    final lower = name.toLowerCase();
    return extensions.any(lower.endsWith);
  }
}
