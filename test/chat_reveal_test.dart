import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';
import 'package:presencekit_mobile/widgets/chat_widgets.dart';

void main() {
  testWidgets('skip exposes every remaining segment and releases sending', (tester) async {
    const store = AppSettingsStore();
    final backend = _LongReplyBackend();
    final controller = ChatController(backend: () => backend, token: () => 'test',
      settings: const SettingsStore(store), relay: const RelayStatusService(store));
    controller.send('hello');
    await tester.pump();
    expect(controller.sent.where((m) => m.role == 'him').length, 1);
    expect(controller.sending, isTrue);
    controller.skipReveal();
    await tester.pump();
    expect(controller.sent.where((m) => m.role == 'him').length, 3);
    expect(controller.sent.where((m) => m.role == 'reasoning').length, 1);
    expect(controller.sending, isFalse);
    expect(controller.himTyping, isFalse);
    await tester.pump(const Duration(seconds: 6));
    expect(controller.sent.where((m) => m.role == 'him').length, 3);
    controller.dispose();
  });

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
    final message = ChatMessage(
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

  test('settling a message preserves its IM metadata', () {
    final message = ChatMessage(
      role: 'you',
      text: 'reply',
      time: '10:24',
      dateKey: '2026-09-02',
      quotedText: 'quoted message',
      quotedLabel: 'him',
      failed: true,
      animate: true,
    );

    final settled = message.settled();

    expect(settled.animate, isFalse);
    expect(settled.dateKey, message.dateKey);
    expect(settled.quotedText, message.quotedText);
    expect(settled.quotedLabel, message.quotedLabel);
    expect(settled.failed, isTrue);
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

class _LongReplyBackend extends BackendClient {
  _LongReplyBackend() : super(baseUrl: 'http://127.0.0.1:8080', settingsStore: const AppSettingsStore());
  @override
  Future<BackendChatResponse> sendChat(String message, {required String token, ReplyTarget? replyTo}) async =>
    BackendChatResponse.fromJson({'reply': '${'A' * 5000}\n\nSecond\n\nThird', 'turn_id': 'canonical'});
  @override
  Future<MobileActivationResult> deactivateMobile({required String token}) async => MobileActivationResult.fromJson({'ok': true, 'active': false});
}
