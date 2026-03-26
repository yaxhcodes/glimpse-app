import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/service_providers.dart';
import '../../shared/widgets/loading_indicator.dart';
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
  const SearchScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _pendingSearch = false;

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
        return results
            .where((r) => r.url.savedAt.isAfter(weekAgo))
            .toList();
      case DateFilter.thisMonth:
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        return results
            .where((r) => r.url.savedAt.isAfter(monthAgo))
            .toList();
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
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _pendingSearch = false);
      ref.read(searchProvider.notifier).search(t);
    });
  }

  Future<void> _onOpenResult(SearchResult result) async {
    await ref
        .read(isarServiceProvider)
        .updateOpenedAt(result.url.id, DateTime.now());
    if (!mounted) return;
    context.push('/url/${result.url.id}');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchProvider);
    final query = _controller.text;
    final dateFilter = ref.watch(dateFilterProvider);
    final queryTrim = query.trim();
    final mode = ref.watch(searchModeProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: widget.embedded ? 16 : 0,
        automaticallyImplyLeading: !widget.embedded,
        scrolledUnderElevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(18),
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
              cursorHeight: 22,
              decoration: InputDecoration(
                hintText: 'Search your library…',
                hintStyle: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w200,
                  height: 1.35,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: false,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 4,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 6, right: 2),
                  child: Icon(
                    Icons.search_rounded,
                    size: 26,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Clear',
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchProvider.notifier).clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {});
                _onQueryChanged(value);
              },
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: DateFilter.values.map((f) {
                final selected = dateFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.label),
                    selected: selected,
                    onSelected: (_) =>
                        ref.read(dateFilterProvider.notifier).state = f,
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: queryTrim.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.travel_explore_rounded,
                            size: 56,
                            color: colorScheme.primary.withValues(alpha: 0.65),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Find anything you saved',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : _pendingSearch || resultsAsync.isLoading
                    ? const LoadingIndicator(
                        message: 'Searching your library…',
                      )
                    : resultsAsync.when(
                        data: (results) {
                          final filtered =
                              _applyDateFilter(results, dateFilter);
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
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No matches for this filter',
                                                style: theme
                                                    .textTheme.titleMedium,
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
                                        itemBuilder: (_, index) {
                                          return _buildSearchResultCard(
                                            filtered[index],
                                            colorScheme,
                                            theme.textTheme,
                                            _onOpenResult,
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
                        error: (err, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_off_outlined,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Search failed',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$err',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
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
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

Widget _buildSearchResultCard(
  SearchResult result,
  ColorScheme cs,
  TextTheme tt,
  Future<void> Function(SearchResult) onTap,
) {
  final relevance = result.score;

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    color: cs.surfaceContainerLow,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: InkWell(
      onTap: () => onTap(result),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 52,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: relevance > 0
                    ? Color.lerp(
                        cs.outline,
                        cs.primary,
                        ((relevance - 0.45) / 0.55).clamp(0.0, 1.0),
                      )
                    : cs.outlineVariant,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.url.title,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Uri.parse(result.url.rawUrl)
                        .host
                        .replaceFirst('www.', ''),
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: result.url.tags.take(3).map((tag) {
                      return Chip(
                        label: Text(tag, style: tt.labelSmall),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
