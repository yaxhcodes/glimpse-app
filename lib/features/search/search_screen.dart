import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/saved_url.dart';
import '../../shared/widgets/url_card.dart';
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
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();

  List<SavedUrl> _applyDateFilter(List<SavedUrl> urls, DateFilter filter) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    switch (filter) {
      case DateFilter.all:
        return urls;
      case DateFilter.today:
        return urls.where((u) => u.savedAt.isAfter(startOfToday)).toList();
      case DateFilter.thisWeek:
        final weekAgo = startOfToday.subtract(const Duration(days: 7));
        return urls.where((u) => u.savedAt.isAfter(weekAgo)).toList();
      case DateFilter.thisMonth:
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        return urls.where((u) => u.savedAt.isAfter(monthAgo)).toList();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchOutcomeProvider);
    final query = ref.watch(searchQueryProvider);
    final dateFilter = ref.watch(dateFilterProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        scrolledUnderElevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(18),
            ),
            child: TextField(
              controller: _searchController,
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
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
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
            child: query.trim().isEmpty
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
                : resultsAsync.when(
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
                              onPressed: () => ref.invalidate(
                                searchOutcomeProvider,
                              ),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (outcome) {
                      final filtered =
                          _applyDateFilter(outcome.urls, dateFilter);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (outcome.mode == SearchMode.semantic &&
                              query.trim().isNotEmpty)
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
                                            style: theme.textTheme.titleMedium,
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
                                      final url = filtered[index];
                                      return UrlCard(
                                        savedUrl: url,
                                        onTap: () => context.push(
                                          '/url/${url.id}',
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
