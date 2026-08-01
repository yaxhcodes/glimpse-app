import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/bulk_selection_provider.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/bulk_selection_toolbar.dart';
import '../../shared/widgets/category_chip.dart' show faviconUrl;
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/premium_design_system.dart';
import '../../shared/widgets/source_icon_resolver.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import 'sources_provider.dart';

enum _SourceItemFilter {
  all('All items', Icons.filter_list_rounded),
  unread('Unread', Icons.mark_email_unread_outlined),
  read('Read', Icons.done_all_rounded);

  const _SourceItemFilter(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum _SourceSort {
  newest('Newest', Icons.sort_rounded),
  oldest('Oldest', Icons.history_rounded),
  recentlyOpened('Recently opened', Icons.schedule_rounded);

  const _SourceSort(this.label, this.icon);

  final String label;
  final IconData icon;
}

class SourceDetailScreen extends ConsumerStatefulWidget {
  const SourceDetailScreen({super.key, required this.sourceName});

  final String sourceName;

  @override
  ConsumerState<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends ConsumerState<SourceDetailScreen> {
  _SourceItemFilter _itemFilter = _SourceItemFilter.all;
  _SourceSort _sort = _SourceSort.newest;

  String get sourceName => widget.sourceName;

  @override
  Widget build(BuildContext context) {
    final urlsAsync = ref.watch(sourceUrlsProvider(sourceName));
    final sourceCluster = ref
        .watch(sourceClustersProvider)
        .valueOrNull
        ?.where((cluster) => cluster.name == sourceName)
        .firstOrNull;
    final cs = Theme.of(context).colorScheme;
    final selectionScope = 'source-$sourceName';
    final selectionState = ref.watch(bulkSelectionProvider(selectionScope));
    final selectionNotifier = ref.read(
      bulkSelectionProvider(selectionScope).notifier,
    );
    final visibleUrls = _applyView(urlsAsync.valueOrNull ?? const <SavedUrl>[]);
    final selectedUrls = visibleUrls
        .where((url) => selectionState.selectedIds.contains(url.id))
        .toList();
    final pagePadding = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );

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
              _sourceAppBar(context),
              const SliverFillRemaining(child: LoadingIndicator()),
            ],
          ),
          error: (err, stack) => CustomScrollView(
            slivers: [
              _sourceAppBar(context),
              SliverFillRemaining(
                child: Center(child: Text('Could not load this source')),
              ),
            ],
          ),
          data: (urls) {
            final displayedUrls = _applyView(urls);
            final displayedIds = displayedUrls.map((url) => url.id).toList();
            if (selectionState.enabled &&
                selectedUrls.length != selectionState.count) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                selectionNotifier.pruneToVisible(
                  displayedUrls.map((url) => url.id),
                );
              });
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: cs.surface,
                  surfaceTintColor: Colors.transparent,
                  title: selectionState.isActive
                      ? BulkSelectionTitle(count: selectedUrls.length)
                      : Text(
                          sourceName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
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
                            visibleUrls: displayedUrls,
                            onDone: () {
                              selectionNotifier.clear();
                              ref.invalidate(sourceUrlsProvider(sourceName));
                            },
                          ),
                        ]
                      : null,
                ),
                if (urls.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('No saves from this source')),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: _SourceMetadataHeader(
                      urls: urls,
                      cluster: sourceCluster,
                      sourceName: sourceName,
                      horizontalPadding: pagePadding,
                      itemFilter: _itemFilter,
                      sort: _sort,
                      onItemFilterChanged: (value) {
                        selectionNotifier.clear();
                        setState(() => _itemFilter = value);
                      },
                      onSortChanged: (value) {
                        selectionNotifier.clear();
                        setState(() => _sort = value);
                      },
                    ),
                  ),
                  if (displayedUrls.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyFilteredSource(filter: _itemFilter),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: (pagePadding - 16).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final url = displayedUrls[index];
                          return SwipeableUrlCard(
                            key: ValueKey(url.id),
                            url: url,
                            selectionMode: selectionState.isActive,
                            isSelected: selectionState.isSelected(url.id),
                            onSelectionStart: () =>
                                selectionNotifier.startWith(url.id),
                            onSelectionToggle: () =>
                                selectionNotifier.toggle(url.id),
                            onTap: () => context.push(
                              '/url/${url.id}',
                              extra: displayedIds,
                            ),
                            onDelete: (context, ref, url) async {
                              await deleteUrlWithUndo(context, ref, url);
                              ref.invalidate(sourceUrlsProvider(sourceName));
                            },
                            onChanged: () {
                              ref.invalidate(sourceUrlsProvider(sourceName));
                            },
                          );
                        }, childCount: displayedUrls.length),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  SliverAppBar _sourceAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(
        sourceName,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  List<SavedUrl> _applyView(List<SavedUrl> urls) {
    final filtered = switch (_itemFilter) {
      _SourceItemFilter.all => urls,
      _SourceItemFilter.unread =>
        urls.where((url) => url.openedAt == null).toList(),
      _SourceItemFilter.read =>
        urls.where((url) => url.openedAt != null).toList(),
    };
    final sorted = List<SavedUrl>.from(filtered);
    sorted.sort((a, b) {
      return switch (_sort) {
        _SourceSort.newest => b.savedAt.compareTo(a.savedAt),
        _SourceSort.oldest => a.savedAt.compareTo(b.savedAt),
        _SourceSort.recentlyOpened => _compareRecentlyOpened(a, b),
      };
    });
    return sorted;
  }

  int _compareRecentlyOpened(SavedUrl a, SavedUrl b) {
    final aOpened = a.openedAt;
    final bOpened = b.openedAt;
    if (aOpened == null && bOpened == null) {
      return b.savedAt.compareTo(a.savedAt);
    }
    if (aOpened == null) return 1;
    if (bOpened == null) return -1;
    return bOpened.compareTo(aOpened);
  }
}

class _SourceMetadataHeader extends StatelessWidget {
  const _SourceMetadataHeader({
    required this.urls,
    required this.cluster,
    required this.sourceName,
    required this.horizontalPadding,
    required this.itemFilter,
    required this.sort,
    required this.onItemFilterChanged,
    required this.onSortChanged,
  });

  final List<SavedUrl> urls;
  final SourceCluster? cluster;
  final String sourceName;
  final double horizontalPadding;
  final _SourceItemFilter itemFilter;
  final _SourceSort sort;
  final ValueChanged<_SourceItemFilter> onItemFilterChanged;
  final ValueChanged<_SourceSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lastSaved = cluster?.lastSavedAt ?? _lastSavedFromUrls(urls);
    final topics = cluster?.mostlyAbout ?? const <String>[];
    final visibleTopics = topics.take(4).toList();
    final remainingThemeCount = ((cluster?.themeCount ?? topics.length) - 4)
        .clamp(0, 999);
    final openedCount = urls.where((url) => url.openedAt != null).length;
    final iconSpec = resolveSourceIcon(sourceName);
    final sourceFavicon = faviconUrl(sourceName) ?? cluster?.faviconUrl;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SourceIconContainer(
                      spec: iconSpec,
                      containerSize: 44,
                      imageUrl: sourceFavicon,
                      preferImage: true,
                      showBackground: false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sourceName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.headlineSmall?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: urls.length == 1 ? 'Save' : 'Saves',
                        value: urls.length.toString(),
                      ),
                    ),
                    const _MetricDivider(),
                    Expanded(
                      child: _Metric(
                        label: 'This week',
                        value: (cluster?.savesThisWeek ?? 0).toString(),
                      ),
                    ),
                    const _MetricDivider(),
                    Expanded(
                      child: _Metric(
                        label: 'Last saved',
                        value: lastSaved == null ? '—' : _timeAgo(lastSaved),
                      ),
                    ),
                    const _MetricDivider(),
                    Expanded(
                      child: _Metric(
                        label: 'Opened',
                        value: openedCount.toString(),
                      ),
                    ),
                  ],
                ),
                if (topics.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Top themes',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final topic in visibleTopics)
                        _ThemePill(topic, percentage: _topicPercentage(topic)),
                      if (remainingThemeCount > 0)
                        _MoreThemesPill(count: remainingThemeCount),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SourceControls(
            itemFilter: itemFilter,
            sort: sort,
            onItemFilterChanged: onItemFilterChanged,
            onSortChanged: onSortChanged,
          ),
        ],
      ),
    );
  }

  int _topicPercentage(String topic) {
    if (urls.isEmpty) return 0;
    final normalized = topic.toLowerCase();
    final matches = urls.where((url) {
      return url.tags.any((tag) => tag.toLowerCase() == normalized);
    }).length;
    return ((matches / urls.length) * 100).round();
  }

  DateTime? _lastSavedFromUrls(List<SavedUrl> urls) {
    DateTime? latest;
    for (final item in urls) {
      final savedAt = item.savedAt;
      if (latest == null || savedAt.isAfter(latest)) latest = savedAt;
    }
    return latest;
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.titleMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.55),
    );
  }
}

class _SourceControls extends StatelessWidget {
  const _SourceControls({
    required this.itemFilter,
    required this.sort,
    required this.onItemFilterChanged,
    required this.onSortChanged,
  });

  final _SourceItemFilter itemFilter;
  final _SourceSort sort;
  final ValueChanged<_SourceItemFilter> onItemFilterChanged;
  final ValueChanged<_SourceSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SourceControlChip(
          icon: itemFilter.icon,
          label: itemFilter.label,
          onTap: () => _chooseItemFilter(context),
        ),
        _SourceControlChip(
          icon: sort.icon,
          label: sort.label,
          onTap: () => _chooseSort(context),
        ),
      ],
    );
  }

  Future<void> _chooseItemFilter(BuildContext context) async {
    final selected = await showModalBottomSheet<_SourceItemFilter>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SourceChoiceSheet<_SourceItemFilter>(
        title: 'Show items',
        selected: itemFilter,
        options: _SourceItemFilter.values,
        labelFor: (option) => option.label,
        iconFor: (option) => option.icon,
      ),
    );
    if (selected != null && context.mounted) {
      onItemFilterChanged(selected);
    }
  }

  Future<void> _chooseSort(BuildContext context) async {
    final selected = await showModalBottomSheet<_SourceSort>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SourceChoiceSheet<_SourceSort>(
        title: 'Sort by',
        selected: sort,
        options: _SourceSort.values,
        labelFor: (option) => option.label,
        iconFor: (option) => option.icon,
      ),
    );
    if (selected != null && context.mounted) {
      onSortChanged(selected);
    }
  }
}

class _SourceControlChip extends StatelessWidget {
  const _SourceControlChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 7),
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceChoiceSheet<T> extends StatelessWidget {
  const _SourceChoiceSheet({
    required this.title,
    required this.selected,
    required this.options,
    required this.labelFor,
    required this.iconFor,
  });

  final String title;
  final T selected;
  final List<T> options;
  final String Function(T option) labelFor;
  final IconData Function(T option) iconFor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Text(
              title,
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                minTileHeight: 48,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Icon(
                  iconFor(option),
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                title: Text(
                  labelFor(option),
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: option == selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                trailing: option == selected
                    ? Icon(Icons.check_rounded, size: 20, color: cs.onSurface)
                    : const SizedBox(width: 20),
                onTap: () => Navigator.of(context).pop(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyFilteredSource extends StatelessWidget {
  const _EmptyFilteredSource({required this.filter});

  final _SourceItemFilter filter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final message = switch (filter) {
      _SourceItemFilter.all => 'No items from this source',
      _SourceItemFilter.unread => 'No unread items',
      _SourceItemFilter.read => 'No read items',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  const _ThemePill(this.label, {required this.percentage});

  final String label;
  final int percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.72,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label  $percentage%',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.05,
        ),
      ),
    );
  }
}

class _MoreThemesPill extends StatelessWidget {
  const _MoreThemesPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.52,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '+$count more',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
