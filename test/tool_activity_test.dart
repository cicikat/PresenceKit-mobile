import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/tool_activity.dart';
import 'package:presencekit_mobile/widgets/tool_activity_widgets.dart';

void main() {
  test(
    'receipt parsing rejects unrelated realms and preserves unknown outcomes',
    () {
      final json = {
        'source': 'reality',
        'event_id': 'e1',
        'chain_id': 'c1',
        'char_id': 'ch',
        'tool_name': 'read_document',
        'status': 'unknown',
      };
      final activity = ToolActivity.tryParse(json)!;
      expect(activity.status, 'unknown');
      expect(
        activity.sameChain(ToolActivity.tryParse({...json, 'event_id': 'e2'})),
        isTrue,
      );
      expect(
        activity.sameChain(
          ToolActivity.tryParse({...json, 'char_id': 'other'}),
        ),
        isFalse,
      );
      expect(ToolActivity.tryParse({...json, 'source': 'dream'}), isNull);
      expect(ToolActivity.tryParse({'tool_name': 'incomplete'}), isNull);
      final entry = ChatLogEntry.fromJson({'tool_activity': json});
      expect(entry.toolActivity!.eventId, 'e1');
      expect(entry.assistant, isEmpty);
      expect(const YxPrefs().showToolActivity, isTrue);
    },
  );

  testWidgets(
    'compact status rows show right-hand dots and joined chains in both themes',
    (tester) async {
      for (final palette in [YxPalette.light, YxPalette.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  for (final status in ['success', 'error', 'unknown'])
                    ToolActivityRow(
                      c: palette,
                      activity: ToolActivity(
                        eventId: status,
                        chainId: 'c',
                        characterId: 'ch',
                        name: status,
                        status: status,
                      ),
                      connectBefore: status != 'success',
                      connectAfter: status != 'unknown',
                    ),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(tester.widget<Text>(find.text('success')).style!.fontSize, 9.5);
        final circles = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        expect(circles, findsNWidgets(3));
        expect(
          tester.getCenter(circles.first).dx,
          greaterThan(tester.getTopRight(find.text('success')).dx),
        );
        final colors = tester
            .widgetList<Container>(circles)
            .map((w) => (w.decoration as BoxDecoration).color)
            .toList();
        expect(colors, [
          const Color(0xFF4C9B70),
          const Color(0xFFD36B6B),
          palette.ink3,
        ]);
        expect(tester.getSize(find.byType(ToolActivityRow).first).height, 22);
      }
    },
  );
}
