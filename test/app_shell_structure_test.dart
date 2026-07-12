import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app_shell structure debt does not grow past the audited baseline', () {
    final source = File('lib/pages/app_shell.dart').readAsStringSync();
    final lineCount = '\n'.allMatches(source).length + 1;

    expect(
      lineCount,
      lessThanOrEqualTo(2674),
      reason: 'New domain state belongs in lib/controllers, not app_shell.dart.',
    );
  });
}
