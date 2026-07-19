// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _storageKey = 'presencekit_mobile.language.v1';

Future<String?> loadWebAppLanguage() async =>
    html.window.localStorage[_storageKey];

Future<void> saveWebAppLanguage(String value) async {
  html.window.localStorage[_storageKey] = value;
}
