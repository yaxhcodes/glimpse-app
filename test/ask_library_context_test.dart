import 'dart:io';
import 'package:glimpse/core/services/ask_input_budget.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/core/services/ask_library_context.dart';
import 'package:glimpse/core/services/ask_stream_decoder.dart';
import 'package:glimpse/core/services/ask_query_plan.dart';
import 'package:glimpse/core/services/gemini_service.dart';
import 'package:glimpse/features/ask/ask_provider.dart';

SavedUrl save(int id) => SavedUrl()
  ..id = id
  ..rawUrl = 'https://example.com/$id'
  ..domain = 'example.com'
  ..title = 'Save $id'
  ..description = ''
  ..summary = ''
  ..category = 'Science'
  ..categoryEmoji = ''
  ..categories = ['Science']
  ..tags = []
  ..savedAt = DateTime(2026, 9, 24);

void main() {
  test('curated recall cases meet the 90 percent candidate recall gate', () {
    final cases =
        (jsonDecode(
                  File(
                    'test/fixtures/ask_quality_cases.json',
                  ).readAsStringSync(),
                )
                as List)
            .cast<Map<String, dynamic>>();
    final targets = [
      for (var i = 0; i < cases.length; i++)
        save(i + 1)..summary = cases[i]['evidence'] as String,
    ];
    final distractors = List.generate(
      400,
      (i) => save(i + 100)
        ..summary =
            'A practical guide to design, cooking, travel, learning and reading.',
    );
    final library = [...distractors, ...targets];
    final index = AskPassageIndex()..refresh(library, []);
    var found = 0;
    for (var i = 0; i < cases.length; i++) {
      if (index
          .search(cases[i]['question'] as String, library)
          .any((s) => s.id == i + 1)) {
        found++;
      }
    }
    expect(found / cases.length, greaterThanOrEqualTo(.9));
  });

  test('warm metadata and passage retrieval benchmark at 400 and 5000 saves', () {
    for (final size in [400, 5000]) {
      final saves = List.generate(
        size,
        (i) => save(i + 1)
          ..summary =
              'A saved article about topic $i and its practical applications.',
      );
      final library = AskLibrarySnapshot(saves, []);
      final index = AskPassageIndex()..refresh(saves, []);
      final timer = Stopwatch()..start();
      expect(
        library.exactCountMatches('how many links do I have?')!.length,
        size,
      );
      final countMs = timer.elapsedMilliseconds;
      timer.reset();
      index.search('topic 4999', saves);
      // Host VM measurements are diagnostic, not Android release evidence.
      // ignore: avoid_print
      print(
        'Ask host benchmark: saves=$size countMs=$countMs retrievalMs=${timer.elapsedMilliseconds}',
      );
    }
  });

  test('referenced follow-ups support natural deepening across locales', () {
    final source = save(1);
    final response = GeminiService().parseChatResponseForTesting(jsonEncode({
      'intro':'Evidence [1]', 'sections':[], 'confidence':'high',
      'followUps':[
        {'question':'What would that look like in practice?', 'sourceIndices':[1]},
        {'question':'なぜですか？', 'sourceIndices':[1]},
        {'question':'Unsupported subject?', 'sourceIndices':[99]},
      ],
    }), [source]);
    expect(response.followUpsHaveReferences, isTrue);
    expect(response.followUpSuggestions, hasLength(2));
    final accepted = AskSuggestionGuard.filter(candidates: response.followUpSuggestions,
      evidence: [source], previousMessages: [], currentQuestion: 'Explain this', referencesValidated: true);
    expect(accepted, hasLength(2));
  });

  test('input-budget clipping preserves Unicode and stays within estimate', () {
    final text = 'A multilingual note 日本語 🌱 ' * 2000;
    final clipped = AskInputBudget.clip(text, 1200);
    expect(AskInputBudget.estimate(clipped), lessThanOrEqualTo(1200));
    expect(text.startsWith(clipped), isTrue);
  });

  test('437 saves are counted independently of the evidence window', () {
    final saves = List.generate(437, save);
    saves.first.intentStatus = 'done';
    final bin = save(1000)..deletedAt = DateTime(2026);
    final library = AskLibrarySnapshot([...saves, bin], []);
    expect(
      library.exactCountMatches('how many links do we have?')!.length,
      437,
    );
    expect(library.toJson()['totalSavedLinks'], 437);
    expect(
      library.exactCountMatches('how many archived links do I have?')!.length,
      1,
    );
    expect(
      library.exactCountMatches('how many links about quantum gravity?'),
      isNull,
    );
  });

  test('metadata predicates are exact, with local calendar boundaries', () {
    final saves = [save(1), save(2)..savedAt = DateTime(2026, 8, 10)];
    final collection = UserCollection()
      ..id = 1
      ..name = 'Reading'
      ..emoji = ''
      ..createdAt = DateTime(2026)
      ..urlIds = [2, 999];
    final library = AskLibrarySnapshot(saves, [collection]);
    expect(
      library.exactCountMatches('how many links in Reading?')!.map((s) => s.id),
      [2],
    );
    expect(
      library
          .exactCountMatches(
            'how many links today?',
            now: DateTime(2026, 9, 24),
          )!
          .map((s) => s.id),
      [1],
    );
    expect(
      library.exactCountMatches('how many links from missing.com?'),
      isNull,
    );
  });

  test(
    'finds deep reader evidence and refreshes changed notes and removals',
    () {
      final target = save(1)
        ..enrichmentJson = jsonEncode({
          'sections': [
            {'text': 'A long unrelated introduction. ' * 300},
            {'text': 'The unusual ingredient is saffron.'},
          ],
        });
      final index = AskPassageIndex()..refresh([target], []);
      expect(index.search('saffron', [target]).single.id, 1);
      expect(index.passages('saffron', 1).first.text, contains('saffron'));
      target.userNotes = 'Bring the telescope';
      index.refresh([target], []);
      expect(index.search('telescope', [target]).single.id, 1);
      index.refresh([], []);
      expect(index.search('saffron', [target]), isEmpty);
    },
  );

  test('stream decoder tolerates every chunk boundary and escaped Unicode', () {
    const text = 'A quote: "hello"\nA path: \\home. 🌱';
    final raw = jsonEncode({'intro': text, 'sections': []});
    for (var length = 0; length <= raw.length; length++) {
      final prefix = AskStreamDecoder.answerPrefix(raw.substring(0, length));
      expect(text.startsWith(prefix), isTrue, reason: 'boundary $length');
    }
    expect(AskStreamDecoder.answerPrefix(raw), text);
    expect(AskStreamDecoder.answerPrefix('{"intro":"\\uD83C'), '');
  });

  test('why and ordinal follow-ups retain the intended live evidence', () {
    final sources = [save(1), save(2)];
    final history = [
      ChatMessage(text: 'These two', isUser: false, sources: sources),
    ];
    expect(
      AskConversationPlanner.plan(
        question: 'why?',
        allUrls: sources,
        previousMessages: history,
      ).contextUrls.map((s) => s.id),
      [1, 2],
    );
    expect(
      AskConversationPlanner.plan(
        question: 'the second one',
        allUrls: sources,
        previousMessages: history,
      ).contextUrls.single.id,
      2,
    );
    expect(
      AskConversationPlanner.plan(
        question: 'why?',
        allUrls: [],
        previousMessages: history,
      ).contextUrls,
      isEmpty,
    );
  });

  test('invalid model citations cannot create source references', () {
    final answer = GeminiService().parseChatResponseForTesting(
      jsonEncode({'intro': 'Evidence [1]. Unsupported [99].', 'sections': []}),
      [save(1)],
    );
    expect(answer.intro, isNot(contains('[99]')));
    expect(answer.sections.single.sourceIndex, 1);
  });

  test(
    'query plans discard malformed fields without executing instructions',
    () {
      final plan = AskQueryPlan.fromJson({
        'query': 42,
        'domain': [],
        'after': 'yesterday',
      }, 'original');
      expect(plan.query, 'original');
      expect(plan.domain, isNull);
      expect(plan.after, isNull);
    },
  );
}
