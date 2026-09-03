import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/music_song.dart';
import 'package:glimpse/core/services/music_catalog_service.dart';

const _recordingId = '11111111-1111-1111-1111-111111111111';
const _groupId = '22222222-2222-2222-2222-222222222222';

void main() {
  test(
    'rejects artists, websites, albums, quotes and missing artists as candidates',
    () {
      for (final item in [
        (title: 'Rick Astley', artist: null, type: 'artist'),
        (title: 'Rick Astley', artist: 'Rick Astley', type: 'music'),
        (title: 'everynoiseatonce.com', artist: 'Music', type: 'music'),
        (
          title:
              'The song told you what you most want is what you most cannot have.',
          artist: 'Odysseus',
          type: 'quote',
        ),
        (title: 'ObZen', artist: 'Meshuggah', type: 'album'),
        (title: 'Bleed', artist: null, type: 'song'),
      ]) {
        expect(
          MusicSongQuery.tryCreate(
            title: item.title,
            artist: item.artist,
            type: item.type,
          ),
          isNull,
        );
      }
    },
  );

  test(
    'verifies title and artist, preferring studio album art to a live recording',
    () async {
      final requests = <RequestOptions>[];
      final service = _service((request) {
        requests.add(request);
        return {
          'recordings': [
            {
              ..._recording(),
              'disambiguation': 'live',
              'releases': [_release(live: true)],
            },
            _recording(),
            {..._recording(), 'title': 'Bleeding'},
            {
              ..._recording(),
              'artist-credit': [
                {'name': 'Cover Band'},
              ],
            },
          ],
        };
      });
      addTearDown(service.dispose);
      final song = await service.resolve(
        const MusicSongQuery(title: 'Bleed', artist: 'Meshuggah'),
      );
      expect(song?.title, 'Bleed');
      expect(song?.artist, 'Meshuggah');
      expect(song?.album, 'ObZen');
      expect(
        song?.artworkUrl,
        'https://coverartarchive.org/release-group/$_groupId/front-500',
      );
      expect(requests, hasLength(1));
      expect(requests.first.headers['User-Agent'], contains('Glimpse'));
    },
  );

  test('does not substitute a nearby title or another artist', () async {
    final service = _service(
      (_) => {
        'recordings': [
          {
            ..._recording(),
            'title': 'A Visceral Retch',
            'artist-credit': [
              {'name': 'Whitechapel'},
            ],
          },
          {..._recording(), 'title': 'Visceral Rage'},
        ],
      },
    );
    addTearDown(service.dispose);
    expect(
      await service.resolve(
        const MusicSongQuery(title: 'Visceral Rage', artist: 'Whitechapel'),
      ),
      isNull,
    );
  });

  test('keeps a verified song when no album is identified', () async {
    final service = _service(
      (_) => {
        'recordings': [
          {..._recording(), 'releases': <Object>[]},
        ],
      },
    );
    addTearDown(service.dispose);
    final song = await service.resolve(
      const MusicSongQuery(title: 'Bleed', artist: 'Meshuggah'),
    );
    expect(song?.id, _recordingId);
    expect(song?.artworkUrl, isNull);
  });

  test('does not cache a failed request as a definitive no-match', () async {
    final service = _service(
      (request) => throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      ),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.resolve(
        const MusicSongQuery(title: 'Bleed', artist: 'Meshuggah'),
      ),
      throwsA(isA<DioException>()),
    );
  });

  test('preserves Unicode and escapes catalog query syntax', () async {
    late RequestOptions request;
    final service = _service((value) {
      request = value;
      return {'recordings': []};
    });
    addTearDown(service.dispose);
    await service.resolve(
      const MusicSongQuery(title: '夜に駆ける "live"', artist: 'YOASOBI'),
    );
    expect(request.uri.queryParameters['query'], contains('夜に駆ける \\"live\\"'));
  });
}

MusicCatalogService _service(
  FutureOr<Map<String, dynamic>> Function(RequestOptions) respond,
) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) async {
        try {
          final data = await respond(request);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: data,
            ),
          );
        } catch (error) {
          handler.reject(
            error is DioException
                ? error
                : DioException(requestOptions: request, error: error),
          );
        }
      },
    ),
  );
  return MusicCatalogService(client: dio, requestInterval: Duration.zero);
}

Map<String, dynamic> _recording() => {
  'id': _recordingId,
  'title': 'Bleed',
  'first-release-date': '2008-03-07',
  'artist-credit': [
    {'name': 'Meshuggah'},
  ],
  'releases': [_release()],
};

Map<String, dynamic> _release({bool live = false}) => {
  'title': live ? 'Alive' : 'ObZen',
  'status': 'Official',
  'release-group': {
    'id': live ? '33333333-3333-3333-3333-333333333333' : _groupId,
    'primary-type': 'Album',
    'secondary-types': [if (live) 'Live'],
  },
};
