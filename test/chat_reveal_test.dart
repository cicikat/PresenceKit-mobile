import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';
import 'package:presencekit_mobile/widgets/chat_widgets.dart';

void main() {
  test('a new reply loses its animation flag once reveal starts', () {
    const store = AppSettingsStore();
    final backend = BackendClient(
      baseUrl: 'http://127.0.0.1:8080',
      settingsStore: store,
    );
    final controller = ChatController(
      backend: () => backend,
      token: () => 'test-token',
      settings: const SettingsStore(store),
      relay: const RelayStatusService(store),
    );
    const message = ChatMessage(
      role: 'him',
      text: '这是一条新回复',
      time: '现在',
      animate: true,
    );
    controller.sent.add(message);

    controller.markRevealStarted(message);

    expect(controller.sent.single.animate, isFalse);
    expect(controller.sent.single.text, message.text);
    controller.dispose();
  });

  testWidgets('an in-progress reveal survives consuming its one-shot flag', (
    tester,
  ) async {
    var started = false;
    const text = '这是一条足够长的新回复，用来确认动画不会因为状态刷新而突然整块显示。';

    Widget build({required bool animate}) => MaterialApp(
      home: AnimatedRevealText(
        text: text,
        animate: animate,
        style: const TextStyle(),
        onRevealStarted: () => started = true,
      ),
    );

    await tester.pumpWidget(build(animate: true));
    await tester.pump();
    expect(started, isTrue);
    expect(find.text(text), findsNothing);

    await tester.pumpWidget(build(animate: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(text), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text(text), findsOneWidget);
  });
}
