import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/bulk_selection_provider.dart';
import '../../core/providers/pinned_urls_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../features/collections/add_to_collection_sheet.dart';
import '../../features/collections/collections_provider.dart';
import '../../features/home/home_provider.dart';
import 'app_snackbar.dart';

class BulkSelectionTitle extends StatelessWidget {
  const BulkSelectionTitle({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: Text('$count', key: ValueKey(count)),
    );
  }
}

class BulkSelectionActionButtons extends ConsumerWidget {
  const BulkSelectionActionButtons({
    super.key,
    required this.scope,
    required this.selectedUrls,
    required this.visibleUrls,
    required this.onDone,
    this.onViewPinned,
    this.onMoveToCollection,
  });

  final String scope;
  final List<SavedUrl> selectedUrls;
  final List<SavedUrl> visibleUrls;
  final VoidCallback onDone;
  final VoidCallback? onViewPinned;
  final Future<void> Function()? onMoveToCollection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final readLabel = _readActionLabel(selectedUrls);
    final pinnedIds = ref.watch(pinnedUrlsProvider);
    final pinLabel = _pinActionLabel(selectedUrls, pinnedIds);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: EdgeInsets.zero,
          tooltip: 'Select all',
          icon: const Icon(Icons.select_all_rounded),
          onPressed: visibleUrls.isEmpty
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(bulkSelectionProvider(scope).notifier)
                      .selectAll(visibleUrls.map((url) => url.id));
                },
        ),
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: EdgeInsets.zero,
          tooltip: readLabel,
          icon: Icon(_readActionIcon(selectedUrls)),
          onPressed: selectedUrls.isEmpty
              ? null
              : () => _markReadState(context, ref, selectedUrls, onDone),
        ),
        PopupMenuButton<_BulkSelectionMenuAction>(
          enabled: selectedUrls.isNotEmpty,
          tooltip: 'More selection actions',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (action) async {
            switch (action) {
              case _BulkSelectionMenuAction.addToCollection:
                showAddManyToCollectionSheet(
                  context,
                  selectedUrls,
                  onCompleted: onDone,
                );
                break;
              case _BulkSelectionMenuAction.moveToCollection:
                await onMoveToCollection?.call();
                break;
              case _BulkSelectionMenuAction.pin:
                _pinSelected(context, ref, selectedUrls, onDone, onViewPinned);
                break;
              case _BulkSelectionMenuAction.delete:
                _confirmDelete(context, ref, selectedUrls, onDone);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _BulkSelectionMenuAction.addToCollection,
              child: ListTile(
                leading: Icon(Icons.create_new_folder_outlined),
                title: Text('Add to collection'),
              ),
            ),
            if (onMoveToCollection != null)
              const PopupMenuItem(
                value: _BulkSelectionMenuAction.moveToCollection,
                child: ListTile(
                  leading: Icon(Icons.drive_file_move_outline),
                  title: Text('Move to collection'),
                ),
              ),
            PopupMenuItem(
              value: _BulkSelectionMenuAction.pin,
              child: ListTile(
                leading: Icon(_pinActionIcon(selectedUrls, pinnedIds)),
                title: Text(pinLabel),
              ),
            ),
            PopupMenuItem(
              value: _BulkSelectionMenuAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                title: Text('Delete', style: TextStyle(color: cs.error)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _BulkSelectionMenuAction { addToCollection, moveToCollection, pin, delete }

String _readActionLabel(List<SavedUrl> urls) {
  if (urls.isEmpty) return 'Mark read';
  final read = urls.where((url) => url.openedAt != null).length;
  if (read == 0) return 'Mark Read';
  if (read == urls.length) return 'Mark Unread';
  return 'Toggle Read Status';
}

IconData _readActionIcon(List<SavedUrl> urls) {
  if (urls.isNotEmpty && urls.every((url) => url.openedAt != null)) {
    return Icons.mark_email_unread_outlined;
  }
  return Icons.mark_email_read_outlined;
}

String _pinActionLabel(List<SavedUrl> urls, List<int> pinnedIds) {
  if (urls.isNotEmpty && urls.every((url) => pinnedIds.contains(url.id))) {
    return 'Unpin';
  }
  return 'Pin';
}

IconData _pinActionIcon(List<SavedUrl> urls, List<int> pinnedIds) {
  if (urls.isNotEmpty && urls.every((url) => pinnedIds.contains(url.id))) {
    return Icons.push_pin_rounded;
  }
  return Icons.push_pin_outlined;
}

Future<void> _markReadState(
  BuildContext context,
  WidgetRef ref,
  List<SavedUrl> urls,
  VoidCallback onDone,
) async {
  final isar = ref.read(isarServiceProvider);
  final allRead = urls.every((url) => url.openedAt != null);
  final allUnread = urls.every((url) => url.openedAt == null);
  final now = DateTime.now();
  for (final url in urls) {
    if (allRead) {
      await isar.clearOpenedAt(url.id);
    } else if (allUnread) {
      await isar.updateOpenedAt(url.id, now);
    } else if (url.openedAt == null) {
      await isar.updateOpenedAt(url.id, now);
    } else {
      await isar.clearOpenedAt(url.id);
    }
  }
  onDone();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(_readActionLabel(urls).replaceFirst('Mark', 'Marked')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
}

Future<void> _pinSelected(
  BuildContext context,
  WidgetRef ref,
  List<SavedUrl> urls,
  VoidCallback onDone,
  VoidCallback? onViewPinned,
) async {
  final currentPins = ref.read(pinnedUrlsProvider);
  final allPinned = urls.every((url) => currentPins.contains(url.id));
  if (allPinned) {
    final notifier = ref.read(pinnedUrlsProvider.notifier);
    for (final url in urls) {
      await notifier.unpin(url.id);
    }
    onDone();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${urls.length} ${urls.length == 1 ? 'item' : 'items'} unpinned',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    return;
  }

  final newIds = urls
      .map((url) => url.id)
      .where((id) => !currentPins.contains(id))
      .toList();
  if (currentPins.length + newIds.length > maxPinnedUrls) {
    if (!context.mounted) return;
    _showPinLimitReached(context, onViewPinned);
    return;
  }

  final notifier = ref.read(pinnedUrlsProvider.notifier);
  for (final id in newIds) {
    await notifier.pin(id);
  }
  onDone();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          '${urls.length} ${urls.length == 1 ? 'item' : 'items'} pinned',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
}

void _showPinLimitReached(BuildContext context, VoidCallback? onViewPinned) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pin limit reached.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onViewPinned?.call();
              },
              icon: const Icon(Icons.vertical_align_top_rounded),
              label: const Text('View Pinned Items'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  List<SavedUrl> urls,
  VoidCallback onDone,
) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final count = urls.length;
      final cs = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete $count ${count == 1 ? 'item' : 'items'}?',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  if (confirmed != true) return;

  final isar = ref.read(isarServiceProvider);
  final pins = ref.read(pinnedUrlsProvider);
  for (final url in urls) {
    await isar.deleteUrl(url.id);
    if (pins.contains(url.id)) {
      await ref.read(pinnedUrlsProvider.notifier).unpin(url.id);
    }
  }
  ref.invalidate(categoriesProvider);
  ref.invalidate(collectionsListProvider);
  ref.invalidate(collectionsSummaryProvider);
  onDone();

  if (!context.mounted) return;
  showAutoDismissSnackBar(
    context,
    SnackBar(
      content: const Text('Deleted'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          for (final url in urls) {
            await isar.saveUrl(url);
            if (pins.contains(url.id)) {
              await ref.read(pinnedUrlsProvider.notifier).pin(url.id);
            }
          }
          ref.invalidate(categoriesProvider);
          ref.invalidate(collectionsListProvider);
          ref.invalidate(collectionsSummaryProvider);
        },
      ),
    ),
  );
}
