import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/url_processing_status.dart';

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
}
