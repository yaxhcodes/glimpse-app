import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/music_song.dart';
import '../../core/services/music_catalog_service.dart';
import '../../core/services/network_status_service.dart';
import '../../core/services/transcript_enrichment_service.dart';
import 'library_entity.dart';

const musicCatalogCacheKey = 'glimpse_music_catalog_v1';

class CachedMusicSong {
  const CachedMusicSong({required this.checkedAt, this.song});
  final DateTime checkedAt;
  final MusicCatalogSong? song;

  bool get isFresh =>
      DateTime.now().difference(checkedAt) <
      Duration(days: song?.artworkUrl == null ? 1 : 30);
}

class MusicLibraryState {
  const MusicLibraryState({
    this.entries = const {},
    this.isLoading = false,
    this.isChecking = false,
    this.hasFailure = false,
  });
  final Map<String, CachedMusicSong> entries;
  final bool isLoading;
  final bool isChecking;
  final bool hasFailure;

  LibrarySnapshot applyTo(LibrarySnapshot snapshot) => LibrarySnapshot(
    entities: [
      for (final entity in snapshot.entities)
        if (entity.kind != LibraryEntityKind.music)
          entity
        else if (entries[entity.key]?.song case final song?)
          LibraryEntity(
            key: entity.key,
            provisionalKey: entity.provisionalKey,
            kind: entity.kind,
            mention: EnrichedMention(
              title: song.title,
              type: 'music',
              creator: song.artist,
              posterUrl: song.artworkUrl ?? entity.artworkUrl,
              year: song.year ?? entity.mention.year,
              subtype: 'song',
              catalogId: song.id,
              catalogSource: 'musicbrainz',
              matchConfidence: 1,
              whyMentioned: entity.mention.whyMentioned,
            ),
            sources: entity.sources,
            discoveredAt: entity.discoveredAt,
          )
        else
          entity,
    ],
  );
}

class MusicLibraryNotifier extends StateNotifier<MusicLibraryState> {
  MusicLibraryNotifier(this._service, {NetworkStatusService? network})
    : _network = network ?? NetworkStatusService(),
      super(const MusicLibraryState(isLoading: true)) {
    _loadFuture = _load();
  }

  final MusicCatalogService _service;
  final NetworkStatusService _network;
  late final Future<void> _loadFuture;
  final Set<String> _attempted = {};
  List<LibraryEntity> _candidates = const [];
  Future<void>? _work;

  Future<void> _load() async {
    final entries = <String, CachedMusicSong>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(musicCatalogCacheKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          try {
            final data = entry.value as Map<String, dynamic>;
            entries[entry.key] = CachedMusicSong(
              checkedAt: DateTime.parse(data['checked_at'] as String),
              song: data['song'] == null
                  ? null
                  : MusicCatalogSong.fromJson(
                      data['song'] as Map<String, dynamic>,
                    ),
            );
          } catch (error, stackTrace) {
            developer.log(
              'Ignoring invalid music cache entry',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
      }
    } catch (error, stackTrace) {
      developer.log(
        'Could not restore music catalog cache',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (mounted) state = MusicLibraryState(entries: Map.unmodifiable(entries));
  }

  Future<void> synchronize(List<LibraryEntity> candidates) async {
    _candidates = candidates;
    await _loadFuture;
    if (!mounted) return;
    if (_work != null) return _work;
    _work = _resolvePending();
    try {
      await _work;
    } finally {
      _work = null;
      if (mounted && _candidates.any(_needsLookup)) {
        unawaited(synchronize(_candidates));
      }
    }
  }

  Future<void> retry() {
    _attempted.clear();
    return synchronize(_candidates);
  }

  Future<void> _resolvePending() async {
    if (!_candidates.any(_needsLookup)) return;
    state = MusicLibraryState(entries: state.entries, isChecking: true);
    var failed = false;
    try {
      if (await _network.isDefinitelyOffline()) {
        failed = true;
        _attempted.addAll(_candidates.map((entity) => entity.key));
        return;
      }
      while (mounted) {
        final pending = _candidates.where(_needsLookup);
        if (pending.isEmpty) break;
        final entity = pending.first;
        _attempted.add(entity.key);
        final query = MusicSongQuery.tryCreate(
          title: entity.title,
          artist: entity.mention.creator,
          type: entity.mention.subtype,
        );
        if (query == null) continue;
        try {
          final song = await _service.resolve(query);
          if (!mounted) return;
          final previous = state.entries[entity.key]?.song;
          final entries = {
            ...state.entries,
            entity.key: CachedMusicSong(
              checkedAt: DateTime.now(),
              song: song ?? previous,
            ),
          };
          state = MusicLibraryState(
            entries: Map.unmodifiable(entries),
            isChecking: true,
          );
        } catch (error, stackTrace) {
          failed = true;
          developer.log(
            'Could not load Library song details',
            error: error,
            stackTrace: stackTrace,
          );
          _attempted.addAll(_candidates.map((entity) => entity.key));
          break;
        }
      }
      if (mounted) await _save();
    } finally {
      if (mounted) {
        state = MusicLibraryState(entries: state.entries, hasFailure: failed);
      }
    }
  }

  bool _needsLookup(LibraryEntity entity) =>
      !_attempted.contains(entity.key) &&
      !(state.entries[entity.key]?.isFresh ?? false);

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        musicCatalogCacheKey,
        jsonEncode({
          for (final entry in state.entries.entries)
            entry.key: {
              'checked_at': entry.value.checkedAt.toIso8601String(),
              'song': entry.value.song?.toJson(),
            },
        }),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Could not cache song details',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

final musicCatalogServiceProvider = Provider<MusicCatalogService>((ref) {
  final service = MusicCatalogService();
  ref.onDispose(service.dispose);
  return service;
});

final musicLibraryProvider =
    StateNotifierProvider<MusicLibraryNotifier, MusicLibraryState>(
      (ref) => MusicLibraryNotifier(ref.watch(musicCatalogServiceProvider)),
    );
