import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/controllers/dream_controller.dart';
import 'package:presencekit_mobile/controllers/voice_input_controller.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/ui_layout.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';
import 'package:presencekit_mobile/widgets/chat_scene.dart';
import 'package:presencekit_mobile/widgets/common_widgets.dart';
import 'package:presencekit_mobile/widgets/conversation_presentation.dart';
import 'package:presencekit_mobile/widgets/dream_scene.dart';
import 'package:presencekit_mobile/widgets/layout_settings.dart';
import 'package:presencekit_mobile/widgets/moonlit_scene.dart';

const exportReview = bool.fromEnvironment('LAYOUT_REVIEW');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!exportReview) return;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final windows = Platform.environment['WINDIR'];
    if (windows == null) return;
    final font = File('$windows/Fonts/msyh.ttc');
    if (font.existsSync()) {
      final loader = FontLoader('LayoutReview')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
      AppTypography.family = 'LayoutReview';
    }
  });
  tearDown(() {
    AppTypography.scale = 1;
  });

  Widget app(Widget body, YxPalette c, {double keyboard = 0}) => MaterialApp(
    theme: ThemeData(fontFamily: AppTypography.family),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: RepaintBoundary(
        key: const ValueKey('review'),
        child: Scaffold(backgroundColor: c.surface, body: body),
      ),
    ),
  );
  Future<void> capture(WidgetTester tester, String name) async {
    if (!exportReview) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('review')),
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 2);
      final data = await picture.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      final directory = Directory('build/layout-review')
        ..createSync(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    });
  }

  for (final layout in DailyLayout.values) {
    testWidgets('${layout.name} fits long messages, keyboard and large type', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const store = AppSettingsStore();
      final backend = BackendClient(
        baseUrl: 'http://127.0.0.1:8080',
        settingsStore: store,
      );
      final controller = ChatController(
        backend: () => backend,
        token: () => null,
        settings: const SettingsStore(store),
        relay: const RelayStatusService(store),
      );
      controller.history.addAll([
        ChatMessage(
          role: 'him',
          text: '今天过得怎么样？\n如果有想说的，我在这里听。',
          time: '20:16',
        ),
        ChatMessage(role: 'you', text: '想和你一起，慢慢说说今天。', time: '20:18'),
        ChatMessage(
          role: 'him',
          text: '好，我们不着急。',
          time: '20:19',
          quotedText: '慢慢说说今天',
        ),
      ]);
      final c = dailyLayoutPalette(layout, YxPalette.light);
      var profileName = '测试角色';
      Widget scene() => ChatScene(
        c: c,
        layout: layout,
        dark: false,
        prefs: const YxPrefs(),
        profileDisplayName: profileName,
        profileAvatarBytes: null,
        userName: '测试用户',
        controller: controller,
        onOpenDrawer: () {},
        onOpenSettings: () {},
        onRoute: (_) {},
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
      );
      await tester.pumpWidget(app(scene(), c));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await capture(tester, layout.name);
      tester.view.physicalSize = const Size(320, 700);
      AppTypography.scale = 1.4;
      profileName = '一个很长很长的自定义角色备注名称';
      await tester.pumpWidget(app(scene(), c, keyboard: 280));
      await tester.enterText(find.byType(TextField), '未发送的草稿');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('未发送的草稿'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
  for (final layout in DreamLayout.values) {
    testWidgets('dream ${layout.name} renders all segment types', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const store = AppSettingsStore();
      final backend = BackendClient(
        baseUrl: 'http://127.0.0.1:8080',
        settingsStore: store,
      );
      final controller = DreamController(
        backend: () => backend,
        token: () => null,
      )..state = DreamState.fromJson({'status': 'DREAM_ACTIVE'});
      controller.messages.add(
        ChatMessage(
          role: 'him',
          text: '',
          time: '20:21',
          segments: const [
            NarrativeSegment(type: 'env', text: '月光穿过窗，落在翻开的书页上。'),
            NarrativeSegment(type: 'do', text: '他合上书，在你身旁坐下来。'),
            NarrativeSegment(type: 'say', text: '今晚想去哪里？我们可以慢慢走。'),
            NarrativeSegment(type: 'feel', text: '风很轻，心也慢慢安静下来。'),
          ],
        ),
      );
      final c = layout == DreamLayout.moonlit
          ? moonlitPalette(YxPalette.dark)
          : YxPalette.dark;
      Widget scene() => LayoutBackdrop(
        c: c,
        moonlit: layout == DreamLayout.moonlit,
        child: DreamPage(
          layout: layout,
          c: c,
          prefs: const YxPrefs(),
          profileDisplayName: '测试角色',
          profileAvatarBytes: null,
          controller: controller,
          onOpenDrawer: () {},
          onWake: () {},
        ),
      );
      await tester.pumpWidget(app(scene(), c));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await capture(tester, 'dream-${layout.name}');
      tester.view.physicalSize = const Size(320, 700);
      AppTypography.scale = 1.4;
      await tester.pumpWidget(app(scene(), c, keyboard: 280));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
  testWidgets('layout selectors fit a narrow expanded settings card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppTypography.scale = 1.4;
    await tester.pumpWidget(
      app(
        SingleChildScrollView(
          child: LayoutSettings(
            c: YxPalette.light,
            daily: DailyLayout.reverie,
            dream: DreamLayout.moonlit,
            onDaily: (_) {},
            onDream: (_) {},
          ),
        ),
        YxPalette.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(DropdownButton<DailyLayout>));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('微信风格'), findsOneWidget);
  });
}
