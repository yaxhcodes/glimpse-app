import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/service_providers.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/services/ai/ai_transport.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/transcript_enrichment_service.dart';
import '../home/home_provider.dart';
import 'library_entity.dart';

const libraryHiddenEntityKeysPrefsKey = 'glimpse_library_hidden_entity_keys';

class LibraryPreferencesState {
  const LibraryPreferencesState({this.hiddenEntityKeys = const {}});

  final Set<String> hiddenEntityKeys;

  LibraryPreferencesState copyWith({Set<String>? hiddenEntityKeys}) {
    return LibraryPreferencesState(
      hiddenEntityKeys: hiddenEntityKeys ?? this.hiddenEntityKeys,
    );
  }
}

class LibraryPreferencesNotifier
    extends StateNotifier<LibraryPreferencesState> {
  LibraryPreferencesNotifier() : super(const LibraryPreferencesState()) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList(libraryHiddenEntityKeysPrefsKey) ?? [];
    state = LibraryPreferencesState(hiddenEntityKeys: Set.unmodifiable(hidden));
  }

  Future<void> hide(String key, {String? provisionalKey}) async {
    final updated = {
      ...state.hiddenEntityKeys,
      key,
      if (provisionalKey != null && provisionalKey.isNotEmpty) provisionalKey,
    };
    state = state.copyWith(hiddenEntityKeys: Set.unmodifiable(updated));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      libraryHiddenEntityKeysPrefsKey,
      updated.toList(growable: false)..sort(),
    );
  }

  Future<void> unhide(String key, {String? provisionalKey}) async {
    final updated = {...state.hiddenEntityKeys}
      ..remove(key)
      ..remove(provisionalKey);
    state = state.copyWith(hiddenEntityKeys: Set.unmodifiable(updated));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      libraryHiddenEntityKeysPrefsKey,
      updated.toList(growable: false)..sort(),
    );
  }
}

final libraryPreferencesProvider =
    StateNotifierProvider<LibraryPreferencesNotifier, LibraryPreferencesState>(
      (ref) => LibraryPreferencesNotifier(),
    );

final _libraryIndexCacheProvider = Provider<LibraryIndexCache>(
  (ref) => LibraryIndexCache(),
);

final librarySnapshotProvider = Provider<AsyncValue<LibrarySnapshot>>((ref) {
  final hidden = ref.watch(
    libraryPreferencesProvider.select((state) => state.hiddenEntityKeys),
  );
  final cache = ref.watch(_libraryIndexCacheProvider);
  return ref
      .watch(urlStreamProvider)
      .whenData((urls) => cache.build(urls, hiddenKeys: hidden));
});

Future<LibrarySnapshot> loadLibrarySnapshot(WidgetRef ref) async {
  final current = ref.read(librarySnapshotProvider).valueOrNull;
  if (current != null) return current;
  final urls = await ref.read(urlStreamProvider.future);
  final hidden = ref.read(libraryPreferencesProvider).hiddenEntityKeys;
  return ref.read(_libraryIndexCacheProvider).build(urls, hiddenKeys: hidden);
}

class LibraryEntityActions {
  const LibraryEntityActions(this._ref);

  final Ref _ref;

  Future<void> setStatus(LibraryEntity entity, LibraryItemStatus status) async {
    await _updateMentions(
      entity,
      (mention) => mention.copyWith(libraryStatus: status.name),
    );
  }

  Future<void> setReadingPage(LibraryEntity entity, int page) async {
    if (entity.kind != LibraryEntityKind.book ||
        entity.status != LibraryItemStatus.active) {
      throw StateError('Reading progress requires an active book');
    }
    if (page < 1) throw RangeError.range(page, 1, null, 'page');
    await _updateMentions(
      entity,
      (mention) => mention.copyWith(currentPage: page),
    );
  }

  Future<void> _updateMentions(
    LibraryEntity entity,
    EnrichedMention Function(EnrichedMention mention) update,
  ) async {
    final isar = _ref.read(isarServiceProvider);
    var updatedSources = 0;
    for (final source in entity.sources) {
      var sourceUpdated = false;
      await isar.mutateUrl(source.urlId, (url) {
        final raw = url.enrichmentJson;
        if (raw == null || raw.trim().isEmpty) return;
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          throw const FormatException('Invalid Library enrichment payload');
        }
        final data = Map<String, dynamic>.from(decoded);
        final parsed = TranscriptEnrichmentResult.fromJson(data);
        if (parsed == null) {
          throw const FormatException('Unreadable Library enrichment payload');
        }
        final updated = <EnrichedMention>[];
        for (final mention in parsed.mentions) {
          final kind = LibraryIndex.kindForMention(mention);
          final matches =
              kind == entity.kind &&
              LibraryIndex.provisionalKeyFor(kind!, mention) ==
                  source.provisionalKey;
          updated.add(matches ? update(mention) : mention);
          sourceUpdated = sourceUpdated || matches;
        }
        if (!sourceUpdated) return;
        data['schema_version'] = 3;
        data['mentions'] = updated
            .map((mention) => mention.toJson())
            .toList(growable: false);
        url.enrichmentJson = jsonEncode(data);
      });
      if (sourceUpdated) updatedSources++;
    }
    if (updatedSources == 0) {
      throw StateError('No source mention matched this Library item');
    }
  }
}

final libraryEntityActionsProvider = Provider<LibraryEntityActions>(
  LibraryEntityActions.new,
);

class LibraryBackfillState {
  const LibraryBackfillState({
    this.isRunning = false,
    this.completed = 0,
    this.total = 0,
    this.failed = 0,
    this.lastError,
    this.issue,
  });

  final bool isRunning;
  final int completed;
  final int total;
  final int failed;
  final String? lastError;
  final LibraryBackfillIssue? issue;

  double get progress => total == 0 ? 0 : completed / total;

  bool get canRetry =>
      !isRunning &&
      failed > 0 &&
      (issue == LibraryBackfillIssue.connection ||
          issue == LibraryBackfillIssue.partial);
}

enum LibraryBackfillIssue { serviceUnavailable, connection, partial }

class LibraryBackfillNotifier extends StateNotifier<LibraryBackfillState> {
  LibraryBackfillNotifier(this._ref) : super(const LibraryBackfillState());

  static const _batchSize = 20;

  final Ref _ref;
  final Set<String> _resolvedOrAttempted = {};
  final Map<String, int> _attempts = {};

  Future<void> start(Iterable<LibraryEntity> entities) async {
    if (state.isRunning) return;
    final pending = entities
        .where(
          (entity) =>
              entity.needsResolution &&
              !_resolvedOrAttempted.contains(entity.key),
        )
        .toList(growable: false);
    if (pending.isEmpty) return;

    _resolvedOrAttempted.addAll(pending.map((entity) => entity.key));
    for (final entity in pending) {
      _attempts.update(entity.key, (value) => value + 1, ifAbsent: () => 1);
    }
    state = LibraryBackfillState(isRunning: true, total: pending.length);
    var completed = 0;
    var failed = 0;
    String? lastError;
    LibraryBackfillIssue? issue;
    final transientFailures = <LibraryEntity>[];

    for (var offset = 0; offset < pending.length; offset += _batchSize) {
      final end = (offset + _batchSize).clamp(0, pending.length);
      final batch = pending.sublist(offset, end);
      try {
        final response = await AiTransport.instance.postLibraryEntities(
          entities: batch.map((entity) => entity.toResolverJson()).toList(),
        );
        final rawEntities = response['entities'];
        final resolvedByKey = <String, EnrichedMention>{};
        final errorsByKey = <String, String>{};
        if (rawEntities is List) {
          for (final raw in rawEntities) {
            if (raw is! Map) continue;
            final map = Map<String, dynamic>.from(raw);
            final clientKey = map['client_key']?.toString().trim() ?? '';
            if (clientKey.isEmpty) continue;
            if (map['resolved'] != true) {
              errorsByKey[clientKey] = map['error']?.toString() ?? '';
              continue;
            }
            resolvedByKey[clientKey] = EnrichedMention.fromJson({
              ...map,
              'type': map['kind'],
              'poster_url': map['artwork_url'] ?? map['poster_url'],
            });
          }
        }
        for (final entity in batch) {
          final resolved = resolvedByKey[entity.key];
          if (resolved == null) {
            final error = errorsByKey[entity.key] ?? '';
            if (error.isEmpty || _isTransient(error)) {
              failed++;
              issue = LibraryBackfillIssue.partial;
            } else {
              completed++;
            }
            if ((error.isEmpty || _isTransient(error)) &&
                (_attempts[entity.key] ?? 0) < 3) {
              transientFailures.add(entity);
            }
            continue;
          }
          await _persistResolvedEntity(entity, resolved);
          completed++;
        }
      } catch (error, stackTrace) {
        final permanentFailure = _isPermanentFailure(error);
        failed += permanentFailure
            ? pending.length - completed - failed
            : batch.length;
        lastError = error.toString();
        issue = permanentFailure
            ? LibraryBackfillIssue.serviceUnavailable
            : LibraryBackfillIssue.connection;
        developer.log(
          'Library catalog backfill failed',
          name: 'LibraryBackfill',
          error: error,
          stackTrace: stackTrace,
        );
        if (permanentFailure) {
          transientFailures.clear();
          break;
        }
        for (final entity in batch) {
          _resolvedOrAttempted.remove(entity.key);
          if ((_attempts[entity.key] ?? 0) < 3) {
            transientFailures.add(entity);
          }
        }
      }
      state = LibraryBackfillState(
        isRunning: true,
        completed: completed + failed,
        total: pending.length,
        failed: failed,
        lastError: lastError,
        issue: issue,
      );
    }

    state = LibraryBackfillState(
      completed: pending.length,
      total: pending.length,
      failed: failed,
      lastError: lastError,
      issue: issue,
    );
    unawaited(
      _ref
          .read(analyticsServiceProvider)
          .trackEvent(
            failed == 0
                ? AnalyticsEvent.libraryBackfillSucceeded
                : AnalyticsEvent.libraryBackfillFailed,
            screen: AnalyticsScreen.collections,
          ),
    );
    if (transientFailures.isNotEmpty) {
      final retryEntities = transientFailures.toSet().toList(growable: false);
      final attempt = retryEntities
          .map((entity) => _attempts[entity.key] ?? 1)
          .reduce((a, b) => a > b ? a : b);
      final delay = Duration(seconds: 1 << attempt.clamp(1, 3));
      unawaited(
        Future<void>.delayed(delay, () async {
          for (final entity in retryEntities) {
            _resolvedOrAttempted.remove(entity.key);
          }
          await start(retryEntities);
        }),
      );
    }
  }

  Future<void> retry(Iterable<LibraryEntity> entities) async {
    for (final entity in entities.where((entity) => entity.needsResolution)) {
      _resolvedOrAttempted.remove(entity.key);
      _attempts.remove(entity.key);
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await start(entities);
  }

  bool _isTransient(String? error) {
    return error == 'provider_unavailable' ||
        error == 'catalog_unavailable' ||
        error == 'upstream_unavailable';
  }

  bool _isPermanentFailure(Object error) {
    return error is AiTransportException && !error.isRetryable;
  }

  Future<void> _persistResolvedEntity(
    LibraryEntity entity,
    EnrichedMention resolved,
  ) async {
    final isar = _ref.read(isarServiceProvider);
    for (final source in entity.sources) {
      await isar.mutateUrl(source.urlId, (url) {
        final raw = url.enrichmentJson;
        if (raw == null || raw.trim().isEmpty) return;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) return;
          final data = Map<String, dynamic>.from(decoded);
          final parsed = TranscriptEnrichmentResult.fromJson(data);
          if (parsed == null) return;
          final updated = <EnrichedMention>[];
          for (final mention in parsed.mentions) {
            final kind = LibraryIndex.kindForMention(mention);
            if (kind != entity.kind ||
                LibraryIndex.provisionalKeyFor(kind!, mention) !=
                    source.provisionalKey) {
              updated.add(mention);
              continue;
            }
            updated.add(_mergeResolved(mention, resolved, entity.kind));
          }
          data['schema_version'] = 3;
          data['mentions'] = updated
              .map((mention) => mention.toJson())
              .toList();
          url.enrichmentJson = jsonEncode(data);
        } on FormatException {
          return;
        }
      });
    }
  }

  EnrichedMention _mergeResolved(
    EnrichedMention original,
    EnrichedMention resolved,
    LibraryEntityKind kind,
  ) {
    final resolvedGenres = {...resolved.rawGenres, ...resolved.genres};
    final rawGenres =
        kind == LibraryEntityKind.movie && resolvedGenres.isNotEmpty
        ? resolvedGenres
        : {...original.rawGenres, ...original.genres, ...resolvedGenres};
    String? prefer(String? resolvedValue, String? originalValue) {
      final resolvedText = resolvedValue?.trim() ?? '';
      if (resolvedText.isNotEmpty) return resolvedText;
      final originalText = originalValue?.trim() ?? '';
      return originalText.isEmpty ? null : originalText;
    }

    return EnrichedMention(
      title: prefer(resolved.title, original.title) ?? original.title,
      type: original.type,
      subtype: prefer(resolved.subtype, original.subtype),
      creator: prefer(resolved.creator, original.creator),
      year: prefer(resolved.year, original.year),
      whyMentioned: original.whyMentioned,
      posterUrl: prefer(resolved.posterUrl, original.posterUrl),
      genres: LibraryGenreNormalizer.normalize(kind, rawGenres),
      rawGenres: rawGenres.toList(growable: false),
      catalogId: prefer(resolved.catalogId, original.catalogId),
      catalogSource: prefer(resolved.catalogSource, original.catalogSource),
      city: prefer(resolved.city, original.city),
      country: prefer(resolved.country, original.country),
      latitude: resolved.latitude ?? original.latitude,
      longitude: resolved.longitude ?? original.longitude,
      matchConfidence: resolved.matchConfidence ?? original.matchConfidence,
      libraryStatus: original.libraryStatus,
      pageCount: resolved.pageCount ?? original.pageCount,
      currentPage: original.currentPage,
      plot: prefer(resolved.plot, original.plot),
      imdbRating: resolved.imdbRating ?? original.imdbRating,
    );
  }
}

final libraryBackfillProvider =
    StateNotifierProvider<LibraryBackfillNotifier, LibraryBackfillState>(
      (ref) => LibraryBackfillNotifier(ref),
    );
