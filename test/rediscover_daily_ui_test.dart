import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/url_processing_status.dart';
import 'package:glimpse/features/home/home_provider.dart';
import 'package:glimpse/features/rediscover/rediscover_daily_set.dart';
import 'package:glimpse/features/rediscover/rediscover_journey_detail_screen.dart';
import 'package:glimpse/features/rediscover/rediscover_journey_provider.dart';
import 'package:glimpse/features/rediscover/rediscover_memory.dart';
import 'package:glimpse/features/rediscover/rediscover_open_context.dart';
import 'package:glimpse/features/rediscover/rediscover_provider.dart';
import 'package:glimpse/features/rediscover/rediscover_screen.dart';

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
  testWidgets('Rediscover renders only the shared daily set', (tester) async {
    final first = _url(3, 'Primary memory');
    final second = _url(
      4,
      'Supporting memory',
      category: 'Travel',
      tags: const ['weekend travel', 'hiking'],
    );
    final memories = [
      RediscoverMemory.fromJourney(
        RediscoverJourney(
          kind: RediscoverJourneyKind.returningTopic,
          title: 'Primary topic',
          subtitle: 'A focused return',
          icon: Icons.playlist_play_rounded,
          items: [_item(first)],
          signal: 100,
          topicAnchor: 'primary topic',
          stableTopicKey: 'technology:primary-topic',
          triggerSaveId: 99,
          triggerTitle: 'A new primary-topic save',
          topicPulseConfidence: 'strong',
        ),
      ),
      RediscoverMemory.fromJourney(
        RediscoverJourney(
          kind: RediscoverJourneyKind.forgottenGems,
          title: 'Supporting topic',
          subtitle: 'A useful older save',
          icon: Icons.diamond_outlined,
          items: [_item(second)],
          signal: 80,
          topicAnchor: 'supporting topic',
        ),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rediscoverDailySetProvider.overrideWith(
            (ref) async => RediscoverDailySet(
              localDate: DateTime(2026, 8, 14),
              memories: memories,
            ),
          ),
          rediscoverDailySetControllerProvider.overrideWithValue(
            _NoopDailySetController(),
          ),
          rediscoveryStatsProvider.overrideWith(
            (ref) async => (total: 2, unopened: 2),
          ),
          rediscoverRecapsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: RediscoverScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Recently resurfaced'), findsNothing);
    expect(find.text('Related saves'), findsNothing);
    expect(find.text('Recaps'), findsNothing);
    expect(find.text(memories.first.rediscoverCopy.title), findsOneWidget);
    expect(find.text(memories.last.rediscoverCopy.title), findsOneWidget);
    expect(find.text('Back in view · 1 save'), findsOneWidget);
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
