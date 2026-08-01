import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/widgets/premium_design_system.dart';

void main() {
  testWidgets('overlaps thumbnails and ends with the remaining count', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MemoryStrip(
            imageUrls: ['one', 'two', 'three', 'four'],
            height: 44,
            overlap: 12,
            gapWidth: 2,
            totalCount: 74,
          ),
        ),
      ),
    );

    expect(find.text('+70'), findsOneWidget);

    final positioned = tester.widgetList<Positioned>(find.byType(Positioned));
    expect(positioned.map((tile) => tile.left), [0, 32, 64, 96, 128]);

    final strip = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(MemoryStrip),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(strip.width, 172);
  });
}
