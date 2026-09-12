import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:presencekit_mobile/main.dart';
import 'package:presencekit_mobile/controllers/dream_controller.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';

void main() {
  test('prompt assets parses the Emerald-client response shape', () {
    final assets = PromptAssets.fromJson({
      'characters': [
        {'id': 'test-character', 'label': 'Nova'},
      ],
      'active': {'active_character': 'test-character'},
    });

    expect(assets.activeCharacter, 'test-character');
    expect(assets.characters.single.label, 'Nova');
  });

  test(
    'lore entries display the keyword group like the desktop EntryManager',
    () {
      final entry = LoreEntry.fromJson({
        'id': 'e1',
        'keyword': ['晨昏', '海边'],
        'content': '…',
        'enabled': true,
        'regex': false,
        'insertion_order': 100,
      });

      expect(entry.displayLabel, '晨昏, 海边');
      expect(entry.enabled, isTrue);
    },
  );

  test('jailbreak entries display the title like the desktop EntryManager', () {
    final entry = JailbreakEntry.fromJson({
      'id': 'e2',
      'title': '温和破限',
      'content': '…',
      'enabled': false,
      'layer': 2,
    });

    expect(entry.displayLabel, '温和破限');
    expect(entry.enabled, isFalse);
  });

  test('dream settings keeps independent defaults', () {
    final settings = DreamSettings.fromJson(const {});

    expect(settings.enableDreamLorebook, isTrue);
    expect(settings.worldLayer, 'reality_derived');
    expect(settings.jailbreakPreset, 'default');
  });

  testWidgets('renders the companion shell', (WidgetTester tester) async {
    // AppLanguage.system (the default before any preference is saved)
    // resolves via localeListResolutionCallback against the *test harness's*
    // reported platform locales, not the dev machine's — flutter test
    // defaults that list to en_US, which would silently flip these Chinese-
    // text assertions to English. Pin it so the test doesn't depend on
    // ambient locale (MaterialApp reads the plural `.locales`, not `.locale`).
    tester.platformDispatcher.localesTestValue = const [Locale('zh')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const MyApp());

    expect(find.text('TA'), findsWidgets);
    expect(find.text('主对话'), findsNothing);
    expect(find.text('对他说些什么…'), findsOneWidget);
  });

  testWidgets(
    'composer hugs the system inset and keyboard without a fake navigation row',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(const MyApp());
      final emptyHeight = tester.getSize(find.byType(Composer)).height;
      for (final inset in [0.0, 24.0, 48.0]) {
        tester.view.padding = FakeViewPadding(bottom: inset);
        tester.view.viewPadding = FakeViewPadding(bottom: inset);
        await tester.pump();
        final footer = find.byType(BottomSystemInset);
        expect(tester.getSize(footer).height, inset);
        expect(tester.widget<BottomSystemInset>(footer).color, Colors.black);
        expect(
          tester.getRect(find.byType(Composer)).bottom,
          closeTo(800 - inset, .01),
        );
        expect(
          tester.getSize(find.byType(Composer)).height,
          closeTo(emptyHeight, .01),
        );
      }
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = FakeViewPadding.zero;
      await tester.pump();
      expect(tester.getSize(find.byType(BottomSystemInset)).height, 0);
      expect(tester.getRect(find.byType(Composer)).bottom, closeTo(500, .01));
      await tester.enterText(find.byType(TextField).first, 'hello');
      await tester.pump();
      expect(tester.getRect(find.byType(Composer)).bottom, closeTo(500, .01));
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(
        tester.getSize(find.byType(Composer)).height,
        closeTo(emptyHeight, .01),
      );
      expect(
        tester.getRect(find.byType(Composer)).bottom -
            tester.getRect(find.byType(TextField).first).bottom,
        closeTo(18, .01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings page prioritizes connection and collapses modules', (
    WidgetTester tester,
  ) async {
    var credentialTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SettingsPage(
            c: YxPalette.light,
            language: AppLanguage.system,
            hasAdminToken: true,
            backgroundNotifications: true,
            backendBaseUrl: 'http://127.0.0.1:8080',
            ownerUserId: '10001',
            dark: false,
            activeThemePresetName: null,
            themePresetCount: 0,
            prefs: const YxPrefs(),
            profileDisplayName: 'Nova',
            profileAvatarBytes: null,

            dreamSettings: null,
            settingsBusy: false,
            settingsError: null,

            notificationTestMode: false,
            stickerEnabled: false,
            autoPlayVoice: false,
            onTheme: (_) {},
            onLanguage: (_) {},
            onManageThemes: () {},
            onPrefs: (_) {},
            onEditProfileName: () {},
            onImportProfileAvatar: () {},
            onResetProfileAvatar: () {},
            onEditRelay: () async {},
            onNotificationTestMode: (_) {},
            onStickerEnabledChanged: (_) {},
            onAutoPlayVoiceChanged: (_) {},

            onDreamLorebook: (_) {},
            onDreamWorldLayer: (_) {},
            onDreamJailbreak: (_) {},
            onEditCredential: () => credentialTapped = true,
            onOpenCapabilities: () {},
            onEditBackend: () {},
            onBackgroundNotifications: (_) {},
          ),
        ),
      ),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsPage)),
    );
    expect(find.text(l10n.settingsSetupComplete), findsWidgets);
    expect(find.text(l10n.settingsLanguageTitle), findsNothing);
    expect(find.text(l10n.settingsChatLorebookTitle), findsNothing);
    expect(find.text(l10n.settingsChatJailbreakTitle), findsNothing);
    expect(find.text(l10n.settingsNightSilentTitle), findsNothing);
    expect(
      tester.getTopLeft(find.text(l10n.settingsAccessTokenTitle)).dy,
      lessThan(tester.getTopLeft(find.text(l10n.settingsSystemModule)).dy),
    );
    await tester.tap(find.text('更换'));
    expect(credentialTapped, isTrue);
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final title in [
      l10n.settingsSystemModule,
      l10n.settingsProfileTitle,
      l10n.settingsAppearanceSection,
      l10n.settingsDreamModule,
    ]) {
      final tile = find.text(title);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('drawer keeps navigation scrollable and local settings visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          drawer: YxDrawer(
            c: YxPalette.light,
            route: AppRoute.chat,
            profileDisplayName: 'Nova',
            profileAvatarBytes: null,
            onRoute: (_) {},
            onOpenSettings: () {},
          ),
        ),
      ),
    );

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.text('设置'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dream page keeps a wake exit and independent composer', (
    WidgetTester tester,
  ) async {
    var woke = false;
    final controller =
        DreamController(
            backend: () => BackendClient(
              baseUrl: 'http://127.0.0.1:8080',
              settingsStore: const AppSettingsStore(),
            ),
            token: () => 'test-token',
          )
          ..state = DreamState.fromJson({
            'status': 'DREAM_ACTIVE',
            'scene_label': '被花包裹的暖房',
          });
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DreamPage(
            c: YxPalette.light,
            prefs: const YxPrefs(),
            profileDisplayName: 'Nova',
            profileAvatarBytes: null,
            controller: controller,
            onOpenDrawer: () {},
            onWake: () => woke = true,
          ),
        ),
      ),
    );

    expect(find.text('梦 · Nova'), findsOneWidget);
    expect(find.text('在这儿写点什么…'), findsOneWidget);

    await tester.tap(find.text('醒来'));
    expect(woke, isTrue);
  });
}
