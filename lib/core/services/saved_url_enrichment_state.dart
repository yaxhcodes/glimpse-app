import 'dart:convert';

import '../models/saved_url.dart';
import 'transcript_enrichment_service.dart';

abstract final class SavedUrlEnrichmentState {
  static final Expando<_AiEnrichmentCache> _cache = Expando();

  static bool hasAiEnrichment(SavedUrl url) {
    final raw = url.enrichmentJson?.trim() ?? '';
    if (raw.isEmpty) return false;
    final cached = _cache[url];
    if (cached?.payload == raw) return cached!.hasAiEnrichment;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final result = TranscriptEnrichmentResult.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      final hasAiEnrichment = result?.hasStructuredEnrichment ?? false;
      _cache[url] = _AiEnrichmentCache(raw, hasAiEnrichment);
      return hasAiEnrichment;
    } catch (_) {
      return false;
    }
  }

  static bool shouldOfferRetry(SavedUrl url, {required bool hasAiSaveAccess}) {
    return hasAiSaveAccess && !url.isProcessingActive && !hasAiEnrichment(url);
  }
}

class _AiEnrichmentCache {
  const _AiEnrichmentCache(this.payload, this.hasAiEnrichment);

  final String payload;
  final bool hasAiEnrichment;
}
