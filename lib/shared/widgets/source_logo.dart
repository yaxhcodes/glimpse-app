import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_icons.dart';
import 'category_chip.dart' show platformColors;
import 'image_decode_size.dart';
import 'platform_icons.dart';
import 'source_icon_resolver.dart';

/// The one way a source's logo is drawn, so Instagram looks the same on a
/// chip, a save's byline and a placeholder.
///
/// Known platforms use the bundled logos (Simple Icons, all on one 24px
/// grid) in their brand colour, each scaled so it looks the same size as
/// its neighbours: a full square reads larger than a circle, and a wide
/// logo is limited by its width. Other sources fall back to [faviconUrl],
/// then to a generic icon.
class SourceLogo extends StatelessWidget {
  const SourceLogo({
    super.key,
    required this.name,
    this.faviconUrl,
    this.size = 16,
  });

  final String name;
  final String? faviconUrl;
  final double size;

  /// How much of the box each logo fills so they look evenly sized beside
  /// each other.
  static const _opticalScale = <String, double>{
    // Outline marks carry little ink, so they sit at full size.
    'assets/brands/instagram.svg': 1.0,
    'assets/brands/x.svg': 0.92,
    'assets/brands/tiktok.svg': 0.95,
    // Solid marks read heavier and are pulled in a little.
    'assets/brands/pinterest.svg': 0.9,
    'assets/brands/spotify-mark.svg': 0.9,
    'assets/brands/github.svg': 0.92,
    'assets/brands/reddit.svg': 0.92,
    'assets/brands/substack.svg': 0.85,
    'assets/brands/medium.svg': 0.9,
    // Wide and short: limited by width, so full size.
    'assets/brands/youtube.svg': 1.0,
  };

  static const _instagramGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [
      Color(0xFFFEDA75),
      Color(0xFFFA7E1E),
      Color(0xFFD62976),
      Color(0xFF962FBF),
      Color(0xFF4F5BD5),
    ],
    stops: [0, 0.25, 0.5, 0.75, 1],
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spec = resolveSourceIcon(name);
    final brand = _brandColor(cs);

    Widget logo;
    if (spec.isAsset) {
      final inner = size * (_opticalScale[spec.assetPath] ?? 0.9);
      final isInstagram = spec.assetPath == 'assets/brands/instagram.svg';
      logo = SvgPicture.asset(
        spec.assetPath!,
        width: inner,
        height: inner,
        colorFilter: ColorFilter.mode(
          isInstagram ? Colors.white : brand,
          BlendMode.srcIn,
        ),
      );
      if (isInstagram) {
        // Instagram is recognised by its gradient, not a flat colour.
        logo = ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: _instagramGradient.createShader,
          child: logo,
        );
      }
    } else if (spec.isGlyph) {
      logo = PlatformIcon(
        platform: spec.glyphPlatform!,
        size: size * 0.9,
        color: brand,
      );
    } else if (faviconUrl != null) {
      final fallback = AppIcon(
        spec.icon ?? AppIcons.globe,
        size: size * 0.9,
        color: cs.onSurfaceVariant,
      );
      logo = ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CachedNetworkImage(
          imageUrl: faviconUrl!,
          width: size * 0.9,
          height: size * 0.9,
          fit: BoxFit.contain,
          memCacheWidth: imageDecodeSize(context, size),
          errorWidget: (_, _, _) => fallback,
        ),
      );
    } else {
      logo = AppIcon(
        spec.icon ?? AppIcons.globe,
        size: size * 0.9,
        color: cs.onSurfaceVariant,
      );
    }
    return SizedBox.square(
      dimension: size,
      child: Center(child: logo),
    );
  }

  /// The platform's colour, or the text colour for monochrome brands (X,
  /// GitHub, Medium) whose grey or black would vanish on a dark surface.
  Color _brandColor(ColorScheme cs) {
    Color? brand;
    final lower = name.trim().toLowerCase();
    for (final entry in platformColors.entries) {
      if (entry.key.toLowerCase() == lower) {
        brand = entry.value;
        break;
      }
    }
    if (brand == null || HSLColor.fromColor(brand).saturation < 0.3) {
      return cs.onSurface;
    }
    if (cs.brightness == Brightness.dark) {
      final hsl = HSLColor.fromColor(brand);
      if (hsl.lightness < 0.55) return hsl.withLightness(0.62).toColor();
    }
    return brand;
  }
}
