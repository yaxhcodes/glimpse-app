import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/source_membership.dart';

void main() {
  SavedUrl url({
    String rawUrl = 'https://example.com/post',
    String domain = 'example.com',
    String title = 'Saved link',
    String description = '',
    String? summary,
    String category = 'X',
    List<String> categories = const ['X'],
    List<String> tags = const [],
  }) {
    return SavedUrl()
      ..rawUrl = rawUrl
      ..domain = domain
      ..title = title
      ..description = description
      ..summary = summary
      ..category = category
      ..categoryEmoji = ''
      ..categories = categories
      ..tags = tags
      ..savedAt = DateTime(2026, 6, 25);
  }

  test('includes inferred topic sources for older saves', () {
    final saved = url(
      title: 'Agentic AI research workflow',
      description: 'A practical LLM automation demo.',
      tags: const ['ai', 'llm', 'automation'],
    );

    expect(SourceMembership.categoriesFor(saved), contains('AI & ML'));
    expect(SourceMembership.contains(saved, 'AI & ML'), isTrue);
  });

  test(
    'includes app platform source from URL even when taxonomy rejects it',
    () {
      final saved = url(
        rawUrl: 'https://x.com/someone/status/123',
        domain: 'x.com',
        title: 'Research thread',
        tags: const ['social', 'twitter'],
      );

      expect(SourceMembership.categoriesFor(saved), contains('X'));
      expect(SourceMembership.contains(saved, 'X'), isTrue);
    },
  );
}
