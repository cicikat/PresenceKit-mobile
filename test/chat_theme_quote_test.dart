import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/ui_layout.dart';
import 'package:presencekit_mobile/widgets/chat_widgets.dart';
import 'package:presencekit_mobile/widgets/conversation_presentation.dart';
import 'package:presencekit_mobile/widgets/reference_layout_shell.dart';
import 'package:presencekit_mobile/widgets/layout_settings.dart';

void main() {
  testWidgets(
    'dreamcore heart switches theme and letter fourth tab opens usage',
    (tester) async {
      var toggled = 0;
      AppRoute? routed;
      Widget header(DailyLayout layout) => MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReferenceHeader(
            c: YxPalette.light,
            layout: layout,
            route: AppRoute.chat,
            name: 'Companion',
            onMenu: () {},
            onSettings: () {},
            dark: false,
            onRoute: (value) => routed = value,
            onToggleTheme: () => toggled++,
          ),
        ),
      );
      await tester.pumpWidget(header(DailyLayout.reverie));
      await tester.tap(find.byIcon(Icons.favorite));
      expect(toggled, 1);
      expect(routed, isNull);
      await tester.pumpWidget(header(DailyLayout.letter));
      expect(find.text('设置'), findsNothing);
      await tester.tap(find.text('使用情况'));
      expect(routed, AppRoute.conversationCalendar);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'letter moon/sun toggles appearance without dream navigation, dark=$dark',
      (tester) async {
        var toggled = 0;
        AppRoute? routed;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ReferenceHeader(
                c: YxPalette.light,
                layout: DailyLayout.letter,
                route: AppRoute.chat,
                name: 'Companion',
                onMenu: () {},
                onSettings: () {},
                dark: dark,
                onRoute: (value) => routed = value,
                onToggleTheme: () => toggled++,
              ),
            ),
          ),
        );
        await tester.tap(
          find.byIcon(
            dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        );
        expect(toggled, 1);
        expect(routed, isNull);
      },
    );
  }
  testWidgets(
    'messenger ellipsis disguises day/night shortcut and picker has one dreamcore',
    (tester) async {
      var toggled = 0;
      var menus = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                ConversationHeader(
                  c: YxPalette.light,
                  name: 'Companion',
                  layout: DailyLayout.messenger,
                  dark: false,
                  onMenu: () => menus++,
                  onSettings: () {},
                  onToggleTheme: () => toggled++,
                ),
                LayoutSettings(
                  c: YxPalette.light,
                  daily: DailyLayout.noir,
                  dream: DreamLayout.classic,
                  onDaily: (_) {},
                  onDream: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.more_horiz));
      expect(toggled, 1);
      expect(menus, 0);
      final picker = tester.widget<DropdownButton<DailyLayout>>(
        find.byType(DropdownButton<DailyLayout>),
      );
      expect(picker.items!.length, 4);
      expect(picker.value, DailyLayout.reverie);
      expect(
        picker.items!
            .where((item) => (item.child as Text).data == '黑粉梦核')
            .length,
        1,
      );
    },
  );
  for (final layout in DailyLayout.values) {
    testWidgets('${layout.name} quotes and waiting use its own presentation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConversationPresentation(
              daily: layout,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const HimMessage(
                      c: YxPalette.light,
                      time: '12:00',
                      text: 'answer',
                      quotedText: '<b>assistant quote</b>',
                      prefs: YxPrefs(),
                      profileDisplayName: 'Companion',
                    ),
                    const YouMessage(
                      c: YxPalette.light,
                      time: '12:00',
                      text: 'my reply',
                      quotedText: '<b>user quote</b>',
                      prefs: YxPrefs(),
                    ),
                    ReplyPreviewBar(
                      c: YxPalette.light,
                      text: '<i>preview quote</i>',
                      label: 'Reply',
                      onCancel: () {},
                    ),
                    const TypingHimMessage(
                      c: YxPalette.light,
                      time: '12:00',
                      prefs: YxPrefs(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.takeException(), isNull);
      expect(find.text('assistant quote'), findsOneWidget);
      expect(find.text('user quote'), findsOneWidget);
      expect(find.text('preview quote'), findsOneWidget);
      final classicStripes = tester
          .widgetList<Container>(find.byType(Container))
          .where((container) {
            final decoration = container.decoration;
            if (decoration is! BoxDecoration || decoration.border is! Border) {
              return false;
            }
            final border = decoration.border! as Border;
            return border.left.width >= 2 &&
                border.left.style == BorderStyle.solid &&
                border.right.style == BorderStyle.none &&
                border.top.style == BorderStyle.none &&
                border.bottom.style == BorderStyle.none;
          });
      expect(classicStripes.isNotEmpty, layout == DailyLayout.classic);
    });
  }
}
