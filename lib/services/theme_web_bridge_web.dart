// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _storageKey = 'presencekit_mobile.color_presets.v1';

Future<String?> loadWebThemePresets() async =>
    html.window.localStorage[_storageKey];

Future<void> saveWebThemePresets(String value) async {
  html.window.localStorage[_storageKey] = value;
}

Future<bool> exportThemeModFile(String filename, String contents) async {
  final blob = html.Blob([contents], 'application/json;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    html.AnchorElement(href: url)
      ..download = filename
      ..click();
    return true;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
