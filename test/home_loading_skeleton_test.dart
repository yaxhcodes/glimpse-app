import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/home/home_loading_skeleton.dart';
import 'package:glimpse/shared/widgets/skeleton.dart';

void main() {
  testWidgets('home skeleton preserves the main feed structure', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeLoadingSkeleton())),
    );

    expect(find.text('Glimpse'), findsOneWidget);
    expect(find.byType(HomeSourcesSkeleton), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
  });

  testWidgets('sources skeleton reserves its section height', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: HomeSourcesSkeleton(),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(HomeSourcesSkeleton)).height, 64);
  });
}
