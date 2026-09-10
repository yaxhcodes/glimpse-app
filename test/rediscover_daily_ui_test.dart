import 'package:glimpse/features/glimpses/glimpse_home_adapter.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/url_processing_status.dart';
import 'package:glimpse/features/home/home_provider.dart';
import 'package:glimpse/features/home/rediscovery_section.dart';
import 'package:glimpse/features/rediscover/rediscover_daily_set.dart';
import 'package:glimpse/features/rediscover/rediscover_journey_detail_screen.dart';
import 'package:glimpse/features/rediscover/rediscover_journey_provider.dart';
import 'package:glimpse/features/rediscover/rediscover_memory.dart';
import 'package:glimpse/features/rediscover/rediscover_open_context.dart';
import 'package:glimpse/features/rediscover/rediscover_provider.dart';

SavedUrl _url(
  int id,
  String title, {
  DateTime? openedAt,
  String category = 'Technology',
  List<String> tags = const ['flutter', 'architecture'],
}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = title
    ..description = ''
    ..category = category
    ..categoryEmoji = ''
    ..categories = [category]
    ..tags = tags
    ..savedAt = DateTime(2026, 6, id)
    ..openedAt = openedAt
    ..processingStatus = UrlProcessingStatus.ready;
}

RediscoveryItem _item(SavedUrl url) {
  return RediscoveryItem(url: url, reason: 'Unopened', timeAgo: '2mo ago');
}

void main() {
  testWidgets('Home crossfades saved skeletons into daily cards', (
    tester,
  ) async {
    final pending = Completer<RediscoverDailySet>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rediscoverHasSavedDailyCardsProvider.overrideWith(
            (ref) async => true,
          ),
          glimpseHomeSetProvider.overrideWith((ref) => pending.future),
          rediscoverDailySetControllerProvider.overrideWithValue(
            _NoopDailySetController(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: RediscoverySection()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final skeleton = find.byKey(const ValueKey('rediscover-journey-skeleton'));
    expect(skeleton, findsOneWidget);
    pending.complete(
      RediscoverDailySet(
        localDate: DateTime.now(),
        memories: [
          RediscoverMemory.fromJourney(
            RediscoverJourney(
              kind: RediscoverJourneyKind.forgottenGems,
              title: 'Architecture notes',
              subtitle: 'Worth reopening',
              icon: Icons.book,
              items: [_item(_url(1, 'Architecture notes'))],
              signal: 80,
              topicAnchor: 'architecture',
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(skeleton, findsOneWidget);
    expect(find.byType(CarouselView), findsOneWidget);
    await tester.pumpAndSettle();
    expect(skeleton, findsNothing);
    expect(find.byType(CarouselView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('journey detail renders each save exactly once', (tester) async {
    final first = _url(1, 'State Management Notes');
    final second = _url(
      2,
      'Offline Architecture Guide',
      openedAt: DateTime(2026, 8, 1),
    );
    final journey = RediscoverJourney(
      kind: RediscoverJourneyKind.returningTopic,
      title: 'Flutter architecture',
      subtitle: 'Two saves worth reopening',
      icon: Icons.code_rounded,
      items: [_item(first), _item(first), _item(second)],
      signal: 80,
      topicAnchor: 'flutter architecture',
      recommendedFirstSaveId: first.id,
      stableTopicKey: 'technology:flutter-architecture',
      triggerSaveId: 3,
      triggerTitle: 'A new Flutter architecture save',
      topicPulseConfidence: 'strong',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tagOccurrenceMapProvider.overrideWithValue(const {})],
        child: MaterialApp(
          home: RediscoverJourneyDetailScreen(journey: journey),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('State Management Notes'), findsOneWidget);
    expect(find.text('Forgotten gems'), findsNothing);
    expect(find.text('Connected saves'), findsNothing);
    expect(find.text('Back in view'), findsOneWidget);
    expect(find.text('Start here'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Offline Architecture Guide'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Offline Architecture Guide'), findsOneWidget);
    expect(find.textContaining('More in'), findsOneWidget);
  });
}

class _NoopDailySetController implements RediscoverDailySetController {
  @override
  Future<void> lessLikeThis(RediscoverMemory memory) async {}

  @override
  Future<void> lessLikeThisWithContext(
    RediscoverMemory memory, {
    required RediscoverOpenContext openContext,
  }) async {}

  @override
  Future<void> markOpened(RediscoverMemory memory) async {}

  @override
  Future<void> markOpenedWithContext(
    RediscoverMemory memory, {
    required RediscoverOpenContext openContext,
  }) async {}

  @override
  Future<void> markShown(RediscoverMemory memory) async {}

  @override
  Future<void> markShownWithContext(
    RediscoverMemory memory, {
    RediscoverSurface surface = RediscoverSurface.rediscover,
    int position = 0,
  }) async {}

  @override
  Future<void> snooze(RediscoverMemory memory) async {}

  @override
  Future<void> snoozeWithContext(
    RediscoverMemory memory, {
    required RediscoverOpenContext openContext,
  }) async {}
}
