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
    if (filter == DateFilter.all) return urls;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    switch (filter) {
      case DateFilter.today:
        return urls.where((u) => u.savedAt.isAfter(startOfToday)).toList();
      case DateFilter.thisWeek:
        final weekAgo = startOfToday.subtract(const Duration(days: 7));
        return urls.where((u) => u.savedAt.isAfter(weekAgo)).toList();
      case DateFilter.thisMonth:
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        return urls.where((u) => u.savedAt.isAfter(monthAgo)).toList();
      default:
        return urls;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);
    final dateFilter = ref.watch(dateFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search your URLs...',
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: (value) {
            ref.read(searchQueryProvider.notifier).state = value;
          },
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Date filter chips ─────────────────────────────
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

          // ─── Results ───────────────────────────────────────
          Expanded(
            child: query.trim().isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 64,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'Search by title, tags, or category',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : resultsAsync.when(
                    loading: () => const LoadingIndicator(),
                    error: (err, _) => Center(child: Text('Error: \$err')),
                    data: (results) {
                      final filtered = _applyDateFilter(results, dateFilter);
                      if (filtered.isEmpty) {
                        return Center(
                          child: Text('No results found',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
                          final url = filtered[index];
                          return UrlCard(
                            savedUrl: url,
                            onTap: () => context.push('/url/${url.id}'),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
