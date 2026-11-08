import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:presencekit_mobile/services/platform_settings_channel.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/widgets/chat_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_history_reconciliation.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/chat_artifact.dart';
import 'package:presencekit_mobile/services/backend_client.dart'
    show BackendException;
import 'package:presencekit_mobile/services/chat_artifact_saver.dart';
import 'package:presencekit_mobile/widgets/chat_artifact_widgets.dart';

const _id = 'a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3';

Map<String, dynamic> _payload({String id = _id, bool preview = true}) => {
  'id': id,
  'filename': 'note.md',
  'mime': 'text/markdown; charset=utf-8',
  'size': 2048,
  'previewable': preview,
  'download_url': '/chat/artifacts/$id',
  if (preview) 'preview_url': '/chat/artifacts/$id/preview',
};

class _FakeSaver extends ChatArtifactSaver {
  _FakeSaver(this.result);
  final bool result;
  String? savedName;
  String? savedText;
  Uint8List? savedBytes;

  @override
  Future<bool> saveImage({
    required String filename,
    required String mime,
    required Uint8List bytes,
  }) async {
    savedBytes = bytes;
    savedName = filename;
    return result;
  }

  @override
  bool get available => true;

  @override
  Future<bool> saveText({
    required String filename,
    required String mime,
    required String text,
  }) async {
    savedName = filename;
    savedText = text;
    return result;
  }
}

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('zh'),
  home: Scaffold(body: child),
);

void main() {
  test(
    'binary image saver keeps bytes intact and reports system cancellation',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      PlatformSettingsChannel.debugForceChannelAvailable = true;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MethodCall? call;
      messenger.setMockMethodCallHandler(PlatformSettingsChannel.channel, (
        c,
      ) async {
        call = c;
        return false;
      });
      try {
        final bytes = Uint8List.fromList([137, 80, 78, 71, 0, 255]);
        final result = await const ChatArtifactSaver().saveImage(
          filename: 'generated.png',
          mime: 'image/png',
          bytes: bytes,
        );
        expect(result, false);
        expect(call!.method, 'saveChatImage');
        expect((call!.arguments as Map)['bytes'], bytes);
      } finally {
        messenger.setMockMethodCallHandler(
          PlatformSettingsChannel.channel,
          null,
        );
        PlatformSettingsChannel.debugForceChannelAvailable = false;
      }
    },
  );

  test('parseList drops invalid items and caps at four', () {
    final list = ChatArtifact.parseList([
      _payload(),
      {'id': 'bad', 'filename': 'x.txt'},
      {'id': _id, 'filename': ''},
      'junk',
      for (var i = 0; i < 6; i++) _payload(id: '${'a' * 31}$i'),
    ]);
    expect(list.length, ChatArtifact.maxPerTurn);
    expect(list.first.filename, 'note.md');
    expect(list.first.previewable, isTrue);
    expect(list.first.downloadPath, '/chat/artifacts/$_id');
    expect(ChatArtifact.parseList(null), isEmpty);
  });

  test('poll, history and chat response all parse artifacts', () {
    final poll = MobilePollMessage.fromJson({
      'id': 't1',
      'content': 'hi',
      'user_id': 'u',
      'artifacts': [_payload()],
    });
    expect(poll.artifacts.single.id, _id);
    expect(
      MobilePollMessage.fromJson(poll.toQueueItemJson()).artifacts.single.id,
      _id,
    );
    final entry = ChatLogEntry.fromJson({
      'time': '10:00',
      'user': '',
      'assistant': 'x',
      'turn_id': 't1',
      'artifacts': [_payload()],
    });
    expect(entry.artifacts.single.filename, 'note.md');
    final resp = BackendChatResponse.fromJson({
      'reply': 'x',
      'artifacts': [_payload()],
    });
    expect(resp.artifacts, hasLength(1));
  });

  test(
    'history artifact row replaces the retained local one (no duplicate)',
    () {
      final artifacts = ChatArtifact.parseList([_payload()]);
      ChatMessage text() =>
          ChatMessage(role: 'him', text: 'hi', time: '10:00', turnId: 't1');
      final remote = [
        text(),
        ChatMessage(
          role: 'him',
          text: '',
          time: '10:00',
          turnId: 't1',
          artifacts: artifacts,
        ),
      ];
      final local = ChatMessage(
        role: 'him',
        text: '',
        time: '10:00',
        turnId: 't1',
        artifacts: artifacts,
        retainOnRefresh: true,
      );
      final merged = reconcileChatHistory(remote, [], [], [local]);
      expect(merged.where((m) => m.artifacts.isNotEmpty), hasLength(1));
    },
  );

  testWidgets(
    'generated image is displayed, enlarged and saved as original binary',
    (tester) async {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final a = ChatArtifact.tryParse({
        ..._payload(),
        'kind': 'image',
        'mime': 'image/png',
        'filename': 'generated.png',
      })!;
      expect(ChatArtifact.tryParse(a.toJson())!.kind, 'image');
      final saver = _FakeSaver(true);
      await tester.pumpWidget(
        _host(
          ArtifactCard(
            c: YxPalette.light,
            artifact: a,
            saver: saver,
            fetch: (a, {onProgress}) async => bytes,
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          MemoryImage(bytes),
          tester.element(find.byType(ArtifactCard)),
        );
      });
      await tester.pumpAndSettle();
      expect(find.byType(ChatImage), findsOneWidget);
      expect(find.byKey(const ValueKey('artifact-preview')), findsNothing);
      await tester.tap(find.byType(ChatImage));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('artifact-download')));
      await tester.pumpAndSettle();
      expect(saver.savedBytes, bytes);
      expect(saver.savedText, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('image fetch failure can retry without losing download card', (
    tester,
  ) async {
    var calls = 0;
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final a = ChatArtifact.tryParse({
      ..._payload(),
      'kind': 'image',
      'mime': 'image/png',
    })!;
    await tester.pumpWidget(
      _host(
        ArtifactCard(
          c: YxPalette.light,
          artifact: a,
          fetch: (a, {onProgress}) async {
            if (++calls == 1) throw const BackendException('expired');
            return bytes;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('expired'), findsOneWidget);
    await tester.tap(find.text('加载图片 / 重试'));
    await tester.runAsync(() async {
      await precacheImage(
        MemoryImage(bytes),
        tester.element(find.byType(ArtifactCard)),
      );
    });
    await tester.pumpAndSettle();
    expect(find.byType(ChatImage), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('card shows name/size, previews text and downloads', (
    tester,
  ) async {
    final artifact = ChatArtifact.parseList([_payload()]).single;
    final saver = _FakeSaver(true);
    await tester.pumpWidget(
      _host(
        ArtifactMessage(
          c: YxPalette.light,
          artifacts: [artifact],
          saver: saver,
          fetch: (a, {onProgress}) async {
            onProgress?.call(5, 10);
            return Uint8List.fromList(utf8.encode('# 你好'));
          },
        ),
      ),
    );
    expect(find.text('note.md'), findsOneWidget);
    expect(find.textContaining('2.0 KB'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('artifact-preview')));
    await tester.pumpAndSettle();
    expect(find.text('# 你好'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('artifact-download')));
    await tester.pumpAndSettle();
    expect(saver.savedName, 'note.md');
    expect(saver.savedText, '# 你好');
    expect(find.textContaining('已保存'), findsOneWidget);
  });

  testWidgets('download failure (expired) surfaces a message', (tester) async {
    final artifact = ChatArtifact.parseList([_payload(preview: false)]).single;
    await tester.pumpWidget(
      _host(
        ArtifactMessage(
          c: YxPalette.light,
          artifacts: [artifact],
          saver: _FakeSaver(true),
          fetch: (a, {onProgress}) async =>
              throw const BackendException('文件已不存在或已过期', statusCode: 404),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('artifact-preview')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('artifact-download')));
    await tester.pumpAndSettle();
    expect(find.text('文件已不存在或已过期'), findsOneWidget);
  });
}
