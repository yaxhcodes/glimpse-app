import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/category_order_provider.dart';
import '../../features/home/home_provider.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import 'category_provider.dart';

class CategoryScreen extends ConsumerWidget {
  final String categoryName;

  const CategoryScreen({super.key, required this.categoryName});

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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
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
                      return SwipeableUrlCard(
                        key: ValueKey(url.id),
                        url: url,
                        onTap: () => context.push('/url/${url.id}'),
                        onDelete: (context, ref, url) async {
                          await deleteUrlWithUndo(context, ref, url);
                          ref.invalidate(categoryUrlsProvider(categoryName));
                        },
                        onChanged: () {
                          ref.invalidate(categoryUrlsProvider(categoryName));
                        },
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
