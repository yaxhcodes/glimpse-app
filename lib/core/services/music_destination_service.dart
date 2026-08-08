import '../models/music_provider.dart';

abstract final class MusicDestinationService {
  static Uri searchUri({
    required MusicProvider provider,
    required String title,
    String? artist,
    String? countryCode,
  }) {
    final query = [
      title.trim(),
      artist?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');

    return switch (provider) {
      MusicProvider.spotify => Uri.https('open.spotify.com', '/search/$query'),
      MusicProvider.youtubeMusic => Uri.https('music.youtube.com', '/search', {
        'q': query,
      }),
      MusicProvider.appleMusic => Uri.https(
        'music.apple.com',
        '/${_appleStorefront(countryCode)}/search',
        {'term': query},
      ),
    };
  }

  static String _appleStorefront(String? countryCode) {
    final normalized = countryCode?.trim().toLowerCase() ?? '';
    return RegExp(r'^[a-z]{2}$').hasMatch(normalized) ? normalized : 'us';
  }
}
