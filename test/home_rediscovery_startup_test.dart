import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glimpse/features/rediscover/rediscover_memory_prefs.dart';
import 'package:glimpse/features/home/rediscovery_section.dart';
import 'package:glimpse/features/rediscover/rediscover_daily_set.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final deferred in [true, false]) {
    testWidgets(
      'saved daily cards reserve skeleton space, deferred=$deferred',
      (tester) async {
        await RediscoverMemoryPrefs.saveDailySet(
          rediscoverDateKey(DateTime.now()),
          [
            {'id': 'saved-memory'},
          ],
        );
        final pending = Completer<RediscoverDailySet>();
        var builds = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              rediscoverDailySetProvider.overrideWith((ref) {
                builds++;
                return pending.future;
              }),
            ],
            child: MaterialApp(
              home: Scaffold(body: RediscoverySection(loadJourneys: !deferred)),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          find.byKey(const ValueKey('rediscover-journey-skeleton')),
          findsOneWidget,
        );
        expect(builds, deferred ? 0 : 1);
        if (!deferred) {
          pending.complete(
            RediscoverDailySet(localDate: DateTime.now(), memories: const []),
          );
          await tester.pumpAndSettle();
          expect(find.text('Rediscover'), findsNothing);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('pending discovery stays hidden until cards are available', (
    tester,
  ) async {
    final pending = Completer<RediscoverDailySet>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rediscoverDailySetProvider.overrideWith((ref) => pending.future),
        ],
        child: const MaterialApp(home: Scaffold(body: RediscoverySection())),
      ),
    );
    await tester.pump();
    expect(find.byType(CarouselView), findsNothing);
    expect(find.text('Rediscover'), findsNothing);
    expect(
      find.byKey(const ValueKey('rediscover-journey-skeleton')),
      findsNothing,
    );
    pending.complete(
      RediscoverDailySet(localDate: DateTime(2026, 9, 8), memories: const []),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rediscover'), findsNothing);
  });

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
      findsNothing,
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
