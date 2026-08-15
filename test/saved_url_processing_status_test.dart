import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/url_processing_status.dart';
import 'package:glimpse/core/services/saved_url_enrichment_state.dart';

SavedUrl _url({
  String? processingStatus,
  String? enrichmentJson,
  String? summary,
}) {
  return SavedUrl()
    ..rawUrl = 'https://www.instagram.com/reel/example'
    ..domain = 'instagram.com'
    ..title = 'Heart Health'
    ..description = ''
    ..category = 'Health'
    ..categoryEmoji = ''
    ..categories = ['Health']
    ..tags = ['health']
    ..savedAt = DateTime(2026, 7, 7)
    ..processingStatus = processingStatus
    ..enrichmentJson = enrichmentJson
    ..summary = summary;
}

void main() {
  group('SavedUrl processing state', () {
    test('partial save with presentable enrichment is ready, not failed', () {
      final url = _url(
        processingStatus: UrlProcessingStatus.partial,
        enrichmentJson: '{"summary":"Blood tests to discuss with a doctor"}',
      );

      expect(url.hasPresentableEnrichment, isTrue);
      expect(url.isProcessingReady, isTrue);
      expect(url.isProcessingFailed, isFalse);
    });

    test('partial save without presentable enrichment remains failed', () {
      final url = _url(processingStatus: UrlProcessingStatus.partial);

      expect(url.hasPresentableEnrichment, isFalse);
      expect(url.isProcessingReady, isTrue);
      expect(url.isProcessingFailed, isTrue);
    });
  });

  group('AI enrichment retry eligibility', () {
    test('offers retry for a terminal metadata-only save with allowance', () {
      final url = _url(
        processingStatus: UrlProcessingStatus.completed,
        summary: 'Saved Instagram post from an exhausted free allowance.',
      );

      expect(SavedUrlEnrichmentState.hasAiEnrichment(url), isFalse);
      expect(
        SavedUrlEnrichmentState.shouldOfferRetry(url, hasAiSaveAccess: true),
        isTrue,
      );
    });

    test('hides retry while no AI save allowance is available', () {
      final url = _url(processingStatus: UrlProcessingStatus.completed);

      expect(
        SavedUrlEnrichmentState.shouldOfferRetry(url, hasAiSaveAccess: false),
        isFalse,
      );
    });

    test('hides retry for active and genuinely AI-enriched saves', () {
      final active = _url(processingStatus: UrlProcessingStatus.enriching);
      final enriched = _url(
        processingStatus: UrlProcessingStatus.completed,
        enrichmentJson: '''
          {
            "meaningful_title": "Heart health markers",
            "summary": "A practical overview of heart health markers and the questions worth discussing with a doctor.",
            "category": "Health",
            "tags": ["heart health", "blood tests"],
            "key_points": ["Review the most useful markers"]
          }
        ''',
      );

      expect(
        SavedUrlEnrichmentState.shouldOfferRetry(active, hasAiSaveAccess: true),
        isFalse,
      );
      expect(SavedUrlEnrichmentState.hasAiEnrichment(enriched), isTrue);
      expect(
        SavedUrlEnrichmentState.shouldOfferRetry(
          enriched,
          hasAiSaveAccess: true,
        ),
        isFalse,
      );
    });
  });
}
