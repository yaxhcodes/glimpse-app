import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/service_providers.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/widgets/link_card_thumbnail.dart';
import '../../shared/widgets/url_card.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../home/home_provider.dart';
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
  final _searchFocus = FocusNode();
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
    _debounce = Timer(const Duration(milliseconds: 600), () {
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

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        automaticallyImplyLeading: !widget.embedded,
        scrolledUnderElevation: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(18),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _searchFocus,
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: DateFilter.values.map((f) {
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
                          const SizedBox(height: 12),
                          Text(
                            'Search titles, tags, notes, and summaries. '
                            'Use the time filters to narrow results.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
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
                                        itemBuilder: (context, index) {
                                          return _buildSearchResultCard(
                                            context,
                                            filtered[index],
                                            colorScheme,
                                            theme.textTheme,
                                            ref.watch(tagOccurrenceMapProvider),
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
      color: selected ? colorScheme.secondaryContainer : Colors.transparent,
      shape: StadiumBorder(
        side: selected
            ? BorderSide.none
            : BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.6),
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: selected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildSearchResultCard(
  BuildContext context,
  SearchResult result,
  ColorScheme cs,
  TextTheme tt,
  Map<String, int> tagFreq,
  Future<void> Function(SearchResult) onTap,
) {
  final theme = Theme.of(context);
  final u = result.url;
  final title = TitleResolver.formatForCompactCard(
    u,
    TitleResolver.collapseWhitespace(
      TitleResolver.resolve(u, tagFrequency: tagFreq),
    ),
  );
  final chips = TagNoiseFilter.visibleTagsForCard(u.tags, tagFreq);
  final isRead = u.openedAt != null;
  final isLight = theme.brightness == Brightness.light;
  final platformLabel = CategoryResolver.displaySourceName(
    rawUrl: u.rawUrl,
    fallbackDomain: u.domain,
  );
  final metaStyle = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    color: UrlCard.listCardFillColor(theme),
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: UrlCard.listCardShape(theme, radius: 14),
    child: InkWell(
      onTap: () => onTap(result),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinkCardThumbnail.build(
              url: result.url,
              isRead: isRead,
              context: context,
              size: 48,
              borderRadius: 8,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedOpacity(
                    opacity: (isRead && isLight) ? 0.45 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (tt.titleSmall ?? const TextStyle()).copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(platformLabel, style: metaStyle),
                      Text(' · ', style: metaStyle),
                      Text(
                        UrlCard.timeAgoSaved(u.savedAt),
                        style: metaStyle,
                      ),
                    ],
                  ),
                  if (chips.visible.isNotEmpty || chips.overflow > 0) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        ...chips.visible.map(
                          (tag) => Chip(
                            label: Text(
                              tag,
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        if (chips.overflow > 0)
                          Chip(
                            label: Text(
                              '+${chips.overflow}',
                              style: tt.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

