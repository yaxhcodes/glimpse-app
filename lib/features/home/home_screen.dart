import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/category_order_provider.dart';
import '../../shared/widgets/url_card.dart';
import '../../shared/widgets/category_chip.dart' show faviconUrl;
import '../../shared/widgets/loading_indicator.dart';
import 'home_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  Future<void> _deleteWithUndo(SavedUrl url) async {
    final isarService = ref.read(isarServiceProvider);
    await isarService.deleteUrl(url.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${url.title.isNotEmpty ? url.title : url.domain}"'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            // Re-save the exact same object (Isar put with existing ID restores it)
            await isarService.saveUrl(url);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urlsAsync = ref.watch(urlStreamProvider);
    final orderedCategories = ref.watch(orderedCategoriesProvider);
    final theme = Theme.of(context);

    // Keep category order in sync with the DB
    ref.listen(categoriesProvider, (_, next) {
      next.whenData((cats) {
        final names = cats.map((c) => c['category'] as String).toList();
        ref.read(categoryOrderProvider.notifier).sync(names);
      });
    });

    return Scaffold(
      body: urlsAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading your URLs...'),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (urls) {
          // Group URLs into sections
          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);
          final startOfWeek = startOfToday.subtract(const Duration(days: 7));

          final todayUrls = urls.where((u) => u.savedAt.isAfter(startOfToday)).toList();
          final weekUrls = urls.where((u) =>
              u.savedAt.isAfter(startOfWeek) && !u.savedAt.isAfter(startOfToday)).toList();
          final earlierUrls = urls.where((u) => !u.savedAt.isAfter(startOfWeek)).toList();

          // Build a flat list of items: null = section header, SavedUrl = card
          final sections = <_Section>[
            if (todayUrls.isNotEmpty) _Section('Today', todayUrls),
            if (weekUrls.isNotEmpty) _Section('This Week', weekUrls),
            if (earlierUrls.isNotEmpty) _Section('Earlier', earlierUrls),
          ];

          return CustomScrollView(
            slivers: [
              // ─── Large Material 3 title ────────────────────────
              SliverAppBar.large(
                title: const Text('Glimpse'),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add_link),
                    tooltip: 'Add URL',
                    onPressed: () => context.push('/add'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => context.push('/search'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),

              // ─── Categories ──────────────────────────────────
              SliverToBoxAdapter(
                child: orderedCategories.isEmpty
                    ? const SizedBox.shrink()
                    : SizedBox(
                        height: 48,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.only(left: 16, right: 24),
                          itemCount: orderedCategories.length,
                          itemBuilder: (context, index) {
                            final cat = orderedCategories[index];
                            final name = cat['category'] as String;
                            final emoji = cat['emoji'] as String;
                            final fav = faviconUrl(name);
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                onLongPress: () =>
                                    _showReorderSheet(context),
                                child: ActionChip(
                                  avatar: fav != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          child: CachedNetworkImage(
                                            imageUrl: fav,
                                            width: 18,
                                            height: 18,
                                            errorWidget: (_, _, _) =>
                                                Text(emoji),
                                          ),
                                        )
                                      : Text(emoji),
                                  label: Text(name),
                                  onPressed: () => context.push(
                                    '/category/${Uri.encodeComponent(name)}',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),

              // ─── Content ───────────────────────────────────────
              if (urls.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark_add_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text('No URLs saved yet',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to save your first URL',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                for (final section in sections) ...[
                  // Section header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
                      child: Text(
                        section.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  // Section items
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final url = section.urls[index];
                        return Dismissible(
                          key: ValueKey(url.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          onDismissed: (_) => _deleteWithUndo(url),
                          child: UrlCard(
                            savedUrl: url,
                            onTap: () => context.push('/url/${url.id}'),
                          ),
                        );
                      },
                      childCount: section.urls.length,
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _AskFab(onPressed: () => context.push('/ask')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
  void _showReorderSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CategoryReorderSheet(),
    );
  }
}

class _AskFab extends StatelessWidget {
  const _AskFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Material(
        color: colorScheme.primaryContainer,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(36),
        ),
        elevation: 4,
        shadowColor: Colors.black26,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/unown_bookmark_transparent.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Ask Glimpse',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryReorderSheet extends ConsumerStatefulWidget {
  const _CategoryReorderSheet();

  @override
  ConsumerState<_CategoryReorderSheet> createState() =>
      _CategoryReorderSheetState();
}

class _CategoryReorderSheetState
    extends ConsumerState<_CategoryReorderSheet> {
  Future<void> _deleteCategory(
      String name, int count) async {
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
    if (confirmed != true || !mounted) return;
    final isarService = ref.read(isarServiceProvider);
    await isarService.deleteUrlsByCategory(name);
    ref.read(categoryOrderProvider.notifier).remove(name);
    ref.invalidate(categoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final orderedCats = ref.watch(orderedCategoriesProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
              child: Row(
                children: [
                  Text('Edit Categories',
                      style: theme.textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Hold the handle to reorder · Tap 🗑️ to delete',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: orderedCats.isEmpty
                  ? const Center(child: Text('No categories yet'))
                  : ReorderableListView.builder(
                      scrollController: scrollController,
                      itemCount: orderedCats.length,
                      onReorder: (oldIndex, newIndex) {
                        ref
                            .read(categoryOrderProvider.notifier)
                            .reorder(oldIndex, newIndex);
                      },
                      itemBuilder: (ctx, index) {
                        final cat = orderedCats[index];
                        final name = cat['category'] as String;
                        final emoji = cat['emoji'] as String;
                        final count = cat['count'] as int;
                        final fav = faviconUrl(name);
                        return ListTile(
                          key: ValueKey(name),
                          leading: fav != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: CachedNetworkImage(
                                    imageUrl: fav,
                                    width: 28,
                                    height: 28,
                                    errorWidget: (_, _, _) => Text(
                                        emoji,
                                        style: const TextStyle(
                                            fontSize: 22)),
                                  ),
                                )
                              : Text(emoji,
                                  style:
                                      const TextStyle(fontSize: 22)),
                          title: Text(name),
                          subtitle: Text(
                              '$count ${count == 1 ? 'link' : 'links'}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color:
                                        theme.colorScheme.error),
                                onPressed: () =>
                                    _deleteCategory(name, count),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Section {
  final String label;
  final List<SavedUrl> urls;
  const _Section(this.label, this.urls);
}

