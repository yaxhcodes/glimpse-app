import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_layout.dart';
import 'library_entity.dart';
import 'library_provider.dart';
import 'library_widgets.dart';

class LibraryBrowserScreen extends ConsumerStatefulWidget {
  const LibraryBrowserScreen({super.key, required this.kind});

  final LibraryEntityKind kind;

  @override
  ConsumerState<LibraryBrowserScreen> createState() =>
      _LibraryBrowserScreenState();
}

class _LibraryBrowserScreenState extends ConsumerState<LibraryBrowserScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedGenre;
  LibraryItemStatus? _selectedStatus;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(librarySnapshotProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: Text(widget.kind.label)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not open Library')),
        data: (snapshot) {
          final all = snapshot.ofKind(widget.kind);
          final genreCounts = <String, int>{};
          for (final entity in all) {
            for (final genre in entity.genres) {
              genreCounts.update(
                genre,
                (count) => count + 1,
                ifAbsent: () => 1,
              );
            }
          }
          final genres = genreCounts.keys.toList()
            ..sort((a, b) {
              if (a == 'Other') return 1;
              if (b == 'Other') return -1;
              return a.compareTo(b);
            });
          final statusCounts = <LibraryItemStatus, int>{
            for (final status in LibraryItemStatus.values.skip(1))
              status: all.where((entity) => entity.status == status).length,
          };
          final visible = all
              .where((entity) {
                final query = _query.trim().toLowerCase();
                final matchesQuery =
                    query.isEmpty ||
                    entity.title.toLowerCase().contains(query) ||
                    (entity.mention.creator ?? '').toLowerCase().contains(
                      query,
                    );
                final matchesGenre =
                    _selectedGenre == null ||
                    entity.genres.contains(_selectedGenre);
                final matchesStatus =
                    _selectedStatus == null || entity.status == _selectedStatus;
                return matchesQuery && matchesGenre && matchesStatus;
              })
              .toList(growable: false);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppLayout.pageHorizontalPadding(
                      MediaQuery.sizeOf(context).width,
                      compactPadding: 16,
                    ),
                    12,
                    AppLayout.pageHorizontalPadding(
                      MediaQuery.sizeOf(context).width,
                      compactPadding: 16,
                    ),
                    8,
                  ),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search ${widget.kind.label.toLowerCase()}',
                    leading: const Icon(Icons.search_rounded),
                    trailing: [
                      if (_query.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
                  child: Text(
                    widget.kind == LibraryEntityKind.book
                        ? 'Reading list'
                        : 'Watchlist',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 58,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 7,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: LibraryItemStatus.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final status = index == 0
                          ? null
                          : LibraryItemStatus.values[index];
                      return FilterChip(
                        selected: _selectedStatus == status,
                        showCheckmark: false,
                        avatar: Icon(
                          status == null
                              ? Icons.apps_rounded
                              : _statusIcon(status),
                          size: 18,
                        ),
                        label: _GenreFilterLabel(
                          label: status?.labelFor(widget.kind) ?? 'All',
                          count: status == null
                              ? all.length
                              : statusCounts[status] ?? 0,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedStatus = status),
                      );
                    },
                  ),
                ),
              ),
              if (genres.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
                    child: Text(
                      'Browse by genre',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              if (genres.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 58,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 7,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: genres.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final genre = index == 0 ? null : genres[index - 1];
                        return FilterChip(
                          selected: _selectedGenre == genre,
                          showCheckmark: false,
                          avatar: genre == null
                              ? const Icon(Icons.apps_rounded, size: 18)
                              : null,
                          label: _GenreFilterLabel(
                            label: genre ?? 'All',
                            count: genre == null
                                ? all.length
                                : genreCounts[genre] ?? 0,
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedGenre = genre),
                        );
                      },
                    ),
                  ),
                ),
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NoResults(
                    hasFilters:
                        _query.isNotEmpty ||
                        _selectedGenre != null ||
                        _selectedStatus != null,
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Text(
                      _query.isNotEmpty
                          ? '${visible.length} ${visible.length == 1 ? 'result' : 'results'}'
                          : _resultsHeading(widget.kind),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (visible.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppLayout.pageHorizontalPadding(
                      MediaQuery.sizeOf(context).width,
                      compactPadding: 16,
                    ),
                    10,
                    AppLayout.pageHorizontalPadding(
                      MediaQuery.sizeOf(context).width,
                      compactPadding: 16,
                    ),
                    32,
                  ),
                  sliver: SliverGrid.builder(
                    itemCount: visible.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 210,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 22,
                          childAspectRatio: 0.54,
                        ),
                    itemBuilder: (context, index) {
                      final entity = visible[index];
                      return LibraryEntityTile(
                        entity: entity,
                        onTap: () => context.push(
                          '/library/entity/${Uri.encodeComponent(entity.key)}',
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _resultsHeading(LibraryEntityKind kind) {
    final status = _selectedStatus?.labelFor(kind);
    if (status != null && _selectedGenre != null) {
      return '$status · $_selectedGenre';
    }
    return status ?? _selectedGenre ?? 'Recently discovered';
  }

  IconData _statusIcon(LibraryItemStatus status) => switch (status) {
    LibraryItemStatus.unlisted => Icons.playlist_remove_rounded,
    LibraryItemStatus.planning => Icons.bookmark_add_outlined,
    LibraryItemStatus.active =>
      widget.kind == LibraryEntityKind.book
          ? Icons.auto_stories_rounded
          : Icons.play_circle_outline_rounded,
    LibraryItemStatus.dropped => Icons.remove_circle_outline_rounded,
    LibraryItemStatus.completed => Icons.check_circle_outline_rounded,
  };
}

class _GenreFilterLabel extends StatelessWidget {
  const _GenreFilterLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 7),
        Text(
          '$count',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          hasFilters
              ? 'Nothing matches these filters.'
              : 'Nothing recognized here yet.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
