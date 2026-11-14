import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_scroll_controller.dart';
import 'package:presencekit_mobile/widgets/anchored_chat_list.dart';

void main() {
  for (final incoming in [1, 10, 50]) {
    testWidgets(
      'visible bubble stays fixed with prepend, $incoming arrivals and a removed anchor',
      (tester) async {
        final controller = ChatScrollController();
        addTearDown(controller.dispose);
        var ids = List<Object>.generate(100, (i) => i);
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return AnchoredChatList(
                    controller: controller,
                    rowIds: ids,
                    itemBuilder: (_, index) => SizedBox(
                      height: ids[index] is int
                          ? 60 + ((ids[index] as int) % 3) * 20
                          : 33,
                      child: Text('bubble-${ids[index]}'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        controller.jumpTo(1600);
        await tester.pumpAndSettle();
        controller.stopFollowing();
        final before = tester.getTopLeft(find.text('bubble-21')).dy;
        controller.preserveBeforeLayout();
        rebuild(
          () => ids = [
            for (var i = 20; i > 0; i--) -i,
            'meta',
            ...ids,
            for (var i = 100; i < 100 + incoming; i++) i,
          ],
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('bubble-21')).dy,
          closeTo(before, 2),
        );
        final neighbour = tester.getTopLeft(find.text('bubble-22')).dy;
        controller.preserveBeforeLayout();
        rebuild(() => ids.remove(20));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('bubble-22')).dy,
          closeTo(neighbour, 2),
        );
        expect(controller.following, isFalse);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
