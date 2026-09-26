import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../core/models/saved_url.dart';
import '../../core/services/saved_media_resolver.dart';
import 'category_chip.dart' show faviconUrl;
import 'image_decode_size.dart';
import '../theme/topic_visual.dart';

/// Read/unread styling for compact link cards (home, search, etc.).
///
/// Unread: full color. Read: ~60% desaturation via [ColorFilter.matrix] — no
/// opacity fade (thumbnail-only signal; works in light and dark themes).
class LinkCardThumbnail {
  LinkCardThumbnail._();

  /// Dark mode: lower [d] = stronger desaturation (easier to see). Light: gentler.
  static ColorFilter readDesaturationFilterForBrightness(
    Brightness brightness,
  ) {
    final d = brightness == Brightness.dark ? 0.35 : 0.45;
    return ColorFilter.matrix(<double>[
      d,
      d,
      d,
      0,
      0,
      d,
      d,
      d,
      0,
      0,
      d,
      d,
      d,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  static Widget wrapReadState({
    required BuildContext context,
    required bool isRead,
    required Widget child,
  }) {
    if (!isRead) return child;
    final filter = readDesaturationFilterForBrightness(
      Theme.of(context).brightness,
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: ColorFiltered(
        key: ValueKey(isRead),
        colorFilter: filter,
        child: child,
      ),
    );
  }

  /// What a save shows before (or instead of) its image: the save's topic
  /// glyph on a tone of that topic, with the source as a small corner mark.
  /// A brand logo filling the tile read as broken, and letters said nothing.
  static Widget tagLetterPlaceholder(
    SavedUrl url,
    BuildContext context, {
    required double size,
    required double borderRadius,
  }) {
    final cs = Theme.of(context).colorScheme;
    final topic = TopicVisual.forTopicNames([...url.categories, ...url.tags]);
    final favicon =
        faviconUrl(url.category) ??
        faviconUrl(url.domain) ??
        _googleFaviconUrl(url);
    final badge = (size * 0.3).clamp(14.0, 22.0);
    final showBadge = favicon != null && size >= 44;

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: topic.container(cs),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(
                topic.icon,
                size: (size * 0.36).clamp(14.0, 40.0),
                color: cs.onSurfaceVariant,
              ),
            ),
            if (showBadge)
              Align(
                alignment: const Alignment(0.86, 0.86),
                child: Container(
                  width: badge,
                  height: badge,
                  padding: EdgeInsets.all(badge * 0.14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: favicon,
                      fit: BoxFit.contain,
                      memCacheWidth: imageDecodeSize(context, badge),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String? _googleFaviconUrl(SavedUrl url) {
    try {
      final host = Uri.parse(url.rawUrl).host;
      if (host.isNotEmpty) {
        return 'https://www.google.com/s2/favicons?domain=$host&sz=64';
      }
    } catch (_) {}
    final domain = url.domain.trim();
    if (domain.isEmpty) return null;
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
  }

  /// Network image when [SavedUrl.thumbnailUrl] is set; otherwise tag placeholder.
  /// [errorWidget] on image load failure uses the same placeholder.
  static Widget build({
    required SavedUrl url,
    required bool isRead,
    required BuildContext context,
    double size = 64,
    double borderRadius = 10,
  }) {
    final assetPath = _assetPath(url.thumbnailUrl);
    final thumbUrls = SavedMediaResolver.imageCandidates(url);

    final Widget base = assetPath != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.asset(
              assetPath,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => tagLetterPlaceholder(
                url,
                context,
                size: size,
                borderRadius: borderRadius,
              ),
            ),
          )
        : thumbUrls.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: _FallbackCachedThumbnail(
              imageUrls: thumbUrls,
              url: url,
              width: size,
              height: size,
              borderRadius: borderRadius,
            ),
          )
        : tagLetterPlaceholder(
            url,
            context,
            size: size,
            borderRadius: borderRadius,
          );

    return wrapReadState(context: context, isRead: isRead, child: base);
  }

  static String? _assetPath(String? value) {
    const prefix = 'asset://';
    final candidate = value?.trim() ?? '';
    if (!candidate.startsWith(prefix) || candidate.length == prefix.length) {
      return null;
    }
    return candidate.substring(prefix.length);
  }
}

class _FallbackCachedThumbnail extends StatefulWidget {
  const _FallbackCachedThumbnail({
    required this.imageUrls,
    required this.url,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final List<String> imageUrls;
  final SavedUrl url;
  final double width;
  final double height;
  final double borderRadius;

  @override
  State<_FallbackCachedThumbnail> createState() =>
      _FallbackCachedThumbnailState();
}

class _FallbackCachedThumbnailState extends State<_FallbackCachedThumbnail> {
  int _index = 0;

  @override
  void didUpdateWidget(covariant _FallbackCachedThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.imageUrls, widget.imageUrls)) {
      _index = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.imageUrls[_index];
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      // Decode by height with headroom: most previews are landscape, and the
      // extra 30% keeps portrait covers sharp once cropped to a square.
      memCacheHeight: imageDecodeSize(context, widget.height, headroom: 1.3),
      httpHeaders: SavedMediaResolver.imageHttpHeaders(imageUrl),
      placeholder: (_, _) => LinkCardThumbnail.tagLetterPlaceholder(
        widget.url,
        context,
        size: widget.width,
        borderRadius: widget.borderRadius,
      ),
      errorWidget: (_, _, _) {
        if (_index + 1 < widget.imageUrls.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index += 1);
          });
        }
        return LinkCardThumbnail.tagLetterPlaceholder(
          widget.url,
          context,
          size: widget.width,
          borderRadius: widget.borderRadius,
        );
      },
    );
  }
}
