import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../services/app_settings_store.dart';

class PersonalizationController extends ChangeNotifier {
  PersonalizationController(this.store);
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  final AppSettingsStore store;
  String name = '';
  String signature = '';
  Uint8List? avatar;
  String? family;
  double themeSize = 16;
  final Map<String, String> fonts = {};
  Directory? _directory;
  Future<void> _writes = Future.value();

  Future<void> restore() async {
    final path = await store.localPresentationDirectory();
    if (path == null) return;
    _directory = Directory(path);
    await _directory!.create(recursive: true);
    final file = File('$path/preferences.json');
    try {
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map;
        name = data['name'] as String? ?? '';
        signature = data['signature'] as String? ?? '';
        themeSize = (data['themeSize'] as num?)?.toDouble().clamp(12, 24) ?? 16;
        family = data['family'] as String?;
        for (final entry in (data['fonts'] as Map? ?? {}).entries) {
          final id = entry.key.toString();
          if (!RegExp(r'^font-[0-9]+$').hasMatch(id)) continue;
          final font = File('$path/$id');
          if (!await font.exists()) continue;
          final loader = FontLoader(id)
            ..addFont(
              Future.value(ByteData.sublistView(await font.readAsBytes())),
            );
          await loader.load();
          fonts[id] = entry.value.toString();
        }
        if (!fonts.containsKey(family)) family = null;
      }
      final image = File('$path/avatar');
      if (await image.exists()) avatar = await image.readAsBytes();
    } catch (_) {
      family = null;
    }
    notifyListeners();
  }

  Future<void> save({
    String? userName,
    String? userSignature,
    double? size,
    String? font,
    bool systemFont = false,
  }) async {
    if (userName != null) name = userName.trim();
    if (userSignature != null) signature = userSignature.trim();
    if (size != null) themeSize = size.clamp(12, 24);
    if (font != null) family = font;
    if (systemFont) family = null;
    notifyListeners();
    final path = _directory?.path;
    if (path == null) return;
    final value = jsonEncode({
      'name': name,
      'signature': signature,
      'themeSize': themeSize,
      'family': family,
      'fonts': fonts,
    });
    _writes = _writes.catchError((_) {}).then((_) async {
      final temporary = File('$path/preferences.tmp');
      await temporary.writeAsString(value, flush: true);
      await temporary.rename('$path/preferences.json');
    });
    await _writes;
  }

  Future<void> pickAvatar({
    required Future<Uint8List?> Function(Uint8List) crop,
  }) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      requestFullMetadata: false,
    );
    if (image == null || _directory == null) return;
    final bytes = await crop(await image.readAsBytes());
    if (bytes == null || _disposed) return;
    await File('${_directory!.path}/avatar').writeAsBytes(bytes, flush: true);
    avatar = bytes;
    notifyListeners();
  }

  Future<bool> importFont() async {
    if (_directory == null) return false;
    final file = await store.pickUploadFile();
    if (file == null) return true;
    if (!RegExp(
          r'\.(ttf|otf|ttc)$',
          caseSensitive: false,
        ).hasMatch(file.name) ||
        file.bytes.length > 20 * 1024 * 1024 ||
        fonts.length >= 10) {
      return false;
    }
    final id = 'font-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final loader = FontLoader(id)
        ..addFont(Future.value(ByteData.sublistView(file.bytes)));
      await loader.load();
      await File(
        '${_directory!.path}/$id',
      ).writeAsBytes(file.bytes, flush: true);
      fonts[id] = file.name;
      await save(font: id);
      return true;
    } catch (_) {
      return false;
    }
  }
}
