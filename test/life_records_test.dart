import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/life_records_controller.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/life_record.dart';
import 'package:presencekit_mobile/services/life_records_service.dart';
import 'package:presencekit_mobile/widgets/life_records_widgets.dart';

Map<String, dynamic> row(
  String id, {
  String category = 'diet',
  String date = '2026-09-11',
  bool pending = false,
}) => {
  'id': id,
  'category': category,
  'occurred_on': date,
  'title': 'Record $id',
  'items': [
    {
      'name': 'Rice',
      'quantity': '1',
      'unit': 'bowl',
      'amount': '10.50',
      'currency': 'CNY',
    },
  ],
  'recognition_status': 'ready',
  'revision': 1,
  'local_operations': pending
      ? [
          {'state': 'queued'},
        ]
      : [],
};

class FakeLifeService extends LifeRecordsService {
  List<Map<String, dynamic>> rows = [];
  final List<String> calls = [];
  final List<Map<String, dynamic>> arguments = [];
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)? onQuery;
  Future<Map<String, dynamic>> Function()? onSync;
  bool snapshotFails = false;
  bool saveFails = false;
  @override
  Future<dynamic> invoke(
    String method,
    String origin,
    String owner, [
    Map<String, dynamic> args = const {},
  ]) async {
    calls.add(method);
    arguments.add(args);
    if (method == 'save' && saveFails) {
      throw PlatformException(code: 'storage_error');
    }
    return 'saved-id';
  }

  @override
  Future<Map<String, dynamic>> object(
    String method,
    String origin,
    String owner, [
    Map<String, dynamic> args = const {},
  ]) async {
    calls.add(method);
    arguments.add(args);
    if (method == 'sync') return onSync?.call() ?? {'status': 'unsupported'};
    if (method == 'query') {
      return onQuery?.call(args) ?? {'records': rows, 'next_cursor': null};
    }
    if (method == 'snapshot') {
      if (snapshotFails) throw PlatformException(code: 'storage_error');
      return {
        'records': rows,
        'queue': {
          'queued': rows
              .where((r) => (r['local_operations'] as List).isNotEmpty)
              .length,
        },
        'sync': {'status': 'unsupported'},
      };
    }
    return {'status': 'unsupported'};
  }

  @override
  Future<Uint8List?> image(String origin, String owner, String id) async =>
      null;
}

void main() {
  late FakeLifeService service;
  late LifeRecordsController controller;
  var owner = 'owner';
  setUp(() {
    owner = 'owner';
    service = FakeLifeService();
    controller = LifeRecordsController(
      origin: () => 'https://example.test',
      owner: () => owner,
      service: service,
    );
  });
  tearDown(() => controller.dispose());

  test('date, category and item text filter cached records', () async {
    service.rows = [
      row('today'),
      row('bill', category: 'bill'),
      row('old', date: '2025-01-01'),
    ];
    await controller.reload();
    controller.filters(
      category: 'diet',
      from: '2026-09-01',
      to: '2026-09-30',
      query: 'rice',
    );
    expect(controller.visible.map((r) => r.id), ['today']);
  });

  test('failed query preserves offline records and actionable error', () async {
    service.rows = [row('local', pending: true)];
    await controller.reload();
    service.onQuery = (_) async => throw PlatformException(code: 'http_404');
    await controller.search();
    expect(controller.visible.single.id, 'local');
    expect(controller.cacheOnly, isTrue);
    expect(controller.error, 'http_404');
  });

  test('server pagination preserves pending changes and uses cursor', () async {
    service.rows = [row('one'), row('two'), row('local', pending: true)];
    service.onQuery = (args) async {
      final filters = jsonDecode(args['filters'] as String);
      return filters['cursor'] == null
          ? {
              'records': [row('one')],
              'next_cursor': 'page-2',
            }
          : {
              'records': [row('two')],
              'next_cursor': null,
            };
    };
    await controller.search();
    expect(controller.visible.map((r) => r.id).toSet(), {'one', 'local'});
    await controller.search(more: true);
    expect(controller.visible.map((r) => r.id).toSet(), {
      'one',
      'two',
      'local',
    });
    expect(controller.cursor, isNull);
  });

  test(
    'late response from previous owner cannot populate current screen',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      service.onQuery = (_) => pending.future;
      final search = controller.search();
      owner = 'new_owner';
      controller.connectionChanged();
      pending.complete({
        'records': [row('private')],
        'next_cursor': null,
      });
      await search;
      expect(controller.records, isEmpty);
    },
  );

  test('editor realm mismatch never sends data', () async {
    final expected = controller.realm;
    owner = 'other';
    expect(
      await controller.save(row('one'), null, expectedRealm: expected),
      isFalse,
    );
    expect(service.calls, isEmpty);
    expect(controller.error, 'account_changed');
  });

  test('durable save remains successful when refresh fails', () async {
    service.snapshotFails = true;
    expect(
      await controller.save(row('one'), null, expectedRealm: controller.realm),
      isTrue,
    );
    expect(service.calls.where((m) => m == 'save').length, 1);
  });

  test(
    'saving during an active sync immediately schedules another pass',
    () async {
      final firstSync = Completer<Map<String, dynamic>>();
      var passes = 0;
      service.onSync = () async {
        passes++;
        if (passes == 1) return firstSync.future;
        return {'status': 'ready'};
      };
      final running = controller.synchronize();
      await Future<void>.delayed(Duration.zero);
      expect(passes, 1);
      expect(
        await controller.save(
          row('new'),
          null,
          expectedRealm: controller.realm,
        ),
        isTrue,
      );
      expect(passes, 1);
      firstSync.complete({'status': 'ready'});
      await running;
      await Future<void>.delayed(Duration.zero);
      expect(passes, 2);
    },
  );

  test(
    'cache failure cannot prevent immediate upload after durable save',
    () async {
      service.snapshotFails = true;
      await controller.save(row('one'), null, expectedRealm: controller.realm);
      await Future<void>.delayed(Duration.zero);
      expect(service.calls, contains('sync'));
      expect(service.calls.where((m) => m == 'save'), hasLength(1));
    },
  );

  test('storage error does not report successful save', () async {
    service.saveFails = true;
    expect(
      await controller.save(row('one'), null, expectedRealm: controller.realm),
      isFalse,
    );
    expect(controller.error, 'storage_error');
  });

  Widget app(Widget child, {String locale = 'zh'}) => MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  test('image descriptions participate in offline search', () async {
    service.rows = [
      row('image')..['recognition_description'] = 'Green vegetables',
    ];
    await controller.reload();
    controller.filters(query: 'vegetables');
    expect(controller.visible.single.id, 'image');
  });

  testWidgets('description is readable separately and saving preserves notes', (
    tester,
  ) async {
    final data = row('image')
      ..['note'] = 'My correction'
      ..['recognition_description'] = 'Visible food description'
      ..['captured_at'] = '2026-09-11T01:00:00Z';
    await tester.pumpWidget(
      app(
        LifeRecordEditor(
          controller: controller,
          record: LifeRecord(data),
          image: null,
          mime: null,
          expectedRealm: controller.realm,
        ),
      ),
    );
    expect(find.text('图片识别描述（未经确认）'), findsOneWidget);
    expect(find.text('Visible food description'), findsOneWidget);
    expect(find.text('My correction'), findsOneWidget);
    await tester.tap(find.text('保存并排队同步'));
    await tester.pumpAndSettle();
    final index = service.calls.indexOf('save');
    expect(index, greaterThanOrEqualTo(0));
    final saved = jsonDecode(service.arguments[index]['record'] as String);
    expect(saved['note'], 'My correction');
    expect(saved['recognition_description'], 'Visible food description');
  });

  testWidgets(
    'page shows queued records and honest backend status in both languages',
    (tester) async {
      service.rows = [row('one', pending: true)];
      await controller.reload();
      final page = LifeRecordsPage(
        c: YxPalette.light,
        controller: controller,
        onBack: () {},
      );
      await tester.pumpWidget(app(page));
      expect(find.text('生活记录'), findsOneWidget);
      expect(find.textContaining('尚未接入'), findsOneWidget);
      expect(find.text('Record one'), findsOneWidget);
      await tester.pumpWidget(app(page, locale: 'en'));
      expect(find.text('Life records'), findsOneWidget);
      expect(find.textContaining('not integrated'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'night record is compact, readable and places actions at lower right',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final value = row('one')..['recognition_status'] = 'failed';
      service.rows = [value];
      await controller.reload();
      final key = GlobalKey();
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: key,
            child: Scaffold(
              backgroundColor: YxPalette.dark.surface,
              body: LifeRecordsPage(
                c: YxPalette.dark,
                controller: controller,
                onBack: () {},
              ),
            ),
          ),
          locale: 'en',
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byType(Card).last;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(tester.getSize(card).height, lessThan(190));
      final edit = find
          .descendant(of: card, matching: find.byType(TextButton))
          .first;
      final remove = find
          .descendant(of: card, matching: find.byType(TextButton))
          .last;
      expect(
        tester.getRect(remove).right,
        closeTo(tester.getRect(card).right - 12, 1),
      );
      expect(tester.getRect(edit).bottom, tester.getRect(remove).bottom);
      final label = tester.widget<Text>(
        find.descendant(of: card, matching: find.byType(Text)).at(1),
      );
      final background = YxPalette.dark.surfaceSoft.computeLuminance();
      expect(
        (label.style!.color!.computeLuminance() + .05) / (background + .05),
        greaterThan(4.5),
      );
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/review')
          ..createSync(recursive: true);
        await File(
          '${directory.path}/life-records-night.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    },
  );

  testWidgets('editor requires currency when an amount is provided', (
    tester,
  ) async {
    final record = row('one');
    (record['items'] as List).first['currency'] = '';
    await tester.pumpWidget(
      app(
        LifeRecordEditor(
          controller: controller,
          record: LifeRecord(record),
          image: null,
          mime: null,
          expectedRealm: controller.realm,
        ),
      ),
    );
    await tester.tap(find.text('保存并排队同步'));
    await tester.pump();
    expect(find.text('填写金额时必须提供三字母币种'), findsOneWidget);
    expect(service.calls.where((m) => m == 'save'), isEmpty);
  });
}
