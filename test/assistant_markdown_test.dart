import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/widgets/assistant_markdown.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:presencekit_mobile/widgets/chat_widgets.dart';
import 'package:presencekit_mobile/controllers/chat_controller.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/session_scope.dart';
import 'package:presencekit_mobile/services/app_settings_store.dart';
import 'package:presencekit_mobile/services/backend_client.dart';
import 'package:presencekit_mobile/services/device_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('MARKDOWN_REVIEW')) return;
    final textFont = FontLoader('ReferenceSong')
      ..addFont(rootBundle.load('assets/fonts/NotoSerifCJKsc-Regular.otf'));
    await textFont.load();
    final system = Platform.environment['WINDIR'];
    if (system != null) {
      final file = File('$system/Fonts/consola.ttf');
      if (file.existsSync()) {
        final codeFont = FontLoader('monospace')
          ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
        await codeFont.load();
      }
    }
  });
  testWidgets('link taps launch only explicit HTTP and HTTPS destinations', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantMarkdown(
            text:
                '[safe](https://example.invalid)\n\n[unsafe](javascript:alert(1))\n\n[file](file:///private)',
            style: const TextStyle(fontSize: 16),
            accent: Colors.red,
            openLink: (uri) async {
              opened.add(uri);
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('safe', findRichText: true));
    await tester.pump();
    await tester.tap(find.text('unsafe', findRichText: true));
    await tester.tap(find.text('file', findRichText: true));
    expect(opened.map((uri) => uri.toString()), ['https://example.invalid']);
    for (final value in [
      'data:text/html,bad',
      'javascript:alert(1)',
      'file:///private',
      '//example.invalid',
      'https://user:secret@example.invalid',
    ]) {
      expect(safeMarkdownUri(value), isNull);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('Markdown supports narrow large text in ${brightness.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const boundaryKey = Key('markdown-review');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness, fontFamily: 'ReferenceSong'),
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: brightness == Brightness.dark
                    ? const Color(0xff121212)
                    : Colors.white,
                child: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(390, 844),
                    textScaler: TextScaler.linear(1.5),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: AssistantMarkdown(
                      text:
                          '# 标题 Title\n\n<hl>强调</hl> **粗体** *italic* ~~old~~\n\n> 嵌套引用\n> > second\n\n- 第一项\n- second\n\n```text\n<hl>literal code</hl>\n```\n\n| A | B | C |\n|---|---|---|\n| long-long-long | 12345678901234567890 | value |',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'ReferenceSong',
                        color: brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                      accent: Colors.red,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Table), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('MARKDOWN_REVIEW')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/review').create(recursive: true);
          await File(
            'build/review/round1-markdown-${brightness.name}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }

  testWidgets(
    'animated assistant switches to Markdown after reveal completion',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedRevealText(
              text: '**bold**',
              animate: true,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
      expect(find.byType(AssistantMarkdown), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AssistantMarkdown), findsOneWidget);
    },
  );

  testWidgets('chat admission keeps a Markdown block in one message', (
    tester,
  ) async {
    const store = AppSettingsStore();
    final backend = _MarkdownBackend();
    final controller = ChatController(
      backend: () => backend,
      token: () => 'synthetic-token',
      settings: const SettingsStore(store),
      relay: const RelayStatusService(store),
      deliveryCharId: () => 'fixture-character',
      deliveryOwner: () => 'owner',
      resolvePresenceSession:
          ({required String charId, bool force = false}) async =>
              PresenceSessionGrant(
                sessionId: 'fixture-session',
                charId: charId,
                ownerId: 'owner',
                domain: 'reality',
              ),
    );
    controller.send('show the fixture');
    await tester.pump();
    expect(
      controller.sent
          .where((message) => message.role == 'him')
          .map((message) => message.text),
      [_MarkdownBackend.reply],
    );
    controller.dispose();
  });
  testWidgets('assistant renders Markdown blocks and keeps code literal', (
    tester,
  ) async {
    const source =
        '# Title\n\n**bold** *italic* ~~old~~ `inline`\n\n> quote\n\n1. first\n2. second\n\n```text\n<hl>literal</hl>\n```\n\n| A | B |\n|---|---|\n| one | two |';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssistantMarkdown(
              text: source,
              style: TextStyle(fontSize: 16),
              accent: Colors.red,
            ),
          ),
        ),
      ),
    );
    final text = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');
    expect(text, isNot(contains('**bold**')));
    expect(text, contains('<hl>literal</hl>'));
    expect(find.byType(Table), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Markdown cannot mount HTML or fetch a remote image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssistantMarkdown(
            text:
                '<script>alert(1)</script>\n\n![private](https://private.invalid/image)',
            style: TextStyle(fontSize: 16),
            accent: Colors.red,
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
    final text = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');
    expect(text, contains('<script>'));
    expect(tester.takeException(), isNull);
  });
}

class _MarkdownBackend extends BackendClient {
  _MarkdownBackend()
    : super(
        baseUrl: 'http://127.0.0.1:8080',
        settingsStore: const AppSettingsStore(),
      );
  static const reply = 'before\n```text\na\nb\n```\n| A |\n|---|\n| B |';
  @override
  Future<BackendChatResponse> sendChat(
    String message, {
    required String token,
    ReplyTarget? replyTo,
    String? sessionId,
    String? voiceReceipt,
    String? requestId,
  }) async => BackendChatResponse.fromJson({
    'reply': reply,
    'turn_id': 'canonical-markdown',
  });
  @override
  Future<MobileActivationResult> deactivateMobile({
    required String token,
  }) async => MobileActivationResult.fromJson({'ok': true, 'active': false});
}
