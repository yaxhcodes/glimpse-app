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
import '../collections/collections_provider.dart';
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

enum SearchStatusFilter {
  all('All'),
  unread('Unread'),
  read('Read');

  final String label;
  const SearchStatusFilter(this.label);
}

enum SearchNotesFilter {
  all('All'),
  withNotes('Has notes'),
  withoutNotes('No notes');

  final String label;
  const SearchNotesFilter(this.label);
}

enum SearchCollectionFilterMode {
  all('All'),
  inCollection('In a collection'),
  notInCollection('Not in a collection'),
  specific('Specific collection');

  final String label;
  const SearchCollectionFilterMode(this.label);
}

enum SearchSortMode {
  relevance('Relevance'),
  newest('Newest saved'),
  oldest('Oldest saved'),
  recentlyOpened('Recently opened');

  final String label;
  const SearchSortMode(this.label);
}

class _SearchFilters {
  const _SearchFilters({
    this.date = DateFilter.all,
    this.status = SearchStatusFilter.all,
    this.notes = SearchNotesFilter.all,
    this.collectionMode = SearchCollectionFilterMode.all,
    this.collectionId,
    this.sort = SearchSortMode.relevance,
  });

  final DateFilter date;
  final SearchStatusFilter status;
  final SearchNotesFilter notes;
  final SearchCollectionFilterMode collectionMode;
  final int? collectionId;
  final SearchSortMode sort;

  bool get isDefault =>
      date == DateFilter.all &&
      status == SearchStatusFilter.all &&
      notes == SearchNotesFilter.all &&
      collectionMode == SearchCollectionFilterMode.all &&
      sort == SearchSortMode.relevance;

  int get activeCount {
    var count = 0;
    if (date != DateFilter.all) count++;
    if (status != SearchStatusFilter.all) count++;
    if (notes != SearchNotesFilter.all) count++;
    if (collectionMode != SearchCollectionFilterMode.all) count++;
    if (sort != SearchSortMode.relevance) count++;
    return count;
  }

  _SearchFilters copyWith({
    DateFilter? date,
    SearchStatusFilter? status,
    SearchNotesFilter? notes,
    SearchCollectionFilterMode? collectionMode,
    int? collectionId,
    bool clearCollectionId = false,
    SearchSortMode? sort,
  }) {
    return _SearchFilters(
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      collectionMode: collectionMode ?? this.collectionMode,
      collectionId: clearCollectionId
          ? null
          : collectionId ?? this.collectionId,
      sort: sort ?? this.sort,
    );
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.embedded = false, this.initialQuery});

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
  _SearchFilters _filters = const _SearchFilters();

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
    } else if (widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final request = ref.read(searchShellQueryRequestProvider);
        if (!mounted || request == null) return;
        _runQuery(request.query);
        _clearConsumedShellQueryRequest(request);
      });
    }
  }

  void _runQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _debounce?.cancel();
    _controller.text = trimmed;
    _controller.selection = TextSelection.collapsed(offset: trimmed.length);
    setState(() => _pendingSearch = false);
    ref.read(searchProvider.notifier).search(trimmed);
  }

  void _clearConsumedShellQueryRequest(SearchShellQueryRequest request) {
    final current = ref.read(searchShellQueryRequestProvider);
    if (current?.revision != request.revision) return;
    ref.read(searchShellQueryRequestProvider.notifier).state = null;
  }

  List<SearchResult> _applyFilters(
    List<SearchResult> results,
    _SearchFilters filters,
    List<CollectionSummary> collections,
  ) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final collectionIdsByUrl = <int, Set<int>>{};
    for (final summary in collections) {
      for (final urlId in summary.collection.urlIds) {
        collectionIdsByUrl
            .putIfAbsent(urlId, () => <int>{})
            .add(summary.collection.id);
      }
    }
    var filtered = results.where((result) {
      final url = result.url;
      switch (filters.date) {
        case DateFilter.all:
          break;
        case DateFilter.today:
          if (!url.savedAt.isAfter(startOfToday)) return false;
        case DateFilter.thisWeek:
          final weekAgo = startOfToday.subtract(const Duration(days: 7));
          if (!url.savedAt.isAfter(weekAgo)) return false;
        case DateFilter.thisMonth:
          final monthAgo = DateTime(now.year, now.month - 1, now.day);
          if (!url.savedAt.isAfter(monthAgo)) return false;
      }

      switch (filters.status) {
        case SearchStatusFilter.all:
          break;
        case SearchStatusFilter.unread:
          if (url.openedAt != null) return false;
        case SearchStatusFilter.read:
          if (url.openedAt == null) return false;
      }

      final hasNotes = url.hasNotes;
      switch (filters.notes) {
        case SearchNotesFilter.all:
          break;
        case SearchNotesFilter.withNotes:
          if (!hasNotes) return false;
        case SearchNotesFilter.withoutNotes:
          if (hasNotes) return false;
      }

      final urlCollectionIds = collectionIdsByUrl[url.id] ?? const <int>{};
      switch (filters.collectionMode) {
        case SearchCollectionFilterMode.all:
          break;
        case SearchCollectionFilterMode.inCollection:
          if (urlCollectionIds.isEmpty) return false;
        case SearchCollectionFilterMode.notInCollection:
          if (urlCollectionIds.isNotEmpty) return false;
        case SearchCollectionFilterMode.specific:
          final id = filters.collectionId;
          if (id == null || !urlCollectionIds.contains(id)) return false;
      }

      return true;
    }).toList();

    switch (filters.sort) {
      case SearchSortMode.relevance:
        return filtered;
      case SearchSortMode.newest:
        filtered.sort((a, b) => b.url.savedAt.compareTo(a.url.savedAt));
      case SearchSortMode.oldest:
        filtered.sort((a, b) => a.url.savedAt.compareTo(b.url.savedAt));
      case SearchSortMode.recentlyOpened:
        filtered.sort((a, b) {
          final aOpened = a.url.openedAt;
          final bOpened = b.url.openedAt;
          if (aOpened == null && bOpened == null) return 0;
          if (aOpened == null) return 1;
          if (bOpened == null) return -1;
          return bOpened.compareTo(aOpened);
        });
    }
    return filtered;
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

  Future<void> _showFilters({
    required List<CollectionSummary> collections,
  }) async {
    final next = await showModalBottomSheet<_SearchFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          _SearchFilterSheet(filters: _filters, collections: collections),
    );
    if (next != null && mounted) {
      setState(() => _filters = next);
    }
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
    ref.listen<SearchShellQueryRequest?>(searchShellQueryRequestProvider, (
      previous,
      next,
    ) {
      if (!widget.embedded || next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _runQuery(next.query);
        _clearConsumedShellQueryRequest(next);
        _searchFocus.requestFocus();
      });
    });

    final resultsAsync = ref.watch(searchProvider);
    final query = _controller.text;
    final queryTrim = query.trim();
    final mode = ref.watch(searchModeProvider);
    final collections =
        ref.watch(collectionsSummaryProvider).valueOrNull ??
        const <CollectionSummary>[];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const selectionScope = 'search';
    final visibleResults = resultsAsync.valueOrNull == null
        ? const <SearchResult>[]
        : _applyFilters(resultsAsync.valueOrNull!, _filters, collections);
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
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
                    const SizedBox(width: 10),
                    _FilterIconButton(
                      active: !_filters.isDefault,
                      onTap: () => _showFilters(collections: collections),
                    ),
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
                            Image.asset(
                              'assets/search.png',
                              width: 132,
                              height: 132,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 18),
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
                              'summaries — then narrow the view.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.8,
                                ),
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
                        final filtered = _applyFilters(
                          results,
                          _filters,
                          collections,
                        );
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

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: active ? 'Filters active' : 'Filters',
      child: SizedBox(
        width: 54,
        height: 54,
        child: Material(
          color: active
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerHigh,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 22,
                  color: active
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                if (active)
                  Positioned(
                    top: 13,
                    right: 13,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(width: 7, height: 7),
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

class _SearchFilterSheet extends StatefulWidget {
  const _SearchFilterSheet({required this.filters, required this.collections});

  final _SearchFilters filters;
  final List<CollectionSummary> collections;

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late _SearchFilters _draft = widget.filters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Filters',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      setState(() => _draft = const _SearchFilters()),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _FilterSection(
              title: 'Time',
              child: _ChoiceWrap<DateFilter>(
                values: DateFilter.values,
                selected: _draft.date,
                labelFor: (value) => value.label,
                onSelected: (value) =>
                    setState(() => _draft = _draft.copyWith(date: value)),
              ),
            ),
            _FilterSection(
              title: 'Status',
              child: _ChoiceWrap<SearchStatusFilter>(
                values: SearchStatusFilter.values,
                selected: _draft.status,
                labelFor: (value) => value.label,
                onSelected: (value) =>
                    setState(() => _draft = _draft.copyWith(status: value)),
              ),
            ),
            _FilterSection(
              title: 'Notes',
              child: _ChoiceWrap<SearchNotesFilter>(
                values: SearchNotesFilter.values,
                selected: _draft.notes,
                labelFor: (value) => value.label,
                onSelected: (value) =>
                    setState(() => _draft = _draft.copyWith(notes: value)),
              ),
            ),
            _FilterSection(
              title: 'Collections',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChoiceWrap<SearchCollectionFilterMode>(
                    values: widget.collections.isEmpty
                        ? SearchCollectionFilterMode.values
                              .where(
                                (value) =>
                                    value !=
                                    SearchCollectionFilterMode.specific,
                              )
                              .toList()
                        : SearchCollectionFilterMode.values,
                    selected: _draft.collectionMode,
                    labelFor: (value) => value.label,
                    onSelected: (value) {
                      final firstId = widget.collections.isEmpty
                          ? null
                          : widget.collections.first.collection.id;
                      setState(
                        () => _draft = _draft.copyWith(
                          collectionMode: value,
                          collectionId:
                              value == SearchCollectionFilterMode.specific
                              ? _draft.collectionId ?? firstId
                              : null,
                          clearCollectionId:
                              value != SearchCollectionFilterMode.specific,
                        ),
                      );
                    },
                  ),
                  if (_draft.collectionMode ==
                          SearchCollectionFilterMode.specific &&
                      widget.collections.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue:
                          _draft.collectionId ??
                          widget.collections.first.collection.id,
                      decoration: const InputDecoration(
                        labelText: 'Collection',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final summary in widget.collections)
                          DropdownMenuItem(
                            value: summary.collection.id,
                            child: Text(summary.collection.name),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(
                          () => _draft = _draft.copyWith(collectionId: value),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            _FilterSection(
              title: 'Sort',
              child: _ChoiceWrap<SearchSortMode>(
                values: SearchSortMode.values,
                selected: _draft.sort,
                labelFor: (value) => value.label,
                onSelected: (value) =>
                    setState(() => _draft = _draft.copyWith(sort: value)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _draft),
                child: const Text('Apply filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(labelFor(value)),
            selected: value == selected,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}
