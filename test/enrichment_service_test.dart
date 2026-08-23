import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/enrichment_service.dart';
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
