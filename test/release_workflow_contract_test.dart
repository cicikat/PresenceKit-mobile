import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formal release workflow explicitly builds and verifies prod flavor', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    expect(workflow, contains('flutter build apk --release --flavor prod'));
    expect(workflow, contains('build/app/outputs/flutter-apk/app-prod-release.apk'));
    expect(workflow, contains('flavor=prod'));
    expect(workflow, contains("com.presencekit.mobile"));
    expect(workflow, isNot(contains('flutter build apk --release\n')));
    expect(workflow, isNot(contains('app-release.apk')));
  });

  test('Android release identity keeps prod distinct from dev', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('create("dev")'));
    expect(gradle, contains('create("prod")'));
    expect(gradle, contains('applicationIdSuffix = ".dev"'));
    expect(gradle, contains('applicationId = "com.presencekit.mobile"'));
    expect(gradle, contains('Release signing is required'));
  });
}
