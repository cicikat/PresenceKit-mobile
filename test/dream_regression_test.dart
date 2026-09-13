import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/dream_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/widgets/dream_widgets.dart';
import 'package:presencekit_mobile/widgets/chat_widgets.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';

class DreamBackend extends BackendClient {
  DreamBackend()
    : super(
        baseUrl: 'http://127.0.0.1:8080',
        settingsStore: const AppSettingsStore(),
      );
  DreamWakeResult result = DreamWakeResult.fromJson({'closed_now': true});
  Completer<DreamChatResponse>? chat;
  Completer<DreamState>? pendingState;
  bool fail = false;
  int exits = 0;
  @override
  Future<DreamWakeResult> exitDream({required String token}) async {
    exits++;
    if (fail) throw BackendException('offline');
    return result;
  }

  @override
  Future<DreamWakeResult> dreamWake({required String token}) async => result;
  @override
  Future<DreamState> loadDreamState({required String token}) async =>
      pendingState == null ? active : await pendingState!.future;
  @override
  Future<DreamChatResponse> sendDreamChat(
    String message, {
    required String token,
  }) async => chat == null ? reply : await chat!.future;
}

final active = DreamState.fromJson({'status': 'DREAM_ACTIVE'});
const reply = DreamChatResponse(
  reply: '',
  exitAccepted: false,
  forceExited: false,
  error: null,
  segments: [
    NarrativeSegment(type: 'env', text: 'First paragraph'),
    NarrativeSegment(type: 'do', text: 'Second paragraph'),
    NarrativeSegment(type: 'say', text: 'Third paragraph'),
  ],
);
DreamController make(DreamBackend b) =>
    DreamController(backend: () => b, token: () => 'test')..state = active;
void main() {
  testWidgets(
    'dream descriptions share an independent inset and user has no header',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                const DreamSegmentedMessage(
                  c: YxPalette.light,
                  prefs: YxPrefs(dreamDescriptionOpacity: .35),
                  time: '12:34',
                  segments: [
                    NarrativeSegment(type: 'env', text: 'Environment'),
                    NarrativeSegment(type: 'do', text: 'Action'),
                  ],
                ),
                const YouMessage(
                  c: YxPalette.light,
                  time: '12:34',
                  text: 'Hello',
                  prefs: YxPrefs(showYouAvatar: true),
                  showHeader: false,
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.text('Environment')).dx,
        tester.getTopLeft(find.text('Action')).dx,
      );
      expect(find.textContaining('12:34'), findsNothing);
      final cards = tester
          .widgetList<Container>(find.byType(Container))
          .where(
            (w) =>
                w.decoration is BoxDecoration &&
                ((w.decoration as BoxDecoration).color?.a ?? 0) > .34 &&
                ((w.decoration as BoxDecoration).color?.a ?? 0) < .36,
          );
      expect(cards, hasLength(2));
    },
  );
  testWidgets('dream send stays visible and preserves draft during reply', (
    tester,
  ) async {
    final sent = <String>[];
    Widget build(bool sending) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DreamComposer(
          c: YxPalette.light,
          sending: sending,
          enabled: true,
          onSend: sent.add,
        ),
      ),
    );
    await tester.pumpWidget(build(true));
    await tester.enterText(find.byType(TextField), 'Next turn');
    final button = find.byWidgetPredicate((w) => w is FilledButton);
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.pumpWidget(build(false));
    expect(find.text('Next turn'), findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    expect(sent, ['Next turn']);
  });
  test('close confirmation matches desktop archive contract', () {
    expect(DreamWakeResult.fromJson({'exited': true}).confirmedClosed, isFalse);
    expect(
      DreamWakeResult.fromJson({'closed_now': true}).confirmedClosed,
      isTrue,
    );
    expect(
      DreamWakeResult.fromJson({
        'already_closed': true,
        'archive_ok': false,
      }).confirmedClosed,
      isFalse,
    );
    expect(
      DreamWakeResult.fromJson({
        'already_closed': true,
        'archive_ok': true,
      }).confirmedClosed,
      isTrue,
    );
    expect(
      DreamWakeResult.fromJson({
        'retained': true,
        'closed_now': true,
      }).confirmedClosed,
      isFalse,
    );
  });
  testWidgets('failed exit preserves dream; confirmed retry clears it', (
    tester,
  ) async {
    final b = DreamBackend()..fail = true;
    final c = make(b);
    c.messages.add(ChatMessage(role: 'you', text: 'hello', time: '12:00'));
    expect(await c.exit(), isFalse);
    expect(c.state!.isActive, isTrue);
    expect(c.messages, hasLength(1));
    expect(c.transitionFailed, isTrue);
    b.fail = false;
    expect(await c.exit(), isTrue);
    expect(c.messages, isEmpty);
    expect(c.state, isNull);
    c.dispose();
  });
  testWidgets('unconfirmed wake does not silently close', (tester) async {
    final b = DreamBackend()
      ..result = DreamWakeResult.fromJson({
        'exited': false,
        'archive_ok': false,
      });
    final c = make(b);
    await c.wake();
    expect(c.transitionFailed, isTrue);
    expect(c.state!.isActive, isTrue);
    expect(b.exits, 0);
    c.dispose();
  });
  testWidgets('segments reveal sequentially and only current tap advances', (
    tester,
  ) async {
    final c = make(DreamBackend());
    c.send('hello');
    c.send('duplicate');
    await tester.pump();
    expect(c.messages.where((m) => m.role == 'you'), hasLength(1));
    expect(c.messages.where((m) => m.role == 'him'), hasLength(1));
    final first = c.messages.last;
    c.markRevealStarted(first);
    expect(c.messages.last.animate, isFalse);
    c.finishReveal(first.id);
    await tester.pump();
    expect(c.messages.where((m) => m.role == 'him'), hasLength(2));
    c.finishReveal(first.id);
    await tester.pump();
    expect(c.messages.where((m) => m.role == 'him'), hasLength(2));
    c.finishReveal(c.messages.last.id);
    await tester.pump();
    c.finishReveal(c.messages.last.id);
    await tester.pump();
    expect(c.messages.where((m) => m.role == 'him'), hasLength(3));
    expect(c.sending, isFalse);
    c.dispose();
  });
  testWidgets('late chat and state cannot resurrect a closed dream', (
    tester,
  ) async {
    final b = DreamBackend()
      ..chat = Completer<DreamChatResponse>()
      ..pendingState = Completer<DreamState>();
    final c = make(b);
    c.send('hello');
    final loading = c.loadState();
    expect(await c.exit(), isTrue);
    b.chat!.complete(reply);
    b.pendingState!.complete(active);
    await loading;
    await tester.pump();
    expect(c.state, isNull);
    expect(c.messages, isEmpty);
    c.dispose();
  });
  testWidgets('all narrative types reveal and retain progress on rebuild', (
    tester,
  ) async {
    for (final type in ['env', 'do', 'feel', 'narration', 'say']) {
      Widget build(bool animate) => MaterialApp(
        home: Scaffold(
          body: DreamSegmentedMessage(
            key: ValueKey(type),
            c: YxPalette.light,
            prefs: const YxPrefs(),
            time: '12:00',
            animate: animate,
            segments: [
              NarrativeSegment(
                type: type,
                text: 'A long paragraph that should reveal gradually.',
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedRevealText), findsOneWidget);
      expect(
        find.text('A long paragraph that should reveal gradually.'),
        findsNothing,
      );
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('A long paragraph that should reveal gradually.'),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('A long paragraph that should reveal gradually.'),
        findsOneWidget,
      );
    }
  });
}
