import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/widgets/reasoning_widgets.dart';

void main() {
  testWidgets('pending anchor loads canonical turn and toggles without a bubble', (tester) async {
    final response = Completer<String>();
    final calls = <String>[];
    Future<String> load(String id) { calls.add(id); return response.future; }
    Widget app(String id, String name) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ReasoningPanel(key: const ValueKey('turn'), c: YxPalette.light,
        turnId: id, name: name, initiallyExpanded: false, load: load)),
    );
    await tester.pumpWidget(app('', 'Mira'));
    await tester.tap(find.text('Show thoughts'));
    await tester.pump();
    expect(calls, isEmpty);
    await tester.pumpWidget(app('canonical-1', 'Mira'));
    expect(calls, ['canonical-1']);
    response.complete('A quiet moment.');
    await tester.pump();
    expect(find.text('Mira’s inner thoughts:\nA quiet moment.'), findsOneWidget);
    await tester.pumpWidget(app('canonical-1', 'Ren'));
    expect(find.text('Ren’s inner thoughts:\nA quiet moment.'), findsOneWidget);
    await tester.tap(find.text('Hide thoughts'));
    await tester.pump();
    expect(find.byType(SelectableText), findsNothing);
    await tester.tap(find.text('Show thoughts'));
    await tester.pump();
    expect(calls, ['canonical-1']);
  });
}
