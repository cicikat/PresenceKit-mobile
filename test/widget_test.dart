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
      'lorebooks': ['base'],
      'jailbreaks': [
        {'id': 'gentle', 'label': '温和破限'},
      ],
      'active': {
        'active_character': 'test-character',
        'enabled_lorebooks': ['base'],
        'enabled_jailbreaks': ['gentle'],
      },
    });

    expect(assets.activeCharacter, 'test-character');
    expect(assets.lorebooks.single.label, 'base');
    expect(assets.enabledJailbreaks, {'gentle'});
  });

  test('dream settings keeps independent defaults', () {
    final settings = DreamSettings.fromJson(const {});

    expect(settings.enableDreamLorebook, isTrue);
    expect(settings.worldLayer, 'reality_derived');
    expect(settings.jailbreakPreset, 'default');
  });

  testWidgets('renders the companion shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('TA'), findsWidgets);
    expect(find.text('主对话'), findsNothing);
    expect(find.text('对他说些什么…'), findsOneWidget);
  });

  testWidgets('settings page puts token first', (WidgetTester tester) async {
    var credentialTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            c: YxPalette.light,
            hasAdminToken: true,
            backgroundNotifications: true,
            backendBaseUrl: 'http://127.0.0.1:8080',
            ownerUserId: '10001',
            dark: false,
            customThemeEnabled: false,
            hasCustomTheme: false,
            prefs: const YxPrefs(),
            profileDisplayName: 'Nova',
            profileAvatarBytes: null,
            promptAssets: null,
            dreamSettings: null,
            settingsBusy: false,
            settingsError: null,
            notificationTestMode: false,
            onTheme: (_) {},
            onCustomTheme: () {},
            onEditCustomTheme: () {},
            onPrefs: (_) {},
            onEditProfileName: () {},
            onImportProfileAvatar: () {},
            onResetProfileAvatar: () {},
            onOpenProfile: () {},
            onEditRelay: () async {},
            onNotificationTestMode: (_) {},
            onToggleLorebook: (_) {},
            onToggleJailbreak: (_) {},
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

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('访问 Token'), findsOneWidget);
    expect(find.textContaining('中继只承载新消息信号'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('访问 Token')).dy,
      lessThan(tester.getTopLeft(find.text('能力检查')).dy),
    );

    await tester.tap(find.text('更换'));
    expect(credentialTapped, isTrue);
  });

  testWidgets('drawer keeps navigation scrollable and local settings visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
