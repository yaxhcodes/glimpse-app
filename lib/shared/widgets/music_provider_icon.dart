import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/music_provider.dart';

class MusicProviderIcon extends StatelessWidget {
  const MusicProviderIcon({super.key, required this.provider, this.size = 42});

  final MusicProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = switch (provider) {
      MusicProvider.spotify => 'assets/brands/spotify.svg',
      MusicProvider.youtubeMusic => 'assets/brands/youtube-music.svg',
      MusicProvider.appleMusic => 'assets/brands/apple-music.svg',
    };

    return SizedBox.square(dimension: size, child: SvgPicture.asset(asset));
  }
}
