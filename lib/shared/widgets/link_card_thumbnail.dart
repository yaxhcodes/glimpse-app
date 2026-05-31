import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/saved_url.dart';
import '../../core/services/tag_noise_filter.dart';
import 'category_chip.dart' show faviconUrl, platformColors;

/// Read/unread styling for compact link cards (home, search, etc.).
///
/// Unread: full color. Read: ~60% desaturation via [ColorFilter.matrix] — no
/// opacity fade (thumbnail-only signal; works in light and dark themes).
class LinkCardThumbnail {
  LinkCardThumbnail._();

  /// Dark mode: lower [d] = stronger desaturation (easier to see). Light: gentler.
  static ColorFilter readDesaturationFilterForBrightness(Brightness brightness) {
    final d = brightness == Brightness.dark ? 0.35 : 0.45;
    return ColorFilter.matrix(<double>[
      d, d, d, 0, 0,
      d, d, d, 0, 0,
      d, d, d, 0, 0,
      0, 0, 0, 1, 0,
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

  static String? _firstNonNoiseTag(SavedUrl url) {
    for (final t in url.tags) {
      final n = t.toLowerCase().trim();
      if (n.isEmpty) continue;
      if (TagNoiseFilter.isNoiseTag(t)) continue;
      return t;
    }
    return null;
  }

  static String _placeholderLetter(SavedUrl url, String? tag) {
    if (tag != null && tag.trim().isNotEmpty) {
      for (final r in tag.runes) {
        final ch = String.fromCharCode(r);
        if (RegExp(r'[a-zA-Z0-9]').hasMatch(ch)) {
          return ch.toUpperCase();
        }
      }
      return String.fromCharCode(tag.runes.first).toUpperCase();
    }
    try {
      final host =
          Uri.parse(url.rawUrl).host.replaceFirst(RegExp(r'^www\.'), '');
      if (host.isNotEmpty) {
        return host[0].toUpperCase();
      }
    } catch (_) {}
    final d = url.domain.replaceFirst(RegExp(r'^www\.'), '');
    if (d.isNotEmpty) return d[0].toUpperCase();
    return '?';
  }

  /// Letter + deterministic container colors from [ColorScheme] (light/dark).
  static Widget tagLetterPlaceholder(
    SavedUrl url,
    BuildContext context, {
    required double size,
    required double borderRadius,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tag = _firstNonNoiseTag(url);
    final label = _placeholderLetter(url, tag);
    final favicon = faviconUrl(url.category) ??
        faviconUrl(url.domain) ??
        _googleFaviconUrl(url);
    final accent = _sourceAccent(url, cs);
    final containerColor = Color.alphaBlend(
      accent.withValues(alpha: 0.12),
      cs.secondaryContainer,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(accent.withValues(alpha: 0.18), containerColor),
            containerColor,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: favicon == null
          ? Text(
              label,
              style: TextStyle(
                fontSize: size * 0.35,
                fontWeight: FontWeight.w600,
                color: cs.onSecondaryContainer,
              ),
            )
          : Padding(
              padding: EdgeInsets.all(size * 0.22),
              child: CachedNetworkImage(
                imageUrl: favicon,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => Text(
                  label,
                  style: TextStyle(
                    fontSize: size * 0.35,
                    fontWeight: FontWeight.w600,
                    color: cs.onSecondaryContainer,
                  ),
                ),
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

  static Color _sourceAccent(SavedUrl url, ColorScheme cs) {
    final byCategory = platformColors[url.category.trim()];
    if (byCategory != null) return byCategory;
    final byDomain = platformColors[url.domain.trim()];
    if (byDomain != null) return byDomain;
    String seed = '';
    try {
      seed = Uri.parse(url.rawUrl).host;
    } catch (_) {
      seed = url.domain;
    }
    seed = seed.replaceFirst(RegExp(r'^www\.'), '').toLowerCase();
    final byHost = _platformAccentForHost(seed);
    if (byHost != null) return byHost;
    if (seed.isEmpty) return cs.primary;
    final hue = seed.codeUnits.fold<int>(0, (sum, item) => sum + item) % 360;
    return HSLColor.fromAHSL(1, hue.toDouble(), 0.42, 0.56).toColor();
  }

  static Color? _platformAccentForHost(String host) {
    if (host.contains('instagram.com')) return platformColors['Instagram'];
    if (host == 'x.com' || host.contains('twitter.com')) {
      return platformColors['X'];
    }
    if (host.contains('github.com')) return platformColors['GitHub'];
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return platformColors['YouTube'];
    }
    if (host.contains('reddit.com')) return platformColors['Reddit'];
    if (host.contains('spotify.com')) return platformColors['Spotify'];
    if (host.contains('pinterest.com')) return platformColors['Pinterest'];
    if (host.contains('linkedin.com')) return platformColors['LinkedIn'];
    return null;
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
    final trimmed = url.thumbnailUrl?.trim();
    final thumbUrl = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;

    final Widget base = thumbUrl != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: CachedNetworkImage(
              imageUrl: thumbUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => tagLetterPlaceholder(
                url,
                context,
                size: size,
                borderRadius: borderRadius,
              ),
            ),
          )
        : tagLetterPlaceholder(
            url,
            context,
            size: size,
            borderRadius: borderRadius,
          );

    return wrapReadState(
      context: context,
      isRead: isRead,
      child: base,
    );
  }
}
