import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
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

  test('history artifact row replaces the retained local one (no duplicate)', () {
    final artifacts = ChatArtifact.parseList([_payload()]);
    ChatMessage text() => ChatMessage(role: 'him', text: 'hi', time: '10:00', turnId: 't1');
    final remote = [
      text(),
      ChatMessage(role: 'him', text: '', time: '10:00', turnId: 't1', artifacts: artifacts),
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
  });

  testWidgets('card shows name/size, previews text and downloads', (tester) async {
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
