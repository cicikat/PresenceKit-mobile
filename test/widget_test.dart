import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yexuan_memery/main.dart';

void main() {
  test('prompt assets parses the Emerald-client response shape', () {
    final assets = PromptAssets.fromJson({
      'characters': [
        {'id': 'yexuan', 'label': '叶瑄'},
      ],
      'lorebooks': ['base'],
      'jailbreaks': [
        {'id': 'gentle', 'label': '温和破限'},
      ],
      'active': {
        'active_character': 'yexuan',
        'enabled_lorebooks': ['base'],
        'enabled_jailbreaks': ['gentle'],
      },
    });

    expect(assets.activeCharacter, 'yexuan');
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

    expect(find.text('叶瑄'), findsWidgets);
    expect(find.text('主对话'), findsNothing);
    expect(find.text('对他说些什么…'), findsOneWidget);
  });

  testWidgets('system settings puts token first', (WidgetTester tester) async {
    var credentialTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SystemSettingsSheet(
            c: YxPalette.light,
            hasAdminToken: true,
            backgroundNotifications: true,
            backendBaseUrl: 'http://127.0.0.1:8080',
            ownerUserId: '10001',
            historyLoaded: false,
            loadingHistory: false,
            historyError: null,
            gardenLoaded: false,
            loadingGarden: false,
            gardenError: null,
            mobileActive: false,
            pollingMobile: false,
            mobileError: null,
            mobileReceivedCount: 0,
            lastMobileContent: null,
            backendBusy: false,
            backendError: null,
            lastBackendReply: null,
            onEditCredential: () => credentialTapped = true,
            onOpenCapabilities: () {},
            onEditBackend: () {},
            onBackgroundNotifications: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('系统设置'), findsOneWidget);
    expect(find.text('访问 Token'), findsOneWidget);
    expect(find.textContaining('中继只承载新消息信号'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('访问 Token')).dy,
      lessThan(tester.getTopLeft(find.text('能力检查')).dy),
    );

    await tester.tap(find.text('更换'));
    expect(credentialTapped, isTrue);
  });

  testWidgets('dream page keeps a wake exit and independent composer', (
    WidgetTester tester,
  ) async {
    var woke = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DreamPage(
            c: YxPalette.light,
            prefs: const YxPrefs(),
            profileDisplayName: '叶瑄',
            profileAvatarBytes: null,
            state: DreamState.fromJson({
              'status': 'DREAM_ACTIVE',
              'scene_label': '被花包裹的暖房',
            }),
            loadingState: false,
            entering: false,
            sending: false,
            error: null,
            messages: const [],
            scrollController: ScrollController(),
            onOpenDrawer: () {},
            onEnter: () {},
            onSend: (_) {},
            onWake: () => woke = true,
          ),
        ),
      ),
    );

    expect(find.text('梦 · 叶瑄'), findsOneWidget);
    expect(find.text('在这儿写点什么…'), findsOneWidget);

    await tester.tap(find.text('醒来'));
    expect(woke, isTrue);
  });
}
