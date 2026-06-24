import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/memory_goal_service.dart';

SavedUrl _url({
  required int id,
  required String title,
  required DateTime savedAt,
  String summary = '',
  List<String> tags = const [],
  String category = 'Other',
  String? enrichmentJson,
  DateTime? openedAt,
}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = title
    ..description = ''
    ..summary = summary
    ..category = category
    ..categoryEmoji = ''
    ..categories = [category]
    ..tags = tags
    ..enrichmentJson = enrichmentJson
    ..openedAt = openedAt
    ..savedAt = savedAt;
}

String _intentJson({
  required String intent,
  required String lifeArea,
  String? location,
  String actionability = 'medium',
}) {
  return jsonEncode({
    'memory_intent': {
      'primary_intent': intent,
      'life_area': lifeArea,
      'location': location,
      'actionability': actionability,
      'why_saved_hypothesis': 'The user may want this later.',
    },
  });
}

void main() {
  group('MemoryGoalService', () {
    test('clusters repeated travel saves into a visit goal', () {
      final urls = [
        _url(
          id: 1,
          title: 'Queenstown itinerary',
          savedAt: DateTime(2026, 5, 1),
          tags: ['queenstown', 'new zealand travel'],
          enrichmentJson: _intentJson(
            intent: 'visit',
            lifeArea: 'travel',
            location: 'New Zealand',
          ),
        ),
        _url(
          id: 2,
          title: 'Milford Sound road trip',
          savedAt: DateTime(2026, 5, 4),
          tags: ['milford sound', 'new zealand travel'],
          enrichmentJson: _intentJson(
            intent: 'visit',
            lifeArea: 'travel',
            location: 'New Zealand',
          ),
        ),
      ];

      final goals = MemoryGoalService.buildGoals(
        urls,
        now: DateTime(2026, 5, 10),
      );

      expect(goals, hasLength(1));
      expect(goals.single.name, 'Visit New Zealand');
      expect(goals.single.intent, 'visit');
      expect(goals.single.lifeArea, 'travel');
      expect(goals.single.saveCount, 2);
      expect(goals.single.status, 'active');
    });

    test(
      'uses fallback intent for older saves without enrichment metadata',
      () {
        final urls = [
          _url(
            id: 1,
            title: 'Flutter Riverpod guide',
            savedAt: DateTime(2026, 3, 1),
            tags: ['flutter'],
            summary: 'A tutorial about providers.',
            category: 'Technology',
          ),
          _url(
            id: 2,
            title: 'Flutter layout tutorial',
            savedAt: DateTime(2026, 3, 2),
            tags: ['flutter'],
            summary: 'A lesson on app layouts.',
            category: 'Technology',
          ),
        ];

        final goals = MemoryGoalService.buildGoals(
          urls,
          now: DateTime(2026, 6, 1),
        );

        expect(goals, hasLength(1));
        expect(goals.single.name, 'Learn Flutter');
        expect(goals.single.status, 'dormant');
        expect(goals.single.nextAction, contains('beginner-friendly'));
      },
    );
  });
}
