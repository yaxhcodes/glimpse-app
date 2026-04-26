import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/category_order_provider.dart';
import '../../features/home/home_provider.dart';
import '../../core/models/saved_url.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/url_card.dart';
import 'category_provider.dart';

class CategoryScreen extends ConsumerWidget {
  final String categoryName;

  const CategoryScreen({super.key, required this.categoryName});

  Future<void> _deleteUrlWithUndo(
      BuildContext context, WidgetRef ref, SavedUrl url) async {
    final isarService = ref.read(isarServiceProvider);
    await isarService.deleteUrl(url.id);
    ref.invalidate(categoryUrlsProvider(categoryName));
    ref.invalidate(categoriesProvider);
    if (!context.mounted) return;
    final tagFreq = ref.read(tagOccurrenceMapProvider);
    var label = TitleResolver.resolve(url, tagFrequency: tagFreq);
    if (label.length > 50) label = '${label.substring(0, 50)}…';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "$label"'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await isarService.saveUrl(url);
              ref.invalidate(categoryUrlsProvider(categoryName));
              ref.invalidate(categoriesProvider);
          },
        ),
      ),
    );
  }

  Future<void> _deleteCategory(
      BuildContext context, WidgetRef ref, String name, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: Text(
          'This will permanently delete all $count ${count == 1 ? 'URL' : 'URLs'} in this category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(isarServiceProvider).deleteUrlsByCategory(name);
    ref.read(categoryOrderProvider.notifier).remove(name);
    ref.invalidate(categoriesProvider);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlsAsync = ref.watch(categoryUrlsProvider(categoryName));

    return Scaffold(
      body: urlsAsync.when(
        loading: () => CustomScrollView(
          slivers: [
            SliverAppBar.large(title: Text(categoryName)),
            const SliverFillRemaining(child: LoadingIndicator()),
          ],
        ),
        error: (err, stack) => CustomScrollView(
          slivers: [
            SliverAppBar.large(title: Text(categoryName)),
            SliverFillRemaining(child: Center(child: Text('Error: $err'))),
          ],
        ),
        data: (urls) {
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(categoryName),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete category',
                    onPressed: () => _deleteCategory(
                        context, ref, categoryName, urls.length),
                  ),
                ],
              ),
              if (urls.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No URLs in this category')),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      '${urls.length} ${urls.length == 1 ? 'link' : 'links'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final url = urls[index];
                      return Dismissible(
                        key: ValueKey(url.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                        onDismissed: (_) =>
                            _deleteUrlWithUndo(context, ref, url),
                        child: UrlCard(
                          savedUrl: url,
                          onTap: () => context.push('/url/${url.id}'),
                        ),
                      );
                    },
                    childCount: urls.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ],
          );
        },
      ),
    );
  }
}
