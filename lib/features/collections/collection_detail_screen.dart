import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/service_providers.dart';
import '../../shared/widgets/url_card.dart';
import 'collections_provider.dart';

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final int collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(collectionMetaProvider(collectionId));
    final urlsAsync = ref.watch(collectionUrlsProvider(collectionId));
    final theme = Theme.of(context);

    final title = metaAsync.maybeWhen(
      data: (c) => c != null ? '${c.emoji} ${c.name}' : 'Collection',
      orElse: () => 'Collection',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
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
                await ref.read(isarServiceProvider).deleteCollection(collectionId);
                ref.invalidate(collectionsListProvider);
                ref.invalidate(collectionMetaProvider(collectionId));
                ref.invalidate(collectionUrlsProvider(collectionId));
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
              return UrlCard(
                savedUrl: url,
                onTap: () => context.push('/url/${url.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
