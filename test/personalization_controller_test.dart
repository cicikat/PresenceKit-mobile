import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/personalization_controller.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';

class _Store extends AppSettingsStore {
  const _Store(this.path);
  final String path;
  @override
  Future<String?> localPresentationDirectory() async => path;
}

void main() {
  test('local identity and interface size survive concurrent saves and restart', () async {
    final directory = await Directory.systemTemp.createTemp('presentation-test');
    try {
      final controller = PersonalizationController(_Store(directory.path));
      await controller.restore();
      await Future.wait([
        controller.save(userName: '  User  ', size: 19),
        controller.save(userSignature: 'A small signature'),
      ]);
      controller.dispose();
      final restored = PersonalizationController(_Store(directory.path));
      await restored.restore();
      expect(restored.name, 'User');
      expect(restored.signature, 'A small signature');
      expect(restored.themeSize, 19);
      restored.dispose();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
