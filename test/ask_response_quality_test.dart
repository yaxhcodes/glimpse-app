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

    test('binds all-three synthesis to only the latest sourced answer', () {
      final unrelated = _saved(
        id: 1,
        title: 'Milk chocolate health risks',
        summary: 'A nutrition save about milk chocolate.',
      );
      final movies = [
        _saved(
          id: 2,
          title: 'Indonesian horror',
          summary: 'Recommended Indonesian horror films.',
        ),
        _saved(
          id: 3,
          title: 'Psychological thrillers',
          summary: 'Thrillers with strong plot twists.',
        ),
        _saved(
          id: 4,
          title: 'Emotionally intense cinema',
          summary: 'Films with emotionally intense stories.',
        ),
      ];

      final plan = AskConversationPlanner.plan(
        question: 'synthesize all three into a summary',
        allUrls: [unrelated, ...movies],
        semanticScored: [MapEntry(unrelated, 0.99)],
        previousMessages: [
          ChatMessage(
            text: 'Chocolate can affect health.',
            isUser: false,
            sources: [unrelated],
          ),
          ChatMessage(text: 'What movies have I saved?', isUser: true),
          ChatMessage(
            text: 'These are your three movie collections.',
            isUser: false,
            sources: movies,
          ),
        ],
      );

      expect(plan.isFollowUp, isTrue);
      expect(plan.suppressedSourceIds, isEmpty);
      expect(plan.contextUrls.map((url) => url.id), [2, 3, 4]);
    });
  });

  group('AskSuggestionGuard', () {
    final heartHealthSave = _saved(
      id: 1,
      title: 'Essential cardiovascular screening',
      summary:
          'Blood testing and five screening tests can identify cardiovascular risk. Discuss the results with your doctor.',
    );
    final seedSave = _saved(
      id: 2,
      title: 'Chia and sabja seed nutrition',
      summary: 'How to soak chia and sabja seeds and prepare lentils.',
    );

    test('rejects an adjacent topic absent from saved evidence', () {
      final result = AskSuggestionGuard.filter(
        candidates: const [
          'Are there specific grains that support heart health?',
          'Which blood tests screen for cardiovascular risk?',
        ],
        evidence: [heartHealthSave, seedSave],
        previousMessages: const [],
        currentQuestion: 'How does insulin resistance affect heart health?',
      );

      expect(result, ['Which blood tests screen for cardiovascular risk?']);
    });

    test('rejects questions already asked or lightly rephrased', () {
      final result = AskSuggestionGuard.filter(
        candidates: const [
          'Which blood tests should I discuss with my doctor?',
          'How should I discuss screening results with my doctor?',
        ],
        evidence: [heartHealthSave],
        previousMessages: [
          ChatMessage(
            text:
                'Which specific blood tests should I discuss with my doctor to screen for cardiovascular risk?',
            isUser: true,
          ),
        ],
        currentQuestion: 'How does insulin resistance affect heart health?',
      );

      expect(result, [
        'How should I discuss screening results with my doctor?',
      ]);
    });

    test('grounds tips only in sources cited by the visible answer', () {
      final security = _saved(
        id: 3,
        title: 'Preventing SIM swap scams',
        summary:
            'Protect online accounts from SIM swap scams with a port-out PIN and authenticator app.',
      );
      final nutrition = _saved(
        id: 4,
        title: 'Healthier snack choices',
        summary: 'Nutrition advice for healthier food and snack choices.',
      );
      final answer = ChatResponse(
        intro: 'You saved advice about staying safe online.',
        sections: const [
          ChatResponseSection(
            sourceIndex: 1,
            heading: 'SIM swap safety',
            summary: 'Protect accounts from SIM swap scams.',
          ),
        ],
      );
      final cited = AskSuggestionGuard.citedEvidence(
        answer: answer,
        retrievedEvidence: [security, nutrition],
      );

      final result = AskSuggestionGuard.filter(
        candidates: const [
          'Would you like healthier food and nutrition advice?',
          'How can I protect online accounts from SIM swap scams?',
        ],
        evidence: cited,
        previousMessages: const [],
        currentQuestion: 'Do I have anything on being safe online?',
        topicText:
            'Being safe online. Preventing SIM swap scams and protecting online accounts.',
      );

      expect(cited.map((source) => source.id), [3]);
      expect(result, [
        'How can I protect online accounts from SIM swap scams?',
      ]);
    });
  });

  group('AskAnswerActionPolicy', () {
    test('hides save answer for library-presence confirmations', () {
      expect(
        AskAnswerActionPolicy.canSaveAnswer(
          question: 'Did I save anything about spirituality?',
          answerType: ChatAnswerType.direct,
          confidence: ChatAnswerConfidence.high,
          sourceCount: 2,
        ),
        isFalse,
      );
    });

    test('keeps save answer for a substantive sourced response', () {
      expect(
        AskAnswerActionPolicy.canSaveAnswer(
          question: 'How does the concept of 33 koti deities work?',
          answerType: ChatAnswerType.direct,
          confidence: ChatAnswerConfidence.high,
          sourceCount: 1,
        ),
        isTrue,
      );
    });

    test('hides save answer for fallback responses', () {
      expect(
        AskAnswerActionPolicy.canSaveAnswer(
          question: 'Explain this topic',
          answerType: ChatAnswerType.fallback,
          confidence: ChatAnswerConfidence.low,
          sourceCount: 1,
        ),
        isFalse,
      );
    });
  });

  group('AskLocalAnswerCopy', () {
    test('answers topic-presence questions from on-device summaries', () {
      expect(
        AskLocalAnswerCopy.intro('What did I save about Software & AI?', 3),
        'You have 3 relevant saves about Software & AI. '
        'This answer uses summaries already saved on this device.',
      );
    });

    test('uses singular copy for one local result', () {
      expect(
        AskLocalAnswerCopy.intro('Explain my saved Riverpod notes', 1),
        'I found one relevant save on this device. '
        'Here is what the saved summaries say about your question.',
      );
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
