import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/widgets/common_widgets.dart';
import 'package:presencekit_mobile/widgets/reference_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reference fonts and license notices are bundled for offline use',
    () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final family in [referenceSerifFamily, referenceLatinFamily]) {
        final item = manifest.cast<Map>().singleWhere(
          (item) => item['family'] == family,
        );
        final loader = FontLoader(family);
        for (final font in item['fonts'] as List) {
          final bytes = await rootBundle.load(font['asset'] as String);
          expect(bytes.lengthInBytes, greaterThan(10000));
          loader.addFont(Future.value(bytes));
        }
        await loader.load();
      }
      for (final asset in [
        'assets/fonts/NotoSerifCJK-LICENSE.txt',
        'assets/fonts/LibreBaskerville-OFL.txt',
      ]) {
        expect(
          await rootBundle.loadString(asset),
          contains('SIL OPEN FONT LICENSE'),
        );
      }
      final text = TextPainter(
        text: TextSpan(
          text: '把日常，慢慢说。「我们之间」',
          style: referenceSerif(YxPalette.light, 14, height: 2.2),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 300);
      expect(text.height, greaterThan(20));
      text.dispose();
    },
  );
  test(
    'imported typeface and chosen scale override only the reference defaults',
    () {
      AppTypography.family = 'chosen-font';
      AppTypography.scale = 1.25;
      final style = referenceSerif(YxPalette.light, 14, height: 2.2);
      expect(style.fontFamily, 'chosen-font');
      expect(style.fontSize, 17.5);
      expect(style.height, 2.2);
      AppTypography.family = null;
      AppTypography.scale = 1;
      expect(
        referenceSerif(YxPalette.light, 14).fontFamily,
        referenceSerifFamily,
      );
    },
  );
}
