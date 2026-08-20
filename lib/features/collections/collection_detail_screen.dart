import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/models/user_collection.dart';
import '../../core/providers/bulk_selection_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/swipe_preferences_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/bulk_selection_toolbar.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import '../add_url/add_url_screen.dart';
import 'collections_provider.dart';
import 'collections_preferences_provider.dart';
import 'create_collection_sheet.dart';
import 'move_collection_contents_sheet.dart';

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
    final collection = metaAsync.valueOrNull;
    final selectedUrls = visibleUrls
        .where((url) => selectionState.selectedIds.contains(url.id))
        .toList();

    final title = metaAsync.maybeWhen(
      data: (c) => c?.name ?? context.l10n.collection,
      orElse: () => context.l10n.collection,
    );
    final description = collection?.description?.trim();

    return PopScope(
      canPop: !selectionState.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectionState.isActive) {
          selectionNotifier.clear();
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: selectionState.isActive
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: context.l10n.exitSelection,
                  onPressed: selectionNotifier.clear,
                )
              : null,
          title: selectionState.isActive
              ? BulkSelectionTitle(count: selectedUrls.length)
              : _CollectionDetailTitle(
                  title: title,
                  description: description == null || description.isEmpty
                      ? null
                      : description,
                ),
          actions: selectionState.isActive
              ? [
                  BulkSelectionActionButtons(
                    scope: selectionScope,
                    selectedUrls: selectedUrls,
                    visibleUrls: visibleUrls,
                    onMoveToCollection: collection == null
                        ? null
                        : () => _moveSelectedUrls(
                            context,
                            collection,
                            selectedUrls,
                            selectionNotifier,
                          ),
                    onDone: () {
                      selectionNotifier.clear();
                      ref.invalidate(
                        collectionUrlsProvider(widget.collectionId),
                      );
                    },
                  ),
                ]
              : [
                  IconButton(
                    icon: const AppIcon(AppIcons.addLink),
                    tooltip: context.l10n.addLink,
                    onPressed: collection == null
                        ? null
                        : () => context.push(
                            '/add',
                            extra: ManualAddArguments(
                              initialCollection: collection,
                            ),
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: context.l10n.editCollection,
                    onPressed: () => _edit(context, metaAsync.valueOrNull),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'delete':
                          await _confirmDeleteCollection(
                            context,
                            collection?.name,
                          );
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: Text(context.l10n.deleteCollection),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
        ),
        body: urlsAsync.when(
          loading: () => const Center(child: ExpressiveLoadingIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (urls) {
            if (urls.isEmpty) {
              return Center(
                child: Text(
                  context.l10n.noLinksInCollection,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            final allIds = urls.map((u) => u.id).toList();
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
                  onTap: () => context.push('/url/${url.id}', extra: allIds),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _moveSelectedUrls(
    BuildContext context,
    UserCollection source,
    List<SavedUrl> selectedUrls,
    BulkSelectionNotifier selectionNotifier,
  ) async {
    final collections = await ref.read(collectionsSummaryProvider.future);
    final targets = collections
        .where((summary) => summary.collection.id != source.id)
        .toList(growable: false);
    if (!context.mounted) return;
    if (targets.isEmpty) {
      showAutoDismissSnackBar(
        context,
        const SnackBar(
          content: Text('Create another collection before moving links'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final target = await showMoveUrlsToCollectionSheet(
      context,
      sourceCollectionName: source.name,
      selectedCount: selectedUrls.length,
      targets: targets,
    );
    if (target == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final movedCount = await ref
        .read(isarServiceProvider)
        .moveUrlsBetweenCollections(
          sourceCollectionId: source.id,
          targetCollectionId: target.id,
          urlIds: selectedUrls.map((url) => url.id),
        );
    selectionNotifier.clear();
    ref.invalidate(collectionsListProvider);
    ref.invalidate(collectionsSummaryProvider);
    ref.invalidate(collectionMetaProvider(source.id));
    ref.invalidate(collectionUrlsProvider(source.id));
    ref.invalidate(collectionMetaProvider(target.id));
    ref.invalidate(collectionUrlsProvider(target.id));
    if (!context.mounted) return;

    showAutoDismissSnackBarVia(
      messenger,
      SnackBar(
        content: Text(
          movedCount == 0
              ? 'No links moved'
              : 'Moved $movedCount ${movedCount == 1 ? 'link' : 'links'} to '
                    '${target.name}',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmDeleteCollection(
    BuildContext context,
    String? collectionName,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          collectionName == null || collectionName.trim().isEmpty
              ? context.l10n.deleteCollection
              : context.l10n.deleteCollectionNamed(collectionName),
        ),
        content: Text(context.l10n.deleteCollectionDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(isarServiceProvider).deleteCollection(widget.collectionId);
      await ref.read(collectionsPreferencesProvider.notifier).removeCollections(
        [widget.collectionId],
      );
      ref.invalidate(collectionsListProvider);
      ref.invalidate(collectionsSummaryProvider);
      ref.invalidate(collectionMetaProvider(widget.collectionId));
      ref.invalidate(collectionUrlsProvider(widget.collectionId));
      if (context.mounted) context.pop();
    }
  }

  Future<void> _edit(BuildContext context, UserCollection? collection) async {
    if (collection == null) return;
    final updated = await showCreateCollectionSheet(
      context,
      collection: collection,
    );
    if (updated == null) return;
    ref.invalidate(collectionsListProvider);
    ref.invalidate(collectionsSummaryProvider);
    ref.invalidate(collectionMetaProvider(widget.collectionId));
  }
}

class _CollectionDetailTitle extends StatelessWidget {
  const _CollectionDetailTitle({required this.title, this.description});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (description != null) ...[
          const SizedBox(height: 2),
          Text(
            description!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
