import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/bulk_selection_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/usage_service.dart';
import '../../shared/widgets/bulk_selection_toolbar.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/premium_design_system.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import '../../shared/widgets/upgrade_gate.dart';
import '../../shared/widgets/usage_badge.dart';
import 'search_provider.dart';

/// Date filter options.
enum DateFilter {
  all('All time'),
  today('Today'),
  thisWeek('This week'),
  thisMonth('This month');

  final String label;
  const DateFilter(this.label);
}

final dateFilterProvider = StateProvider<DateFilter>((ref) => DateFilter.all);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.embedded = false,
    this.initialQuery,
  });

  final bool embedded;
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  bool _pendingSearch = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _controller.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(searchProvider.notifier).search(initial);
      });
    }
  }

  List<SearchResult> _applyDateFilter(
    List<SearchResult> results,
    DateFilter filter,
  ) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    switch (filter) {
      case DateFilter.all:
        return results;
      case DateFilter.today:
        return results
            .where((r) => r.url.savedAt.isAfter(startOfToday))
            .toList();
      case DateFilter.thisWeek:
        final weekAgo = startOfToday.subtract(const Duration(days: 7));
        return results.where((r) => r.url.savedAt.isAfter(weekAgo)).toList();
      case DateFilter.thisMonth:
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        return results.where((r) => r.url.savedAt.isAfter(monthAgo)).toList();
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final t = query.trim();
    if (t.length <= 2) {
      ref.read(searchProvider.notifier).clear();
      setState(() => _pendingSearch = false);
      return;
    }
    setState(() => _pendingSearch = true);
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _pendingSearch = false);
      ref.read(searchProvider.notifier).search(t);
    });
  }

  Future<void> _onOpenResult(
    SearchResult result, {
    List<int> siblingIds = const [],
  }) async {
    await ref
        .read(isarServiceProvider)
        .updateOpenedAt(result.url.id, DateTime.now());
    if (!mounted) return;
    context.push(
      '/url/${result.url.id}',
      extra: siblingIds.isNotEmpty ? siblingIds : null,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(searchShellRefocusProvider, (previous, next) {
      if (!widget.embedded) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocus.requestFocus();
      });
    });

    final resultsAsync = ref.watch(searchProvider);
    final query = _controller.text;
    final dateFilter = ref.watch(dateFilterProvider);
    final queryTrim = query.trim();
    final mode = ref.watch(searchModeProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const selectionScope = 'search';
    final visibleResults = resultsAsync.valueOrNull == null
        ? const <SearchResult>[]
        : _applyDateFilter(resultsAsync.valueOrNull!, dateFilter);
    final visibleUrls = visibleResults.map((result) => result.url).toList();
    final selectionState = ref.watch(bulkSelectionProvider(selectionScope));
    final selectionNotifier = ref.read(
      bulkSelectionProvider(selectionScope).notifier,
    );
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
        backgroundColor: premiumBackground(context),
        appBar: AppBar(
          toolbarHeight: selectionState.isActive
              ? null
              : (widget.embedded ? 0 : kToolbarHeight),
          automaticallyImplyLeading: !widget.embedded,
          scrolledUnderElevation: 0,
          leading: selectionState.isActive
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Exit selection',
                  onPressed: selectionNotifier.clear,
                )
              : null,
          title: selectionState.isActive
              ? BulkSelectionTitle(count: selectedUrls.length)
              : null,
          actions: selectionState.isActive
              ? [
                  BulkSelectionActionButtons(
                    scope: selectionScope,
                    selectedUrls: selectedUrls,
                    visibleUrls: visibleUrls,
                    onDone: selectionNotifier.clear,
                  ),
                ]
              : null,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!selectionState.isActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: PremiumSearchBar(
                  controller: _controller,
                  focusNode: _searchFocus,
                  autofocus: true,
                  hint: 'Search your library…',
                  onChanged: (value) {
                    setState(() {});
                    _onQueryChanged(value);
                  },
                  onClear: query.isNotEmpty
                      ? () {
                          _controller.clear();
                          ref.read(searchProvider.notifier).clear();
                          setState(() {});
                        }
                      : null,
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...DateFilter.values.map((f) {
                    final selected = dateFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _DateFilterPill(
                        label: f.label,
                        selected: selected,
                        onTap: () =>
                            ref.read(dateFilterProvider.notifier).state = f,
                        colorScheme: colorScheme,
                        textTheme: theme.textTheme,
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  const UsageBadge(feature: UsageFeature.search),
                ],
              ),
            ),
            Expanded(
              child: queryTrim.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer
                                    .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Icon(
                                Icons.travel_explore_rounded,
                                size: 38,
                                color: colorScheme.onSecondaryContainer
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Find anything you saved',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Search across titles, tags, notes, and '
                              'summaries — then filter by time.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.8),
                                height: 1.45,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : _pendingSearch || resultsAsync.isLoading
                  ? const LoadingIndicator(message: 'Searching your library…')
                  : resultsAsync.when(
                      data: (results) {
                        final filtered = _applyDateFilter(results, dateFilter);
                        if (selectionState.enabled &&
                            selectedUrls.length != selectionState.count) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            selectionNotifier.pruneToVisible(
                              filtered.map((result) => result.url.id),
                            );
                          });
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (mode == SearchMode.semantic &&
                                queryTrim.length > 2)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer
                                          .withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.auto_awesome,
                                            size: 16,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Semantic match',
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSecondaryContainer,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: filtered.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.search_off_rounded,
                                              size: 52,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No matches for this filter',
                                              style:
                                                  theme.textTheme.titleMedium,
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Try another time range or '
                                              'broaden your search.',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        bottom: 24,
                                      ),
                                      itemCount: filtered.length,
                                      itemBuilder: (context, index) {
                                        final result = filtered[index];
                                        final url = result.url;
                                        final filteredIds = filtered
                                            .map((r) => r.url.id)
                                            .toList();
                                        return SwipeableUrlCard(
                                          key: ValueKey(url.id),
                                          url: url,
                                          selectionMode:
                                              selectionState.isActive,
                                          isSelected: selectionState.isSelected(
                                            url.id,
                                          ),
                                          onSelectionStart: () =>
                                              selectionNotifier.startWith(
                                                url.id,
                                              ),
                                          onSelectionToggle: () =>
                                              selectionNotifier.toggle(url.id),
                                          onChanged: () {
                                            final t = _controller.text.trim();
                                            if (t.length > 2) {
                                              ref
                                                  .read(searchProvider.notifier)
                                                  .search(t);
                                            }
                                          },
                                          onTap: () => _onOpenResult(
                                            result,
                                            siblingIds: filteredIds,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                      loading: () => const LoadingIndicator(
                        message: 'Searching your library…',
                      ),
                      error: (err, _) {
                        final isLimit = err is UsageLimitReachedException;
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLimit
                                      ? Icons.lock_clock_outlined
                                      : Icons.cloud_off_outlined,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  isLimit
                                      ? 'Monthly limit reached'
                                      : 'Search failed',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isLimit
                                      ? "You've reached your monthly search limit. Upgrade to Glimpse Pro for unlimited searches."
                                      : '$err',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                if (isLimit)
                                  FilledButton.icon(
                                    onPressed: () async {
                                      final upgraded = await showUpgradeGate(
                                        context,
                                        UpgradeFeature.search,
                                      );
                                      if (upgraded == true && mounted) {
                                        final t = _controller.text.trim();
                                        if (t.length > 2) {
                                          ref
                                              .read(searchProvider.notifier)
                                              .search(t);
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.workspace_premium_outlined,
                                    ),
                                    label: const Text('Upgrade to Pro'),
                                  )
                                else
                                  FilledButton.tonalIcon(
                                    onPressed: () {
                                      final t = _controller.text.trim();
                                      if (t.length > 2) {
                                        ref
                                            .read(searchProvider.notifier)
                                            .search(t);
                                      }
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Try again'),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFilterPill extends StatelessWidget {
  const _DateFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: selected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}
