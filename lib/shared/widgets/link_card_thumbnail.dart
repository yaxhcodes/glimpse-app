import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/saved_url.dart';
import '../../core/services/tag_noise_filter.dart';

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
    final colors = <Color>[
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiaryContainer,
      cs.surfaceContainerHighest,
    ];
    final textColors = <Color>[
      cs.onPrimaryContainer,
      cs.onSecondaryContainer,
      cs.onTertiaryContainer,
      cs.onSurfaceVariant,
    ];
    final colorIndex = tag != null
        ? tag.codeUnits.fold<int>(0, (a, b) => a + b) % colors.length
        : 0;
    final bgColor = colors[colorIndex];
    final textColor = textColors[colorIndex];
    final label = _placeholderLetter(url, tag);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
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
