import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/music_provider.dart';
import 'package:glimpse/core/services/music_destination_service.dart';

void main() {
  group('MusicDestinationService', () {
    test('builds a Spotify search from title and artist', () {
      final uri = MusicDestinationService.searchUri(
        provider: MusicProvider.spotify,
        title: 'From the Sky',
        artist: 'Gojira',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'open.spotify.com');
      expect(uri.pathSegments, ['search', 'From the Sky Gojira']);
    });

    test('builds a YouTube Music search from title and artist', () {
      final uri = MusicDestinationService.searchUri(
        provider: MusicProvider.youtubeMusic,
        title: 'Bleed',
        artist: 'Meshuggah',
      );

      expect(uri.host, 'music.youtube.com');
      expect(uri.path, '/search');
      expect(uri.queryParameters['q'], 'Bleed Meshuggah');
    });

    test('uses the device country for Apple Music storefront', () {
      final uri = MusicDestinationService.searchUri(
        provider: MusicProvider.appleMusic,
        title: 'Visceral Rage',
        artist: 'Whitechapel',
        countryCode: 'IN',
      );

      expect(uri.host, 'music.apple.com');
      expect(uri.pathSegments, ['in', 'search']);
      expect(uri.queryParameters['term'], 'Visceral Rage Whitechapel');
    });

    test('falls back to the US Apple Music storefront', () {
      final uri = MusicDestinationService.searchUri(
        provider: MusicProvider.appleMusic,
        title: 'Song',
        countryCode: 'invalid',
      );

      expect(uri.pathSegments.first, 'us');
    });
  });
}
