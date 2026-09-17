import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/attachment_coordinator.dart';
import 'package:presencekit_mobile/models/screen_context.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/device_services.dart';

class _Store extends AppSettingsStore {
  PickedUploadFile? file;
  List<PickedUploadFile> images = const [];
  int filePicks = 0;
  int imagePicks = 0;

  @override
  Future<PickedUploadFile?> pickUploadFile() async {
    filePicks += 1;
    return file;
  }

  @override
  Future<List<PickedUploadFile>> pickUploadImages() async {
    imagePicks += 1;
    return images;
  }
}

PickedUploadFile _file(String name, int size) =>
    PickedUploadFile(name: name, bytes: Uint8List(size));

void main() {
  late _Store store;
  late AttachmentCoordinator coordinator;

  setUp(() {
    store = _Store();
    coordinator = AttachmentCoordinator(settings: SettingsStore(store));
  });

  test('cancel returns no file and does not invent a payload', () async {
    store.file = null;
    expect(await coordinator.pickFile(), isNull);
    expect(store.filePicks, 1);
  });

  test('rejects unsupported and oversized files before upload', () {
    expect(
      coordinator.validateFile(_file('notes.pdf', 10)),
      AttachmentValidationError.typeUnsupported,
    );
    expect(
      coordinator.validateFile(
        _file('notes.txt', AttachmentCoordinator.fileMaxBytes + 1),
      ),
      AttachmentValidationError.tooLarge,
    );
    expect(coordinator.validateFile(_file('notes.md', 12)), isNull);
  });

  test('rejects mixed image types and oversized images', () {
    expect(
      coordinator.validateImages([_file('a.png', 10), _file('b.txt', 10)]),
      AttachmentValidationError.typeUnsupported,
    );
    expect(
      coordinator.validateImages([
        _file('a.jpg', AttachmentCoordinator.imageMaxBytes + 1),
      ]),
      AttachmentValidationError.tooLarge,
    );
    expect(coordinator.validateImages([_file('a.webp', 20)]), isNull);
  });

  test('image preview names keep a three-item cap', () {
    final files = [
      _file('a.png', 1),
      _file('b.png', 1),
      _file('c.png', 1),
      _file('d.png', 1),
    ];
    expect(coordinator.imageNamesPreview(files), 'a.png、b.png、c.png');
    expect(coordinator.imagesHaveMore(files), isTrue);
    expect(coordinator.filePreview(files.first), '📎 a.png');
  });
}
