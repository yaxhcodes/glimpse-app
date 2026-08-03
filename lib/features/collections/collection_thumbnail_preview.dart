import 'package:flutter/material.dart';

import '../../core/models/saved_url.dart';
import '../../shared/widgets/link_card_thumbnail.dart';

class CollectionThumbnailPreview extends StatelessWidget {
  const CollectionThumbnailPreview({
    super.key,
    required this.previewUrls,
    required this.linkCount,
  });

  final List<SavedUrl> previewUrls;
  final int linkCount;

  static const _tileSize = 36.0;
  static const _tileOffset = 24.0;

  @override
  Widget build(BuildContext context) {
    final thumbnails = linkCount > 3
        ? previewUrls.take(2).toList(growable: false)
        : previewUrls.take(3).toList(growable: false);
    final overflowCount = linkCount > 3 ? linkCount - thumbnails.length : 0;
    final tileCount = thumbnails.length + (overflowCount > 0 ? 1 : 0);
    final width = _tileSize + ((tileCount - 1) * _tileOffset);

    return SizedBox(
      width: width,
      height: _tileSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < thumbnails.length; index++)
            Positioned(
              left: index * _tileOffset,
              child: _ThumbnailTile(
                key: ValueKey(
                  'collection-preview-thumbnail-${thumbnails[index].id}',
                ),
                url: thumbnails[index],
              ),
            ),
          if (overflowCount > 0)
            Positioned(
              left: thumbnails.length * _tileOffset,
              child: _OverflowTile(count: overflowCount),
            ),
        ],
      ),
    );
  }
}

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({super.key, required this.url});

  final SavedUrl url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: CollectionThumbnailPreview._tileSize,
      height: CollectionThumbnailPreview._tileSize,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(11),
      ),
      child: LinkCardThumbnail.build(
        url: url,
        isRead: false,
        context: context,
        size: CollectionThumbnailPreview._tileSize - 4,
        borderRadius: 8,
      ),
    );
  }
}

class _OverflowTile extends StatelessWidget {
  const _OverflowTile({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('collection-preview-overflow'),
      width: CollectionThumbnailPreview._tileSize,
      height: CollectionThumbnailPreview._tileSize,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        border: Border.all(color: cs.surfaceContainerLow, width: 2),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '+$count',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
