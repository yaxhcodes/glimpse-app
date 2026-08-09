import 'package:flutter/material.dart';

import 'library_entity.dart';

String libraryListName(LibraryEntityKind kind) => switch (kind) {
  LibraryEntityKind.book => 'Reading list',
  LibraryEntityKind.movie => 'Watchlist',
  LibraryEntityKind.place => 'Places',
};

IconData libraryStatusIcon(LibraryItemStatus status, LibraryEntityKind kind) =>
    switch (status) {
      LibraryItemStatus.unlisted => Icons.playlist_add_rounded,
      LibraryItemStatus.planning => Icons.bookmark_add_outlined,
      LibraryItemStatus.active =>
        kind == LibraryEntityKind.book
            ? Icons.auto_stories_rounded
            : Icons.play_circle_outline_rounded,
      LibraryItemStatus.dropped => Icons.remove_circle_outline_rounded,
      LibraryItemStatus.completed => Icons.check_circle_outline_rounded,
    };

Future<LibraryItemStatus?> showLibraryStatusPicker(
  BuildContext context, {
  required LibraryEntity entity,
}) {
  assert(entity.kind != LibraryEntityKind.place);
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return showModalBottomSheet<LibraryItemStatus>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entity.kind == LibraryEntityKind.book
                      ? 'Reading status'
                      : 'Watch status',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  entity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          for (final status in LibraryItemStatus.values.skip(1))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                minTileHeight: 52,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                selected: entity.status == status,
                selectedTileColor: cs.secondaryContainer,
                leading: Icon(libraryStatusIcon(status, entity.kind)),
                title: Text(status.labelFor(entity.kind)),
                trailing: entity.status == status
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, status),
              ),
            ),
          if (entity.status != LibraryItemStatus.unlisted) ...[
            const Divider(height: 16),
            ListTile(
              minTileHeight: 52,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              leading: const Icon(Icons.playlist_remove_rounded),
              title: Text(
                entity.kind == LibraryEntityKind.book
                    ? 'Remove from reading list'
                    : 'Remove from watchlist',
              ),
              onTap: () => Navigator.pop(context, LibraryItemStatus.unlisted),
            ),
          ],
        ],
      ),
    ),
  );
}
