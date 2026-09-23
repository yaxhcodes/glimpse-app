import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/widgets/expressive_fab.dart';

void main() {
  testWidgets('collapses with a fixed icon position and keeps its action', (tester) async {
    var expanded = true;
    var taps = 0;
    late StateSetter update;
    const iconKey = ValueKey('mascot');
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        update = setState;
        return Scaffold(
          floatingActionButton: ExpressiveExtendedFab(
            isExtended: expanded,
            tooltip: 'Ask Glimpse',
            onPressed: () => taps++,
            icon: const Icon(Icons.chat, key: iconKey, size: 20),
            label: const Text('Ask Glimpse'),
          ),
        );
      }),
    ));
    await tester.pumpAndSettle();
    final initialX = tester.getCenter(find.byKey(iconKey)).dx;
    final initialWidth = tester.getSize(find.byType(FloatingActionButton)).width;
    update(() => expanded = false);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FloatingActionButton)).width, lessThan(initialWidth));
    expect(tester.getCenter(find.byKey(iconKey)).dx, closeTo(initialX, 1));
    expect(find.byTooltip('Ask Glimpse'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    expect(taps, 1);
    update(() => expanded = true);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FloatingActionButton)).width, initialWidth);
    expect(tester.takeException(), isNull);
  });
}
