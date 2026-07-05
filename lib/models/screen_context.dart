import 'dart:typed_data';

class ScreenTextUploadAppOption {
  const ScreenTextUploadAppOption({
    required this.packageName,
    required this.appLabel,
  });

  factory ScreenTextUploadAppOption.fromPlatform(Map<dynamic, dynamic> raw) {
    return ScreenTextUploadAppOption(
      packageName: (raw['packageName'] ?? '').toString(),
      appLabel: (raw['appLabel'] ?? '').toString(),
    );
  }

  final String packageName;
  final String appLabel;
}

class PickedUploadFile {
  const PickedUploadFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class ScreenContextSnapshot {
  const ScreenContextSnapshot({
    required this.isBlocked,
    required this.blockedReason,
    required this.textUploadAllowed,
    required this.packageName,
    required this.appLabel,
    required this.className,
    required this.windowTitle,
    required this.visibleText,
    required this.clickableText,
    required this.capturedAt,
  });

  factory ScreenContextSnapshot.fromPlatform(Map<dynamic, dynamic> raw) {
    List<String> readList(String key) {
      final value = raw[key];
      if (value is Iterable) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      return const [];
    }

    final captured = raw['capturedAt'];
    return ScreenContextSnapshot(
      isBlocked: raw['isBlocked'] == true,
      blockedReason: (raw['blockedReason'] ?? '').toString(),
      textUploadAllowed: raw['textUploadAllowed'] == true,
      packageName: (raw['packageName'] ?? '').toString(),
      appLabel: (raw['appLabel'] ?? '').toString(),
      className: (raw['className'] ?? '').toString(),
      windowTitle: (raw['windowTitle'] ?? '').toString(),
      visibleText: readList('visibleText'),
      clickableText: readList('clickableText'),
      capturedAt: captured is num
          ? captured.toDouble()
          : double.tryParse((captured ?? '0').toString()) ?? 0,
    );
  }

  final bool isBlocked;
  final String blockedReason;
  final bool textUploadAllowed;
  final String packageName;
  final String appLabel;
  final String className;
  final String windowTitle;
  final List<String> visibleText;
  final List<String> clickableText;
  final double capturedAt;

  bool get isEmpty =>
      !isBlocked &&
      packageName.isEmpty &&
      appLabel.isEmpty &&
      windowTitle.isEmpty &&
      visibleText.isEmpty;

  Map<String, dynamic> toRealtimePayload({
    int windowSeconds = 45,
    bool allowTextUpload = false,
  }) {
    if (isBlocked) {
      throw StateError('Blocked screen context must not be uploaded');
    }
    final includeText = textUploadAllowed && allowTextUpload;
    final titleHint = includeText && windowTitle.isNotEmpty
        ? windowTitle
        : appLabel;
    return {
      'window_seconds': windowSeconds,
      'ts': DateTime.now().millisecondsSinceEpoch / 1000,
      'sensor_version': 'android_accessibility_1.0',
      'input': {
        'keystrokes': 0,
        'mouse_clicks': 0,
        'mouse_distance_px': 0,
        'idle_seconds': 0,
      },
      'focus': {'app': packageName, 'title_hint': titleHint, 'switch_count': 0},
      'screen': {
        'package_name': packageName,
        'app_label': appLabel,
        'window_title': includeText ? windowTitle : '',
        'visible_text': includeText
            ? visibleText.take(60).toList(growable: false)
            : const <String>[],
        'clickable_text': includeText
            ? clickableText.take(40).toList(growable: false)
            : const <String>[],
      },
    };
  }
}
