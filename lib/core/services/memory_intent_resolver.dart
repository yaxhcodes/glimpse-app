import 'dart:convert';

import '../models/saved_url.dart';
import 'transcript_enrichment_service.dart';

class MemoryIntentResolver {
  const MemoryIntentResolver._();

  static MemoryIntentMetadata? fromUrl(SavedUrl url) {
    final raw = url.enrichmentJson;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return MemoryIntentMetadata.fromJsonOrNull(
        decoded['memory_intent'] ?? decoded,
      );
    } catch (_) {
      return null;
    }
  }

  static String searchableText(SavedUrl url) {
    final intent = fromUrl(url);
    if (intent == null) return '';
    return [
      intent.primaryIntent,
      ...intent.secondaryIntents,
      intent.lifeArea,
      intent.whySavedHypothesis,
      intent.actionability,
      intent.timeHorizon,
      intent.effortLevel,
      intent.costLevel,
      intent.difficulty,
      intent.skillLevel,
      intent.location,
      intent.timeRequired,
      intent.freshnessSensitivity,
    ].whereType<String>().where((item) => item.trim().isNotEmpty).join(' ');
  }
}
