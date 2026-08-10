import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real-device matrix is versioned and does not fabricate evidence', () {
    final matrix = jsonDecode(
      File('docs/android/device-lifecycle-matrix.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(matrix['schema_version'], '1.0.0');
    expect(matrix['scope'], 'real_device_acceptance');
    expect(matrix['status_summary'], isIn(['not-run', 'partial', 'passed', 'failed']));

    final environment = matrix['environment'] as Map<String, dynamic>;
    final cases = matrix['cases'] as List<dynamic>;
    expect(cases, isNotEmpty);

    for (final item in cases.cast<Map<String, dynamic>>()) {
      expect(item['id'], isNotEmpty);
      expect(item['status'], isIn(['not-run', 'passed', 'failed', 'blocked']));
      if (item['status'] == 'passed') {
        expect(matrix['status_summary'], isIn(['partial', 'passed']));
        expect(environment['device_model'], isNotEmpty);
        expect(environment['android_version'], isNotEmpty);
        expect(environment['app_version'], isNotEmpty);
        expect(environment['executed_at'], isNotEmpty);
        expect(item['evidence'], isNotEmpty);
      }
    }
  });
}
