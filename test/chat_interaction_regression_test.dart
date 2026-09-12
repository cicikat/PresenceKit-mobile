import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/l10n/l10n.dart';
import 'package:presencekit_mobile/models/app_models.dart';
import 'package:presencekit_mobile/models/screen_context.dart';
import 'package:presencekit_mobile/widgets/chat_image.dart';
import 'package:presencekit_mobile/widgets/chat_widgets.dart';
import 'package:presencekit_mobile/widgets/edge_refresh.dart';
import 'package:presencekit_mobile/widgets/image_crop_viewport.dart';
import 'package:presencekit_mobile/widgets/scene_background.dart';
import 'package:presencekit_mobile/widgets/settings_editor_widgets.dart';

Widget app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Future<Uint8List> picture() async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 600, 300), Paint()..color = Colors.red);
  final drawing = recorder.endRecording();
  final image = await drawing.toImage(600, 300);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  drawing.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  testWidgets('own reply and select all do not reopen composer keyboard', (tester) async {
    var replied = false;
    await tester.pumpWidget(app(Scaffold(body: Column(children: [
      YouMessage(c: YxPalette.light, time: '12:00', text: 'my supplement',
        prefs: const YxPrefs(), onReply: () => replied = true),
      const TextField(),
    ]))));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.longPress(find.text('my supplement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(replied, isTrue);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.longPress(find.text('my supplement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)));
    expect(field.controller!.selection, const TextSelection(baseOffset: 0, extentOffset: 13));
    expect(field.readOnly, isTrue);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Copy')));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  test(
    'legacy data URI attachments are recognized without exposing encoded text',
    () {
      const uri = 'data:image/png;base64,AQID';
      expect(AttachmentPlaceholder.parse(uri)!.isImage, isTrue);
      expect(AttachmentPlaceholder.parse('📎 $uri')!.isImage, isTrue);
    },
  );

  testWidgets('legacy data URI renders an image instead of base64 text', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(picture))!;
    final uri = 'data:image/png;base64,${base64Encode(bytes)}';
    await tester.pumpWidget(
      app(
        Scaffold(
          body: YouMessage(
            c: YxPalette.light,
            time: '12:00',
            text: uri,
            prefs: const YxPrefs(),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pumpAndSettle();
    expect(find.byType(ChatImage), findsOneWidget);
    expect(find.text(uri), findsNothing);
  });

  testWidgets('crop dialogs fit a landscape small window', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = (await tester.runAsync(picture))!;
    for (final dialog in <Widget>[
      ChatBackgroundEditorDialog(
        c: YxPalette.light,
        bytes: bytes,
        initialBlur: 0,
        initialOpacity: 1,
      ),
      AvatarCropDialog(c: YxPalette.light, bytes: bytes),
    ]) {
      await tester.pumpWidget(app(dialog));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  for (final direction in [-1.0, 1.0]) {
    testWidgets(
      'short list refreshes only after release, direction $direction',
      (tester) async {
        final gate = Completer<void>();
        var calls = 0;
        await tester.pumpWidget(
          app(
            Scaffold(
              body: EdgeRefresh(
                onRefresh: () {
                  calls++;
                  return gate.future;
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  children: const [Text('one message')],
                ),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(const Offset(200, 300));
        for (var i = 0; i < 12; i++) {
          await gesture.moveBy(Offset(0, direction * 20));
          await tester.pump();
        }
        expect(calls, 0);
        expect(find.text('Release to refresh'), findsOneWidget);
        await gesture.up();
        await tester.pump();
        expect(calls, 1);
        expect(find.text('Refreshing connection…'), findsOneWidget);
        await tester.drag(find.byType(ListView), Offset(0, direction * 250));
        expect(calls, 1);
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text('Refreshing connection…'), findsNothing);
      },
    );
  }

  testWidgets(
    'scrolling within long history does not refresh; bottom drag does',
    (tester) async {
      var calls = 0;
      final scroll = ScrollController();
      await tester.pumpWidget(
        app(
          Scaffold(
            body: EdgeRefresh(
              onRefresh: () async {
                calls++;
              },
              child: ListView.builder(
                controller: scroll,
                itemExtent: 70,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                itemCount: 100,
                itemBuilder: (_, i) => Text('message $i'),
              ),
            ),
          ),
        ),
      );
      scroll.jumpTo(1000);
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(calls, 0);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
    },
  );

  testWidgets('crop pan, pinch, slider and export stay inside original image', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(picture))!;
    final key = GlobalKey<ImageCropViewportState>();
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: ImageCropViewport(key: key, bytes: bytes, aspectRatio: .5),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pumpAndSettle();
    void bounded() {
      final rect = key.currentState!.sourceRect;
      expect(rect.left, greaterThanOrEqualTo(-.001));
      expect(rect.top, greaterThanOrEqualTo(-.001));
      expect(rect.right, lessThanOrEqualTo(600.001));
      expect(rect.bottom, lessThanOrEqualTo(300.001));
    }

    final initialWidth = key.currentState!.sourceRect.width;
    await tester.drag(
      find.byKey(const ValueKey('crop-gesture')),
      const Offset(1500, 1500),
    );
    bounded();
    final center = tester.getCenter(find.byKey(const ValueKey('crop-gesture')));
    final a = await tester.startGesture(
      center - const Offset(25, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(25, 0),
      pointer: 2,
    );
    await tester.pump();
    await a.moveTo(center - const Offset(75, 0));
    await b.moveTo(center + const Offset(75, 0));
    await tester.pump();
    await a.up();
    await b.up();
    expect(key.currentState!.sourceRect.width, lessThan(initialWidth));
    bounded();
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(5);
    await tester.pump();
    bounded();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(1);
    await tester.pump();
    bounded();
    key.currentState!.reset();
    await tester.pump();
    bounded();
    expect(key.currentState!.sourceRect.width, closeTo(initialWidth, .001));
    final cropped = await tester.runAsync(() => key.currentState!.crop());
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(cropped!);
      final frame = await codec.getNextFrame();
      final rgba = await frame.image.toByteData();
      // Neither transparent margins nor the editor's white border are exported.
      for (final offset in [0, rgba!.lengthInBytes - 4]) {
        expect(rgba.getUint8(offset), 244);
        expect(rgba.getUint8(offset + 3), 255);
      }
      expect(frame.image.width / frame.image.height, closeTo(.5, .01));
      frame.image.dispose();
      codec.dispose();
    });
  });

  testWidgets('wallpaper geometry stays fixed with keyboard and dialog', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(picture))!;
    Widget scene(double inset) => app(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          viewInsets: EdgeInsets.only(bottom: inset),
        ),
        child: SceneBackground(
          bytes: bytes,
          color: Colors.white,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          const AlertDialog(content: Text('dialog')),
                    ),
                    child: const Text('open'),
                  ),
                  const Spacer(),
                  const TextField(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(scene(0));
    await tester.pumpAndSettle();
    final wallpaper = tester.getRect(
      find.byKey(const ValueKey('scene-wallpaper')),
    );
    final input = tester.getRect(find.byType(TextField));
    await tester.pumpWidget(scene(250));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('scene-wallpaper'))),
      wallpaper,
    );
    expect(
      tester.getRect(find.byType(TextField)).bottom,
      lessThan(input.bottom),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('scene-wallpaper'))),
      wallpaper,
    );
  });

  testWidgets('multiple uploads render bytes and caption and open original', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(picture))!;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: YouMessage(
              c: YxPalette.light,
              time: '12:00',
              text: 'internal filenames',
              prefs: const YxPrefs(),
              uploadNote: 'caption',
              attachments: [
                PickedUploadFile(name: 'one.png', bytes: bytes),
                PickedUploadFile(name: 'two.png', bytes: bytes),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pumpAndSettle();
    expect(find.byType(ChatImage), findsNWidgets(2));
    expect(find.text('caption'), findsOneWidget);
    expect(find.text('internal filenames'), findsNothing);
    expect(find.text('one.png'), findsNothing);
    for (final preview in find.byType(ChatImage).evaluate()) {
      final size = tester.getSize(find.byWidget(preview.widget));
      expect(size.width, closeTo(126, .01));
      expect(size.height, closeTo(63, .01));
    }
    final caption = find.byKey(const ValueKey('image-caption-bubble'));
    expect(
      find.descendant(of: caption, matching: find.text('caption')),
      findsOneWidget,
    );
    final bubble = tester.widget<Container>(caption);
    expect(
      (bubble.decoration as BoxDecoration).color,
      YxPalette.light.userBubble.withValues(alpha: .94),
    );
    expect(
      tester.getRect(caption).top,
      greaterThan(tester.getRect(find.byType(ChatImage).last).bottom),
    );
    await tester.tap(find.byType(ChatImage).first);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.getSize(find.byType(Image).last).width, greaterThan(126));
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.every((image) => (image.image as MemoryImage).bytes == bytes),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('background editor fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = (await tester.runAsync(picture))!;
    await tester.pumpWidget(
      app(
        ChatBackgroundEditorDialog(
          c: YxPalette.light,
          bytes: bytes,
          initialBlur: 0,
          initialOpacity: 1,
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
