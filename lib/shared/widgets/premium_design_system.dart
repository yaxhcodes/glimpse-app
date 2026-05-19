import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'platform_icons.dart';
import 'source_icon_resolver.dart';

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color premiumBackground(BuildContext context) {
  return Theme.of(context).colorScheme.surface;
}

Color premiumCardSurface(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return _isDark(context) ? cs.surfaceContainerLow : cs.surfaceContainerLow;
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: (tt.labelSmall ?? const TextStyle()).copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: cs.onSecondaryContainer,
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

  const SourceIconContainer({
    super.key,
    required this.spec,
    this.containerSize = 38,
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
        child: spec.isGlyph
            ? PlatformIcon(platform: spec.glyphPlatform!, size: containerSize * 0.47)
            : Icon(
                spec.icon,
                size: containerSize * 0.47,
                color: cs.onSurfaceVariant,
              ),
      ),
    );
  }
}

class PremiumSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onClear;

  const PremiumSearchBar({
    super.key,
    required this.controller,
    this.hint = 'Search...',
    this.onClear,
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
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
  final double overlap;

  const MemoryStrip({
    super.key,
    required this.imageUrls,
    this.height = 48,
    this.overlap = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: Stack(
        children: imageUrls.asMap().entries.map((entry) {
          final index = entry.key;
          final url = entry.value;
          return Positioned(
            left: index * (height - overlap),
            child: Container(
              width: height,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isDark(context) ? 0.25 : 0.08),
                    blurRadius: 6,
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
            ),
          );
        }).toList(),
      ),
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
        borderRadius: BorderRadius.circular(16),
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
                  if (hasImage)
                    CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: hasImage
                            ? [
                                Colors.black.withValues(alpha: 0.04),
                                Colors.black.withValues(alpha: 0.20),
                                Colors.black.withValues(alpha: 0.55),
                                Colors.black.withValues(alpha: 0.82),
                                Colors.black.withValues(alpha: 0.94),
                              ]
                            : [
                                cs.surfaceContainerLow,
                                cs.surfaceContainerLow,
                              ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (reason != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                reason!,
                                style: tt.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: cs.onSurface.withValues(alpha: 0.60),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                          ],
                          Text(
                            subtitle,
                            style: tt.labelSmall?.copyWith(
                              fontSize: 10,
                              color: hasImage
                                  ? Colors.white.withValues(alpha: 0.60)
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      height: 1.2,
                      letterSpacing: -0.15,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: tags
                          .take(4)
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
