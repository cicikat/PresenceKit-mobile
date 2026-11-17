import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/l10n/generated/app_localizations.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/widgets/phone_ambient_settings.dart';

// The visible editor must persist explicit consent in the displayed scope and
// show server effective state rather than equating a saved switch with sensing.
void main() {
  Map<String, dynamic> data() => {
    'char_id': 'fixture-character',
    'configured': {
      'enabled': false,
      'light': true,
      'motion': true,
      'usage': true,
    },
    'effective': {'light': false, 'motion': false, 'usage': false},
    'reason_codes': {
      'light': 'unavailable',
      'motion': 'unavailable',
      'usage': 'permission_denied',
    },
  };
  Widget app({
    required Future<Map<String, dynamic>> Function() load,
    required Future<Map<String, dynamic>> Function(
      Map<String, dynamic>,
      String?,
    )
    save,
    bool readOnly = false,
  }) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: PhoneAmbientSettings(
          c: YxPalette.light,
          load: load,
          save: save,
          readOnly: readOnly,
        ),
      ),
    ),
  );
  testWidgets(
    'explicit switch writes scoped consent; sources stay unavailable',
    (tester) async {
      final current = data();
      final writes = <Map<String, dynamic>>[];
      String? savedCharacter;
      await tester.pumpWidget(
        app(
          load: () async => current,
          save: (patch, character) async {
            writes.add(patch);
            savedCharacter = character;
            current['configured'] = <String, dynamic>{
              ...current['configured'] as Map<String, dynamic>,
              ...patch,
            };
            return current;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNWidgets(4));
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(writes, [
        {'enabled': true},
      ]);
      expect(savedCharacter, 'fixture-character');
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
      expect(find.text('Ready'), findsNothing);
    },
  );
  testWidgets('failed load retries and observation offers no controls', (
    tester,
  ) async {
    var fail = true;
    var saves = 0;
    await tester.pumpWidget(
      app(
        readOnly: true,
        load: () async {
          if (fail) throw StateError('synthetic private error');
          return data();
        },
        save: (_, _) async {
          saves++;
          return data();
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('synthetic private'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    fail = false;
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(saves, 0);
  });
}
