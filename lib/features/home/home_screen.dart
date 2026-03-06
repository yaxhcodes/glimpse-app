import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
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
    final categoriesAsync = ref.watch(categoriesProvider);
    final theme = Theme.of(context);

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
                child: categoriesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (categories) {
                    if (categories.isEmpty) return const SizedBox.shrink();
                    return SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final name = cat['category'] as String;
                          final emoji = cat['emoji'] as String;
                          final fav = faviconUrl(name);
                          return ActionChip(
                            avatar: fav != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: CachedNetworkImage(
                                      imageUrl: fav,
                                      width: 18,
                                      height: 18,
                                      errorWidget: (_, _, _) => Text(emoji),
                                    ),
                                  )
                                : Text(emoji),
                            label: Text(name),
                            onPressed: () => context.push(
                              '/category/${Uri.encodeComponent(name)}',
                            ),
                          );
                        },
                      ),
                    );
                  },
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
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/add'),
          icon: const Icon(Icons.add),
          label: const Text('Add URL'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _Section {
  final String label;
  final List<SavedUrl> urls;
  const _Section(this.label, this.urls);
}

