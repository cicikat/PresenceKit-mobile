import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/conversation_calendar_controller.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/conversation_calendar.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/widgets/conversation_calendar_widgets.dart';

class CalendarBackend extends BackendClient {
  CalendarBackend()
    : super(
        baseUrl: 'http://127.0.0.1:8080',
        settingsStore: const AppSettingsStore(),
      );
  final requests = <Map<String, String?>>[];
  Completer<ConversationCalendar>? pending;
  bool fail = false;
  bool unknownBoundary = false;
  @override
  Future<ConversationCalendar> fetchConversationCalendar({
    required String token,
    String period = 'month',
    String? date,
    String? character,
    String? start,
    String? end,
  }) async {
    requests.add({
      'period': period,
      'date': date,
      'char_id': character,
      'start': start,
      'end': end,
    });
    if (fail) throw const BackendException('unavailable', statusCode: 503);
    if (pending case final wait?) {
      pending = null;
      return wait.future;
    }
    final anchor = DateTime.parse(date ?? '2026-09-12');
    final first = start != null
        ? DateTime.parse(start)
        : switch (period) {
            'year' => DateTime(anchor.year),
            'month' => DateTime(anchor.year, anchor.month),
            'week' => anchor.subtract(Duration(days: anchor.weekday - 1)),
            _ => anchor,
          };
    final last = end != null
        ? DateTime.parse(end)
        : switch (period) {
            'year' => DateTime(anchor.year, 12, 31),
            'month' => DateTime(anchor.year, anchor.month + 1, 0),
            'week' => first.add(const Duration(days: 6)),
            _ => anchor,
          };
    return ConversationCalendar.fromJson({
      'start': ConversationCalendarController.dateKey(first),
      'end': ConversationCalendarController.dateKey(last),
      'char_id': 'nova',
      'totals_partial': true,
      'days': [
        for (
          var day = first;
          !day.isAfter(last);
          day = day.add(const Duration(days: 1))
        )
          {
            'date': ConversationCalendarController.dateKey(day),
            'coverage': day.isAfter(DateTime(2026, 9, 12))
                ? 'future'
                : day.day < 4
                ? 'unavailable'
                : 'complete',
            'chat_rounds':
                day.isAfter(DateTime(2026, 9, 12)) ||
                    day.day < 4 ||
                    (unknownBoundary && day.day == 9)
                ? null
                : day.day == 12 || day.day == 9
                ? 0
                : day.day * 3,
            'total_tokens': day.day < 4 ? null : day.day * 1234,
            'input_tokens': day.day * 1000,
            'output_tokens': day.day * 234,
            'tool_calls': day.day,
            'image_views': day.day ~/ 2,
            'model_calls': day.day * 2,
            'usage_missing_calls': 0,
          },
      ],
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['CALENDAR_SCREENSHOTS'] != '1') return;
    final path = File('C:/Windows/Fonts/msyh.ttc');
    if (!path.existsSync()) return;
    final bytes = await path.readAsBytes();
    for (final family in ['serif', 'monospace', 'Roboto']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  test(
    'unknown totals remain unknown, and streak spans yesterday using server date',
    () async {
      final empty = ConversationCalendar.fromJson({
        'start': '2026-01-01',
        'end': '2026-01-01',
        'char_id': 'nova',
        'days': [
          {
            'date': '2026-01-01',
            'coverage': 'unavailable',
            'chat_rounds': null,
          },
        ],
      });
      expect(empty.total('chat_rounds'), isNull);
      final backend = CalendarBackend();
      final controller = ConversationCalendarController(
        backend: () => backend,
        token: () => 'test',
      );
      await controller.load();
      expect(controller.streak, 2);
      expect(controller.streakLowerBound, isFalse);
      expect(backend.requests.last['char_id'], 'nova');
      expect(backend.requests.last['end'], '2026-09-12');
      backend.unknownBoundary = true;
      await controller.load();
      expect(controller.streak, 2);
      expect(controller.streakLowerBound, isTrue);
      controller.dispose();
    },
  );

  test(
    'late requests cannot replace a newer period or notify after disposal',
    () async {
      final backend = CalendarBackend();
      final controller = ConversationCalendarController(
        backend: () => backend,
        token: () => 'test',
      );
      final pending = Completer<ConversationCalendar>();
      backend.pending = pending;
      final old = controller.load(period: 'month');
      await controller.load(period: 'year', date: DateTime(2024));
      expect(controller.calendar!.days.length, 366);
      final latest = controller.calendar;
      pending.complete(latest);
      await old;
      expect(controller.calendar, same(latest));
      backend.fail = true;
      await controller.load();
      expect(controller.calendar, isNull);
      expect(controller.error, 'unavailable');
      controller.dispose();
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'calendar ${dark ? 'night' : 'day'}: narrow layout, periods and day details',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final c = dark ? YxPalette.dark : YxPalette.light;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                backgroundColor: c.surface,
                body: ConversationCalendarPage(
                  c: c,
                  palette: 'jade',
                  name: 'Nova',
                  backend: CalendarBackend(),
                  token: 'test',
                  onBack: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Nova'), findsWidgets);
        final cell = find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == '2026-09-10 · 30',
        );
        await tester.ensureVisible(cell);
        await tester.tap(cell);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('输入 Token'), findsWidgets);
        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await tester.pumpAndSettle();
        for (final label in ['日', '周', '年', '月']) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          final segment = find.descendant(
            of: find.byType(SegmentedButton<String>),
            matching: find.text(label),
          );
          await tester.tap(segment);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        if (Platform.environment['CALENDAR_SCREENSHOTS'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('build/calendar-${dark ? 'night' : 'day'}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}
