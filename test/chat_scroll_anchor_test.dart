import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presencekit_mobile/controllers/chat_scroll_controller.dart';
import 'package:presencekit_mobile/widgets/anchored_chat_list.dart';

void main() {
  testWidgets('52-A2 A3 A6: follow growth, viewport and explicit latest', (
    tester,
  ) async {
    final controller = ChatScrollController();
    addTearDown(controller.dispose);
    var count = 3;
    var height = 500.0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            rebuild = setState;
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                height: height,
                child: AnchoredChatList(
                  controller: controller,
                  rowIds: List<Object>.generate(count, (i) => i),
                  itemBuilder: (_, i) =>
                      SizedBox(height: 90, child: Text('row-$i')),
                ),
              ),
            );
          },
        ),
      ),
    );
    for (final next in [6, 10, 20]) {
      rebuild(() => count = next);
      await tester.pumpAndSettle();
      expect(controller.position.extentAfter, lessThanOrEqualTo(1));
    }
    controller.jumpTo(controller.position.maxScrollExtent - 40);
    rebuild(() {
      count++;
      height = 320;
    });
    await tester.pumpAndSettle();
    expect(controller.following, isTrue);
    expect(controller.position.extentAfter, lessThanOrEqualTo(1));
    controller.followAfterLayout();
    await tester.drag(find.byType(AnchoredChatList), const Offset(0, 220));
    await tester.pumpAndSettle();
    expect(controller.following, isFalse);
    expect(controller.position.extentAfter, greaterThan(100));
    await tester.fling(
      find.byType(AnchoredChatList),
      const Offset(0, -100),
      4000,
    );
    await tester.pumpAndSettle();
    expect(controller.following, isTrue);
    expect(controller.position.extentAfter, lessThanOrEqualTo(1));
    await tester.drag(find.byType(AnchoredChatList), const Offset(0, 220));
    await tester.pumpAndSettle();
    expect(controller.following, isFalse);
    controller.follow();
    controller.followAfterLayout();
    await tester.pumpAndSettle();
    expect(controller.position.extentAfter, lessThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox());
  });
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
        controller.stopFollowing();
        await tester.pumpAndSettle();
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
        final stable = tester.getTopLeft(find.text('bubble-22')).dy;
        controller.preserveBeforeLayout();
        rebuild(() => ids.add('typing'));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('bubble-22')).dy,
          closeTo(stable, 2),
        );
        controller.preserveBeforeLayout();
        rebuild(() => ids.remove('typing'));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('bubble-22')).dy,
          closeTo(stable, 2),
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
