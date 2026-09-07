import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'library_entity.dart';
import 'library_localization.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

IconData libraryStatusIcon(LibraryItemStatus status, LibraryEntityKind kind) =>
    switch (status) {
      LibraryItemStatus.unlisted => AppIcons.listAdd,
      LibraryItemStatus.planning => AppIcons.bookmark,
      LibraryItemStatus.active =>
        kind == LibraryEntityKind.book ? AppIcons.bookOpen : AppIcons.play,
      LibraryItemStatus.dropped => AppIcons.removeCircle,
      LibraryItemStatus.completed => AppIcons.checkCircle,
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
                      ? context.l10n.readingStatus
                      : context.l10n.watchStatus,
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
                leading: AppIcon(libraryStatusIcon(status, entity.kind)),
                title: Text(
                  localizedLibraryStatus(context.l10n, status, entity.kind),
                ),
                trailing: entity.status == status
                    ? const Icon(AppIcons.check)
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
              leading: const Icon(AppIcons.listRemove),
              title: Text(
                entity.kind == LibraryEntityKind.book
                    ? context.l10n.removeFromReadingList
                    : context.l10n.removeFromWatchlist,
              ),
              onTap: () => Navigator.pop(context, LibraryItemStatus.unlisted),
            ),
          ],
        ],
      ),
    ),
  );
}
