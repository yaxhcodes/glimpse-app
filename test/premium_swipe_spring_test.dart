import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/providers/swipe_preferences_provider.dart';
import 'package:glimpse/shared/widgets/card_open_transition.dart';
import 'package:glimpse/shared/widgets/premium_swipe_card.dart';

void main() {
  Widget row(String label, {VoidCallback? onDismissed}) => PremiumSwipeCard(
    key: ValueKey(label),
    leftSwipeAction: SwipeActionType.delete,
    rightSwipeAction: SwipeActionType.none,
    onDismissed: (_) => onDismissed?.call(),
    child: CardOpenOrigin(
      child: SizedBox(
        height: 80,
        width: double.infinity,
        child: ColoredBox(color: Colors.teal, child: Text(label)),
      ),
    ),
  );

  Future<void> pumpList(WidgetTester tester, List<String> rows) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                for (final label in rows)
                  row(
                    label,
                    onDismissed: () => setState(() => rows.remove(label)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double shiftOf(WidgetTester tester, String label) => tester
      .widgetList<Transform>(
        find.ancestor(of: find.text(label), matching: find.byType(Transform)),
      )
      .map((transform) => transform.transform.getTranslation().y)
      .fold(0.0, (a, b) => b.abs() > a.abs() ? b : a);

  testWidgets('a swipe let go early springs home', (tester) async {
    await pumpList(tester, ['a', 'b']);
    final card = find.byKey(const ValueKey('a'));
    final start = tester.getRect(find.text('a'));
    final gesture = await tester.startGesture(tester.getCenter(card));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getRect(find.text('a')).left, lessThan(start.left));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('a')), start);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a deleted row closes on a spring and the row below catches', (
    tester,
  ) async {
    await pumpList(tester, ['a', 'b']);
    final belowStart = tester.getRect(find.text('b')).top;
    await tester.drag(
      find.byKey(const ValueKey('a')),
      Offset(-tester.getSize(find.byKey(const ValueKey('a'))).width * .8, 0),
    );
    // Past the slide off-screen, into the close-up.
    await tester.pump(const Duration(milliseconds: 260));
    final positions = <double>[];
    var furthestCatch = 0.0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 11));
      if (find.text('b').evaluate().isEmpty) break;
      positions.add(tester.getRect(find.text('b')).top);
      furthestCatch = math.min(furthestCatch, shiftOf(tester, 'b'));
    }
    // Slid up through the gap over several frames, not in one jump.
    final between = positions.where((y) => y > 5 && y < belowStart - 5);
    expect(between.length, greaterThan(2));
    // Carried on past its place, then settled.
    expect(furthestCatch, lessThan(-1));

    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
    expect(tester.getRect(find.text('b')).top, 0);
    expect(shiftOf(tester, 'b'), 0);
    expect(tester.takeException(), isNull);
  });
}
