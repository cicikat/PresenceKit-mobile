// test/no_hardcoded_qq_number_test.dart
//
// Regression test mirroring the backend's tests/test_no_hardcoded_qq_number.py:
// no file that would be tracked by git may contain the real owner QQ number
// literal. Fixture/test doubles must use an obviously-fake id (e.g. '10001').

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _forbiddenNumber = '1043484516';
const Set<String> _scanDirs = {'lib', 'android', 'docs', 'test'};
const Set<String> _textExtensions = {
  '.dart',
  '.kt',
  '.md',
  '.yaml',
  '.yml',
  '.json',
  '.gradle',
  '.xml',
};
const Set<String> _excludeDirParts = {
  '.git',
  '.dart_tool',
  'build',
  '.gradle',
  '.idea',
};
const String _selfName = 'no_hardcoded_qq_number_test.dart';

Directory _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('pubspec.yaml not found above ${Directory.current.path}');
    }
    dir = parent;
  }
}

void main() {
  test('repo contains no hardcoded owner QQ number', () {
    final root = _findRepoRoot();
    final violations = <String>[];

    for (final dirName in _scanDirs) {
      final dir = Directory('${root.path}/$dirName');
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final relParts = entity.path
            .substring(root.path.length)
            .split(RegExp(r'[\\/]'));
        if (relParts.any(_excludeDirParts.contains)) continue;
        final ext = entity.path.contains('.')
            ? entity.path.substring(entity.path.lastIndexOf('.'))
            : '';
        if (!_textExtensions.contains(ext)) continue;
        if (entity.uri.pathSegments.isNotEmpty &&
            entity.uri.pathSegments.last == _selfName) {
          continue;
        }
        String text;
        try {
          text = entity.readAsStringSync();
        } catch (_) {
          continue;
        }
        if (text.contains(_forbiddenNumber)) {
          final lines = text.split('\n');
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].contains(_forbiddenNumber)) {
              violations.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
            }
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Found hardcoded QQ number $_forbiddenNumber:\n'
          '${violations.join('\n')}',
    );
  });
}
