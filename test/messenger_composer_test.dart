import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/ui_layout.dart';
import 'package:presencekit_mobile/controllers/voice_input_controller.dart';
import 'package:presencekit_mobile/widgets/chat_widgets.dart';
import 'package:presencekit_mobile/widgets/conversation_presentation.dart';

void main() {
  testWidgets(
    'messenger emoji edits draft, attachment opens, recording and send stay wired',
    (tester) async {
      var attached = 0;
      var recorded = 0;
      String? sent;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConversationPresentation(
              daily: DailyLayout.messenger,
              child: Composer(
                c: dailyLayoutPalette(DailyLayout.messenger, YxPalette.light),
                bubbleOpacity: .94,
                fontSize: 16,
                sending: false,
                onOpenAttach: () => attached++,
                onSend: (text) => sent = text,
                onVoiceRecordStart: () async {
                  recorded++;
                  return null;
                },
                onVoiceRecordStop: () async => const VoiceInputResult(),
                onVoiceRecordCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Emoji'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('😊'));
      await tester.pumpAndSettle();
      expect(find.text('😊'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(sent, '😊');
      expect(find.text('😊'), findsNothing);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      expect(attached, 1);
      await tester.longPress(find.byIcon(Icons.mic_none_rounded));
      await tester.pump();
      expect(recorded, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
