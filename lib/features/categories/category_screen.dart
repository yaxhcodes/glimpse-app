import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/bulk_selection_provider.dart';
import '../../core/providers/pinned_urls_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/category_order_provider.dart';
import '../../features/home/home_provider.dart';
import '../../features/collections/collections_provider.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/bulk_selection_toolbar.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import 'category_provider.dart';
import '../../l10n/l10n.dart';

class CategoryScreen extends ConsumerWidget {
  final String categoryName;

  const CategoryScreen({super.key, required this.categoryName});

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    String name,
    List<SavedUrl> urls,
  ) async {
    final ids = urls.map((url) => url.id).toList(growable: false);
    final pinned = ref
        .read(pinnedUrlsProvider)
        .where(ids.contains)
        .toList(growable: false);
    final isar = ref.read(isarServiceProvider);
    await isar.moveUrlsToBin(ids);
    await ref.read(pinnedUrlsProvider.notifier).unpinAll(pinned);
    ref.read(categoryOrderProvider.notifier).remove(name);
    ref.invalidate(categoriesProvider);
    ref.invalidate(collectionsSummaryProvider);
    if (!context.mounted) return;
    showAutoDismissSnackBar(
      context,
      SnackBar(
        content: const Text('Moved to Bin'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await isar.restoreUrlsFromBin(ids);
            for (final id in pinned) {
              await ref.read(pinnedUrlsProvider.notifier).pin(id);
            }
            ref.invalidate(categoriesProvider);
            ref.invalidate(collectionsSummaryProvider);
          },
        ),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlsAsync = ref.watch(categoryUrlsProvider(categoryName));
    final cs = Theme.of(context).colorScheme;
    final selectionScope = 'category-$categoryName';
    final selectionState = ref.watch(bulkSelectionProvider(selectionScope));
    final selectionNotifier = ref.read(
      bulkSelectionProvider(selectionScope).notifier,
    );
    final visibleUrls = urlsAsync.valueOrNull ?? [];
    final selectedUrls = visibleUrls
        .where((url) => selectionState.selectedIds.contains(url.id))
        .toList();

    return PopScope(
      canPop: !selectionState.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectionState.isActive) {
          selectionNotifier.clear();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        body: urlsAsync.when(
          loading: () => CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(
                  localizedCategoryLabel(context.l10n, categoryName),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SliverFillRemaining(child: LoadingIndicator()),
            ],
          ),
          error: (err, stack) => CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(
                  categoryName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              SliverFillRemaining(child: Center(child: Text('Error: $err'))),
            ],
          ),
          data: (urls) {
            final canDeleteStoredCategory =
                urls.isNotEmpty &&
                urls.every(
                  (url) => url.effectiveCategories.contains(categoryName),
                );
            if (selectionState.enabled &&
                selectedUrls.length != selectionState.count) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                selectionNotifier.pruneToVisible(urls.map((url) => url.id));
              });
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar.large(
                  title: selectionState.isActive
                      ? BulkSelectionTitle(count: selectedUrls.length)
                      : Text(
                          categoryName,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                  leading: selectionState.isActive
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Exit selection',
                          onPressed: selectionNotifier.clear,
                        )
                      : null,
                  actions: selectionState.isActive
                      ? [
                          BulkSelectionActionButtons(
                            scope: selectionScope,
                            selectedUrls: selectedUrls,
                            visibleUrls: urls,
                            onDone: () {
                              selectionNotifier.clear();
                              ref.invalidate(
                                categoryUrlsProvider(categoryName),
                              );
                            },
                          ),
                        ]
                      : [
                          if (canDeleteStoredCategory)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete category',
                              onPressed: () => _deleteCategory(
                                context,
                                ref,
                                categoryName,
                                urls,
                              ),
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
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final url = urls[index];
                      final allIds = urls.map((u) => u.id).toList();
                      return SwipeableUrlCard(
                        key: ValueKey(url.id),
                        url: url,
                        selectionMode: selectionState.isActive,
                        isSelected: selectionState.isSelected(url.id),
                        onSelectionStart: () =>
                            selectionNotifier.startWith(url.id),
                        onSelectionToggle: () =>
                            selectionNotifier.toggle(url.id),
                        onTap: () =>
                            context.push('/url/${url.id}', extra: allIds),
                        onDelete: (context, ref, url) async {
                          await deleteUrlWithUndo(context, ref, url);
                          ref.invalidate(categoryUrlsProvider(categoryName));
                        },
                        onChanged: () {
                          ref.invalidate(categoryUrlsProvider(categoryName));
                        },
                      );
                    }, childCount: urls.length),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
