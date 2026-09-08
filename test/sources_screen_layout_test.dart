import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/sources/sources_provider.dart';
import 'package:glimpse/features/sources/sources_screen.dart';

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('Top sources keeps bottom padding at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: TopSourcesRail(
                sources: [
                  SourceCluster(
                    name: 'jiohotstar.com',
                    count: 2,
                    mostlyAbout: [],
                    themeCount: 0,
                    memoryStripUrls: [],
                    savesThisWeek: 2,
                  ),
                  SourceCluster(
                    name: 'myntra.com',
                    count: 2,
                    mostlyAbout: [],
                    themeCount: 0,
                    memoryStripUrls: [],
                    savesThisWeek: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rail = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      final cards = find.descendant(of: rail, matching: find.byType(Card));
      final week = find.descendant(
        of: cards.first,
        matching: find.text('+2 this week'),
      );
      final cardRect = tester.getRect(cards.first);
      final weekRect = tester.getRect(week);
      expect(cardRect.bottom - weekRect.bottom, greaterThanOrEqualTo(12));
      expect(
        tester.getSize(cards.first).height,
        tester.getSize(cards.last).height,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
