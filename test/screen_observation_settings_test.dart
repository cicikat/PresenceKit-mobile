import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/l10n/generated/app_localizations.dart';
import 'package:presencekit_mobile/widgets/screen_observation_settings.dart';
import 'package:presencekit_mobile/models/app_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('presence_mobile/screen_observation');
  final calls = <MethodCall>[];
  bool supported = true;
  bool enabled = false;
  setUp(() {
    supported = true; enabled = false; calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'set') enabled = (call.arguments as Map)['enabled'] == true;
      return {'supported': supported, 'enabled': enabled};
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
  Widget app({bool access = true, bool readOnly = false}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ScreenObservationSettings(c: YxPalette.light, accessibilityEnabled: access, readOnly: readOnly)),
  );
  testWidgets('explicit local consent persists independently', (tester) async {
    await tester.pumpWidget(app()); await tester.pumpAndSettle();
    expect(calls.map((c) => c.method), ['get']);
    await tester.tap(find.byType(Switch)); await tester.pumpAndSettle();
    expect(enabled, true);
    expect(calls.last.arguments, {'enabled': true});
    await tester.tap(find.byType(Switch)); await tester.pumpAndSettle();
    expect(enabled, false);
  });
  testWidgets('observation page has no disabled editable switch', (tester) async {
    await tester.pumpWidget(app(access: false, readOnly: true)); await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(calls.length, 1);
  });
  testWidgets('unsupported devices can still revoke existing consent', (tester) async {
    supported = false; enabled = true;
    await tester.pumpWidget(app()); await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch)); await tester.pumpAndSettle();
    expect(enabled, false);
  });
}
