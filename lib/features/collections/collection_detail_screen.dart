import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/models/user_collection.dart';
import '../../core/providers/bulk_selection_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/swipe_preferences_provider.dart';
import '../../shared/widgets/bulk_selection_toolbar.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import 'collection_visual.dart';
import 'collections_provider.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final int collectionId;

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(collectionMetaProvider(widget.collectionId));
    final urlsAsync = ref.watch(collectionUrlsProvider(widget.collectionId));
    final theme = Theme.of(context);
    final selectionScope = 'collection-${widget.collectionId}';
    final selectionState = ref.watch(bulkSelectionProvider(selectionScope));
    final selectionNotifier = ref.read(
      bulkSelectionProvider(selectionScope).notifier,
    );
    final visibleUrls = urlsAsync.valueOrNull ?? const <SavedUrl>[];
    final selectedUrls = visibleUrls
        .where((url) => selectionState.selectedIds.contains(url.id))
        .toList();

    final title = metaAsync.maybeWhen(
      data: (c) => c?.name ?? 'Collection',
      orElse: () => 'Collection',
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: selectionState.isActive
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Exit selection',
                onPressed: selectionNotifier.clear,
              )
            : null,
        title: selectionState.isActive
            ? BulkSelectionTitle(count: selectedUrls.length)
            : Text(title),
        actions: selectionState.isActive
            ? [
                BulkSelectionActionButtons(
                  scope: selectionScope,
                  selectedUrls: selectedUrls,
                  visibleUrls: visibleUrls,
                  onDone: () {
                    selectionNotifier.clear();
                    ref.invalidate(collectionUrlsProvider(widget.collectionId));
                  },
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Rename',
                  onPressed: () => _rename(context, metaAsync.valueOrNull),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'select':
                        final urls = urlsAsync.valueOrNull ?? [];
                        if (urls.isNotEmpty) {
                          selectionNotifier.startWith(urls.first.id);
                        }
                        break;
                      case 'delete':
                        await _confirmDeleteCollection(context);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if ((urlsAsync.valueOrNull ?? []).isNotEmpty)
                      const PopupMenuItem(
                        value: 'select',
                        child: ListTile(
                          leading: Icon(Icons.check_circle_outline),
                          title: Text('Select'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete collection'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: urlsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (urls) {
          if (urls.isEmpty) {
            return Center(
              child: Text(
                'No links in this collection yet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: urls.length,
            itemBuilder: (_, i) {
              final url = urls[i];
              return SwipeableUrlCard(
                key: ValueKey(url.id),
                url: url,
                leftSwipeAction: SwipeActionType.delete,
                rightSwipeAction: SwipeActionType.none,
                selectionMode: selectionState.isActive,
                isSelected: selectionState.isSelected(url.id),
                onSelectionStart: () => selectionNotifier.startWith(url.id),
                onSelectionToggle: () => selectionNotifier.toggle(url.id),
                onDelete: (context, ref, url) {
                  return removeUrlFromCollectionWithUndo(
                    context: context,
                    ref: ref,
                    url: url,
                    collectionId: widget.collectionId,
                  );
                },
                onChanged: () {
                  ref.invalidate(collectionUrlsProvider(widget.collectionId));
                },
                onTap: () => context.push('/url/${url.id}'),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteCollection(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete collection?'),
        content: const Text(
          'Links stay in your library; only this group is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(isarServiceProvider).deleteCollection(widget.collectionId);
      ref.invalidate(collectionsListProvider);
      ref.invalidate(collectionsSummaryProvider);
      ref.invalidate(collectionMetaProvider(widget.collectionId));
      ref.invalidate(collectionUrlsProvider(widget.collectionId));
      if (context.mounted) context.pop();
    }
  }

  Future<void> _rename(BuildContext context, dynamic collection) async {
    if (collection == null) return;
    final controller = TextEditingController(text: collection.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Collection name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      final visual = resolveCollectionVisualStyle(
        null,
        name: result,
        description: collection.description,
      );
      await ref
          .read(isarServiceProvider)
          .updateCollection(
            UserCollection()
              ..id = collection.id
              ..name = result
              ..emoji = visual.key
              ..description = collection.description
              ..createdAt = collection.createdAt
              ..urlIds = collection.urlIds,
          );
      ref.invalidate(collectionsListProvider);
      ref.invalidate(collectionsSummaryProvider);
      ref.invalidate(collectionMetaProvider(widget.collectionId));
    }
    controller.dispose();
  }
}
