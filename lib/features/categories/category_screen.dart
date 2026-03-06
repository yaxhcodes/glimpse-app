import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/url_card.dart';
import '../../shared/widgets/loading_indicator.dart';
import 'category_provider.dart';

class CategoryScreen extends ConsumerWidget {
  final String categoryName;

  const CategoryScreen({super.key, required this.categoryName});

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
              SliverAppBar.large(title: Text(categoryName)),
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
                      return UrlCard(
                        savedUrl: url,
                        onTap: () => context.push('/url/${url.id}'),
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
