import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/widgets/swipe_deck.dart';

void main() {
  late PageController controller;

  Future<void> pumpDeck(WidgetTester tester) async {
    controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SwipeDeck(
          controller: controller,
          itemCount: 3,
          itemBuilder: (context, index) => ColoredBox(
            color: Colors.white,
            child: Center(child: Text('page $index')),
          ),
        ),
      ),
    );
  }

  ClipRRect cardOf(WidgetTester tester, String page) =>
      tester.widget<ClipRRect>(
        find
            .ancestor(of: find.text(page), matching: find.byType(ClipRRect))
            .first,
      );

  double driftOf(WidgetTester tester, String page) => tester
      .widget<Transform>(
        find
            .ancestor(of: find.text(page), matching: find.byType(Transform))
            .first,
      )
      .transform
      .getTranslation()
      .x;

  testWidgets('a settled page is just the page', (tester) async {
    await pumpDeck(tester);
    expect(cardOf(tester, 'page 0').clipBehavior, Clip.none);
    expect(driftOf(tester, 'page 0'), 0);
  });

  testWidgets('mid-swipe the pages become cards and the one left dims', (
    tester,
  ) async {
    await pumpDeck(tester);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();

    expect(cardOf(tester, 'page 0').clipBehavior, Clip.antiAlias);
    expect(cardOf(tester, 'page 1').clipBehavior, Clip.antiAlias);
    // Content lags its card: the incoming page's drifts back, the leaving
    // page's forward.
    expect(driftOf(tester, 'page 1'), lessThan(0));
    expect(driftOf(tester, 'page 0'), greaterThan(0));
    expect(
      find.descendant(
        of: find
            .ancestor(of: find.text('page 0'), matching: find.byType(Stack))
            .first,
        matching: find.byType(ColoredBox),
      ),
      findsWidgets,
    );

    // Past halfway and let go: on to the next page.
    await gesture.moveBy(const Offset(-300, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.page, 1);
    expect(cardOf(tester, 'page 1').clipBehavior, Clip.none);
    expect(driftOf(tester, 'page 1'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fling carries into the next page on a spring', (tester) async {
    await pumpDeck(tester);
    await tester.fling(find.text('page 0'), const Offset(-120, 0), 1200);
    var furthest = 0.0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 11));
      furthest = controller.page! > furthest ? controller.page! : furthest;
    }
    expect(furthest, greaterThanOrEqualTo(1));
    await tester.pumpAndSettle();
    expect(controller.page!.round(), 1);
    expect(tester.takeException(), isNull);
  });
}
