import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/ask_retrieval_service.dart';

SavedUrl _saved({
  required int id,
  required String title,
  required String summary,
  String description = '',
  List<String> tags = const [],
  DateTime? savedAt,
  String? enrichmentJson,
}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = title
    ..description = description
    ..category = 'Film'
    ..categoryEmoji = ''
    ..categories = ['Film']
    ..tags = tags
    ..summary = summary
    ..enrichmentJson = enrichmentJson
    ..savedAt = savedAt ?? DateTime(2026, 5, id);
}

void main() {
  group('AskRetrievalService', () {
    test('finds separate saved items mentioned in one vague question', () {
      final urls = [
        _saved(
          id: 1,
          title: 'The Moose of Isle Royale',
          summary: 'A nature documentary about moose, wolves, and forests.',
          tags: ['moose', 'wildlife'],
        ),
        _saved(
          id: 2,
          title: 'Waterwalker',
          summary: 'Bill Mason travels by canoe through Canadian waters.',
          tags: ['canoe', 'documentary'],
        ),
        _saved(
          id: 3,
          title: 'Flutter state management notes',
          summary: 'A practical guide to Riverpod providers.',
          tags: ['flutter'],
        ),
      ];

      final result = AskRetrievalService.retrieve(
        query: 'what were those two documentaries, mooses and waterwalker?',
        allUrls: urls,
      );

      expect(result.map((u) => u.id), containsAllInOrder([2, 1]));
      expect(result.map((u) => u.id), isNot(contains(3)));
    });

    test(
      'respects requested documentary quantity and filters low-fit platforms',
      () {
        final urls = [
          _saved(
            id: 1,
            title: 'I Did Wildlife Photography in India',
            summary: 'A YouTube wildlife expedition through India.',
            tags: ['wildlife'],
          )..domain = 'youtube.com',
          _saved(
            id: 2,
            title: 'IN THE COMPANY OF MOOSE with Gisele Benoit',
            summary: 'A YouTube documentary on moose behavior and habitat.',
            tags: ['moose', 'nature'],
          )..domain = 'youtube.com',
          _saved(
            id: 3,
            title: 'Waterwalker',
            summary:
                'This feature-length documentary follows Bill Mason by canoe through the Ontario wilderness and his sense of nature.',
            tags: ['nature'],
          )..domain = 'youtube.com',
          _saved(
              id: 4,
              title: 'Here are 10 GitHub repos that quietly print money',
              summary: 'A developer thread about open source repositories.',
              tags: ['github'],
            )
            ..domain = 'x.com'
            ..category = 'X'
            ..categories = ['X'],
          _saved(
              id: 5,
              title: 'Adventure Travel Nature Reel',
              summary: 'An Instagram reel from a scenic trek.',
              tags: ['nature'],
            )
            ..domain = 'instagram.com'
            ..category = 'Instagram'
            ..categories = ['Instagram'],
        ];

        final result = AskRetrievalService.retrieve(
          query:
              'i saved 2 documentaries a while ago about wildlife and nature',
          allUrls: urls,
          semanticScored: [
            MapEntry(urls[0], 0.84),
            MapEntry(urls[1], 0.81),
            MapEntry(urls[2], 0.83),
            MapEntry(urls[3], 0.78),
            MapEntry(urls[4], 0.78),
          ],
        );

        expect(result.map((u) => u.id), containsAll([2, 3]));
        expect(result.length, 2);
      },
    );

    test('plural memory words match singular saved titles', () {
      final urls = [
        _saved(
          id: 1,
          title: 'Moose: Life of a Twig Eater',
          summary: 'A documentary following a young moose.',
        ),
      ];

      final result = AskRetrievalService.retrieve(
        query: 'find the one about mooses',
        allUrls: urls,
      );

      expect(result.single.id, 1);
    });

    test(
      'exact keyword match outranks unrelated semantic nearest neighbor',
      () {
        final waterwalker = _saved(
          id: 1,
          title: 'Waterwalker',
          summary: 'A canoe documentary.',
        );
        final unrelated = _saved(
          id: 2,
          title: 'A random productivity article',
          summary: 'Notes on task planning.',
        );

        final result = AskRetrievalService.retrieve(
          query: 'waterwalker',
          allUrls: [waterwalker, unrelated],
          semanticScored: [MapEntry(unrelated, 0.99)],
        );

        expect(result.first.id, 1);
      },
    );

    test('drops semantic-only guesses below the relevance floor', () {
      final unrelated = _saved(
        id: 1,
        title: 'A random URL',
        summary: 'Something unrelated.',
      );

      final result = AskRetrievalService.retrieve(
        query: 'waterwalker',
        allUrls: [unrelated],
        semanticScored: [MapEntry(unrelated, 0.40)],
      );

      expect(result, isEmpty);
    });

    test(
      'matches natural language learning intent from enrichment metadata',
      () {
        final flutter = _saved(
          id: 1,
          title: 'Riverpod provider patterns',
          summary: 'A short reference about state management.',
          enrichmentJson: jsonEncode({
            'memory_intent': {
              'primary_intent': 'learn',
              'life_area': 'education',
              'why_saved_hypothesis':
                  'The user may want to learn Flutter architecture later.',
            },
          }),
        );
        final recipe = _saved(
          id: 2,
          title: 'Mushroom pasta',
          summary: 'A weeknight dinner recipe.',
        );

        final result = AskRetrievalService.retrieve(
          query: 'things I wanted to learn',
          allUrls: [recipe, flutter],
        );

        expect(result.map((u) => u.id), contains(1));
        expect(result.map((u) => u.id), isNot(contains(2)));
      },
    );
  });
}
