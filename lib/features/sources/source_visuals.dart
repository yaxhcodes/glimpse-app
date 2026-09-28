import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/saved_url.dart';
import '../../core/services/saved_media_resolver.dart';
import '../../shared/widgets/category_chip.dart' show faviconUrl;
import '../../shared/widgets/image_decode_size.dart';
import '../../shared/widgets/source_logo.dart';
import 'sources_provider.dart';

/// The logo on a quiet rounded tile, the one way a source is marked on the
/// Sources pages. Brand marks keep their colour; the tile stays neutral so a
/// page of fifty sources doesn't turn into a rainbow.
class SourceLogoTile extends StatelessWidget {
  const SourceLogoTile({
    super.key,
    required this.name,
    this.fallbackFaviconUrl,
    this.size = 40,
    this.color,
  });

  final String name;
  final String? fallbackFaviconUrl;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: SourceLogo(
        name: name,
        faviconUrl: faviconUrl(name) ?? fallbackFaviconUrl,
        size: size * 0.56,
      ),
    );
  }
}

/// Up to four of a source's newest saves, tiled edge to edge: one fills the
/// frame, two split it, three lead with a tall tile, four make a grid.
class SourcePreviewMosaic extends StatelessWidget {
  const SourcePreviewMosaic({super.key, required this.previews, this.gap = 2});

  final List<SavedUrl> previews;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final tiles = previews.take(4).toList(growable: false);
    Widget tile(int i) => _PreviewTile(url: tiles[i]);
    Widget column(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          Expanded(child: children[i]),
        ],
      ],
    );
    Widget row(List<Widget> children) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: children[i]),
        ],
      ],
    );

    return switch (tiles.length) {
      0 => const SizedBox.expand(),
      1 => tile(0),
      2 => row([tile(0), tile(1)]),
      3 => row([
        tile(0),
        column([tile(1), tile(2)]),
      ]),
      _ => column([
        row([tile(0), tile(1)]),
        row([tile(2), tile(3)]),
      ]),
    };
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.url});

  final SavedUrl url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final empty = ColoredBox(color: cs.surfaceContainerHighest);
    final image = sourcePreviewImage(url);
    if (image == null) return empty;
    // A fixed decode width: tiles are at most a card wide, and the rail
    // measures itself intrinsically, which a LayoutBuilder can't answer.
    return _SourceImage(
      image: image,
      decodeWidth: imageDecodeSize(context, 164, headroom: 1.3),
      fallback: empty,
    );
  }
}

class _SourceImage extends StatelessWidget {
  const _SourceImage({
    required this.image,
    required this.decodeWidth,
    required this.fallback,
  });

  final ({String path, bool isAsset}) image;
  final int decodeWidth;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (image.isAsset) {
      return Image.asset(
        image.path,
        fit: BoxFit.cover,
        cacheWidth: decodeWidth,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return CachedNetworkImage(
      imageUrl: image.path,
      fit: BoxFit.cover,
      httpHeaders: SavedMediaResolver.imageHttpHeaders(image.path),
      memCacheWidth: decodeWidth,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

/// The newest save's artwork, heavily blurred and melted into the page: the
/// source page opens in the colours of what was last saved from it. Sources
/// without artwork get a faint neutral tone instead.
class SourceArtworkWash extends StatelessWidget {
  const SourceArtworkWash({super.key, required this.previews});

  final List<SavedUrl> previews;

  @override
  Widget build(BuildContext context) {
    // The page colour, not cs.surface: on the black theme they differ and
    // the wash would end in a visible seam.
    final page = Theme.of(context).scaffoldBackgroundColor;
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final artwork = previews.isEmpty
        ? null
        : sourcePreviewImage(previews.first);
    final Widget wash = artwork == null
        ? ColoredBox(color: cs.surfaceContainerHigh)
        : Opacity(
            opacity: dark ? 0.55 : 0.4,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 48,
                sigmaY: 48,
                tileMode: TileMode.clamp,
              ),
              child: _SourceImage(
                image: artwork,
                decodeWidth: 200,
                fallback: const SizedBox.shrink(),
              ),
            ),
          );
    // The blur paints past its box; clip it to the hero.
    return IgnorePointer(
      child: ClipRect(
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: page),
              wash,
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      page.withValues(alpha: dark ? 0.1 : 0.2),
                      page.withValues(alpha: 0.4),
                      page,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
