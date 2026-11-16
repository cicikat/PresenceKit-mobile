import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/finance_controller.dart';
import 'package:presencekit_mobile/services/finance_service.dart';
import 'package:presencekit_mobile/widgets/finance_widgets.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';

Map<String, dynamic> candidate() => {
  'candidate_id': 'fixture-candidate',
  'source_app': 'com.tencent.mm',
  'occurred_at': DateTime.now().millisecondsSinceEpoch,
  'amount_minor': 1600,
  'currency': 'CNY',
  'merchant': 'Fixture store',
  'direction': 'expense',
  'status': 'candidate',
  'sync_status': 'pending',
  'reason_codes': ['possible_duplicate'],
};

class FixtureFinance extends FinanceService {
  List<Map<String, dynamic>> rows = [candidate()];
  final calls = <String>[];
  final arguments = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? delayed;
  String status = 'offline';
  @override
  Future<Map<String, dynamic>> snapshot(String origin, String owner) async =>
      delayed == null
      ? {
          'records': rows,
          'permission': false,
          'enabled': false,
          'sync': {'status': status},
        }
      : delayed!.future;
  @override
  Future<dynamic> invoke(
    String method,
    String origin,
    String owner, [
    Map<String, dynamic> args = const {},
  ]) async {
    calls.add(method);
    arguments.add(args);
    if (method == 'edit') {
      final patch = jsonDecode(args['patch'] as String) as Map;
      rows = rows
          .map(
            (row) => row['candidate_id'] == args['id']
                ? {...row, ...Map<String, dynamic>.from(patch)}
                : row,
          )
          .toList();
    }
    if (method == 'setEnabled') {
      throw PlatformException(code: 'permission_required');
    }
    return null;
  }
}

FinanceController controller(
  FixtureFinance service, {
  String Function()? owner,
}) => FinanceController(
  origin: () => 'http://127.0.0.1:8080',
  owner: owner ?? () => 'owner',
  service: service,
);
Widget app(
  FinanceController controller, {
  bool dark = false,
  String locale = 'zh',
  double scale = 1,
}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: RepaintBoundary(
    key: const ValueKey('finance-capture'),
    child: FinancePage(
      c: dark ? YxPalette.dark : YxPalette.light,
      controller: controller,
    ),
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('FINANCE_CAPTURE')) {
      final font = await rootBundle.load(
        'assets/fonts/NotoSerifCJKsc-Regular.otf',
      );
      for (final family in ['serif', 'Roboto', 'monospace']) {
        await (FontLoader(family)..addFont(Future.value(font))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  test(
    'late old-account snapshot is discarded and stale editor cannot send',
    () async {
      final service = FixtureFinance()..delayed = Completer();
      var owner = 'owner';
      final c = controller(service, owner: () => owner);
      final pending = c.refresh();
      owner = 'other';
      service.delayed!.complete({
        'records': [candidate()],
        'permission': true,
        'enabled': true,
        'sync': {'status': 'ready'},
      });
      await pending;
      expect(c.records, isEmpty);
      expect(c.enabled, isFalse);
      await c.edit(candidate(), {
        'status': 'confirmed',
      }, 'http://127.0.0.1:8080\nowner');
      expect(service.calls, isEmpty);
      expect(c.status, 'account_changed');
      c.dispose();
    },
  );
  test('MethodChannel carries scope and structured edit, no token', () async {
    MethodCall? observed;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(FinanceService.channel, (call) async {
          observed = call;
          return null;
        });
    await FinanceService().invoke('edit', 'https://fixture.example', 'owner', {
      'id': 'candidate',
      'patch': jsonEncode({'amount_minor': 1600}),
    });
    expect(observed!.method, 'edit');
    expect(observed!.arguments, {
      'origin': 'https://fixture.example',
      'owner': 'owner',
      'id': 'candidate',
      'patch': '{"amount_minor":1600}',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(FinanceService.channel, null);
  });
  testWidgets(
    'confirmation sends integer identity, pending never becomes server success',
    (tester) async {
      final service = FixtureFinance();
      final c = controller(service);
      await tester.pumpWidget(app(c));
      await tester.pumpAndSettle();
      expect(find.text('16.00 CNY · 支出'), findsOneWidget);
      expect(find.text('服务端已保存'), findsNothing);
      final confirm = find.text('确认入账');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(service.calls, ['edit']);
      expect(service.arguments.single['id'], 'fixture-candidate');
      expect(jsonDecode(service.arguments.single['patch'] as String), {
        'status': 'confirmed',
      });
      await tester.tap(find.text('已确认流水'));
      await tester.pumpAndSettle();
      expect(find.text('16.00 CNY · 支出'), findsOneWidget);
      expect(find.text('服务端已保存'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      '320px large text ${dark ? 'dark' : 'light'} permission and editor stay readable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = FixtureFinance();
        final c = controller(service);
        await tester.pumpWidget(app(c, dark: dark, scale: 1.4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('手动记录'));
        await tester.tap(find.text('手动记录'));
        await tester.pumpAndSettle();
        expect(find.text('金额（元，CNY）'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).first, '16.123');
        await tester.ensureVisible(find.text('保存'));
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(find.text('请输入大于零、最多两位小数的金额'), findsOneWidget);
        expect(service.calls, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        if (const bool.fromEnvironment('FINANCE_CAPTURE')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('finance-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('build/review/finance330').create(recursive: true);
            await File(
              'build/review/finance330/${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('English permissions and correction preserve channel contract', (
    tester,
  ) async {
    final service = FixtureFinance();
    final c = controller(service);
    await tester.pumpWidget(app(c, locale: 'en'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(
      find.text('Notification access is off. Enable it in system settings.'),
      findsWidgets,
    );
    expect(service.calls, ['setEnabled']);
    expect(c.enabled, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
