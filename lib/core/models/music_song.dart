class MusicSongQuery {
  const MusicSongQuery({required this.title, required this.artist});

  final String title;
  final String artist;

  static MusicSongQuery? tryCreate({
    required String title,
    required String? artist,
    required String? type,
    String? label,
  }) {
    var kind = type?.trim().toLowerCase() ?? 'music';
    if ({'other', 'reference', ''}.contains(kind) &&
        _songLabels.contains(label?.trim().toLowerCase())) {
      kind = 'song';
    }
    if (!{'song', 'track', 'music'}.contains(kind)) return null;
    final cleanTitle = title.trim();
    final cleanArtist = artist?.trim() ?? '';
    if (cleanTitle.isEmpty || cleanArtist.isEmpty || cleanTitle.length > 240) {
      return null;
    }
    final website = RegExp(
      r'(https?://|www\.|\b[^\s]+\.(com|org|net|io)\b)',
      caseSensitive: false,
    );
    if (website.hasMatch(cleanTitle) || website.hasMatch(cleanArtist)) {
      return null;
    }
    if (normalize(cleanTitle) == normalize(cleanArtist)) return null;
    return MusicSongQuery(title: cleanTitle, artist: cleanArtist);
  }

  /// A notable item enrichment tagged as a song, whatever its broad type
  /// ("Fireflies" arrives as a product labelled Song, "Human Being" as other
  /// labelled Song title). Quotes labelled Song are lyrics, not songs.
  static bool isSongItem({required String? type, required String? label}) {
    final kind = type?.trim().toLowerCase() ?? '';
    if ({'song', 'track'}.contains(kind)) return true;
    if (kind == 'quote') return false;
    if (!{
      'other',
      'reference',
      '',
      'product',
      'music',
      'title',
    }.contains(kind)) {
      return false;
    }
    final name = label?.trim().toLowerCase() ?? '';
    return _songLabels.contains(name) ||
        _songLabels.contains(
          name.replaceFirst(RegExp(r'\s+(title|name)$'), ''),
        );
  }

  static const _songLabels = {
    'song',
    'track',
    '曲',
    '楽曲',
    'canción',
    'chanson',
    'morceau',
    'música',
    'canção',
    'faixa',
    'lied',
  };

  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}

class MusicCatalogSong {
  const MusicCatalogSong({
    required this.id,
    required this.title,
    required this.artist,
    this.artworkUrl,
    this.album,
    this.year,
  });

  final String id;
  final String title;
  final String artist;
  final String? artworkUrl;
  final String? album;
  final String? year;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'artwork_url': artworkUrl,
    'album': album,
    'year': year,
  };

  factory MusicCatalogSong.fromJson(Map<String, dynamic> json) =>
      MusicCatalogSong(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        artworkUrl: json['artwork_url'] as String?,
        album: json['album'] as String?,
        year: json['year'] as String?,
      );
}
