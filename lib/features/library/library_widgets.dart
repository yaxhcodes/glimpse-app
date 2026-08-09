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
  });

  final LibraryEntity entity;
  final BorderRadius borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final artwork = entity.artworkUrl?.trim() ?? '';
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
    Widget content({required bool useHero}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: useHero
              ? Hero(
                  tag: 'library-artwork-${entity.key}',
                  child: LibraryArtwork(entity: entity),
                )
              : LibraryArtwork(entity: entity),
        ),
        const SizedBox(height: 8),
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
      preview: content(useHero: false),
      child: content(useHero: true),
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
