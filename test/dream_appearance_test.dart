import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/theme_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/dream_appearance.dart';
import 'package:presencekit_mobile/models/theme_models.dart';
import 'package:presencekit_mobile/models/ui_layout.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/platform_settings_channel.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/widgets/dream_appearance_manager.dart';
import 'package:presencekit_mobile/widgets/dream_flow_surface.dart';
import 'package:presencekit_mobile/widgets/conversation_presentation.dart';
import 'package:presencekit_mobile/widgets/dream_widgets.dart';
import 'package:presencekit_mobile/widgets/chat_widgets.dart';
import 'package:presencekit_mobile/pages/app_shell.dart';
import 'package:presencekit_mobile/widgets/settings_widgets.dart';
import 'package:presencekit_mobile/widgets/theme_widgets.dart';
import 'package:presencekit_mobile/widgets/drawer_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'two flow themes restore independent presets and day/night colors',
    () async {
      String? data;
      final theme = ThemeController(
        loadPersisted: () async => data,
        savePersisted: (v) async {
          data = v;
        },
      );
      final ordinary = await theme.create(name: 'existing day', base: 'light');
      final theatre = await theme.dreamAppearance.save(
        builtInDreamPresets.first.copyWith(
          name: 'my theatre',
          flow: const DreamFlowSettings(
            lightColors: [0xffccddee, 0xffaaaaff, 0xffffffff],
            speed: .15,
          ),
        ),
      );
      final orbit = await theme.dreamAppearance.save(
        builtInDreamPresets.last.copyWith(
          name: 'my orbit',
          flow: const DreamFlowSettings(
            darkColors: [0xff111144, 0xff4444bb, 0xff7788ee],
            warp: 1.8,
          ),
        ),
      );
      await theme.dreamAppearance.select(theatre);
      await theme.dreamAppearance.select(orbit);
      await theme.setDreamLayout(DreamLayout.orbit);
      final restored = ThemeController(
        loadPersisted: () async => data,
        savePersisted: (v) async {
          data = v;
        },
      );
      await restored.restore();
      expect(restored.dreamLayout, DreamLayout.orbit);
      expect(restored.activeId, ordinary.id);
      expect(
        restored.dreamAppearance.active(DreamLayout.theatre).flow.lightColors,
        theatre.flow.lightColors,
      );
      expect(
        restored.dreamAppearance.active(DreamLayout.orbit).flow.darkColors,
        orbit.flow.darkColors,
      );
      expect(
        restored.dreamAppearance.active(DreamLayout.orbit).flow.lightColors,
        const DreamFlowSettings().lightColors,
      );
      final edited = await restored.dreamAppearance.save(
        orbit.copyWith(name: 'edited', flow: orbit.flow.copyWith(speed: 0)),
      );
      expect(edited.id, orbit.id);
      expect(restored.dreamAppearance.active(DreamLayout.orbit).flow.speed, 0);
      expect(
        restored.dreamAppearance.active(DreamLayout.theatre).id,
        theatre.id,
      );
      theme.dispose();
      restored.dispose();
    },
  );
  test(
    'legacy theme JSON keeps daily and dream preferences, corrupt flow data is bounded',
    () {
      final snapshot = ThemePresetSnapshot.fromJsonString(
        '{"schema":"presencekit-mobile-color-presets","version":1,"presets":[],"dreamLayout":"moonlit"}',
      )!;
      expect(snapshot.dreamLayout, DreamLayout.moonlit);
      expect(snapshot.dreamAppearance.presets, isEmpty);
      final flow = DreamFlowSettings.fromJson({
        'speed': double.nan,
        'scale': 99,
        'seed': -500,
        'lightColors': [1, 2],
        'darkColors': [0, 1, 2],
      });
      expect(flow.speed, .24);
      expect(flow.scale, 1.8);
      expect(flow.seed, 0);
      expect(flow.lightColors, const DreamFlowSettings().lightColors);
      expect(flow.darkColors.first, 0xff000000);
      final invalid = DreamAppearanceSnapshot.fromJson({
        'version': 1,
        'presets': [
          {'id': 'invalid'},
        ],
        'selected': {'theatre': 'dream-orbit'},
      });
      expect(invalid.selected, isEmpty);
      expect(invalid.presets, isEmpty);
    },
  );
  test(
    'failed save leaves selection unchanged and later retry works',
    () async {
      bool fail = true;
      final theme = ThemeController(
        loadPersisted: () async => null,
        savePersisted: (v) async {
          if (fail) throw StateError('disk full');
        },
      );
      await expectLater(
        theme.dreamAppearance.save(
          builtInDreamPresets.first.copyWith(name: 'failed'),
        ),
        throwsStateError,
      );
      expect(theme.dreamAppearance.presets, hasLength(2));
      await expectLater(
        theme.setDreamLayout(DreamLayout.orbit),
        throwsStateError,
      );
      expect(theme.dreamLayout, DreamLayout.classic);
      fail = false;
      final saved = await theme.dreamAppearance.save(
        builtInDreamPresets.first.copyWith(name: 'retry'),
      );
      await theme.dreamAppearance.select(saved);
      expect(theme.dreamAppearance.active(DreamLayout.theatre).id, saved.id);
      theme.dispose();
    },
  );
  test(
    'overlapping ordinary and dream writes do not erase dream presets',
    () async {
      String? data;
      final gate = Completer<void>();
      var writes = 0;
      final theme = ThemeController(
        loadPersisted: () async => data,
        savePersisted: (v) async {
          if (writes++ == 0) await gate.future;
          data = v;
        },
      );
      final save = theme.dreamAppearance.save(
        builtInDreamPresets.last.copyWith(name: 'orbit'),
      );
      await Future<void>.delayed(Duration.zero);
      final mode = theme.setMode(AppThemeMode.dark);
      gate.complete();
      final preset = await save;
      await mode;
      final snapshot = ThemePresetSnapshot.fromJsonString(data)!;
      expect(snapshot.dreamAppearance.presets.single.id, preset.id);
      expect(snapshot.themeMode, 'dark');
      theme.dispose();
    },
  );
  test(
    'native opaque JSON roundtrips and platform save failures propagate',
    () async {
      PlatformSettingsChannel.debugForceChannelAvailable = true;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      String? stored;
      messenger.setMockMethodCallHandler(PlatformSettingsChannel.channel, (
        call,
      ) async {
        if (call.method == 'getCustomThemePalette') return stored;
        if (call.method == 'setCustomThemePalette') {
          stored = (call.arguments as Map)['value'];
          return null;
        }
        return null;
      });
      const store = AppSettingsStore();
      final json = jsonEncode({
        'dreamAppearance': const DreamAppearanceSnapshot().toJson(),
      });
      await store.saveCustomThemePalette(json);
      expect(await store.loadCustomThemePalette(), json);
      messenger.setMockMethodCallHandler(
        PlatformSettingsChannel.channel,
        (call) async => throw PlatformException(code: 'theme_save_failed'),
      );
      await expectLater(
        store.saveCustomThemePalette(json, reportFailure: true),
        throwsA(isA<PlatformException>()),
      );
      messenger.setMockMethodCallHandler(PlatformSettingsChannel.channel, null);
      PlatformSettingsChannel.debugForceChannelAvailable = false;
    },
  );

  Widget host(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(body: child),
  );
  testWidgets(
    '320px manager previews both themes, saves and applies a custom preset',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? data;
      final theme = ThemeController(
        loadPersisted: () async => data,
        savePersisted: (v) async {
          data = v;
        },
      );
      await tester.pumpWidget(
        host(
          DreamAppearanceManager(
            c: YxPalette.light,
            controller: theme,
            prefs: const YxPrefs(),
            onPrefs: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(DreamFlowPreview), findsOneWidget);
      await tester.tap(find.text('Indigo orbit'));
      await tester.pump();
      expect(
        tester.widget<DreamFlowPreview>(find.byType(DreamFlowPreview)).layout,
        DreamLayout.orbit,
      );
      final name = find.byKey(const ValueKey('dream-preset-name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'My orbit');
      await tester.pump();
      final apply = find.byKey(const ValueKey('apply-dream-preset'));
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pump();
      await tester.pump();
      expect(theme.dreamLayout, DreamLayout.orbit);
      expect(theme.dreamAppearance.active(DreamLayout.orbit).name, 'My orbit');
      expect(data, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      theme.dispose();
    },
  );
  testWidgets(
    'flow theme switching and reply state preserve the composer draft',
    (tester) async {
      Widget view(DreamLayout layout, bool sending) => host(
        ConversationPresentation(
          dream: layout,
          child: DreamFlowSurface(
            layout: layout,
            settings: const DreamFlowSettings(),
            dark: false,
            animate: false,
            child: Column(
              children: [
                const Spacer(),
                DreamComposer(
                  c: YxPalette.light,
                  sending: sending,
                  enabled: true,
                  onSend: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(view(DreamLayout.theatre, false));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'keep this dream');
      await tester.pumpWidget(view(DreamLayout.orbit, true));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'keep this dream',
      );
      await tester.pumpWidget(view(DreamLayout.classic, false));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'keep this dream',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('flow narrative honors original text sizes, colors and opacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ConversationPresentation(
          dream: DreamLayout.orbit,
          child: DreamFlowSurface(
            layout: DreamLayout.orbit,
            settings: const DreamFlowSettings(),
            dark: false,
            animate: false,
            child: SingleChildScrollView(
              child: DreamSegmentedMessage(
                c: YxPalette.light,
                time: '',
                prefs: const YxPrefs(
                  dreamChatSize: 22,
                  dreamChatColor: 0xff123456,
                  dreamActionSize: 18,
                  dreamDescriptionOpacity: .35,
                ),
                segments: const [
                  NarrativeSegment(type: 'say', text: 'Hello'),
                  NarrativeSegment(type: 'do', text: 'Action'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final say = tester
        .widgetList<AnimatedRevealText>(find.byType(AnimatedRevealText))
        .first;
    expect(say.style.fontSize, 22);
    expect(say.style.color, const Color(0xff123456));
    expect(
      tester
          .widgetList<Container>(find.byType(Container))
          .any(
            (c) =>
                c.decoration is BoxDecoration &&
                ((c.decoration as BoxDecoration).color?.a ?? 0) > .34 &&
                ((c.decoration as BoxDecoration).color?.a ?? 0) < .36,
          ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'closing appearance children returns to the same settings sheet',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CompanionApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      (tester.widget<Scaffold>(find.byType(Scaffold).first).drawer as YxDrawer)
          .onOpenSettings();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final appearance = find.text('Appearance & display');
      await tester.ensureVisible(appearance);
      await tester.tap(appearance);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final day = find.text('Day appearance theme');
      await tester.ensureVisible(day);
      await tester.tap(day);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(ThemePresetManagerSheet), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(ThemePresetManagerSheet), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Day appearance theme'), findsOneWidget);
      final dream = find.text('Dream appearance');
      await tester.ensureVisible(dream);
      await tester.tap(dream);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(DreamAppearanceManager), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('close-dream-appearance')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(DreamAppearanceManager), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
