import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/isar_service.dart';
import '../services/link_preview_service.dart';
import '../services/api_key_service.dart';
import '../services/embedding_service.dart';
import '../services/bundled_keys.dart';

/// Global provider for the Isar database service.
final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService();
});

/// Global provider for the link preview service.
final linkPreviewServiceProvider = Provider<LinkPreviewService>((ref) {
  return LinkPreviewService();
});

/// Global provider for the API key service (secure storage).
final apiKeyServiceProvider = Provider<ApiKeyService>((ref) {
  return ApiKeyService();
});

/// Voyage embedding API (null when no bundled key).
final embeddingServiceProvider = Provider<EmbeddingService?>((ref) {
  if (!BundledKeys.hasVoyage) return null;
  return EmbeddingService(BundledKeys.voyageKey);
});
