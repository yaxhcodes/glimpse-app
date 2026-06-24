import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/embedding_input.dart';

void main() {
  test('includes memory intent text in bookmark embedding input', () {
    final input = buildBookmarkEmbeddingInput(
      title: 'Riverpod provider patterns',
      description: 'A short article about state management.',
      tags: ['flutter'],
      category: 'Technology',
      summary: 'A practical guide to provider architecture.',
      memoryIntentText:
          'learn education The user may want to learn Flutter architecture.',
    );

    expect(input, contains('Riverpod provider patterns'));
    expect(input, contains('learn education'));
    expect(input, contains('Flutter architecture'));
  });
}
