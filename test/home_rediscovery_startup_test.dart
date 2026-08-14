import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/home/rediscovery_section.dart';
import 'package:glimpse/features/rediscover/rediscover_daily_set.dart';

void main() {
  testWidgets('home fast path does not start journey generation', (
    tester,
  ) async {
    var dailySetBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rediscoverDailySetProvider.overrideWith((ref) async {
            dailySetBuilds++;
            return RediscoverDailySet(
              localDate: DateTime(2026, 8, 14),
              memories: const [],
            );
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RediscoverySection(loadJourneys: false)),
        ),
      ),
    );
    await tester.pump();

    expect(dailySetBuilds, 0);
    expect(
      find.byKey(const ValueKey('rediscover-journey-skeleton')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('rediscover-journey-skeleton')))
          .height,
      greaterThan(200),
    );
  });

  testWidgets('journey generation starts when the deferred path is enabled', (
    tester,
  ) async {
    var dailySetBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rediscoverDailySetProvider.overrideWith((ref) async {
            dailySetBuilds++;
            return RediscoverDailySet(
              localDate: DateTime(2026, 8, 14),
              memories: const [],
            );
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: RediscoverySection())),
      ),
    );
    await tester.pump();

    expect(dailySetBuilds, 1);
    expect(
      find.byKey(const ValueKey('rediscover-journey-skeleton')),
      findsNothing,
    );
  });
}
