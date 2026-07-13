import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

void main() {
  test('primary destinations have distinct semantic icons', () {
    final destinations = <IconData>{
      AppIcons.home,
      AppIcons.collections,
      AppIcons.interests,
      AppIcons.search,
    };

    expect(destinations, hasLength(4));
  });

  testWidgets('selected navigation icon uses filled heavier treatment', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            AppIcon(AppIcons.collections, key: ValueKey('inactive')),
            AppIcon(
              AppIcons.collections,
              key: ValueKey('selected'),
              selected: true,
            ),
          ],
        ),
      ),
    );

    final inactive = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('inactive')),
        matching: find.byType(RichText),
      ),
    );
    final selected = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('selected')),
        matching: find.byType(RichText),
      ),
    );
    final inactiveAxes = _fontAxes(inactive);
    final selectedAxes = _fontAxes(selected);

    expect(inactiveAxes['FILL'], 0);
    expect(inactiveAxes['wght'], 400);
    expect(selectedAxes['FILL'], 1);
    expect(selectedAxes['wght'], 550);
  });
}

Map<String, double> _fontAxes(RichText text) {
  final span = text.text as TextSpan;
  return {
    for (final variation in span.style!.fontVariations!)
      variation.axis: variation.value,
  };
}
