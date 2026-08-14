import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/models/user_collection.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../home/home_provider.dart';
import 'collection_visual.dart';
import 'collections_provider.dart';
import 'create_collection_sheet.dart';

class AddToCollectionSheet extends ConsumerStatefulWidget {
  const AddToCollectionSheet({super.key, required this.url, this.onAdded});

  final SavedUrl url;
  final VoidCallback? onAdded;

  @override
  ConsumerState<AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<AddToCollectionSheet> {
  Future<void> _createCollection() {
    return _createCollectionAndAddUrls(
      context,
      ref,
      [widget.url],
      openCollection: true,
      onCompleted: widget.onAdded,
    );
  }

  Future<void> _setCollectionMembership(
    UserCollection collection, {
    required bool add,
  }) async {
    final isar = ref.read(isarServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    if (add) {
      await isar.addUrlToCollection(
        collectionId: collection.id,
        urlId: widget.url.id,
      );
      widget.onAdded?.call();
    } else {
      await isar.removeUrlFromCollection(
        collectionId: collection.id,
        urlId: widget.url.id,
      );
    }
    _refreshCollection(collection.id);
    if (mounted) setState(() {});

    if (!add || !mounted) return;
    Navigator.pop(context);
    showAutoDismissSnackBarVia(
      messenger,
      SnackBar(
        content: Text('Added to ${collection.name}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await isar.removeUrlFromCollection(
              collectionId: collection.id,
              urlId: widget.url.id,
            );
            container.invalidate(collectionsListProvider);
            container.invalidate(collectionsSummaryProvider);
            container.invalidate(collectionUrlsProvider(collection.id));
          },
        ),
      ),
    );
  }

  void _refreshCollection(int collectionId) {
    ref.invalidate(collectionsListProvider);
    ref.invalidate(collectionsSummaryProvider);
    ref.invalidate(collectionUrlsProvider(collectionId));
  }

  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(collectionsListProvider);
    final tagFreq = ref.watch(tagOccurrenceMapProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add to collection', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              TitleResolver.resolveDetailTitle(
                widget.url,
                tagFrequency: tagFreq,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            collectionsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: ExpressiveLoadingIndicator()),
              ),
              error: (e, _) => Text('Could not load collections: $e'),
              data: (collections) {
                if (collections.isEmpty) {
                  return Column(
                    children: [
                      Text(
                        'No collections yet.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _createCollection,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('New collection'),
                      ),
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _createCollection,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New collection'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: (collections.length * 52.0).clamp(120, 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: collections.length,
                        itemBuilder: (ctx, i) {
                          final c = collections[i];
                          final inCollection = c.urlIds.contains(widget.url.id);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            minLeadingWidth: 44,
                            leading: CollectionVisual(
                              style: resolveCollectionVisual(c),
                              seed: c.name,
                              size: 40,
                              iconSize: 18,
                            ),
                            title: Text(c.name),
                            trailing: Checkbox(
                              value: inCollection,
                              onChanged: (value) => _setCollectionMembership(
                                c,
                                add: value == true,
                              ),
                            ),
                            onTap: () =>
                                _setCollectionMembership(c, add: !inCollection),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void showAddToCollectionSheet(
  BuildContext context,
  SavedUrl url, {
  VoidCallback? onAdded,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => AddToCollectionSheet(url: url, onAdded: onAdded),
  );
}

class AddManyToCollectionSheet extends ConsumerWidget {
  const AddManyToCollectionSheet({
    super.key,
    required this.urls,
    this.onCompleted,
  });

  final List<SavedUrl> urls;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(collectionsListProvider);
    final theme = Theme.of(context);
    final count = urls.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add to collection', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '$count ${count == 1 ? 'item' : 'items'} selected',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            collectionsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: ExpressiveLoadingIndicator()),
              ),
              error: (e, _) => Text('Could not load collections: $e'),
              data: (collections) {
                if (collections.isEmpty) {
                  return FilledButton.tonalIcon(
                    onPressed: () => _createCollectionAndAddUrls(
                      context,
                      ref,
                      urls,
                      onCompleted: onCompleted,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New collection'),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _createCollectionAndAddUrls(
                        context,
                        ref,
                        urls,
                        onCompleted: onCompleted,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New collection'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: (collections.length * 56.0).clamp(120, 360),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: collections.length,
                        itemBuilder: (ctx, i) {
                          final c = collections[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            minLeadingWidth: 44,
                            leading: CollectionVisual(
                              style: resolveCollectionVisual(c),
                              seed: c.name,
                              size: 40,
                              iconSize: 18,
                            ),
                            title: Text(c.name),
                            subtitle: Text('${c.urlIds.length} links'),
                            onTap: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await ref
                                  .read(isarServiceProvider)
                                  .addUrlsToCollection(
                                    collectionId: c.id,
                                    urlIds: urls.map((url) => url.id).toList(),
                                  );
                              ref.invalidate(collectionsListProvider);
                              ref.invalidate(collectionsSummaryProvider);
                              ref.invalidate(collectionUrlsProvider(c.id));
                              onCompleted?.call();
                              if (context.mounted) Navigator.pop(context);
                              showAutoDismissSnackBarVia(
                                messenger,
                                SnackBar(
                                  content: Text(
                                    urls.length == 1
                                        ? 'Added to ${c.name}'
                                        : 'Added ${urls.length} items to '
                                              '${c.name}',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void showAddManyToCollectionSheet(
  BuildContext context,
  List<SavedUrl> urls, {
  VoidCallback? onCompleted,
}) {
  if (urls.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) =>
        AddManyToCollectionSheet(urls: urls, onCompleted: onCompleted),
  );
}

Future<void> _createCollectionAndAddUrls(
  BuildContext context,
  WidgetRef ref,
  List<SavedUrl> urls, {
  bool openCollection = false,
  VoidCallback? onCompleted,
}) async {
  final collection = await showCreateCollectionSheet(context);
  if (collection == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);

  await ref
      .read(isarServiceProvider)
      .addUrlsToCollection(
        collectionId: collection.id,
        urlIds: urls.map((url) => url.id).toList(),
      );
  ref.invalidate(collectionsListProvider);
  ref.invalidate(collectionsSummaryProvider);
  ref.invalidate(collectionUrlsProvider(collection.id));
  onCompleted?.call();

  if (!context.mounted) return;
  Navigator.pop(context);
  showAutoDismissSnackBarVia(
    messenger,
    SnackBar(
      content: Text(
        urls.length == 1
            ? 'Added to ${collection.name}'
            : 'Added ${urls.length} items to ${collection.name}',
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
  if (openCollection) {
    context.push('/collections/${collection.id}');
  }
}
