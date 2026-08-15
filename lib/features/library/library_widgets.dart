import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'library_entity.dart';
import 'library_radial_status_menu.dart';

class LibraryArtwork extends StatelessWidget {
  const LibraryArtwork({
    super.key,
    required this.entity,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.fit = BoxFit.cover,
    this.imageUrlOverride,
  });

  final LibraryEntity entity;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final String? imageUrlOverride;

  @override
  Widget build(BuildContext context) {
    final artwork =
        imageUrlOverride?.trim() ??
        (entity.kind == LibraryEntityKind.place
            ? entity.placeImageUrl?.trim()
            : entity.artworkUrl?.trim()) ??
        '';
    final fallback = _ArtworkFallback(entity: entity);
    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: artwork.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: artwork,
                fit: fit,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class LibraryEntityTile extends StatelessWidget {
  const LibraryEntityTile({
    super.key,
    required this.entity,
    required this.onTap,
    required this.onStatusSelected,
    required this.onStatusMenuRequested,
  });

  final LibraryEntity entity;
  final VoidCallback onTap;
  final ValueChanged<LibraryItemStatus> onStatusSelected;
  final VoidCallback onStatusMenuRequested;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final metadata = [
      if ((entity.mention.creator ?? '').trim().isNotEmpty)
        entity.mention.creator!,
      if ((entity.mention.year ?? '').trim().isNotEmpty) entity.mention.year!,
    ].join(' · ');
    Widget artwork({required bool useHero, required bool showStatusBadge}) {
      final artwork = LibraryArtwork(entity: entity);
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (useHero)
            Hero(tag: 'library-artwork-${entity.key}', child: artwork)
          else
            artwork,
          if (showStatusBadge && entity.status != LibraryItemStatus.unlisted)
            Positioned(
              left: 10,
              bottom: -14,
              child: _LibraryStatusBadge(entity: entity),
            ),
        ],
      );
    }

    Widget content({
      required bool useHero,
      required bool showStatusBadge,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: artwork(useHero: useHero, showStatusBadge: showStatusBadge),
        ),
        SizedBox(
          height: showStatusBadge && entity.status != LibraryItemStatus.unlisted
              ? 22
              : 8,
        ),
        Text(
          entity.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: tt.titleSmall?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
            height: 1.18,
          ),
        ),
        if (metadata.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            metadata,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
    return LibraryRadialStatusTarget(
      entity: entity,
      onTap: onTap,
      onStatusSelected: onStatusSelected,
      onStatusMenuRequested: onStatusMenuRequested,
      preview: content(useHero: false, showStatusBadge: false),
      child: content(useHero: true, showStatusBadge: true),
    );
  }
}

class _LibraryStatusBadge extends StatelessWidget {
  const _LibraryStatusBadge({required this.entity});

  final LibraryEntity entity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Status: ${entity.status.labelFor(entity.kind)}',
      child: Material(
        key: ValueKey('library-status-badge-${entity.key}'),
        color: cs.inverseSurface,
        elevation: 1,
        shadowColor: cs.shadow.withValues(alpha: 0.24),
        shape: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Text(
            entity.status.labelFor(entity.kind),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onInverseSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class LibraryGenreChip extends StatelessWidget {
  const LibraryGenreChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.entity});

  final LibraryEntity entity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final icon = switch (entity.kind) {
      LibraryEntityKind.book => Icons.menu_book_rounded,
      LibraryEntityKind.movie => Icons.movie_rounded,
      LibraryEntityKind.place => Icons.place_rounded,
    };
    final initial = entity.title.trim().isEmpty
        ? ''
        : entity.title.trim().characters.first.toUpperCase();
    final creator = entity.mention.creator?.trim() ?? '';
    final year = entity.mention.year?.trim() ?? '';
    final byline = [
      if (creator.isNotEmpty) creator,
      if (year.isNotEmpty) year,
    ].join(' · ');
    if (entity.kind == LibraryEntityKind.place) {
      return const _PlaceArtworkFallback();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 112 || constraints.maxHeight < 150;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primaryContainer,
                cs.tertiaryContainer.withValues(alpha: 0.82),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: compact ? -8 : -14,
                bottom: compact ? -10 : -18,
                child: Icon(
                  icon,
                  size: compact ? 58 : 104,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.1),
                ),
              ),
              if (compact)
                Center(
                  child: Text(
                    initial,
                    style: tt.headlineMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entity.kind.singularLabel.toUpperCase(),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onPrimaryContainer.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        entity.title,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleLarge?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                        ),
                      ),
                      if (byline.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          byline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelMedium?.copyWith(
                            color: cs.onPrimaryContainer.withValues(
                              alpha: 0.76,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlaceArtworkFallback extends StatelessWidget {
  const _PlaceArtworkFallback();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _PlaceFallbackPainter(
        background: cs.surfaceContainerHigh,
        road: cs.outlineVariant.withValues(alpha: 0.68),
        pin: cs.onSurfaceVariant.withValues(alpha: 0.72),
      ),
      child: const Center(child: Icon(Icons.place_rounded, size: 30)),
    );
  }
}

class _PlaceFallbackPainter extends CustomPainter {
  const _PlaceFallbackPainter({
    required this.background,
    required this.road,
    required this.pin,
  });

  final Color background;
  final Color road;
  final Color pin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()
      ..color = road
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var index = 0; index < 4; index++) {
      final y = size.height * (0.18 + index * 0.24);
      final path = Path()
        ..moveTo(-8, y)
        ..cubicTo(
          size.width * 0.26,
          y - size.height * 0.18,
          size.width * 0.72,
          y + size.height * 0.17,
          size.width + 8,
          y - size.height * 0.05,
        );
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.2),
      3,
      Paint()..color = pin,
    );
  }

  @override
  bool shouldRepaint(covariant _PlaceFallbackPainter oldDelegate) =>
      oldDelegate.background != background ||
      oldDelegate.road != road ||
      oldDelegate.pin != pin;
}
