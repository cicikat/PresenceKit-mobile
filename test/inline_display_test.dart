import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/inline_display.dart';
import 'package:presencekit_mobile/widgets/inline_display_text.dart';
import 'package:presencekit_mobile/widgets/chat_widgets.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';

void main() {
  testWidgets(
    'chat bubble renders red emphasis and preserves it during selection',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: HimMessage(
              c: YxPalette.light,
              time: '12:00',
              text: 'red big small',
              displayText: '<hl>red</hl> <big>big</big> <sm>small</sm>',
              prefs: YxPrefs(),
              profileDisplayName: 'Companion',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(AnimatedRevealText),
          matching: find.byType(Text),
        ),
      );
      expect(
        ((text.textSpan! as TextSpan).children!.first as TextSpan).style!.color,
        YxPalette.light.danger,
      );
      final label = AppLocalizations.of(
        tester.element(find.byType(HimMessage)),
      ).selectAllAction;
      await tester.longPress(find.byType(AnimatedRevealText));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      final selected = tester.widget<EditableText>(find.byType(EditableText));
      final span = selected.controller.buildTextSpan(
        context: tester.element(find.byType(EditableText)),
        style: selected.style,
        withComposing: false,
      );
      expect(
        selected.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 13),
      );
      expect(span.toPlainText(), 'red big small');
      expect(
        (span.children!.first as TextSpan).style!.color,
        YxPalette.light.danger,
      );
    },
  );

  test('desktop tags map to accent, large and small text', () {
    final span = inlineDisplaySpan(
      text: 'red big small',
      displayText: '<hl>red</hl> <big>big</big> <sm>small</sm>',
      style: const TextStyle(fontSize: 20, color: Colors.black),
      accent: Colors.red,
    );
    final runs = span.children!.cast<TextSpan>();
    expect(span.toPlainText(), 'red big small');
    expect(runs[0].style!.color, Colors.red);
    expect(runs[0].style!.fontWeight, FontWeight.w600);
    expect(runs[2].style!.fontSize, closeTo(23.6, .001));
    expect(runs[4].style!.fontSize, 17);
    expect(runs[4].style!.color!.a, closeTo(.8, .01));
  });

  test('paragraph split carries styles across lines and repeats', () {
    expect(inlineDisplayParts('a\na', '<hl>a\na</hl>', ['a', 'a']), [
      '<hl>a</hl>',
      '<hl>a</hl>',
    ]);
    expect(inlineDisplayParts('hello', '<hl>different</hl>', ['hello']), [
      'hello',
    ]);
  });

  test('unknown or malformed tags are literal; stale copy falls back', () {
    expect(inlinePlainText('<script>x</script>'), '<script>x</script>');
    expect(inlinePlainText('<hl>x</big>'), '<hl>x</big>');
    expect(
      validatedInlineDisplay('canonical', '<hl>other</hl>').single.text,
      'canonical',
    );
    expect(inlinePlainText('<hl>${'x' * 201}</hl>'), '<hl>${'x' * 201}</hl>');
  });

  test('HTTP and poll keep canonical text and optional styling', () {
    final response = BackendChatResponse.fromJson({
      'reply': 'hi',
      'display_text': '<hl>hi</hl>',
    });
    expect(response.reply, 'hi');
    expect(response.displayText, '<hl>hi</hl>');
    final poll = MobilePollMessage.fromJson({
      'content': 'hi',
      'display_text': '<big>hi</big>',
    });
    expect(poll.content, 'hi');
    expect(
      poll.toChatMessage().settled().copyWith().displayText,
      '<big>hi</big>',
    );
    expect(BackendChatResponse.fromJson({'reply': 'old'}).displayText, isNull);
    expect(
      MobilePollMessage.fromJson({
        'content': 'old',
        'display_text': 12,
      }).displayText,
      isNull,
    );
  });

  testWidgets('typing reveals graphemes without partial tag characters', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedRevealText(
            text: '👩‍💻hello',
            displayText: '<hl>👩‍💻hello</hl>',
            accent: Colors.red,
            animate: true,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    final rich = tester.widget<Text>(find.byType(Text).last).textSpan!;
    expect(rich.toPlainText(), '👩‍💻▍');
    expect(rich.toPlainText(), isNot(contains('<')));
    await tester.tap(find.byType(AnimatedRevealText));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byType(Text).last).textSpan!.toPlainText(),
      '👩‍💻hello',
    );
  });
}
