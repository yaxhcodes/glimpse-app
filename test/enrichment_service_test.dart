import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/enrichment_service.dart';
import 'package:glimpse/core/services/gemini_service.dart';
import 'package:glimpse/core/services/source_evidence.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/core/services/usage_service.dart';

void main() {
  test('successful media re-enrichment replaces provisional tags', () async {
    final database = _MemoryIsarService(
      SavedUrl()
        ..id = 1
        ..rawUrl = 'https://www.instagram.com/reel/example'
        ..domain = 'instagram.com'
        ..title = 'Brand strategy'
        ..description = 'A guide to building a thoughtful personal brand.'
        ..category = 'Web'
        ..categoryEmoji = '🌐'
        ..categories = const ['Web']
        ..tags = const ['example', 'old metadata tag']
        ..savedAt = DateTime(2026, 8, 23),
    );
    final service = EnrichmentService(
      isarService: database,
      transcriptEnrichmentService: _SuccessfulTranscriptEnrichmentService(),
      usageService: UsageService(),
      isPro: false,
    );

    await service.enrichSingle(1, forceAi: true, countAiUsage: false);

    expect(database.url.tags, const ['personal branding', 'career strategy']);
    expect(database.url.tags, isNot(contains('old metadata tag')));
  });

  test(
    'rich generic enrichment persists the schema v5 reader contract',
    () async {
      final database = _MemoryIsarService(
        SavedUrl()
          ..id = 2
          ..rawUrl = 'https://example.com/knowledge'
          ..domain = 'example.com'
          ..title = 'Knowledge systems'
          ..description = 'A guide to building a useful knowledge library.'
          ..category = 'Other'
          ..categoryEmoji = '📌'
          ..categories = const ['Other']
          ..tags = const []
          ..savedAt = DateTime(2026, 9, 4),
      );
      final service = EnrichmentService(
        isarService: database,
        geminiService: _SuccessfulGenericGeminiService(),
        usageService: UsageService(),
        isPro: false,
      );

      await service.enrichSingle(2, forceAi: true, countAiUsage: false);

      final stored = jsonDecode(database.url.enrichmentJson!);
      expect(stored['schema_version'], 5);
      expect(stored['notification_blurb'], contains('knowledge library'));
      expect(stored['content_sections'], hasLength(1));
      expect(stored['notable_items'].single['url'], 'https://example.org/tool');
    },
  );
}

class _SuccessfulGenericGeminiService extends GeminiService {
  _SuccessfulGenericGeminiService() : super('');

  @override
  Future<CategorizationResult> categorize({
    required String title,
    required String description,
    required String url,
    SourceEvidence? sourceEvidence,
  }) async {
    return const CategorizationResult(
      meaningfulTitle: 'A Useful Knowledge Library',
      category: 'Productivity',
      emoji: '⚡',
      tags: ['knowledge management', 'reading'],
      summary:
          'A practical guide to turning saved reading into a useful personal knowledge library.',
      brief: 'Build a calm system that keeps useful ideas easy to revisit.',
      notificationBlurb:
          'A practical guide to building a calm, useful personal knowledge library from saved reading.',
      keyPoints: ['Keep each save readable and easy to revisit.'],
      contentSections: [
        EnrichedContentSection(
          title: 'Design for retrieval',
          points: [
            'Present the useful explanation before raw source evidence.',
          ],
        ),
      ],
      notableItems: [
        EnrichedNotableItem(
          text: 'Example Tool',
          type: 'tool',
          destinationUrl: 'https://example.org/tool',
        ),
      ],
    );
  }
}

class _SuccessfulTranscriptEnrichmentService
    extends TranscriptEnrichmentService {
  @override
  Future<TranscriptEnrichmentResult?> enrichUrl({
    required String rawUrl,
    required String title,
    required String description,
    required String? thumbnailUrl,
    required String domain,
    String? saveId,
    String? processingId,
    int attempt = 1,
    bool forceRefresh = false,
    String outputLocale = 'en',
  }) async {
    return const TranscriptEnrichmentResult(
      meaningfulTitle: 'A Thoughtful Personal Brand',
      category: 'Career',
      tags: ['personal branding', 'career strategy'],
      summary:
          'A practical guide to developing a personal brand with clear positioning and consistent communication.',
      caption: 'A guide to developing a thoughtful personal brand.',
    );
  }
}

class _MemoryIsarService implements IsarService {
  _MemoryIsarService(this.url);

  SavedUrl url;

  @override
  Future<SavedUrl?> getUrlById(int id) async => id == url.id ? url : null;

  @override
  Future<void> updateUrl(SavedUrl updated) async {
    url = updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected database call: ${invocation.memberName}',
    );
  }
}
