import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../models/music_song.dart';

class MusicCatalogService {
  MusicCatalogService({
    Dio? client,
    Duration requestInterval = const Duration(milliseconds: 1100),
  }) : _client =
           client ??
           Dio(BaseOptions(connectTimeout: const Duration(seconds: 12))),
       _requestInterval = requestInterval;

  final Dio _client;
  final Duration _requestInterval;
  DateTime? _lastRequest;
  Future<void> _queue = Future.value();
  static final _mbid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  Future<MusicCatalogSong?> resolve(MusicSongQuery query) {
    final result = _queue.then((_) => _resolve(query));
    _queue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        developer.log(
          'Music catalog request failed',
          error: error,
          stackTrace: stack,
        );
      },
    );
    return result;
  }

  Future<MusicCatalogSong?> _resolve(MusicSongQuery query) async {
    final previous = _lastRequest;
    if (previous != null) {
      final delay = _requestInterval - DateTime.now().difference(previous);
      if (delay > Duration.zero) await Future<void>.delayed(delay);
    }
    _lastRequest = DateTime.now();
    final data = await _get(
      Uri.https('musicbrainz.org', '/ws/2/recording', {
        'query':
            'recording:"${_escape(query.title)}" AND artist:"${_escape(query.artist)}"',
        'fmt': 'json',
        'limit': '25',
      }),
    );
    if (data['recordings'] is! List) {
      throw const FormatException('Invalid music catalog response');
    }
    final matches = (data['recordings'] as List).whereType<Map>().where((
      recording,
    ) {
      if (recording['video'] == true ||
          !_mbid.hasMatch(recording['id']?.toString() ?? '')) {
        return false;
      }
      if (MusicSongQuery.normalize(recording['title']?.toString() ?? '') !=
          MusicSongQuery.normalize(query.title)) {
        return false;
      }
      final credits =
          (recording['artist-credit'] as List?)?.whereType<Map>().toList() ??
          [];
      final artist = credits
          .map(
            (credit) => '${credit['name'] ?? ''}${credit['joinphrase'] ?? ''}',
          )
          .join();
      return MusicSongQuery.normalize(artist) ==
          MusicSongQuery.normalize(query.artist);
    }).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => _recordingRank(b).compareTo(_recordingRank(a)));
    final recording = matches.first;
    final releases =
        (recording['releases'] as List?)
            ?.whereType<Map>()
            .where((release) => release['status'] == 'Official')
            .toList() ??
        [];
    releases.sort((a, b) => _releaseRank(b).compareTo(_releaseRank(a)));
    String? artwork;
    Map? albumRelease;
    for (final release in releases) {
      final group = release['release-group'];
      if (group is! Map) continue;
      final id = group['id']?.toString() ?? '';
      if (!_mbid.hasMatch(id)) continue;
      albumRelease = release;
      artwork = Uri.https(
        'coverartarchive.org',
        '/release-group/$id/front-500',
      ).toString();
      break;
    }
    final credits = (recording['artist-credit'] as List).whereType<Map>();
    final date = recording['first-release-date']?.toString() ?? '';
    return MusicCatalogSong(
      id: recording['id'] as String,
      title: recording['title'] as String,
      artist: credits
          .map(
            (credit) => '${credit['name'] ?? ''}${credit['joinphrase'] ?? ''}',
          )
          .join(),
      artworkUrl: artwork,
      album: albumRelease?['title']?.toString(),
      year: date.length >= 4 ? date.substring(0, 4) : null,
    );
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await _client.getUri<Object?>(
      uri,
      options: Options(
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Glimpse/1.0 (https://www.getglimpse.xyz)',
        },
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
        validateStatus: (status) => status == 200 || status == 404,
      ),
    );
    if (response.statusCode != 200) {
      throw StateError('Catalog HTTP ${response.statusCode}');
    }
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid catalog JSON');
    }
    return data;
  }

  static String _escape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  static int _recordingRank(Map recording) {
    final disambiguation =
        recording['disambiguation']?.toString().toLowerCase() ?? '';
    final releases = (recording['releases'] as List? ?? []).whereType<Map>();
    return (disambiguation.contains('live') ? -100 : 0) +
        releases.fold<int>(
          0,
          (best, release) =>
              _releaseRank(release) > best ? _releaseRank(release) : best,
        );
  }

  static int _releaseRank(Map release) {
    final group = release['release-group'];
    final secondary = group is Map
        ? group['secondary-types'] as List? ?? []
        : const [];
    return (release['status'] == 'Official' ? 20 : 0) +
        (group is Map && group['primary-type'] == 'Album' ? 10 : 0) -
        (secondary.contains('Live') || secondary.contains('Compilation')
            ? 20
            : 0);
  }

  void dispose() => _client.close(force: true);
}
