import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/widgets/letter_flow_text.dart';

void main() {
  for (final scale in [1.0, 1.6]) {
    testWidgets('letter float preserves rich Unicode text at scale $scale', (
      tester,
    ) async {
      const text = '月光落在窗边。👩🏽‍🚀 我们慢慢说，e\u0301 不必着急。\n';
      final body = List.filled(8, text).join();
      final span = TextSpan(
        style: const TextStyle(fontSize: 14, height: 2.2),
        children: [
          TextSpan(
            text: body,
            style: const TextStyle(color: Colors.blue),
          ),
          const TextSpan(
            text: '最后一句。',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SizedBox(
                width: 270,
                child: SingleChildScrollView(
                  child: LetterFlowText(span: span, c: YxPalette.light),
                ),
              ),
            ),
          ),
        ),
      );
      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.textSpan != null)
          .toList();
      expect(
        rendered.map((t) => t.textSpan!.toPlainText()).join(),
        '$body最后一句。',
      );
      expect(rendered.length, greaterThan(1));
      expect(tester.takeException(), isNull);
      final spans = rendered
          .expand((t) => (t.textSpan as TextSpan).children!.cast<TextSpan>())
          .toList();
      expect(spans.first.style!.color, Colors.blue);
      expect(spans.last.style!.fontStyle, FontStyle.italic);
    });
  }
}
