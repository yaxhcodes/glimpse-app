enum MusicProvider { spotify, youtubeMusic, appleMusic }

extension MusicProviderInfo on MusicProvider {
  String get label {
    return switch (this) {
      MusicProvider.spotify => 'Spotify',
      MusicProvider.youtubeMusic => 'YouTube Music',
      MusicProvider.appleMusic => 'Apple Music',
    };
  }
}
