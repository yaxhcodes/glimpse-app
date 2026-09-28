import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/bulk_selection_provider.dart';
import '../../core/services/app_haptics.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/bulk_selection_toolbar.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import '../../shared/widgets/url_card.dart';
import 'source_visuals.dart';
import 'sources_provider.dart';

enum _SourceItemFilter { all, unread, read }

enum _SourceSort {
  newest(AppIcons.sort),
  oldest(AppIcons.rediscover),
  recentlyOpened(AppIcons.clock);

  const _SourceSort(this.icon);

  final IconData icon;
}

String _localizedItemFilter(
  AppLocalizations strings,
  _SourceItemFilter filter,
) => switch (filter) {
  _SourceItemFilter.all => strings.all,
  _SourceItemFilter.unread => strings.unread,
  _SourceItemFilter.read => strings.read,
};

String _localizedSourceSort(AppLocalizations strings, _SourceSort sort) =>
    switch (sort) {
      _SourceSort.newest => strings.newest,
      _SourceSort.oldest => strings.oldest,
      _SourceSort.recentlyOpened => strings.recentlyOpened,
    };

/// One source's page. It opens like a title card, in the blurred colours of
/// the newest save from it, then lists every save without repeating the
/// source's name on each row.
class SourceDetailScreen extends ConsumerStatefulWidget {
  const SourceDetailScreen({super.key, required this.sourceName});

  final String sourceName;

  @override
  ConsumerState<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends ConsumerState<SourceDetailScreen> {
  _SourceItemFilter _itemFilter = _SourceItemFilter.all;
  _SourceSort _sort = _SourceSort.newest;

  /// The name moves into the app bar once the hero has scrolled away.
  final _titleVisible = ValueNotifier(false);

  String get sourceName => widget.sourceName;

  @override
  void dispose() {
    _titleVisible.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      _titleVisible.value = notification.metrics.pixels > 150;
    }
    return false;
  }

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
    final urls = urlsAsync.valueOrNull ?? const <SavedUrl>[];
    final displayedUrls = _applyView(urls);
    final selectedUrls = displayedUrls
        .where((url) => selectionState.selectedIds.contains(url.id))
        .toList();
    final pagePadding = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );

    final appBar = AppBar(
      // Clear over the hero wash, solid once the list scrolls under it.
      backgroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.scrolledUnder)
            ? cs.surfaceContainer
            : Colors.transparent,
      ),
      surfaceTintColor: Colors.transparent,
      title: selectionState.isActive
          ? BulkSelectionTitle(count: selectedUrls.length)
          : ValueListenableBuilder<bool>(
              valueListenable: _titleVisible,
              builder: (context, visible, child) => AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: child,
              ),
              child: Text(
                sourceName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
      leading: selectionState.isActive
          ? IconButton(
              icon: const Icon(AppIcons.arrowBack),
              tooltip: context.l10n.exitSelection,
              onPressed: () {
                AppHaptics.play(AppHaptics.tick);
                selectionNotifier.clear();
              },
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
    );

    return PopScope(
      canPop: !selectionState.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectionState.isActive) {
          selectionNotifier.clear();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        body: urlsAsync.when(
          loading: () => const LoadingIndicator(),
          error: (err, stack) =>
              Center(child: Text(context.l10n.couldNotLoadSource)),
          data: (urls) {
            if (urls.isEmpty) {
              return Center(child: Text(context.l10n.noSavesFromSource));
            }
            final displayedIds = displayedUrls.map((url) => url.id).toList();
            if (selectionState.enabled &&
                selectedUrls.length != selectionState.count) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                selectionNotifier.pruneToVisible(displayedIds);
              });
            }

            return NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _SourceHero(
                      sourceName: sourceName,
                      urls: urls,
                      cluster: sourceCluster,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        pagePadding,
                        0,
                        pagePadding,
                        6,
                      ),
                      child: _SourceControls(
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
                            showSourceName: false,
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
              ),
            );
          },
        ),
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

/// Logo, name in the editorial serif, one quiet line of numbers and the
/// source's recurring themes, centred over the artwork wash.
class _SourceHero extends StatelessWidget {
  const _SourceHero({
    required this.sourceName,
    required this.urls,
    required this.cluster,
  });

  final String sourceName;
  final List<SavedUrl> urls;
  final SourceCluster? cluster;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final strings = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final previews =
        cluster?.previews ??
        urls
            .where((u) => sourcePreviewImage(u) != null)
            .take(4)
            .toList(growable: false);
    final lastSaved = cluster?.lastSavedAt ?? _newest(urls);
    final thisWeek = cluster?.savesThisWeek ?? 0;
    final facts = [
      strings.saveCount(urls.length),
      if (thisWeek > 0) strings.savesThisWeek(thisWeek),
      if (lastSaved != null)
        strings.lastSaved(UrlCard.timeAgoSaved(context, lastSaved)),
    ];
    final themes = (cluster?.mostlyAbout ?? const <String>[])
        .take(3)
        // Non-breaking inside a theme, so lines only break between themes.
        .map(
          (tag) => _sentenceCase(
            localizedTagLabel(strings, tag),
          ).replaceAll(' ', ' '),
        )
        .toList(growable: false);

    return Stack(
      children: [
        Positioned.fill(child: SourceArtworkWash(previews: previews)),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, top + 12, 24, 24),
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: dark ? 0.28 : 0.08,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SourceLogoTile(
                      name: sourceName,
                      fallbackFaviconUrl: cluster?.faviconUrl,
                      size: 72,
                      color: cs.surfaceContainerLowest,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    sourceName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.editorial(
                      tt.headlineMedium,
                      color: cs.onSurface,
                      height: 1.1,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    facts.join(' · '),
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (themes.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      strings.topThemes,
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      themes.join('  ·  '),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static DateTime? _newest(List<SavedUrl> urls) {
    DateTime? latest;
    for (final item in urls) {
      if (latest == null || item.savedAt.isAfter(latest)) latest = item.savedAt;
    }
    return latest;
  }

  static String _sentenceCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

/// All / Unread / Read as one inline segmented choice, sort on the right.
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final filter in _SourceItemFilter.values)
                _FilterSegment(
                  label: _localizedItemFilter(context.l10n, filter),
                  selected: filter == itemFilter,
                  onTap: () {
                    if (filter == itemFilter) return;
                    AppHaptics.play(AppHaptics.tick);
                    onItemFilterChanged(filter);
                  },
                ),
            ],
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            AppHaptics.play(AppHaptics.tick);
            _chooseSort(context);
          },
          style: TextButton.styleFrom(
            foregroundColor: cs.onSurfaceVariant,
            textStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          icon: AppIcon(sort.icon, size: 16, color: cs.onSurfaceVariant),
          label: Text(_localizedSourceSort(context.l10n, sort)),
        ),
      ],
    );
  }

  Future<void> _chooseSort(BuildContext context) async {
    final selected = await showModalBottomSheet<_SourceSort>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SourceChoiceSheet<_SourceSort>(
        title: context.l10n.sortBy,
        selected: sort,
        options: _SourceSort.values,
        labelFor: (option) => _localizedSourceSort(context.l10n, option),
        iconFor: (option) => option.icon,
      ),
    );
    if (selected != null && context.mounted) {
      onSortChanged(selected);
    }
  }
}

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? cs.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(
            label,
            style: tt.labelLarge?.copyWith(
              color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
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
                leading: AppIcon(
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
                    ? Icon(AppIcons.check, size: 20, color: cs.onSurface)
                    : const SizedBox(width: 20),
                onTap: () {
                  AppHaptics.play(AppHaptics.tick);
                  Navigator.of(context).pop(option);
                },
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
    final strings = context.l10n;
    final message = switch (filter) {
      _SourceItemFilter.all => strings.noItemsFromSource,
      _SourceItemFilter.unread => strings.noUnreadItems,
      _SourceItemFilter.read => strings.noReadItems,
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
