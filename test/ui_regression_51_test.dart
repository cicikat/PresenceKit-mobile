import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/controllers/voice_input_controller.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/ui_layout.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';
import 'package:presencekit_mobile/services/platform_settings_channel.dart';
import 'package:presencekit_mobile/widgets/ambient_permissions.dart';
import 'package:presencekit_mobile/widgets/capability_widgets.dart';
import 'package:presencekit_mobile/widgets/common_widgets.dart';
import 'package:presencekit_mobile/widgets/chat_widgets.dart';
import 'package:presencekit_mobile/widgets/conversation_presentation.dart';
import 'package:presencekit_mobile/widgets/reference_layout_shell.dart';
import 'package:presencekit_mobile/widgets/edge_refresh.dart';
import 'package:presencekit_mobile/widgets/screen_observation_settings.dart';
import 'package:presencekit_mobile/widgets/settings_editor_widgets.dart';

const capture = bool.fromEnvironment('UI_51_CAPTURE');
const phase = String.fromEnvironment('UI_51_PHASE', defaultValue: 'after');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('ReferenceSong')
          ..addFont(rootBundle.load('assets/fonts/NotoSerifCJKsc-Regular.otf')))
        .load();
    await (FontLoader('ReferenceLatin')
          ..addFont(
            rootBundle.load('assets/fonts/LibreBaskerville-Regular.ttf'),
          )
          ..addFont(
            rootBundle.load('assets/fonts/LibreBaskerville-Italic.ttf'),
          ))
        .load();
    if (!capture) return;
    final data = ByteData.sublistView(
      File(
        '${Platform.environment['WINDIR']}/Fonts/msyh.ttc',
      ).readAsBytesSync(),
    );
    for (final family in ['serif', 'monospace', 'sans-serif', 'Review51']) {
      await (FontLoader(family)..addFont(Future.value(data))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    PlatformSettingsChannel.debugForceChannelAvailable = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformSettingsChannel.channel, (
          call,
        ) async {
          if (call.method == 'readBatteryStatus') return {'percent': 72};
          if (call.method == 'isAccessibilityServiceEnabled') return true;
          return {
            'light': true,
            'lightSupported': true,
            'motion': false,
            'motionSupported': true,
            'usage': true,
            'usageSupported': true,
            'usageGranted': false,
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('presence_mobile/screen_observation'),
          (_) async => {'enabled': true, 'supported': true},
        );
  });
  tearDown(() {
    PlatformSettingsChannel.debugForceChannelAvailable = false;
    for (final channel in [
      PlatformSettingsChannel.channel,
      const MethodChannel('presence_mobile/screen_observation'),
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
  Widget app(Widget child, YxPalette c) => MaterialApp(
    theme: ThemeData(
      brightness: c == YxPalette.dark ? Brightness.dark : Brightness.light,
      fontFamily: capture ? 'Review51' : null,
    ),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: RepaintBoundary(
      key: const ValueKey('capture51'),
      child: Scaffold(backgroundColor: c.surface, body: child),
    ),
  );
  Future<void> shot(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    if (!capture) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture51')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final directory = Directory('build/review/ui-51/$phase')
        ..createSync(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    });
  }

  testWidgets('all headers keep one inset dot and an accessible details entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const c = YxPalette.dark;
    var opened = 0;
    for (final layout in DailyLayout.values) {
      Rect? previous;
      for (final connected in [true, false]) {
        const name = '叶宣 · A very long character name';
        void details() => opened++;
        final Widget header = layout == DailyLayout.classic
            ? ChatTopBar(
                c: c,
                dark: true,
                presence: PresenceSnapshot.current(
                  lookupAppLocalizations(const Locale('zh')),
                ),
                prefs: const YxPrefs(infoStrip: false),
                profileDisplayName: name,
                profileAvatarBytes: null,
                connected: connected,
                onDetails: details,
                onToggleTheme: () {},
                onOpenDrawer: () {},
                onOpenSettings: () {},
              )
            : hasReferenceShell(layout)
            ? ReferenceLayoutShell(
                layout: layout,
                route: AppRoute.chat,
                c: c,
                name: name,
                connected: connected,
                onDetails: details,
                onRoute: (_) {},
                onMenu: () {},
                onSettings: () {},
                onToggleTheme: () {},
                dark: true,
                child: const SizedBox.shrink(),
              )
            : ConversationHeader(
                c: c,
                name: name,
                layout: layout,
                connected: connected,
                onDetails: details,
                onMenu: () {},
                onSettings: () {},
                onToggleTheme: () {},
                dark: true,
              );
        await tester.pumpWidget(
          app(
            MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 844),
                textScaler: TextScaler.linear(1.8),
              ),
              child: header,
            ),
            c,
          ),
        );
        await tester.pump();
        final dot = find.byKey(const ValueKey('chat-connection-dot'));
        expect(dot, findsOneWidget);
        final rect = tester.getRect(dot);
        final avatar = tester.getRect(find.byType(YxAvatar));
        expect(avatar.contains(rect.topLeft), isTrue);
        expect(avatar.contains(rect.bottomRight), isTrue);
        expect(
          (rect.center - avatar.center).distance + rect.width / 2,
          lessThan(avatar.width / 2),
        );
        if (previous != null) expect(rect, previous);
        previous = rect;
        await tester.tap(find.byKey(const ValueKey('chat-delivery-details')));
        await tester.pump();
        await shot(
          tester,
          'header-${layout.name}-${connected ? 'connected' : 'disconnected'}-320-large',
        );
      }
    }
    expect(opened, DailyLayout.values.length * 2);
  });

  for (final dark in [true, false]) {
    testWidgets(
      'refresh indicator follows palette ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = dark ? YxPalette.dark : YxPalette.light;
        final refresh = Completer<void>();
        await tester.pumpWidget(
          app(
            EdgeRefresh(
              c: c,
              onRefresh: () => refresh.future,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                children: const [SizedBox(height: 100)],
              ),
            ),
            c,
          ),
        );
        await tester.drag(find.byType(ListView), const Offset(0, 220));
        await tester.pump();
        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.color, c.character);
        final label = tester.widget<Text>(
          find.text(lookupAppLocalizations(const Locale('zh')).chatRefreshing),
        );
        expect(label.style?.color, c.ink2);
        await shot(tester, 'refresh-progress-${dark ? 'dark' : 'light'}');
        refresh.complete();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
    testWidgets('chat and refresh ${dark ? 'dark' : 'light'}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = dark ? YxPalette.dark : YxPalette.light;
      const store = AppSettingsStore();
      final controller = ChatController(
        backend: () => BackendClient(
          baseUrl: 'http://127.0.0.1:8080',
          settingsStore: store,
        ),
        token: () => null,
        settings: const SettingsStore(store),
        relay: const RelayStatusService(store),
      );
      controller.mobileActive = true;
      controller.history.addAll([
        ChatMessage(role: 'him', text: '今天过得怎么样？我想听你慢慢说。', time: '20:16'),
        ChatMessage(role: 'you', text: '刚忙完，终于可以坐下来聊一会儿。', time: '20:18'),
      ]);
      Widget scene() => app(
        ChatScene(
          c: c,
          dark: dark,
          prefs: const YxPrefs(),
          profileDisplayName: '叶宣',
          profileAvatarBytes: null,
          controller: controller,
          onOpenDrawer: () {},
          onOpenSettings: () {},
          onOpenAttach: () {},
          onToggleTheme: () {},
          onLockNow: () {},
          onOpenOrderAccessibility: () {},
          onOpenMeituan: () {},
          onOpenTaobao: () {},
          onShowOrderBubble: () {},
          onVoiceRecordStart: () async => null,
          onVoiceRecordStop: () async => const VoiceInputResult(),
          onVoiceRecordCancel: () {},
        ),
        c,
      );
      await tester.pumpWidget(scene());
      await tester.pump(const Duration(milliseconds: 300));
      await shot(tester, 'chat-${dark ? 'dark' : 'light'}-connected');
      controller.mobileActive = false;
      await tester.pumpWidget(scene());
      await tester.pump();
      await shot(tester, 'chat-${dark ? 'dark' : 'light'}-disconnected');
      final list = find.byType(Scrollable).first;
      final gesture = await tester.startGesture(tester.getCenter(list));
      await gesture.moveBy(const Offset(0, 110));
      await tester.pump();
      await shot(tester, 'refresh-${dark ? 'dark' : 'light'}');
      await gesture.moveBy(const Offset(0, -110));
      await gesture.up();
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
    for (final readOnly in [false, true]) {
      testWidgets('sensing ${dark ? 'dark' : 'light'} readOnly $readOnly', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = dark ? YxPalette.dark : YxPalette.light;
        await tester.pumpWidget(
          app(
            SingleChildScrollView(
              child: Column(
                children: [
                  CapabilityRow(
                    c: c,
                    icon: Icons.accessibility_new_rounded,
                    title: '无障碍服务',
                    subtitle: '帮助读取当前屏幕，按你的要求操作。',
                    enabled: true,
                    actionLabel: '已启用',
                  ),
                  AmbientPermissions(
                    readOnly: readOnly,
                    onChanged: (_, _) async {},
                  ),
                  ScreenObservationSettings(c: c, readOnly: readOnly),
                  SettingsRow(
                    c: c,
                    title: '自动播放语音',
                    subtitle: '收到语音时自动播放。',
                    child: Switch(value: true, onChanged: (_) {}),
                  ),
                ],
              ),
            ),
            c,
          ),
        );
        await tester.pumpAndSettle();
        await shot(
          tester,
          '${readOnly ? 'capabilities' : 'settings'}-${dark ? 'dark' : 'light'}',
        );
      });
    }
  }
}
