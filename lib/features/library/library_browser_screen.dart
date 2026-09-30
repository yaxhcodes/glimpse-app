import 'package:flutter/material.dart';
import 'package:glimpse/shared/widgets/app_menu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import 'library_entity.dart';
import 'library_localization.dart';
import 'library_provider.dart';
import 'library_status_picker.dart';
import 'library_widgets.dart';
import 'package:glimpse/shared/theme/app_icons.dart';
import '../../core/services/app_haptics.dart';

enum LibrarySortOrder { discovered, title, year, status }

extension on LibrarySortOrder {
  IconData get icon => switch (this) {
    LibrarySortOrder.discovered => AppIcons.clock,
    LibrarySortOrder.title => AppIcons.sortAlphabetical,
    LibrarySortOrder.year => AppIcons.calendar,
    LibrarySortOrder.status => AppIcons.checklist,
  };
}

String _localizedSortOrder(BuildContext context, LibrarySortOrder order) =>
    switch (order) {
      LibrarySortOrder.discovered => context.l10n.recentlyDiscovered,
      LibrarySortOrder.title => context.l10n.titleAZ,
      LibrarySortOrder.year => context.l10n.yearNewest,
      LibrarySortOrder.status => context.l10n.status,
    };

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
        title: Text(localizedLibraryKind(context.l10n, widget.kind)),
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
        loading: () => const Center(child: ExpressiveLoadingIndicator()),
        error: (_, _) => Center(child: Text(context.l10n.couldNotOpenLibrary)),
        data: (snapshot) {
          final all = snapshot.ofKind(widget.kind);
          final visible = _visibleEntities(all);
          final railGenres = _railGenres(all);
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
                          hintText: context.l10n.searchLibraryItems(
                            localizedLibraryKind(context.l10n, widget.kind),
                          ),
                          leading: const AppIcon(AppIcons.search),
                          trailing: [
                            if (_query.isNotEmpty)
                              IconButton(
                                tooltip: context.l10n.clearSearch,
                                onPressed: () {
                                  AppHaptics.play(AppHaptics.tick);
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(AppIcons.close),
                              ),
                          ],
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (railGenres.length > 1)
                SliverToBoxAdapter(
                  child: _GenreRail(
                    genres: railGenres,
                    selected: _selectedGenre,
                    horizontalPadding: horizontal,
                    onSelected: (genre) {
                      AppHaptics.play(AppHaptics.tick);
                      setState(() => _selectedGenre = genre);
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedStatus != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (_selectedStatus case final status?)
                              InputChip(
                                deleteIcon: const Icon(AppIcons.close),
                                label: Text(
                                  localizedLibraryStatus(
                                    context.l10n,
                                    status,
                                    widget.kind,
                                  ),
                                ),
                                onDeleted: () =>
                                    setState(() => _selectedStatus = null),
                              ),
                            TextButton(
                              onPressed: () {
                                AppHaptics.play(AppHaptics.tick);
                                _clearFilters();
                              },
                              child: Text(context.l10n.clearAll),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              _localizedSortOrder(context, _sortOrder),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            context.l10n.itemCount(visible.length),
                            style: Theme.of(context).textTheme.labelMedium
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
                  padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 32),
                  sliver: SliverGrid.builder(
                    itemCount: visible.length,
                    gridDelegate: _posterGridDelegate(
                      context,
                      MediaQuery.sizeOf(context).width - horizontal * 2,
                    ),
                    itemBuilder: (context, index) {
                      final entity = visible[index];
                      return LibraryEntityTile(
                        entity: entity,
                        onTap: () => context.push(
                          '/library/entity/${Uri.encodeComponent(entity.key)}',
                          // Swipe through the grid in the order it shows.
                          extra: [for (final item in visible) item.key],
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

  /// Three covers a row on a phone, more as the window widens; each cell is
  /// exactly a cover plus its caption so nothing stretches or letterboxes.
  SliverGridDelegate _posterGridDelegate(BuildContext context, double width) {
    const spacing = 12.0;
    final columns = (width / 150).floor().clamp(3, 8);
    final cellWidth = (width - spacing * (columns - 1)) / columns;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: 20,
      mainAxisExtent:
          cellWidth / libraryArtworkAspectRatio(widget.kind) +
          LibraryEntityTile.textBlockHeight(context),
    );
  }

  /// The most common genres first, so the rail opens on what the library is
  /// mostly made of. "Other" stays in the filter sheet only.
  List<String> _railGenres(List<LibraryEntity> entities) {
    final counts = _genreCounts(entities)..remove('Other');
    final genres = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    final selected = _selectedGenre;
    if (selected != null && !genres.contains(selected)) {
      genres.insert(0, selected);
    }
    return genres;
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
      if (widget.kind == LibraryEntityKind.book &&
          _sortOrder == LibrarySortOrder.discovered) {
        final readingPriority = _readingRank(a).compareTo(_readingRank(b));
        if (readingPriority != 0) return readingPriority;
      }
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

  int _readingRank(LibraryEntity entity) =>
      entity.status == LibraryItemStatus.active ? 0 : 1;

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
        SnackBar(content: Text(context.l10n.couldNotUpdateLibraryItem)),
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
      tooltip: context.l10n.libraryOptions(
        localizedLibraryKind(context.l10n, kind),
      ),
      icon: Badge.count(
        count: activeFilterCount,
        isLabelVisible: activeFilterCount > 0,
        child: const Icon(AppIcons.more),
      ),
      initialValue: _menuActionForSortOrder(sortOrder),
      onSelected: (action) {
        AppHaptics.play(AppHaptics.tick);
        final selectedSort = action.sortOrder;
        if (selectedSort == null) {
          onFilterSelected();
        } else {
          onSortSelected(selectedSort);
        }
      },
      itemBuilder: (context) => [
        appMenuItem(
          value: _LibraryMenuAction.filters,
          icon: AppIcons.adjust,
          label: context.l10n.filters,
          selected: activeFilterCount > 0,
        ),
        appMenuDivider,
        for (final option in LibrarySortOrder.values)
          appMenuItem(
            value: _menuActionForSortOrder(option),
            icon: option.icon,
            label: _localizedSortOrder(context, option),
            selected: option == sortOrder,
          ),
      ],
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
                    context.l10n.filterLibraryItems(
                      localizedLibraryKind(context.l10n, widget.kind),
                    ),
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    AppHaptics.play(AppHaptics.tick);
                    setState(() {
                      _status = null;
                      _genre = null;
                    });
                  },
                  child: Text(context.l10n.reset),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.kind == LibraryEntityKind.book
                  ? context.l10n.readingStatus
                  : context.l10n.watchStatus,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(context.l10n.anyStatus),
                  selected: _status == null,
                  onSelected: (_) {
                    AppHaptics.play(AppHaptics.tick);
                    setState(() => _status = null);
                  },
                ),
                for (final status in LibraryItemStatus.values.skip(1))
                  ChoiceChip(
                    avatar: AppIcon(
                      libraryStatusIcon(status, widget.kind),
                      size: 18,
                    ),
                    label: Text(
                      localizedLibraryStatus(context.l10n, status, widget.kind),
                    ),
                    selected: _status == status,
                    onSelected: (_) {
                      AppHaptics.play(AppHaptics.tick);
                      setState(() => _status = status);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.genre,
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
                      label: Text(context.l10n.allGenres),
                      selected: _genre == null,
                      onSelected: (_) {
                        AppHaptics.play(AppHaptics.tick);
                        setState(() => _genre = null);
                      },
                    ),
                    for (final genre in widget.genres)
                      ChoiceChip(
                        label: Text(localizedLibraryGenre(context.l10n, genre)),
                        selected: _genre == genre,
                        onSelected: (_) {
                          AppHaptics.play(AppHaptics.tick);
                          setState(() => _genre = genre);
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  AppHaptics.play(AppHaptics.tap);
                  Navigator.pop(
                    context,
                    _BrowserFilters(status: _status, genre: _genre),
                  );
                },
                child: Text(context.l10n.showItems),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreRail extends StatelessWidget {
  const _GenreRail({
    required this.genres,
    required this.selected,
    required this.horizontalPadding,
    required this.onSelected,
  });

  final List<String> genres;
  final String? selected;
  final double horizontalPadding;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          4,
        ),
        itemCount: genres.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = index == 0 ? null : genres[index - 1];
          return ChoiceChip(
            label: Text(
              genre == null
                  ? context.l10n.allGenres
                  : localizedLibraryGenre(context.l10n, genre),
            ),
            showCheckmark: false,
            selected: selected == genre,
            onSelected: (_) {
              AppHaptics.play(AppHaptics.tick);
              onSelected(genre);
            },
          );
        },
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
            Icon(AppIcons.searchEmpty, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              hasFilters
                  ? context.l10n.nothingMatchesFilters
                  : context.l10n.nothingRecognizedHere,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  AppHaptics.play(AppHaptics.tick);
                  onClear();
                },
                child: Text(context.l10n.clearSearch),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
