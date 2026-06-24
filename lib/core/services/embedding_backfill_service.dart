import 'dart:developer' as developer;

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import 'embedding_input.dart';
import 'embedding_service.dart';
import 'memory_intent_resolver.dart';

/// Fills missing Voyage embeddings for URLs saved before embedding existed.
class EmbeddingBackfillService {
  EmbeddingBackfillService({
    required IsarService isarService,
    required EmbeddingService embeddingService,
  }) : _isar = isarService,
       _voyage = embeddingService;

  final IsarService _isar;
  final EmbeddingService _voyage;

  /// Returns how many URLs received a non-empty embedding (0 if none / skipped).
  Future<int> backfillIfNeeded() async {
    final unembedded = await _isar.getUrlsWithoutEmbedding();
    if (unembedded.isEmpty) return 0;

    developer.log(
      'Embedding backfill: ${unembedded.length} URL(s) without embeddings',
      name: 'EmbeddingBackfill',
    );

    const batchSize = 8;
    var successCount = 0;

    for (var i = 0; i < unembedded.length; i += batchSize) {
      final batch = unembedded.skip(i).take(batchSize).toList();
      final ok = await _embedBatch(batch);
      successCount += ok;

      if (i + batchSize < unembedded.length) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }

    developer.log(
      'Embedding backfill finished ($successCount vector(s) written)',
      name: 'EmbeddingBackfill',
    );
    return successCount;
  }

  Future<int> _embedBatch(List<SavedUrl> urls) async {
    final texts = urls.map(_buildEmbedText).toList();
    try {
      final embeddings = await _voyage.generateEmbeddingsBatch(texts);
      var wrote = 0;
      for (var j = 0; j < urls.length; j++) {
        final vec = j < embeddings.length ? embeddings[j] : <double>[];
        if (vec.isEmpty) continue;
        await _isar.updateEmbedding(id: urls[j].id, embedding: vec);
        wrote++;
      }
      return wrote;
    } catch (e, st) {
      developer.log(
        'Embedding backfill batch failed: $e',
        name: 'EmbeddingBackfill',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }

  String _buildEmbedText(SavedUrl url) {
    return buildBookmarkEmbeddingInput(
      title: url.title,
      description: url.description,
      tags: url.tags,
      category: url.category,
      summary: url.summary,
      memoryIntentText: MemoryIntentResolver.searchableText(url),
    );
  }
}
