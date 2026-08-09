import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_layout.dart';
import 'library_entity.dart';
import 'library_provider.dart';
import 'library_status_picker.dart';
import 'library_widgets.dart';

enum LibrarySortOrder { discovered, title, year, status }

extension on LibrarySortOrder {
  String get label => switch (this) {
    LibrarySortOrder.discovered => 'Recently discovered',
    LibrarySortOrder.title => 'Title A–Z',
    LibrarySortOrder.year => 'Year newest',
    LibrarySortOrder.status => 'Status',
  };

  IconData get icon => switch (this) {
    LibrarySortOrder.discovered => Icons.schedule_rounded,
    LibrarySortOrder.title => Icons.sort_by_alpha_rounded,
    LibrarySortOrder.year => Icons.calendar_today_rounded,
    LibrarySortOrder.status => Icons.playlist_add_check_rounded,
  };
}

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
  LibrarySortOrder _sortOrder = LibrarySortOrder.discovered;

  int get _activeFilterCount =>
      (_selectedGenre == null ? 0 : 1) + (_selectedStatus == null ? 0 : 1);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(librarySnapshotProvider);
    final cs = Theme.of(context).colorScheme;
    final appBarEntities =
        async.asData?.value.ofKind(widget.kind) ?? const <LibraryEntity>[];
    final appBarGenres = _sortedGenres(appBarEntities);
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(widget.kind.label),
        actions: [
          _LibraryOptionsMenu(
            kind: widget.kind,
            activeFilterCount: _activeFilterCount,
            sortOrder: _sortOrder,
            onFilterSelected: () => _showFilters(appBarGenres),
            onSortSelected: (value) => setState(() => _sortOrder = value),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not open Library')),
        data: (snapshot) {
          final all = snapshot.ofKind(widget.kind);
          final visible = _visibleEntities(all);
          final horizontal = AppLayout.pageHorizontalPadding(
            MediaQuery.sizeOf(context).width,
            compactPadding: 16,
          );
          return CustomScrollView(
            key: PageStorageKey('library-${widget.kind.name}-browser'),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 52,
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
                      if (_activeFilterCount > 0) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (_selectedStatus case final status?)
                              InputChip(
                                label: Text(status.labelFor(widget.kind)),
                                onDeleted: () =>
                                    setState(() => _selectedStatus = null),
                              ),
                            if (_selectedGenre case final genre?)
                              InputChip(
                                label: Text(genre),
                                onDeleted: () =>
                                    setState(() => _selectedGenre = null),
                              ),
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear all'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _sortOrder.label,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '${visible.length} ${visible.length == 1 ? 'item' : 'items'}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NoResults(
                    hasFilters: _query.isNotEmpty || _activeFilterCount > 0,
                    onClear: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                        _selectedGenre = null;
                        _selectedStatus = null;
                      });
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 32),
                  sliver: SliverGrid.builder(
                    itemCount: visible.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 190,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 18,
                          childAspectRatio: 0.52,
                        ),
                    itemBuilder: (context, index) {
                      final entity = visible[index];
                      return LibraryEntityTile(
                        entity: entity,
                        onTap: () => context.push(
                          '/library/entity/${Uri.encodeComponent(entity.key)}',
                        ),
                        onStatusSelected: (status) =>
                            _setStatus(entity, status),
                        onStatusMenuRequested: () => _showStatusPicker(entity),
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

  Map<String, int> _genreCounts(List<LibraryEntity> entities) {
    final counts = <String, int>{};
    for (final entity in entities) {
      for (final genre in entity.genres) {
        counts.update(genre, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  List<String> _sortedGenres(List<LibraryEntity> entities) =>
      _sortGenreNames(_genreCounts(entities).keys);

  List<String> _sortGenreNames(Iterable<String> genres) =>
      genres.toList()..sort((a, b) {
        if (a == 'Other') return 1;
        if (b == 'Other') return -1;
        return a.compareTo(b);
      });

  List<LibraryEntity> _visibleEntities(List<LibraryEntity> all) {
    final query = _query.trim().toLowerCase();
    final visible = all
        .where((entity) {
          final matchesQuery =
              query.isEmpty ||
              entity.title.toLowerCase().contains(query) ||
              (entity.mention.creator ?? '').toLowerCase().contains(query) ||
              (entity.mention.year ?? '').contains(query);
          final matchesGenre =
              _selectedGenre == null || entity.genres.contains(_selectedGenre);
          final matchesStatus =
              _selectedStatus == null || entity.status == _selectedStatus;
          return matchesQuery && matchesGenre && matchesStatus;
        })
        .toList(growable: false);
    visible.sort((a, b) {
      final primary = switch (_sortOrder) {
        LibrarySortOrder.discovered => b.discoveredAt.compareTo(a.discoveredAt),
        LibrarySortOrder.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        LibrarySortOrder.year => _yearOf(b).compareTo(_yearOf(a)),
        LibrarySortOrder.status => _statusRank(
          a.status,
        ).compareTo(_statusRank(b.status)),
      };
      return primary != 0 ? primary : b.discoveredAt.compareTo(a.discoveredAt);
    });
    return visible;
  }

  int _yearOf(LibraryEntity entity) =>
      int.tryParse(entity.mention.year ?? '') ?? -1;

  int _statusRank(LibraryItemStatus status) => switch (status) {
    LibraryItemStatus.planning => 0,
    LibraryItemStatus.active => 1,
    LibraryItemStatus.dropped => 2,
    LibraryItemStatus.completed => 3,
    LibraryItemStatus.unlisted => 4,
  };

  Future<void> _showFilters(List<String> genres) async {
    final selected = await showModalBottomSheet<_BrowserFilters>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => _LibraryFilterSheet(
        kind: widget.kind,
        genres: genres,
        initial: _BrowserFilters(
          status: _selectedStatus,
          genre: _selectedGenre,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedStatus = selected.status;
      _selectedGenre = selected.genre;
    });
  }

  Future<void> _showStatusPicker(LibraryEntity entity) async {
    final selected = await showLibraryStatusPicker(context, entity: entity);
    if (selected == null || selected == entity.status || !mounted) return;
    await _setStatus(entity, selected);
  }

  Future<void> _setStatus(
    LibraryEntity entity,
    LibraryItemStatus selected,
  ) async {
    if (selected == entity.status) return;
    try {
      await ref.read(libraryEntityActionsProvider).setStatus(entity, selected);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this Library item.')),
      );
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedGenre = null;
      _selectedStatus = null;
    });
  }
}

enum _LibraryMenuAction { filters, discovered, title, year, status }

extension on _LibraryMenuAction {
  LibrarySortOrder? get sortOrder => switch (this) {
    _LibraryMenuAction.filters => null,
    _LibraryMenuAction.discovered => LibrarySortOrder.discovered,
    _LibraryMenuAction.title => LibrarySortOrder.title,
    _LibraryMenuAction.year => LibrarySortOrder.year,
    _LibraryMenuAction.status => LibrarySortOrder.status,
  };
}

_LibraryMenuAction _menuActionForSortOrder(LibrarySortOrder order) =>
    switch (order) {
      LibrarySortOrder.discovered => _LibraryMenuAction.discovered,
      LibrarySortOrder.title => _LibraryMenuAction.title,
      LibrarySortOrder.year => _LibraryMenuAction.year,
      LibrarySortOrder.status => _LibraryMenuAction.status,
    };

class _LibraryOptionsMenu extends StatelessWidget {
  const _LibraryOptionsMenu({
    required this.kind,
    required this.activeFilterCount,
    required this.sortOrder,
    required this.onFilterSelected,
    required this.onSortSelected,
  });

  final LibraryEntityKind kind;
  final int activeFilterCount;
  final LibrarySortOrder sortOrder;
  final VoidCallback onFilterSelected;
  final ValueChanged<LibrarySortOrder> onSortSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_LibraryMenuAction>(
      tooltip: '${kind.label} options',
      icon: Badge.count(
        count: activeFilterCount,
        isLabelVisible: activeFilterCount > 0,
        child: const Icon(Icons.more_vert_rounded),
      ),
      initialValue: _menuActionForSortOrder(sortOrder),
      onSelected: (action) {
        final selectedSort = action.sortOrder;
        if (selectedSort == null) {
          onFilterSelected();
        } else {
          onSortSelected(selectedSort);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _LibraryMenuAction.filters,
          padding: EdgeInsets.zero,
          child: _LibraryMenuRow(
            icon: Icons.tune_rounded,
            label: 'Filters',
            selected: activeFilterCount > 0,
          ),
        ),
        const PopupMenuDivider(),
        for (final option in LibrarySortOrder.values)
          PopupMenuItem(
            value: _menuActionForSortOrder(option),
            padding: EdgeInsets.zero,
            child: _LibraryMenuRow(
              icon: option.icon,
              label: option.label,
              selected: option == sortOrder,
            ),
          ),
      ],
    );
  }
}

class _LibraryMenuRow extends StatelessWidget {
  const _LibraryMenuRow({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          if (selected) ...[
            const SizedBox(width: 12),
            Icon(Icons.check_rounded, size: 20, color: cs.primary),
          ],
        ],
      ),
    );
  }
}

class _BrowserFilters {
  const _BrowserFilters({this.status, this.genre});

  final LibraryItemStatus? status;
  final String? genre;
}

class _LibraryFilterSheet extends StatefulWidget {
  const _LibraryFilterSheet({
    required this.kind,
    required this.genres,
    required this.initial,
  });

  final LibraryEntityKind kind;
  final List<String> genres;
  final _BrowserFilters initial;

  @override
  State<_LibraryFilterSheet> createState() => _LibraryFilterSheetState();
}

class _LibraryFilterSheetState extends State<_LibraryFilterSheet> {
  LibraryItemStatus? _status;
  String? _genre;

  @override
  void initState() {
    super.initState();
    _status = widget.initial.status;
    _genre = widget.initial.genre;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return FractionallySizedBox(
      heightFactor: 0.78,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter ${widget.kind.label}',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _status = null;
                    _genre = null;
                  }),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.kind == LibraryEntityKind.book
                  ? 'Reading status'
                  : 'Watch status',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any status'),
                  selected: _status == null,
                  onSelected: (_) => setState(() => _status = null),
                ),
                for (final status in LibraryItemStatus.values.skip(1))
                  ChoiceChip(
                    avatar: Icon(
                      libraryStatusIcon(status, widget.kind),
                      size: 18,
                    ),
                    label: Text(status.labelFor(widget.kind)),
                    selected: _status == status,
                    onSelected: (_) => setState(() => _status = status),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Genre',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All genres'),
                      selected: _genre == null,
                      onSelected: (_) => setState(() => _genre = null),
                    ),
                    for (final genre in widget.genres)
                      ChoiceChip(
                        label: Text(genre),
                        selected: _genre == genre,
                        onSelected: (_) => setState(() => _genre = genre),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _BrowserFilters(status: _status, genre: _genre),
                ),
                child: const Text('Show items'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.hasFilters, required this.onClear});

  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 44,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters
                  ? 'Nothing matches these filters.'
                  : 'Nothing recognized here yet.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onClear, child: const Text('Clear search')),
            ],
          ],
        ),
      ),
    );
  }
}
