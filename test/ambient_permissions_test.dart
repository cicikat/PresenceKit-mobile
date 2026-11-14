import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/l10n/generated/app_localizations.dart';
import 'package:presencekit_mobile/services/platform_settings_channel.dart';
import 'package:presencekit_mobile/widgets/ambient_permissions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var fail = false;
  var granted = false;
  final calls = <String>[];
  setUp(() {
    fail = false;
    granted = false;
    calls.clear();
    PlatformSettingsChannel.debugForceChannelAvailable = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformSettingsChannel.channel, (
          call,
        ) async {
          calls.add(call.method);
          if (fail) throw PlatformException(code: 'unavailable');
          if (call.method == 'readBatteryStatus') return {'percent': 72};
          if (call.method == 'openUsageAccess') return null;
          return {
            'light': false,
            'lightSupported': false,
            'motion': false,
            'motionSupported': true,
            'usage': true,
            'usageSupported': true,
            'usageGranted': granted,
          };
        });
  });
  tearDown(() {
    PlatformSettingsChannel.debugForceChannelAvailable = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformSettingsChannel.channel, null);
  });
  Widget app({bool readOnly = false}) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: AmbientPermissions(
          readOnly: readOnly,
          onChanged: (_, _) async {},
        ),
      ),
    ),
  );
  testWidgets('read failure keeps capabilities and can retry', (tester) async {
    fail = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Light around my phone'), findsOneWidget);
    expect(
      find.text('Could not read sensing settings. Please retry.'),
      findsOneWidget,
    );
    expect(find.byType(Switch), findsNothing);
    fail = false;
    await tester.tap(find.byTooltip('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNWidgets(3));
    expect(
      find.text('Battery at 72%. No additional permission needed.'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch).first).onChanged, isNull);
  });
  testWidgets('unsupported platform remains visible', (tester) async {
    PlatformSettingsChannel.debugForceChannelAvailable = false;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.text('These sensing settings are unavailable on this device.'),
      findsOneWidget,
    );
    expect(find.text('Recent screen activity'), findsOneWidget);
    expect(calls, isEmpty);
  });
  testWidgets('usage consent is separate from grant and refreshes on resume', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Usage access has not been granted. Allow it in system settings.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Allow usage access in system settings'));
    await tester.pumpAndSettle();
    granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'getAmbientSettings').length, 2);
    expect(calls, contains('openUsageAccess'));
    expect(find.text('Allow usage access in system settings'), findsNothing);
    expect(calls, isNot(contains('setAmbientEnabled')));
  });
  testWidgets('observation has no editable or disabled switches', (
    tester,
  ) async {
    await tester.pumpWidget(app(readOnly: true));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Light around my phone'), findsOneWidget);
  });
}
