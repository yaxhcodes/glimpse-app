import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/widgets/expressive_loading_indicator.dart';

void main() {
  testWidgets('blob loader preserves sizing and loading semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ExpressiveLoadingIndicator(
              size: 24,
              color: Colors.deepPurple,
            ),
          ),
        ),
      ),
    );

    final loader = find.byType(ExpressiveLoadingIndicator);
    expect(loader, findsOneWidget);
    expect(tester.getSize(loader), const Size.square(24));
    expect(tester.getSemantics(loader).label, 'Loading');

    final before = tester.widget<CustomPaint>(
      find.descendant(of: loader, matching: find.byType(CustomPaint)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    final after = tester.widget<CustomPaint>(
      find.descendant(of: loader, matching: find.byType(CustomPaint)),
    );
    expect(after.painter, isNot(same(before.painter)));
    semantics.dispose();
  });
}
