import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/l10n/generated/app_localizations.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/widgets/chat_widgets.dart';

void main() {
  test('mobile poll message preserves a self-contained sticker payload', () {
    final message = MobilePollMessage.fromJson(const {
      'id': 'sticker-1',
      'seq': 1,
      'content': '',
      'user_id': 'owner',
      'timestamp': 1781280000,
      'sticker': {
        'kind': 'sticker',
        'emotion': '开心',
        'data_url':
            'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==',
      },
    });

    expect(message.sticker?.emotion, '开心');
    expect(message.toChatMessage().text, isEmpty);
    expect(
      message.toChatMessage().sticker?.dataUrl,
      startsWith('data:image/gif'),
    );
  });

  testWidgets('empty-text sticker renders as an image bubble', (tester) async {
    await tester.pumpWidget(
      _messageWithSticker(
        const StickerPayload(
          emotion: '开心',
          dataUrl:
              'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==',
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('表情包加载失败'), findsNothing);
  });

  testWidgets('invalid sticker data shows the localized fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _messageWithSticker(
        const StickerPayload(
          emotion: '',
          dataUrl: 'data:text/plain;base64,ZmFpbGVk',
        ),
      ),
    );

    expect(find.text('表情包加载失败'), findsOneWidget);
  });
}

Widget _messageWithSticker(StickerPayload sticker) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: HimMessage(
      c: YxPalette.light,
      time: '现在',
      text: '',
      sticker: sticker,
      prefs: const YxPrefs(),
    ),
  ),
);
