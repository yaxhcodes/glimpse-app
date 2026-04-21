import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/isar_service.dart';
import '../services/bundled_keys.dart';
import '../services/embedding_service.dart';
import '../services/gemini_service.dart';
import '../services/link_preview_service.dart';

/// Global provider for the Isar database service.
final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService();
});

/// Global provider for the link preview service.
final linkPreviewServiceProvider = Provider<LinkPreviewService>((ref) {
  return LinkPreviewService();
});

/// Single shared Voyage embedding client.
///
/// Returns `null` when there is no Voyage key AND the AI proxy is not
/// enabled, so call sites can gracefully degrade to keyword paths.
final embeddingServiceProvider = Provider<EmbeddingService?>((ref) {
  if (!BundledKeys.hasVoyage) return null;
  return EmbeddingService(apiKey: BundledKeys.voyageKey);
});

/// Single shared Gemini client.
///
/// Returns `null` when Gemini is unavailable (no key AND no proxy),
/// so call sites can skip AI-only features without try/catching missing keys.
final geminiServiceProvider = Provider<GeminiService?>((ref) {
  if (!BundledKeys.hasGemini) return null;
  return GeminiService(BundledKeys.geminiKey);
});
