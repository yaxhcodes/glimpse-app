import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/title_resolver.dart';
import '../home/home_provider.dart';
import 'collection_visual.dart';
import 'collections_provider.dart';
import 'create_collection_sheet.dart';

class AddToCollectionSheet extends ConsumerStatefulWidget {
  const AddToCollectionSheet({super.key, required this.url});

  final SavedUrl url;

  @override
  ConsumerState<AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<AddToCollectionSheet> {
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
            Text(
              'Add to collection',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              TitleResolver.resolve(widget.url, tagFrequency: tagFreq),
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
                child: Center(child: CircularProgressIndicator()),
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
                      FilledButton.tonal(
                        onPressed: () async {
                          final collection =
                              await showCreateCollectionSheet(context);
                          if (collection == null) return;
                          if (!context.mounted) return;
                          await ref.read(isarServiceProvider).addUrlToCollection(
                                collectionId: collection.id,
                                urlId: widget.url.id,
                              );
                          ref.invalidate(collectionsListProvider);
                          ref.invalidate(collectionsSummaryProvider);
                          ref.invalidate(collectionUrlsProvider(collection.id));
                          if (context.mounted) {
                            Navigator.pop(context);
                            context.push('/collections/${collection.id}');
                          }
                        },
                        child: const Text('New collection'),
                      ),
                    ],
                  );
                }
                return SizedBox(
                  height: (collections.length * 52.0).clamp(120, 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: collections.length,
                    itemBuilder: (ctx, i) {
                      final c = collections[i];
                      final inCollection =
                          c.urlIds.contains(widget.url.id);
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
                          onChanged: (v) async {
                          final isar = ref.read(isarServiceProvider);
                          if (v == true) {
                            await isar.addUrlToCollection(
                              collectionId: c.id,
                              urlId: widget.url.id,
                            );
                          } else {
                            await isar.removeUrlFromCollection(
                              collectionId: c.id,
                              urlId: widget.url.id,
                            );
                          }
                          ref.invalidate(collectionsListProvider);
                          ref.invalidate(collectionsSummaryProvider);
                          ref.invalidate(
                            collectionUrlsProvider(c.id),
                          );
                          setState(() {});
                          },
                        ),
                        onTap: () async {
                          final isar = ref.read(isarServiceProvider);
                          if (inCollection) {
                            await isar.removeUrlFromCollection(
                              collectionId: c.id,
                              urlId: widget.url.id,
                            );
                          } else {
                            await isar.addUrlToCollection(
                              collectionId: c.id,
                              urlId: widget.url.id,
                            );
                          }
                          ref.invalidate(collectionsListProvider);
                          ref.invalidate(collectionsSummaryProvider);
                          ref.invalidate(collectionUrlsProvider(c.id));
                          setState(() {});
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void showAddToCollectionSheet(BuildContext context, SavedUrl url) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => AddToCollectionSheet(url: url),
  );
}
