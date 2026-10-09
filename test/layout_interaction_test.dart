import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/ui_layout.dart';
import 'package:presencekit_mobile/controllers/voice_input_controller.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';
import 'package:presencekit_mobile/widgets/chat_scene.dart';
import 'package:presencekit_mobile/widgets/conversation_presentation.dart';

void main() {
  testWidgets('layout changes preserve a focused draft and real navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
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
    AppRoute? routed;
    Widget page(DailyLayout layout) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatScene(
          c: dailyLayoutPalette(layout, YxPalette.light),
          layout: layout,
          dark: false,
          prefs: const YxPrefs(),
          profileDisplayName: 'Nova',
          profileAvatarBytes: null,
          controller: controller,
          onOpenDrawer: () {},
          onOpenSettings: () {},
          onRoute: (v) {
            routed = v;
          },
          onOpenAttach: () {},
          onToggleTheme: () {},
          onLockNow: () {},
          onOpenOrderAccessibility: () {},
          onOpenMeituan: () {},
          onOpenTaobao: () {},
          onShowOrderBubble: () {},
          onVoiceRecordStart: () async => null,
          onVoiceRecordStop: () async =>
              const VoiceInputResult(text: '', error: null),
          onVoiceRecordCancel: () {},
        ),
      ),
    );
    await tester.pumpWidget(page(DailyLayout.classic));
    await tester.enterText(find.byType(TextField), 'keep this draft');
    await tester.pumpWidget(page(DailyLayout.letter));
    await tester.pump();
    expect(find.text('keep this draft'), findsOneWidget);
    await tester.tap(find.text("Nova's diary"));
    expect(routed, AppRoute.diary);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(page(DailyLayout.classic));
    expect(find.text('keep this draft'), findsOneWidget);
    for (final layout in [DailyLayout.reverie, DailyLayout.noir]) {
      await tester.pumpWidget(page(layout));
      expect(find.text('keep this draft'), findsOneWidget);
      await tester.tap(find.text('Enter dream'));
      expect(routed, AppRoute.dream);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(page(DailyLayout.messenger));
    expect(find.text('keep this draft'), findsOneWidget);
    expect(find.text("Nova's diary"), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
