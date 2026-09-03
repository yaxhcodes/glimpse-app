import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/music_song.dart';
import 'package:glimpse/core/services/music_catalog_service.dart';
import 'package:glimpse/core/services/network_status_service.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_provider.dart';
import 'package:glimpse/features/library/music_library_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'shows saved songs immediately and enriches them without changing source keys',
    () async {
      final gate = Completer<MusicCatalogSong?>();
      final service = _Catalog((_) => gate.future);
      final candidate = _entity('Bleed');
      final notifier = MusicLibraryNotifier(service, network: _Network(false));
      final container = ProviderContainer(
        overrides: [
          libraryCandidatesProvider.overrideWith(
            (ref) => AsyncValue.data(LibrarySnapshot(entities: [candidate])),
          ),
          musicLibraryProvider.overrideWith((ref) => notifier),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(librarySnapshotProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(
        container.read(librarySnapshotProvider).value!.entities.single,
        same(candidate),
      );
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.isChecking, isTrue);
      expect(
        container.read(librarySnapshotProvider).value!.entities.single,
        same(candidate),
      );
      gate.complete(_song);
      await notifier.synchronize([candidate]);
      final shown = container
          .read(librarySnapshotProvider)
          .value!
          .entities
          .single;
      expect(shown.title, 'Bleed');
      expect(shown.artworkUrl, _song.artworkUrl);
      expect(shown.key, candidate.key);
      expect(shown.sources, same(candidate.sources));
      expect(service.calls, 1);
    },
  );

  test('keeps uncached saved songs visible when offline', () async {
    final candidate = _entity('Bleed');
    final snapshot = LibrarySnapshot(entities: [candidate]);
    final service = _Catalog((_) => throw StateError('Must stay offline'));
    final notifier = MusicLibraryNotifier(service, network: _Network(true));
    addTearDown(notifier.dispose);
    await notifier.synchronize([candidate]);
    expect(notifier.state.hasFailure, isTrue);
    expect(notifier.state.applyTo(snapshot).entities.single, same(candidate));
    expect(service.calls, 0);
  });

  test(
    'a cached catalog miss does not hide a saved song after restart',
    () async {
      final candidate = _entity('Bleed');
      SharedPreferences.setMockInitialValues({
        musicCatalogCacheKey: jsonEncode({
          candidate.key: {
            'checked_at': DateTime.now().toIso8601String(),
            'song': null,
          },
        }),
      });
      final service = _Catalog((_) => throw StateError('Must use the cache'));
      final notifier = MusicLibraryNotifier(service, network: _Network(false));
      addTearDown(notifier.dispose);
      await notifier.synchronize([candidate]);
      expect(
        notifier.state
            .applyTo(LibrarySnapshot(entities: [candidate]))
            .entities
            .single,
        same(candidate),
      );
      expect(service.calls, 0);
    },
  );

  test('restores confirmed songs offline without querying again', () async {
    final candidate = _entity('Bleed');
    SharedPreferences.setMockInitialValues({
      musicCatalogCacheKey: jsonEncode({
        candidate.key: {
          'checked_at': DateTime.now().toIso8601String(),
          'song': _song.toJson(),
        },
      }),
    });
    final service = _Catalog((_) => throw StateError('Must use the cache'));
    final notifier = MusicLibraryNotifier(service, network: _Network(true));
    addTearDown(notifier.dispose);
    await notifier.synchronize([candidate]);
    expect(
      notifier.state
          .applyTo(LibrarySnapshot(entities: [candidate]))
          .entities
          .single
          .title,
      'Bleed',
    );
    expect(service.calls, 0);
    expect(
      notifier.state.applyTo(const LibrarySnapshot(entities: [])).entities,
      isEmpty,
    );
  });

  test(
    'caches no-match results but allows retry after connection failure',
    () async {
      var failing = true;
      final service = _Catalog((_) {
        if (failing) throw StateError('Offline');
        return null;
      });
      final notifier = MusicLibraryNotifier(service, network: _Network(false));
      addTearDown(notifier.dispose);
      final candidate = _entity('Bleed');
      final snapshot = LibrarySnapshot(entities: [candidate]);
      await notifier.synchronize([candidate]);
      expect(notifier.state.hasFailure, isTrue);
      expect(notifier.state.entries, isEmpty);
      expect(notifier.state.applyTo(snapshot).entities.single, same(candidate));
      failing = false;
      await notifier.retry();
      expect(notifier.state.hasFailure, isFalse);
      expect(notifier.state.entries[candidate.key]?.song, isNull);
      expect(notifier.state.applyTo(snapshot).entities.single, same(candidate));
      await notifier.synchronize([candidate]);
      expect(service.calls, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString(musicCatalogCacheKey)!),
        contains(candidate.key),
      );
    },
  );

  test('processes newly discovered songs while a lookup is running', () async {
    final gate = Completer<MusicCatalogSong?>();
    final service = _Catalog(
      (query) => query.title == 'Bleed' ? gate.future : null,
    );
    final notifier = MusicLibraryNotifier(service, network: _Network(false));
    addTearDown(notifier.dispose);
    final first = notifier.synchronize([_entity('Bleed')]);
    await Future<void>.delayed(Duration.zero);
    final second = notifier.synchronize([
      _entity('Bleed'),
      _entity('Visceral Rage'),
    ]);
    gate.complete(_song);
    await Future.wait([first, second]);
    expect(service.calls, 2);
    expect(notifier.state.entries, hasLength(2));
  });
}

const _song = MusicCatalogSong(
  id: 'b7adb9c7-9c55-4e73-a125-e8f2cf269612',
  title: 'Bleed',
  artist: 'Meshuggah',
  artworkUrl:
      'https://coverartarchive.org/release-group/bc3c02ea-5837-32ab-9c65-f60125458187/front-500',
);

LibraryEntity _entity(String title) {
  final mention = EnrichedMention(
    title: title,
    type: 'music',
    subtype: 'song',
    creator: 'Meshuggah',
  );
  return LibraryEntity(
    key: 'music:$title',
    provisionalKey: 'music:$title',
    kind: LibraryEntityKind.music,
    mention: mention,
    sources: [
      LibrarySourceReference(
        urlId: 1,
        title: 'A source save',
        domain: 'example.com',
        savedAt: DateTime(2026),
        provisionalKey: 'music:$title',
        mention: mention,
      ),
    ],
    discoveredAt: DateTime(2026),
  );
}

class _Network extends NetworkStatusService {
  _Network(this.offline);
  final bool offline;
  @override
  Future<bool> isDefinitelyOffline() async => offline;
}

class _Catalog implements MusicCatalogService {
  _Catalog(this.respond);
  final FutureOr<MusicCatalogSong?> Function(MusicSongQuery) respond;
  int calls = 0;
  @override
  Future<MusicCatalogSong?> resolve(MusicSongQuery query) async {
    calls++;
    return respond(query);
  }

  @override
  void dispose() {}
}
