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
import '../add_url/add_url_provider.dart';
import 'home_provider.dart';
import 'rediscovery_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > 0;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

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
    final addUrlStatus = ref.watch(addUrlProvider.select((s) => s.status));
    final isAddingUrl = addUrlStatus != AddUrlStatus.idle &&
        addUrlStatus != AddUrlStatus.done &&
        addUrlStatus != AddUrlStatus.error;
    final theme = Theme.of(context);

    // Keep category order in sync with the DB
    ref.listen(categoriesProvider, (_, next) {
      next.whenData((cats) {
        final names = cats.map((c) => c['category'] as String).toList();
        ref.read(categoryOrderProvider.notifier).sync(names);
      });
    });

    return Scaffold(
      body: Stack(
        children: [
          urlsAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading your URLs...'),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_tethering_error_rounded,
                  size: 52,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not load your library',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$err',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: () => ref.invalidate(urlStreamProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
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

          return RefreshIndicator(
            edgeOffset: 60,
            onRefresh: () async {
              ref.invalidate(urlStreamProvider);
              ref.invalidate(categoriesProvider);
              await ref.read(urlStreamProvider.future);
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                centerTitle: false,
                title: Text(
                  'Glimpse',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add_link_rounded),
                    tooltip: 'Add URL',
                    onPressed: () => context.push('/add'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),

              if (urls.isNotEmpty)
                const SliverToBoxAdapter(child: RediscoverySection()),

              if (orderedCategories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                        child: Text(
                          'Filter by source',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: orderedCategories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final cat = orderedCategories[index];
                            final name = cat['category'] as String;
                            final emoji = cat['emoji'] as String;
                            final fav = faviconUrl(name);
                            return GestureDetector(
                              onLongPress: () => _showReorderSheet(context),
                              child: FilterChip(
                                showCheckmark: false,
                                avatar: fav != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
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
                                selected: false,
                                onSelected: (_) => context.push(
                                  '/category/${Uri.encodeComponent(name)}',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── Content ───────────────────────────────────────

              // Skeleton card while a URL is being processed
              if (isAddingUrl)
                const SliverToBoxAdapter(child: UrlCardSkeleton()),

              if (urls.isEmpty && !isAddingUrl)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Icon(
                                Icons.add_link_rounded,
                                size: 48,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Your link library is empty',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Save articles, videos, and threads in one tap. '
                            'Glimpse fetches a preview and sorts them for you.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: () => context.push('/add'),
                            icon: const Icon(Icons.add_link),
                            label: const Text('Save a link'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/search'),
                            icon: const Icon(Icons.search),
                            label: const Text('Search (when you have links)'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (urls.isNotEmpty) ...[
                for (final section in sections) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
                      child: Text(
                        section.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
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
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ],
            ),
          );
        },
          ),
          // Status-bar scrim: fades in as soon as the user scrolls so the
          // system icons remain readable against scrolled content.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isScrolled ? 1.0 : 0.0,
                child: Container(
                  height: MediaQuery.of(context).padding.top + 16,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _showReorderSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _CategoryReorderSheet(),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
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
