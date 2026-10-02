import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import 'embedding_input.dart';
import 'embedding_service.dart';
import 'memory_intent_resolver.dart';

/// Fills missing Voyage embeddings for URLs saved before embedding existed.
///
/// A save the embedding service keeps rejecting used to be re-sent on every
/// launch, forever. Failures are now remembered per save and retried on a
/// widening schedule (1, 2, 4… days, at most 30), and forgotten once the
/// save embeds.
class EmbeddingBackfillService {
  EmbeddingBackfillService({
    required IsarService isarService,
    required EmbeddingService embeddingService,
    DateTime Function()? now,
  }) : _isar = isarService,
       _voyage = embeddingService,
       _now = now ?? DateTime.now;

  final IsarService _isar;
  final EmbeddingService _voyage;
  final DateTime Function() _now;

  static const _attemptsKey = 'embedding_backfill_attempts_v1';
  static const _maxBackoff = Duration(days: 30);

  /// Returns how many URLs received a non-empty embedding (0 if none / skipped).
  Future<int> backfillIfNeeded() async {
    final unembedded = await _isar.getUrlsWithoutEmbedding();
    if (unembedded.isEmpty) return 0;

    final prefs = await SharedPreferences.getInstance();
    final attempts = _readAttempts(prefs);
    final now = _now();
    final due = unembedded
        .where((url) => _isDue(attempts[url.id], now))
        .toList();

    developer.log(
      'Embedding backfill: ${unembedded.length} URL(s) without embeddings, '
      '${due.length} due',
      name: 'EmbeddingBackfill',
    );
    if (due.isEmpty) return 0;

    const batchSize = 8;
    var successCount = 0;

    for (var i = 0; i < due.length; i += batchSize) {
      final batch = due.skip(i).take(batchSize).toList();
      final embedded = await _embedBatch(batch);
      successCount += embedded.length;
      for (final url in batch) {
        if (embedded.contains(url.id)) {
          attempts.remove(url.id);
        } else {
          final previous = attempts[url.id];
          attempts[url.id] = _Attempt(
            count: (previous?.count ?? 0) + 1,
            at: now,
          );
        }
      }

      if (i + batchSize < due.length) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }

    // Forget saves that have embedded elsewhere or no longer exist.
    final stillMissing = unembedded.map((url) => url.id).toSet();
    attempts.removeWhere((id, _) => !stillMissing.contains(id));
    await _writeAttempts(prefs, attempts);

    developer.log(
      'Embedding backfill finished ($successCount vector(s) written)',
      name: 'EmbeddingBackfill',
    );
    return successCount;
  }

  /// Ids of the saves in [urls] that received a vector.
  Future<Set<int>> _embedBatch(List<SavedUrl> urls) async {
    final texts = urls.map(_buildEmbedText).toList();
    try {
      final embeddings = await _voyage.generateEmbeddingsBatch(texts);
      final wrote = <int>{};
      for (var j = 0; j < urls.length; j++) {
        final vec = j < embeddings.length ? embeddings[j] : <double>[];
        if (vec.isEmpty) continue;
        await _isar.updateEmbedding(id: urls[j].id, embedding: vec);
        wrote.add(urls[j].id);
      }
      return wrote;
    } catch (e, st) {
      developer.log(
        'Embedding backfill batch failed: $e',
        name: 'EmbeddingBackfill',
        error: e,
        stackTrace: st,
      );
      return const {};
    }
  }

  bool _isDue(_Attempt? attempt, DateTime now) {
    if (attempt == null) return true;
    final days = math.pow(2, attempt.count - 1).toInt();
    final wait = Duration(days: days) > _maxBackoff
        ? _maxBackoff
        : Duration(days: days);
    return !now.isBefore(attempt.at.add(wait));
  }

  Map<int, _Attempt> _readAttempts(SharedPreferences prefs) {
    final raw = prefs.getString(_attemptsKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          ?int.tryParse(entry.key): _Attempt.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAttempts(
    SharedPreferences prefs,
    Map<int, _Attempt> attempts,
  ) async {
    if (attempts.isEmpty) {
      await prefs.remove(_attemptsKey);
      return;
    }
    await prefs.setString(
      _attemptsKey,
      jsonEncode({
        for (final entry in attempts.entries)
          '${entry.key}': entry.value.toJson(),
      }),
    );
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

class _Attempt {
  const _Attempt({required this.count, required this.at});

  factory _Attempt.fromJson(Map<String, dynamic> json) => _Attempt(
    count: (json['n'] as num?)?.toInt() ?? 1,
    at: DateTime.fromMillisecondsSinceEpoch((json['at'] as num?)?.toInt() ?? 0),
  );

  final int count;
  final DateTime at;

  Map<String, Object> toJson() => {'n': count, 'at': at.millisecondsSinceEpoch};
}
