import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/glimpses/glimpse_home_adapter.dart';
import 'package:glimpse/features/home/home_loading_skeleton.dart';
import 'package:glimpse/shared/widgets/skeleton.dart';

void main() {
  testWidgets('home skeleton preserves the main feed structure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          glimpseHomeHasCardsProvider.overrideWith((ref) async => true),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeLoadingSkeleton())),
      ),
    );
    await tester.pump();

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
