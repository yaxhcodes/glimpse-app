import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/widgets/entrance_motion.dart';

void main() {
  testWidgets('a spring entrance rises a touch past its place and settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EntranceMotion(spring: true, offset: 18, child: Text('card')),
        ),
      ),
    );
    double rise() => tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.text('card'),
            matching: find.byType(Transform),
          ),
        )
        .map((transform) => transform.transform.getTranslation().y)
        .fold(0.0, (a, b) => b.abs() > a.abs() ? b : a);
    double opacity() => tester
        .widget<Opacity>(
          find.ancestor(of: find.text('card'), matching: find.byType(Opacity)),
        )
        .opacity;

    expect(rise(), 18);
    expect(opacity(), 0);
    var highest = double.infinity;
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 11));
      highest = math.min(highest, rise());
    }
    // Carried above its resting place before settling.
    expect(highest, lessThan(-0.5));

    await tester.pumpAndSettle();
    expect(rise(), 0);
    expect(opacity(), 1);
  });

  testWidgets('the timed entrance is unchanged', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EntranceMotion(child: Text('card'))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 240));
    final halfway = tester
        .widget<Opacity>(
          find.ancestor(of: find.text('card'), matching: find.byType(Opacity)),
        )
        .opacity;
    expect(halfway, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.text('card'),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      1,
    );
  });
}
