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
