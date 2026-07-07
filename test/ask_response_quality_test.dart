import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/gemini_service.dart';
import 'package:glimpse/features/ask/ask_provider.dart';

SavedUrl _saved({
  required int id,
  required String title,
  required String summary,
  String domain = 'example.com',
  DateTime? savedAt,
}) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://$domain/$id'
    ..domain = domain
    ..title = title
    ..description = summary
    ..category = 'Article'
    ..categoryEmoji = ''
    ..categories = ['Article']
    ..tags = const []
    ..summary = summary
    ..savedAt = savedAt ?? DateTime(2026, 6, id);
}

void main() {
  group('AskConversationPlanner', () {
    test('suppresses already cited sources for what-else follow-ups', () {
      final first = _saved(
        id: 1,
        title: 'Moose documentary',
        summary: 'A saved documentary about moose behavior.',
      );
      final second = _saved(
        id: 2,
        title: 'Moose field notes',
        summary: 'A saved field guide about moose habitat.',
      );

      final plan = AskConversationPlanner.plan(
        question: 'what else about moose?',
        allUrls: [first, second],
        previousMessages: [
          ChatMessage(text: 'show me moose saves', isUser: true),
          ChatMessage(text: 'You saved this.', isUser: false, sources: [first]),
        ],
      );

      expect(plan.isFollowUp, isTrue);
      expect(plan.suppressedSourceIds, contains(1));
      expect(plan.contextUrls.map((url) => url.id), contains(2));
      expect(plan.contextUrls.map((url) => url.id), isNot(contains(1)));
    });

    test('reuses active context when the user asks about that source', () {
      final source = _saved(
        id: 1,
        title: 'Waterwalker',
        summary: 'A documentary about canoeing and nature.',
      );

      final plan = AskConversationPlanner.plan(
        question: 'tell me more about that',
        allUrls: [source],
        previousMessages: [
          ChatMessage(text: 'what was waterwalker?', isUser: true),
          ChatMessage(
            text: 'It is this save.',
            isUser: false,
            sources: [source],
          ),
        ],
      );

      expect(plan.isFollowUp, isTrue);
      expect(plan.suppressedSourceIds, isEmpty);
      expect(plan.contextUrls.single.id, 1);
    });
  });

  group('GeminiService chat response parsing', () {
    test('parses answer metadata and follow-up suggestions', () {
      final source = _saved(
        id: 1,
        title: 'Pasta notes',
        summary: 'A recipe save.',
      );
      final service = GeminiService('');

      final response = service.parseChatResponseForTesting(
        jsonEncode({
          'intro': 'This is mainly a quick pasta recipe.',
          'answerType': 'selected_save',
          'confidence': 'high',
          'sections': [
            {
              'sourceIndex': 1,
              'heading': 'Recipe clue',
              'summary':
                  'The saved ingredient list points to a weeknight pasta.',
            },
          ],
          'followUps': [
            'What ingredients do I need?',
            'How long would it take?',
            'Can I make it higher protein?',
            'This extra one should be ignored?',
          ],
        }),
        [source],
      );

      expect(response.answerType, ChatAnswerType.selectedSave);
      expect(response.confidence, ChatAnswerConfidence.high);
      expect(response.followUpSuggestions, hasLength(3));
      expect(response.sections.single.sourceIndex, 1);
    });

    test('falls back safely when model JSON is malformed', () {
      final source = _saved(
        id: 1,
        title: 'Fallback source',
        summary: 'A useful local summary.',
      );
      final service = GeminiService('');

      final response = service.parseChatResponseForTesting('not json', [
        source,
      ]);

      expect(response.answerType, ChatAnswerType.fallback);
      expect(response.confidence, ChatAnswerConfidence.low);
      expect(response.sections.single.summary, 'A useful local summary.');
    });
  });
}
