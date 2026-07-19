import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> loadArb(String path) {
    return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  }

  Set<String> messageKeys(Map<String, dynamic> arb) {
    return arb.keys.where((key) => !key.startsWith('@')).toSet();
  }

  test('Chinese and English catalogs expose the same message keys', () {
    final zh = loadArb('lib/l10n/app_zh.arb');
    final en = loadArb('lib/l10n/app_en.arb');

    expect(messageKeys(en), messageKeys(zh));
    for (final key in messageKeys(zh)) {
      expect(zh[key], isA<String>(), reason: 'zh message $key must be text');
      expect(en[key], isA<String>(), reason: 'en message $key must be text');
      expect((zh[key] as String).trim(), isNotEmpty, reason: 'empty zh: $key');
      expect((en[key] as String).trim(), isNotEmpty, reason: 'empty en: $key');
    }
  });

  test(
    'localization generator keeps checked-in output and untranslated report',
    () {
      final config = File('l10n.yaml').readAsStringSync();

      expect(config, contains('output-dir: lib/l10n/generated'));
      expect(config, contains('synthetic-package: false'));
      expect(config, contains('untranslated-messages-file:'));
    },
  );
}
