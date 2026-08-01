import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'platform_icons.dart';
import 'source_icon_resolver.dart';
import 'tag_group.dart' show tagChipColors;

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color premiumBackground(BuildContext context) {
  return Theme.of(context).colorScheme.surface;
}

Color premiumCardSurface(BuildContext context) {
  return Theme.of(context).colorScheme.surfaceContainerLow;
}

Color premiumBorderColor(BuildContext context) {
  return Theme.of(context).colorScheme.outlineVariant;
}

Color premiumPillSurface(BuildContext context) {
  return Theme.of(context).colorScheme.surfaceContainerLow;
}

Color premiumMutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

class MonochromePill extends StatelessWidget {
  final String label;
  final bool compact;

  const MonochromePill(this.label, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final chip = tagChipColors(cs);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: chip.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: (tt.labelSmall ?? const TextStyle()).copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: chip.foreground,
          letterSpacing: 0.1,
          height: 1.3,
        ),
      ),
    );
  }
}

class MonochromeIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final double containerSize;

  const MonochromeIcon({
    super.key,
    required this.icon,
    this.size = 22,
    this.containerSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          icon,
          size: size,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class SourceIconContainer extends StatelessWidget {
  final SourceIconSpec spec;
  final double containerSize;
  final Color? accentColor;
  final String? imageUrl;
  final bool preferImage;
  final bool showBackground;

  const SourceIconContainer({
    super.key,
    required this.spec,
    this.containerSize = 38,
    this.accentColor,
    this.imageUrl,
    this.preferImage = false,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentColor ?? cs.onSurfaceVariant;
    final fallback = spec.isAsset
        ? SvgPicture.asset(
            spec.assetPath!,
            width: containerSize * 0.47,
            height: containerSize * 0.47,
            colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
          )
        : spec.isGlyph
        ? PlatformIcon(
            platform: spec.glyphPlatform!,
            size: containerSize * 0.47,
            color: accent,
          )
        : Icon(spec.icon, size: containerSize * 0.47, color: accent);

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: showBackground
            ? accentColor == null
                  ? cs.secondaryContainer.withValues(alpha: 0.5)
                  : accent.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.18
                          : 0.12,
                    )
            : Colors.transparent,
        borderRadius: BorderRadius.circular(containerSize * 0.3),
      ),
      child: Center(
        child: preferImage && imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(containerSize * 0.1),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: containerSize * 0.58,
                  height: containerSize * 0.58,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => fallback,
                ),
              )
            : spec.isAsset || spec.isGlyph || imageUrl == null
            ? fallback
            : ClipRRect(
                borderRadius: BorderRadius.circular(containerSize * 0.1),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: containerSize * 0.48,
                  height: containerSize * 0.48,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => fallback,
                ),
              ),
      ),
    );
  }
}

class PremiumSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  const PremiumSearchBar({
    super.key,
    required this.controller,
    this.hint = 'Search...',
    this.onClear,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: tt.bodyMedium?.copyWith(color: cs.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: cs.onSurfaceVariant,
          ),
          suffixIcon: onClear != null
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: onClear,
                )
              : null,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final int? count;

  const SectionTitle(this.title, {super.key, this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.25,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MemoryStrip extends StatelessWidget {
  final List<String> imageUrls;
  final double height;

  /// Max number of thumbnails to render before collapsing the rest into a
  /// "+N" tile.
  final int maxVisible;

  /// Total items represented by the strip (e.g. saves in the source). Used to
  /// compute the "+N" overflow count; falls back to [imageUrls] length.
  final int? totalCount;

  const MemoryStrip({
    super.key,
    required this.imageUrls,
    this.height = 48,
    this.maxVisible = 4,
    this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final visible = imageUrls.take(maxVisible).toList();
    final remaining = (totalCount ?? imageUrls.length) - visible.length;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _MemoryTile(url: visible[i], size: height),
          ],
          if (remaining > 0) ...[
            const SizedBox(width: 6),
            Container(
              width: height,
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+$remaining',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  final String url;
  final double size;

  const _MemoryTile({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark(context) ? 0.25 : 0.08),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

/// Shared proportional sizing for a horizontal rail of [CinematicCard]s.
///
/// Every Rediscover shelf used to hardcode its own width/height (220/246 in one
/// place, 236/270 in another), which made the rails feel subtly mismatched.
/// This derives both from the viewport so the cards keep one rhythm — a card
/// width that's a fixed share of the screen (leaving a peek of the next card),
/// and a list height equal to the 16:9 media plus the card's fixed text block.
class CinematicRailMetrics {
  const CinematicRailMetrics({
    required this.cardWidth,
    required this.listHeight,
  });

  final double cardWidth;
  final double listHeight;

  /// Allowance for the card's text section (title, subtitle, tags, padding)
  /// that sits below the 16:9 media. Measured from [CinematicCard]'s layout.
  static const double _textBlock = 116.0;

  factory CinematicRailMetrics.of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width > 600;
    final cardWidth = isTablet
        ? 248.0
        : (width * 0.62).clamp(212.0, 250.0);
    final listHeight = cardWidth * 9 / 16 + _textBlock;
    return CinematicRailMetrics(
      cardWidth: cardWidth,
      listHeight: listHeight,
    );
  }
}

class CinematicCard extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String subtitle;
  final String? reason;
  final List<String> tags;
  final VoidCallback onTap;

  const CinematicCard({
    super.key,
    this.imageUrl,
    required this.title,
    required this.subtitle,
    this.reason,
    this.tags = const [],
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: cs.surfaceContainerHighest),
                  if (hasImage)
                    CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          ColoredBox(color: cs.surfaceContainerHighest),
                      errorWidget: (_, __, ___) => Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 26,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.bookmark_outline_rounded,
                        size: 26,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  // Fade the image bottom into the card surface so it merges
                  // seamlessly into the text section below (white in light
                  // mode, dark in dark mode — driven by the theme).
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.5, 0.82, 1.0],
                        colors: [
                          cs.surfaceContainerLow.withValues(alpha: 0.0),
                          cs.surfaceContainerLow.withValues(alpha: 0.55),
                          cs.surfaceContainerLow,
                        ],
                      ),
                    ),
                  ),
                  if (reason != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          reason!,
                          style: tt.labelSmall?.copyWith(
                            fontSize: 10,
                            color: cs.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      height: 1.25,
                      letterSpacing: -0.15,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: tt.labelSmall?.copyWith(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: tags
                          .take(3)
                          .map((t) => MonochromePill(t, compact: true))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
