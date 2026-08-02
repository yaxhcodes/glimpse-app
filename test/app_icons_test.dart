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

  testWidgets('selected navigation icon uses the matching fill variant', (
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

    final inactive = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('inactive')),
        matching: find.byType(Icon),
      ),
    );
    final selected = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('selected')),
        matching: find.byType(Icon),
      ),
    );

    expect(inactive.icon!.codePoint, selected.icon!.codePoint);
    expect(inactive.icon!.fontFamily, 'PhosphorRegular');
    expect(selected.icon!.fontFamily, 'PhosphorFill');
  });
}
