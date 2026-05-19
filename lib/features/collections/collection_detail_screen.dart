import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_collection.dart';
import '../../core/providers/service_providers.dart';
import '../../shared/widgets/url_card.dart';
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

    final title = metaAsync.maybeWhen(
      data: (c) => c?.name ?? 'Collection',
      orElse: () => 'Collection',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename',
            onPressed: () => _rename(context, metaAsync.valueOrNull),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete collection',
            onPressed: () async {
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
                await ref
                    .read(isarServiceProvider)
                    .deleteCollection(widget.collectionId);
                ref.invalidate(collectionsListProvider);
                ref.invalidate(collectionsSummaryProvider);
                ref.invalidate(
                    collectionMetaProvider(widget.collectionId));
                ref.invalidate(
                    collectionUrlsProvider(widget.collectionId));
                if (context.mounted) context.pop();
              }
            },
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
              return Dismissible(
                key: ValueKey(url.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  color: theme.colorScheme.error,
                  child: Icon(Icons.remove_circle_outline,
                      color: theme.colorScheme.onError),
                ),
                confirmDismiss: (_) async {
                  return showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remove link?'),
                      content: Text(
                        '"${url.title}" will be removed from this collection. It stays in your library.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) async {
                  await ref.read(isarServiceProvider).removeUrlFromCollection(
                        collectionId: widget.collectionId,
                        urlId: url.id,
                      );
                  ref.invalidate(collectionsListProvider);
                  ref.invalidate(collectionsSummaryProvider);
                  ref.invalidate(
                      collectionUrlsProvider(widget.collectionId));
                },
                child: UrlCard(
                  savedUrl: url,
                  onTap: () => context.push('/url/${url.id}'),
                ),
              );
            },
          );
        },
      ),
    );
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
      await ref.read(isarServiceProvider).updateCollection(
        UserCollection()
          ..id = collection.id
          ..name = result
          ..emoji = collection.emoji
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
