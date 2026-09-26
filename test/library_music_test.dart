import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/music_provider.dart';
import 'package:glimpse/core/models/music_song.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/providers/music_provider_preference_provider.dart';
import 'package:glimpse/core/services/music_catalog_service.dart';
import 'package:glimpse/core/services/network_status_service.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/features/home/home_provider.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_entity_detail_screen.dart';
import 'package:glimpse/features/library/library_music_screen.dart';
import 'package:glimpse/features/library/library_provider.dart';
import 'package:glimpse/features/library/music_library_provider.dart';
import 'package:glimpse/shared/widgets/music_provider_icon.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('songs in any save', () {
    List<String> songsOf({
      String title = 'A save',
      String summary = '',
      List<String> steps = const [],
      List<Map<String, dynamic>> mentions = const [],
      List<Map<String, dynamic>> notable = const [],
    }) {
      final save = _saved(1, mentions: mentions, notable: notable);
      final data = jsonDecode(save.enrichmentJson!) as Map<String, dynamic>;
      save.enrichmentJson = jsonEncode({
        ...data,
        'meaningful_title': title,
        'summary': summary,
        'steps': [
          for (final step in steps) {'title': step},
        ],
      });
      return [
        for (final entity in LibraryIndex.build([
          save,
        ]).ofKind(LibraryEntityKind.music))
          if (!LibraryIndex.isArtistMention(entity.mention))
            '${entity.title} / ${entity.mention.creator}',
      ];
    }

    test('takeaways that open with a song by an artist', () {
      expect(
        songsOf(
          summary: 'Three rainy-day tracks to put on repeat.',
          steps: [
            'Holocene by Bon Iver sets a quiet mood.',
            'Motion Picture Soundtrack by Radiohead closes the list.',
            'Bloodbuzz Ohio by The National adds some drive.',
          ],
        ),
        [
          'Holocene / Bon Iver',
          'Motion Picture Soundtrack / Radiohead',
          'Bloodbuzz Ohio / The National',
        ],
      );
    });

    test('songs from albums in a save about one artist', () {
      expect(
        songsOf(
          title: 'Fleetwood Mac · Deep Cuts',
          summary: 'Five songs worth hearing beyond the hits.',
          steps: [
            'Dreams from Rumours is the obvious start.',
            'Sara from Tusk rewards a slow listen.',
          ],
          mentions: [
            {
              'title': 'Fleetwood Mac',
              'type': 'music',
              'why_mentioned': 'The band the list is about.',
            },
          ],
        ),
        ['Dreams / Fleetwood Mac', 'Sara / Fleetwood Mac'],
      );
    });

    test('a note that names the song makes the mention its artist', () {
      expect(
        songsOf(
          mentions: [
            {
              'title': 'Kendrick Lamar',
              'type': 'music',
              'why_mentioned': 'His song Alright became a protest anthem.',
            },
          ],
        ),
        ['Alright / Kendrick Lamar'],
      );
    });

    test('a tagged song pairs with the only artist in the save', () {
      expect(
        songsOf(
          mentions: [
            {
              'title': 'Hozier',
              'type': 'music',
              'why_mentioned': 'The singer who wrote and performed it.',
            },
          ],
          notable: [
            {'text': 'Cherry Wine', 'type': 'other', 'label': 'Song title'},
          ],
        ),
        ['Cherry Wine / Hozier'],
      );
    });

    test('books and films written "X by Y" do not become songs', () {
      expect(
        songsOf(
          title: 'Reading list · Habits',
          summary: 'Two books that changed how I work.',
          steps: [
            'Atomic Habits by James Clear is the practical one.',
            'Deep Work by Cal Newport covers focus.',
          ],
          mentions: [
            {'title': 'Atomic Habits', 'type': 'book'},
          ],
        ),
        isEmpty,
      );
      expect(
        songsOf(
          summary: 'How a landmark anime changed pop culture and music.',
          steps: ['Created by Katsuhiro Otomo with 70 artists.'],
          mentions: [
            {'title': 'Akira', 'type': 'movie'},
          ],
        ),
        isEmpty,
      );
    });

    test('a music save still ignores a book it names', () {
      expect(
        songsOf(
          summary: 'Songs and one book for the road.',
          steps: [
            'Night Drive by Chromatics sets the tone.',
            'On the Road by Jack Kerouac is the book to bring.',
          ],
          mentions: [
            {'title': 'On the Road', 'type': 'book'},
          ],
        ),
        ['Night Drive / Chromatics'],
      );
    });
  });

  test('a saved Spotify track is a song with its album art', () {
    final save = _saved(1)
      ..rawUrl = 'https://open.spotify.com/track/2a1iMaoWQ5MnvLFBDv4qkf'
      ..domain = 'open.spotify.com'
      ..title = 'Sparkle by RADWIMPS from Your Name'
      ..thumbnailUrl = 'https://i.scdn.co/image/sparkle';
    final music = LibraryIndex.build([
      save,
    ]).ofKind(LibraryEntityKind.music);

    expect(music, hasLength(1));
    expect(music.single.title, 'Sparkle');
    expect(music.single.mention.creator, 'RADWIMPS');
    expect(music.single.artworkUrl, 'https://i.scdn.co/image/sparkle');
  });

  test('a saved track and the same song in its enrichment stay one item', () {
    final save =
        _saved(
            1,
            notable: [_track('High and Dry', 'Radiohead')],
            mentions: [
              {
                'title': 'High and Dry',
                'type': 'music',
                'subtype': 'song',
                'creator': 'Radiohead',
              },
            ],
          )
          ..rawUrl = 'https://open.spotify.com/track/abc'
          ..title = 'High and Dry by Radiohead';

    expect(
      LibraryIndex.build([save]).ofKind(LibraryEntityKind.music),
      hasLength(1),
    );
  });

  test('artists whose song the save names become that song', () {
    final save = _saved(
      1,
      mentions: [
        for (final (artist, song) in [
          ('The Cutting Crew', 'I Just Died In Your Arms Tonight'),
          ('Whitesnake', 'Is This Love'),
          ('Billy Idol', 'Eyes Without a Face'),
        ])
          {
            'title': artist,
            'type': 'music',
            'why_mentioned': 'Artist of the song $song.',
          },
      ],
    );
    final music = LibraryIndex.build([save]).ofKind(LibraryEntityKind.music);

    expect(
      music.map((entity) => '${entity.title} / ${entity.mention.creator}'),
      [
        'I Just Died In Your Arms Tonight / The Cutting Crew',
        'Is This Love / Whitesnake',
        'Eyes Without a Face / Billy Idol',
      ],
    );
    expect(
      music.any((entity) => LibraryIndex.isArtistMention(entity.mention)),
      isFalse,
    );
  });

  test('a creator-less track and its artist pair into one song', () {
    final save = _saved(
      1,
      mentions: [
        {
          'title': 'Teal Peel',
          'type': 'music',
          'why_mentioned':
              'The creator identifies them as the artist behind the song.',
        },
        {
          'title': 'How Many Bugs',
          'type': 'music',
          'why_mentioned': 'The specific track recommended by the creator.',
        },
      ],
    )..title = 'Put on headphones for this one';
    final music = LibraryIndex.build([save]).ofKind(LibraryEntityKind.music);

    expect(music, hasLength(1));
    expect(music.single.title, 'How Many Bugs');
    expect(music.single.mention.creator, 'Teal Peel');
  });

  test('a quoted song in the summary is a song; its people stay artists', () {
    final save = _saved(
      1,
      mentions: [
        {
          'title': 'Matthew Thiessen',
          'type': 'music',
          'why_mentioned': 'Featured as a vocalist on the track.',
        },
      ],
    );
    final data = jsonDecode(save.enrichmentJson!) as Map<String, dynamic>;
    save.enrichmentJson = jsonEncode({
      ...data,
      'summary': 'The 2009 synth-pop hit "Fireflies" by the project Owl City.',
    });
    final music = LibraryIndex.build([save]).ofKind(LibraryEntityKind.music);

    final byTitle = {for (final entity in music) entity.title: entity};
    expect(byTitle.keys, unorderedEquals(['Fireflies', 'Matthew Thiessen']));
    expect(byTitle['Fireflies']!.mention.creator, 'Owl City');
    expect(
      LibraryIndex.isArtistMention(byTitle['Matthew Thiessen']!.mention),
      isTrue,
    );
  });

  test('a song named in the takeaways takes its artist from them', () {
    final pairs = LibraryIndex.pairMusicMentions(
      [
        EnrichedMention(title: 'Hysteria', type: 'music'),
        EnrichedMention(
          title: 'Def Leppard',
          type: 'music',
          whyMentioned: 'The band behind it.',
        ),
      ],
      context: ['Hysteria by Def Leppard is recommended for its guitar riffs.'],
    );

    expect(pairs.first?.creator, 'Def Leppard');
    expect(pairs.last, isNull);
  });

  test('artists a reel mentions join the library, grouped across saves', () {
    final snapshot = LibraryIndex.build([
      _saved(
        1,
        mentions: [
          {'title': 'Pink Floyd', 'type': 'music'},
          {'title': 'David Gilmour', 'type': 'music', 'subtype': 'musician'},
        ],
      ),
      _saved(
        2,
        mentions: [
          {'title': 'Pink Floyd', 'type': 'music'},
        ],
      ),
    ]);
    final music = snapshot.ofKind(LibraryEntityKind.music);

    expect(music.map((entity) => entity.title), [
      'Pink Floyd',
      'David Gilmour',
    ]);
    expect(music.first.sources, hasLength(2));
    expect(music.every((e) => LibraryIndex.isArtistMention(e.mention)), isTrue);
  });

  test('keeps the artist, drops the website and song-labelled quote', () {
    final snapshot = LibraryIndex.build([
      _saved(
        1,
        mentions: [
          {'title': 'Rick Astley', 'type': 'artist'},
        ],
        notable: [
          {
            'text': 'everynoiseatonce.com',
            'type': 'website',
            'label': 'Music discovery',
          },
          {
            'text':
                "The song told you what you most want is what you most can't have.",
            'type': 'quote',
            'label': 'Song',
            'attribution': 'Odysseus',
          },
          _track('Bleed', 'Meshuggah'),
          _track('From the Sky', 'Gojira'),
        ],
      ),
    ]);
    expect(snapshot.entities.map((entity) => entity.title), [
      'Rick Astley',
      'Bleed',
      'From the Sky',
    ]);
    expect(LibraryIndex.isArtistMention(snapshot.entities.first.mention), true);
  });

  test('uses exact song labels only for otherwise untyped notable items', () {
    final snapshot = LibraryIndex.build([
      _saved(
        1,
        notable: [
          {..._track('Bleed', 'Meshuggah'), 'type': 'song', 'label': null},
          {..._track('From the Sky', 'Gojira'), 'type': 'reference'},
          {..._track('Teardrop', 'Massive Attack'), 'label': ' Chanson '},
          {..._track('The Siren’s Song', 'Odysseus'), 'type': 'quote'},
          {..._track('Rick Astley', 'Rick Astley'), 'type': 'artist'},
          {..._track('obZen', 'Meshuggah'), 'label': 'Album'},
          {..._track('Music discovery', 'Someone'), 'label': 'Music tool'},
          {..._track('Unknown', ''), 'label': 'Song'},
        ],
      ),
    ]);
    expect(snapshot.entities.map((entity) => entity.title), [
      'Bleed',
      'From the Sky',
      'Teardrop',
    ]);
    expect(
      snapshot.entities.every((entity) => entity.mention.subtype == 'song'),
      isTrue,
    );
  });

  test('indexes music mentions and notable items with shared provenance', () {
    final snapshot = LibraryIndex.build([
      _saved(1, notable: [_track('Teardrop', 'Massive Attack')]),
      _saved(
        2,
        mentions: [
          {
            'title': 'Teardrop',
            'type': 'music',
            'creator': 'Massive Attack',
            'subtype': 'track',
          },
        ],
      ),
    ]);
    final entity = snapshot.entities.single;
    expect(entity.kind, LibraryEntityKind.music);
    expect(entity.sources.map((source) => source.urlId), [2, 1]);
    expect(entity.mention.creator, 'Massive Attack');
    expect(entity.needsResolution, isFalse);
    expect(entity.genres, isEmpty);
    expect(
      LibraryIndex.build(
        [
          _saved(1, notable: [_track('Teardrop', 'Massive Attack')]),
        ],
        hiddenKeys: {entity.key},
      ).entities,
      isEmpty,
    );
  });

  test('keeps different song artists distinct and excludes albums', () {
    final snapshot = LibraryIndex.build([
      _saved(1, notable: [_track('Home', 'Artist One')]),
      _saved(2, notable: [_track('Home', 'Artist Two')]),
      _saved(
        3,
        notable: [
          {..._track('Home', 'Artist One'), 'type': 'album'},
        ],
      ),
    ]);
    expect(snapshot.entities, hasLength(2));
  });

  test('preserves non-Latin music titles and artist identities', () {
    final snapshot = LibraryIndex.build([
      _saved(1, notable: [_track('夜に駆ける', 'YOASOBI')]),
      _saved(2, notable: [_track('群青', 'YOASOBI')]),
      _saved(3, notable: [_track('夜に駆ける', '別の歌手')]),
    ]);
    expect(snapshot.entities, hasLength(3));
    expect(snapshot.entities.map((entity) => entity.title), contains('群青'));
  });

  test('refreshes music when its source is edited or deleted', () {
    final cache = LibraryIndexCache();
    final saved = _saved(1, notable: [_track('Teardrop', 'Massive Attack')]);
    expect(cache.build([saved]).entities.single.title, 'Teardrop');
    saved.enrichmentJson = _saved(
      1,
      notable: [_track('Angel', 'Massive Attack')],
    ).enrichmentJson;
    expect(cache.build([saved]).entities.single.title, 'Angel');
    expect(cache.build([]).entities, isEmpty);
  });

  testWidgets(
    'saved songs stay searchable when catalog lookup fails through the real providers',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        musicProviderPreferenceKey: 'spotify',
      });
      final lookup = Completer<MusicCatalogSong?>();
      final notifier = MusicLibraryNotifier(
        _PendingCatalog(lookup.future),
        network: _OnlineNetwork(),
      );
      final container = ProviderContainer(
        overrides: [
          urlStreamProvider.overrideWith(
            (ref) => Stream.value([
              _saved(
                1,
                mentions: [
                  {'title': 'Rick Astley', 'type': 'artist'},
                ],
                notable: [
                  _track('Bleed', 'Meshuggah'),
                  _track('From the Sky', 'Gojira'),
                  {'text': 'everynoiseatonce.com', 'type': 'website'},
                  {
                    'text': 'The song told you what you most want.',
                    'type': 'quote',
                    'label': 'Song',
                    'attribution': 'Odysseus',
                  },
                ],
              ),
            ]),
          ),
          musicLibraryProvider.overrideWith((ref) => notifier),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LibraryMusicScreen()),
        ),
      );
      for (var frame = 0; frame < 20 && !notifier.state.isChecking; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump();
      expect(find.text('Loading song details…'), findsOneWidget);
      expect(find.text('Bleed'), findsOneWidget);
      expect(find.text('From the Sky'), findsOneWidget);
      expect(find.text('Rick Astley'), findsOneWidget);
      expect(find.text('everynoiseatonce.com'), findsNothing);
      expect(find.text('The song told you what you most want.'), findsNothing);

      lookup.completeError(TimeoutException('Catalog unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.text('Some song details could not be loaded.'),
        findsOneWidget,
      );
      expect(find.text('Bleed'), findsOneWidget);
      expect(find.text('From the Sky'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'gojira');
      await tester.pumpAndSettle();
      expect(find.text('From the Sky'), findsOneWidget);
      expect(find.text('Bleed'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'does not prompt on entry and changes the app through the labeled provider menu',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          librarySnapshotProvider.overrideWith(
            (ref) => const AsyncValue.data(LibrarySnapshot(entities: [])),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LibraryMusicScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Songs and artists found in your saved links will appear here.',
        ),
        findsOneWidget,
      );
      expect(find.text('Where do you listen?'), findsNothing);
      await tester.tap(find.byTooltip('Music options'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Choose where songs open'));
      await tester.pumpAndSettle();
      expect(find.text('Where do you listen?'), findsOneWidget);
      await tester.tap(find.text('Spotify'));
      await tester.pumpAndSettle();
      expect(
        container.read(musicProviderPreferenceProvider).provider,
        MusicProvider.spotify,
      );
      await tester.tap(find.byTooltip('Music options'));
      await tester.pumpAndSettle();
      expect(find.text('Music app'), findsOneWidget);
      expect(find.text('Spotify'), findsNothing);
      expect(find.byIcon(AppIcons.musicProvider), findsNothing);
      expect(
        tester
            .widget<MusicProviderIcon>(find.byType(MusicProviderIcon))
            .provider,
        MusicProvider.spotify,
      );
      expect(find.bySemanticsLabel('Music app: Spotify'), findsOneWidget);
      await tester.tap(find.text('Music app'));
      await tester.pumpAndSettle();
      expect(find.byIcon(AppIcons.checkCircle), findsOneWidget);
      await tester.tap(find.text('Apple Music'));
      await tester.pumpAndSettle();
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(musicProviderPreferenceKey), 'appleMusic');
      expect(find.text('Apple Music'), findsNothing);
      await tester.tap(find.byTooltip('Music options'));
      await tester.pumpAndSettle();
      expect(find.text('Apple Music'), findsNothing);
      expect(
        tester
            .widget<MusicProviderIcon>(find.byType(MusicProviderIcon))
            .provider,
        MusicProvider.appleMusic,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the picker stays closed until requested', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          librarySnapshotProvider.overrideWith(
            (ref) => AsyncValue.data(
              LibraryIndex.build([
                _saved(1, notable: [_track('Bleed', 'Meshuggah')]),
              ]),
            ),
          ),
        ],
        child: const MaterialApp(home: LibraryMusicScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Where do you listen?'), findsNothing);
    await tester.enterText(find.byType(TextField), 'bleed');
    await tester.pumpAndSettle();
    expect(find.text('Where do you listen?'), findsNothing);
    await tester.tap(find.byTooltip('Music options'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose where songs open'));
    await tester.pumpAndSettle();
    expect(find.text('Where do you listen?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'searches music, opens its details and uses the selected provider with web fallback',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        musicProviderPreferenceKey: 'youtubeMusic',
      });
      final launches = <Map<dynamic, dynamic>>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'launch') {
          launches.add(call.arguments as Map<dynamic, dynamic>);
          return launches.length > 1;
        }
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final snapshot = LibraryIndex.build([
        _saved(1, notable: [_track('Teardrop', 'Massive Attack')]),
        _saved(
          2,
          notable: [_track('Everything In Its Right Place', 'Radiohead')],
        ),
      ]);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const LibraryMusicScreen()),
          GoRoute(
            path: '/library/entity/:key',
            builder: (_, state) => LibraryEntityDetailScreen(
              entityKey: state.pathParameters['key']!,
            ),
          ),
          GoRoute(
            path: '/url/:id',
            builder: (_, state) => Scaffold(
              body: Text('Opened source ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            librarySnapshotProvider.overrideWith(
              (ref) => AsyncValue.data(snapshot),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('YouTube Music'), findsNothing);
      expect(find.byTooltip('Music options'), findsOneWidget);
      expect(find.text('Where do you listen?'), findsNothing);
      await tester.enterText(find.byType(TextField), 'massive');
      await tester.pumpAndSettle();
      expect(find.text('Teardrop'), findsOneWidget);
      expect(find.text('Everything In Its Right Place'), findsNothing);
      await tester.tap(find.text('Teardrop'));
      await tester.pumpAndSettle();
      expect(find.text('Add to your watchlist'), findsNothing);
      expect(find.text('Why it mattered'), findsOneWidget);
      await tester.tap(find.text('Open in YouTube Music'));
      await tester.pumpAndSettle();
      expect(launches, hasLength(2));
      expect(
        Uri.parse(launches.last['url'] as String).queryParameters['q'],
        'Teardrop Massive Attack',
      );
      expect(launches.first['universalLinksOnly'], isTrue);
      expect(launches.last['universalLinksOnly'], isFalse);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Source 1'));
      await tester.tap(find.text('Source 1'));
      await tester.pumpAndSettle();
      expect(find.text('Opened source 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _OnlineNetwork extends NetworkStatusService {
  @override
  Future<bool> isDefinitelyOffline() async => false;
}

class _PendingCatalog implements MusicCatalogService {
  _PendingCatalog(this.result);
  final Future<MusicCatalogSong?> result;

  @override
  Future<MusicCatalogSong?> resolve(MusicSongQuery query) => result;

  @override
  void dispose() {}
}

Map<String, dynamic> _track(String title, String artist) => {
  'text': title,
  'type': 'other',
  'label': 'Song',
  'attribution': artist,
  'why_important': 'A recommendation worth listening to.',
};

SavedUrl _saved(
  int id, {
  List<Map<String, dynamic>> notable = const [],
  List<Map<String, dynamic>> mentions = const [],
}) => SavedUrl()
  ..id = id
  ..rawUrl = 'https://example.com/$id'
  ..domain = 'example.com'
  ..title = 'Source $id'
  ..description = ''
  ..category = 'Other'
  ..categories = ['Music']
  ..tags = []
  ..categoryEmoji = ''
  ..savedAt = DateTime(2026, 8, id)
  ..enrichmentJson = jsonEncode({
    'schema_version': 3,
    'meaningful_title': 'Source $id',
    'summary': 'Music recommendations',
    'category': 'Music',
    'notable_items': notable,
    'mentions': mentions,
  });
