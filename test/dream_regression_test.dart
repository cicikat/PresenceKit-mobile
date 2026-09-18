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
  Completer<DreamStats>? pendingStats;
  Completer<DreamSettings>? pendingSettings;
  Completer<List<PromptAssetOption>>? pendingWorlds;
  final settingsQueue = <Completer<DreamSettings>>[];
  final optionsQueue = <Completer<List<PromptAssetOption>>>[];
  Completer<bool>? pendingEnter;
  Completer<DreamWakeResult>? pendingWake;
  bool fail = false;
  bool failSettings = false;
  int exits = 0;
  int wakes = 0;
  int enters = 0;
  int settingsLoads = 0;
  int settingsUpdates = 0;
  @override
  Future<DreamWakeResult> exitDream({required String token}) async {
    exits++;
    if (fail) throw BackendException('offline');
    return result;
  }

  @override
  Future<DreamWakeResult> dreamWake({required String token}) async {
    wakes++;
    return pendingWake == null ? result : await pendingWake!.future;
  }

  @override
  Future<DreamState> loadDreamState({required String token}) async =>
      pendingState == null ? active : await pendingState!.future;

  @override
  Future<DreamStats> loadDreamStats({required String token}) async =>
      pendingStats == null
      ? const DreamStats(totalValid: 1, totalArchived: 0, lastDreamAt: null)
      : await pendingStats!.future;

  @override
  Future<DreamChatResponse> sendDreamChat(
    String message, {
    required String token,
  }) async => chat == null ? reply : await chat!.future;

  @override
  Future<bool> enterDream({required String token}) async {
    enters++;
    return pendingEnter == null ? true : await pendingEnter!.future;
  }

  @override
  Future<DreamSettings> loadDreamSettings({required String token}) async {
    settingsLoads++;
    if (failSettings) throw const BackendException('settings unavailable');
    if (settingsQueue.isNotEmpty) return settingsQueue.removeAt(0).future;
    return pendingSettings == null
        ? DreamSettings.fromJson(const {})
        : await pendingSettings!.future;
  }

  @override
  Future<List<PromptAssetOption>> loadDreamOptions({
    required String token,
    required bool worlds,
  }) async {
    if (worlds && optionsQueue.isNotEmpty) {
      return optionsQueue.removeAt(0).future;
    }
    if (worlds && pendingWorlds != null) return pendingWorlds!.future;
    return [PromptAssetOption(id: worlds ? 'w1' : 'p1', label: 'opt')];
  }

  @override
  Future<DreamSettings> updateDreamSettings({
    required String token,
    bool? enableDreamLorebook,
    String? worldLayer,
    String? jailbreakPreset,
    List<String>? jailbreakPresets,
    String? memoryAccess,
    String? boundaryLevel,
    String? lucidMode,
  }) async {
    settingsUpdates++;
    return DreamSettings.fromJson({'world_layer': worldLayer ?? 'reality_derived'});
  }
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
  test('identity invalidation drops local dream without posting exit', () async {
    final b = DreamBackend();
    final c = make(b)
      ..settings = DreamSettings.fromJson(const {})
      ..error = 'old'
      ..sending = true;
    c.messages.add(ChatMessage(role: 'you', text: 'hello', time: '12:00'));
    c.invalidateLocalSession(clearSettings: false);
    expect(c.messages, isEmpty);
    expect(c.state, isNull);
    expect(c.sending, isFalse);
    expect(c.error, isNull);
    expect(c.settings, isNotNull);
    expect(b.exits, 0);
    expect(b.wakes, 0);
    c.dispose();
  });

  test('late state and stats cannot restore a switched identity', () async {
    final b = DreamBackend()
      ..pendingState = Completer<DreamState>()
      ..pendingStats = Completer<DreamStats>();
    final c = DreamController(backend: () => b, token: () => 'test');
    final state = c.loadState();
    final stats = c.loadStats();
    await Future<void>.delayed(Duration.zero);
    c.invalidateLocalSession(clearSettings: true);
    b.pendingState!.complete(active);
    b.pendingStats!.complete(
      const DreamStats(totalValid: 9, totalArchived: 1, lastDreamAt: null),
    );
    await state;
    await stats;
    expect(c.state, isNull);
    expect(c.stats, isNull);
    expect(c.loadingState, isFalse);
    c.dispose();
  });

  test('late settings success does not cover a newer identity', () async {
    final b = DreamBackend()
      ..pendingSettings = Completer<DreamSettings>()
      ..pendingWorlds = Completer<List<PromptAssetOption>>();
    final c = DreamController(backend: () => b, token: () => 'test');
    final first = c.loadSettings();
    await Future<void>.delayed(Duration.zero);
    expect(c.loadingSettings, isTrue);
    c.invalidateLocalSession(clearSettings: true);
    b.pendingSettings!.complete(DreamSettings.fromJson(const {}));
    b.pendingWorlds!.complete(const [
      PromptAssetOption(id: 'stale', label: 'stale'),
    ]);
    await first;
    expect(c.settings, isNull);
    expect(c.worlds, isEmpty);
    expect(c.loadingSettings, isFalse);
    await c.loadSettings();
    expect(c.settings, isNotNull);
    expect(c.loadingSettings, isFalse);
    c.dispose();
  });

  test('late enter and wake do not archive or reopen after invalidation', () async {
    final b = DreamBackend()
      ..pendingEnter = Completer<bool>()
      ..pendingWake = Completer<DreamWakeResult>();
    final c = make(b);
    final entering = c.enter();
    final waking = c.wake();
    await Future<void>.delayed(Duration.zero);
    c.invalidateLocalSession(clearSettings: true);
    b.pendingEnter!.complete(true);
    b.pendingWake!.complete(DreamWakeResult.fromJson({'closed_now': true}));
    await entering;
    final wake = await waking;
    expect(wake, isNull);
    expect(c.state, isNull);
    expect(c.entering, isFalse);
    expect(c.transitioning, isFalse);
    expect(b.exits, 0);
    c.dispose();
  });

  test('send/reveal in flight is abandoned on identity change', () async {
    final b = DreamBackend()..chat = Completer<DreamChatResponse>();
    final c = make(b);
    c.send('hello');
    await Future<void>.delayed(Duration.zero);
    expect(c.sending, isTrue);
    c.invalidateLocalSession(clearSettings: false);
    b.chat!.complete(reply);
    await Future<void>.delayed(Duration.zero);
    expect(c.messages, isEmpty);
    expect(c.sending, isFalse);
    expect(b.exits, 0);
    c.dispose();
  });

  test('old finally does not clear a newer settings load', () async {
    final firstSettings = Completer<DreamSettings>();
    final firstWorlds = Completer<List<PromptAssetOption>>();
    final secondGate = Completer<DreamSettings>();
    final secondWorlds = Completer<List<PromptAssetOption>>();
    final b = DreamBackend()
      ..settingsQueue.addAll([firstSettings, secondGate])
      ..optionsQueue.addAll([firstWorlds, secondWorlds]);
    final c = DreamController(backend: () => b, token: () => 'test');
    final first = c.loadSettings();
    await Future<void>.delayed(Duration.zero);
    c.invalidateLocalSession(clearSettings: true);
    final second = c.loadSettings();
    await Future<void>.delayed(Duration.zero);
    expect(c.loadingSettings, isTrue);
    firstSettings.complete(DreamSettings.fromJson(const {}));
    firstWorlds.complete(const [
      PromptAssetOption(id: 'stale', label: 'stale'),
    ]);
    await first;
    expect(c.loadingSettings, isTrue);
    secondGate.complete(DreamSettings.fromJson({'world_layer': 'fresh'}));
    secondWorlds.complete(const [PromptAssetOption(id: 'fresh', label: 'fresh')]);
    await second;
    expect(c.loadingSettings, isFalse);
    expect(c.settings?.worldLayer, 'fresh');
    expect(c.worlds.single.id, 'fresh');
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
