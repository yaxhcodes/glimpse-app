import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/bulk_selection_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/bulk_selection_toolbar.dart';
import '../../shared/widgets/expressive_fab.dart';
import '../../shared/widgets/expressive_tap_scale.dart';
import '../library/library_home.dart';
import '../library/library_provider.dart';
import 'collection_card.dart';
import 'collection_reorder_sheet.dart';
import 'collections_provider.dart';
import 'collections_preferences_provider.dart';
import 'create_collection_sheet.dart';
import 'move_collection_contents_sheet.dart';

enum _CollectionsMenuAction {
  viewGrid,
  viewList,
  sortManual,
  sortNewest,
  sortName,
  reorder,
}

class _CollectionsLibrarySwitch extends StatefulWidget {
  const _CollectionsLibrarySwitch({
    required this.mode,
    required this.onChanged,
  });

  final CollectionsSurfaceMode mode;
  final ValueChanged<CollectionsSurfaceMode> onChanged;

  @override
  State<_CollectionsLibrarySwitch> createState() =>
      _CollectionsLibrarySwitchState();
}

class _CollectionsLibrarySwitchState extends State<_CollectionsLibrarySwitch>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: CollectionsSurfaceMode.values.length,
    vsync: this,
    initialIndex: widget.mode.index,
  );

  @override
  void didUpdateWidget(covariant _CollectionsLibrarySwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode &&
        _controller.index != widget.mode.index) {
      _controller.animateTo(widget.mode.index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _controller,
            indicator: ShapeDecoration(
              color: cs.secondaryContainer,
              shape: const StadiumBorder(),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: cs.onSecondaryContainer,
            unselectedLabelColor: cs.onSurfaceVariant,
            labelStyle: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: Theme.of(context).textTheme.labelLarge,
            splashBorderRadius: BorderRadius.circular(20),
            onTap: (index) =>
                widget.onChanged(CollectionsSurfaceMode.values[index]),
            tabs: const [
              _MaterialModeTab(
                icon: Icons.folder_rounded,
                label: 'Collections',
              ),
              _MaterialModeTab(
                icon: Icons.auto_stories_rounded,
                label: 'Library',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialModeTab extends StatelessWidget {
  const _MaterialModeTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 21), const SizedBox(width: 9), Text(label)],
      ),
    );
  }
}

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  static const _selectionScope = 'collections';

  List<int> _lastVisibleIds = const [];
  List<int> _lastReconciledIds = const [];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(collectionsSummaryProvider);
    final preferences = ref.watch(collectionsPreferencesProvider);
    final preferencesNotifier = ref.read(
      collectionsPreferencesProvider.notifier,
    );
    final selectionState = ref.watch(bulkSelectionProvider(_selectionScope));
    final selectionNotifier = ref.read(
      bulkSelectionProvider(_selectionScope).notifier,
    );
    final libraryPreferences = ref.watch(libraryPreferencesProvider);
    final showLibrary =
        !selectionState.isActive &&
        libraryPreferences.mode == CollectionsSurfaceMode.library;
    final loadedCollections = async.valueOrNull ?? const <CollectionSummary>[];
    final orderedCollections = preferences.sortSummaries(loadedCollections);
    final selectedCollections = orderedCollections
        .where(
          (summary) =>
              selectionState.selectedIds.contains(summary.collection.id),
        )
        .toList(growable: false);
    final canMoveSelection =
        selectedCollections.any((summary) => summary.linkCount > 0) &&
        orderedCollections.any(
          (summary) =>
              !selectionState.selectedIds.contains(summary.collection.id),
        );
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasCollections = loadedCollections.isNotEmpty;
    final shellBottomInset =
        widget.embedded &&
            !AppLayout.usesNavigationRail(MediaQuery.sizeOf(context).width)
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;
    final scrollBottomPadding = 24.0 + shellBottomInset;

    return PopScope(
      canPop: !selectionState.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectionState.isActive) {
          selectionNotifier.clear();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          titleSpacing: selectionState.isActive
              ? null
              : widget.embedded
              ? 20
              : null,
          automaticallyImplyLeading:
              !selectionState.isActive && !widget.embedded,
          leading: selectionState.isActive
              ? IconButton(
                  tooltip: 'Exit selection',
                  onPressed: selectionNotifier.clear,
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
          title: selectionState.isActive
              ? BulkSelectionTitle(count: selectedCollections.length)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showLibrary ? 'Library' : 'Collections',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showLibrary
                          ? 'Things discovered in your saves'
                          : 'Your saved spaces',
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
          actions: selectionState.isActive
              ? [
                  IconButton(
                    tooltip: 'Select all',
                    onPressed: () => selectionNotifier.selectAll(
                      orderedCollections.map(
                        (summary) => summary.collection.id,
                      ),
                    ),
                    icon: const Icon(Icons.select_all_rounded),
                  ),
                  if (selectedCollections.length == 1)
                    IconButton(
                      tooltip: 'Edit collection',
                      onPressed: () => _editCollection(
                        context,
                        selectedCollections.single,
                        selectionNotifier,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  IconButton(
                    tooltip: 'Move contents',
                    onPressed: canMoveSelection
                        ? () => _moveCollectionContents(
                            context,
                            selectedCollections,
                            orderedCollections,
                            selectionNotifier,
                            preferencesNotifier,
                          )
                        : null,
                    icon: const Icon(Icons.drive_file_move_outline),
                  ),
                  IconButton(
                    tooltip: 'Delete selected collections',
                    color: cs.error,
                    onPressed: selectedCollections.isEmpty
                        ? null
                        : () => _confirmDeleteCollections(
                            context,
                            selectedCollections,
                            selectionNotifier,
                            preferencesNotifier,
                          ),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ]
              : [
                  if (!showLibrary && hasCollections)
                    _CollectionsOptionsMenu(
                      preferences: preferences,
                      canReorder: loadedCollections.length > 1,
                      onSelected: (action) => _handleMenuAction(
                        context,
                        action,
                        orderedCollections,
                        preferencesNotifier,
                      ),
                    ),
                  if (!showLibrary && hasCollections) const SizedBox(width: 8),
                ],
        ),
        body: Column(
          children: [
            if (!selectionState.isActive)
              _CollectionsLibrarySwitch(
                mode: libraryPreferences.mode,
                onChanged: (mode) =>
                    ref.read(libraryPreferencesProvider.notifier).setMode(mode),
              ),
            Expanded(
              child: showLibrary
                  ? LibraryHome(bottomPadding: scrollBottomPadding)
                  : async.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('$e')),
                      data: (rawCollections) {
                        _scheduleCollectionStateSync(
                          rawCollections,
                          preferences,
                          preferencesNotifier,
                          selectionNotifier,
                        );
                        final collections = preferences.sortSummaries(
                          rawCollections,
                        );
                        if (collections.isEmpty) {
                          return _CollectionsEmptyState(
                            colorScheme: cs,
                            textTheme: tt,
                            onCreate: () => _createCollection(context),
                          );
                        }
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                cs.surface,
                                cs.surfaceContainerLow.withValues(alpha: 0.42),
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeOutCubic,
                                  child:
                                      preferences.layout ==
                                          CollectionsLayout.grid
                                      ? GridView.builder(
                                          key: const ValueKey(
                                            'collections-grid',
                                          ),
                                          padding: EdgeInsets.fromLTRB(
                                            16,
                                            8,
                                            16,
                                            scrollBottomPadding,
                                          ),
                                          gridDelegate:
                                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                                maxCrossAxisExtent: 224,
                                                crossAxisSpacing: 12,
                                                mainAxisSpacing: 12,
                                                childAspectRatio: 0.96,
                                              ),
                                          itemCount: collections.length,
                                          itemBuilder: (context, i) {
                                            final summary = collections[i];
                                            final id = summary.collection.id;
                                            return ExpressiveTapScale(
                                              child: CollectionCard(
                                                key: ValueKey(
                                                  'collection-card-$id',
                                                ),
                                                summary: summary,
                                                selectionMode:
                                                    selectionState.isActive,
                                                isSelected: selectionState
                                                    .isSelected(id),
                                                onSelectionStart: () =>
                                                    selectionNotifier.startWith(
                                                      id,
                                                    ),
                                                onSelectionToggle: () =>
                                                    selectionNotifier.toggle(
                                                      id,
                                                    ),
                                              ),
                                            );
                                          },
                                        )
                                      : ListView.builder(
                                          key: const ValueKey(
                                            'collections-list',
                                          ),
                                          padding: EdgeInsets.fromLTRB(
                                            0,
                                            8,
                                            0,
                                            scrollBottomPadding,
                                          ),
                                          itemCount: collections.length,
                                          itemBuilder: (context, i) {
                                            final summary = collections[i];
                                            final id = summary.collection.id;
                                            return ExpressiveTapScale(
                                              child: CollectionListCard(
                                                key: ValueKey(
                                                  'collection-list-card-$id',
                                                ),
                                                summary: summary,
                                                selectionMode:
                                                    selectionState.isActive,
                                                isSelected: selectionState
                                                    .isSelected(id),
                                                onSelectionStart: () =>
                                                    selectionNotifier.startWith(
                                                      id,
                                                    ),
                                                onSelectionToggle: () =>
                                                    selectionNotifier.toggle(
                                                      id,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton:
            !showLibrary && hasCollections && !selectionState.isActive
            ? Padding(
                padding: EdgeInsets.only(bottom: shellBottomInset),
                child: ExpressiveFab(
                  heroTag: 'collections-create',
                  tooltip: 'New collection',
                  onPressed: () => _createCollection(context),
                  child: const AppIcon(AppIcons.addToCollection),
                ),
              )
            : null,
      ),
    );
  }

  void _scheduleCollectionStateSync(
    List<CollectionSummary> collections,
    CollectionsPreferencesState preferences,
    CollectionsPreferencesNotifier preferencesNotifier,
    BulkSelectionNotifier selectionNotifier,
  ) {
    final ids = collections
        .map((summary) => summary.collection.id)
        .toList(growable: false);
    if (!_sameIds(ids, _lastVisibleIds)) {
      _lastVisibleIds = ids;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        selectionNotifier.pruneToVisible(ids);
      });
    }
    if (preferences.isLoaded && !_sameIds(ids, _lastReconciledIds)) {
      _lastReconciledIds = ids;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        preferencesNotifier.reconcile(ids);
      });
    }
  }

  bool _sameIds(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    _CollectionsMenuAction action,
    List<CollectionSummary> collections,
    CollectionsPreferencesNotifier preferences,
  ) async {
    switch (action) {
      case _CollectionsMenuAction.viewGrid:
        await preferences.setLayout(CollectionsLayout.grid);
      case _CollectionsMenuAction.viewList:
        await preferences.setLayout(CollectionsLayout.list);
      case _CollectionsMenuAction.sortManual:
        await preferences.setSort(CollectionsSort.manual);
      case _CollectionsMenuAction.sortNewest:
        await preferences.setSort(CollectionsSort.newest);
      case _CollectionsMenuAction.sortName:
        await preferences.setSort(CollectionsSort.name);
      case _CollectionsMenuAction.reorder:
        final order = await showCollectionReorderSheet(context, collections);
        if (order != null) await preferences.setManualOrder(order);
    }
  }

  Future<void> _editCollection(
    BuildContext context,
    CollectionSummary summary,
    BulkSelectionNotifier selectionNotifier,
  ) async {
    final updated = await showCreateCollectionSheet(
      context,
      collection: summary.collection,
    );
    if (updated == null) return;
    selectionNotifier.clear();
    ref.invalidate(collectionsListProvider);
    ref.invalidate(collectionsSummaryProvider);
  }

  Future<void> _moveCollectionContents(
    BuildContext context,
    List<CollectionSummary> selected,
    List<CollectionSummary> allCollections,
    BulkSelectionNotifier selectionNotifier,
    CollectionsPreferencesNotifier preferencesNotifier,
  ) async {
    final selectedIds = selected
        .map((summary) => summary.collection.id)
        .toSet();
    final targets = allCollections
        .where((summary) => !selectedIds.contains(summary.collection.id))
        .toList(growable: false);
    final target = await showMoveCollectionContentsSheet(
      context,
      sources: selected,
      targets: targets,
    );
    if (target == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final movedCount = await ref
        .read(isarServiceProvider)
        .moveCollectionsInto(
          sourceCollectionIds: selectedIds,
          targetCollectionId: target.id,
        );
    await preferencesNotifier.removeCollections(selectedIds);
    selectionNotifier.clear();
    ref.invalidate(collectionsListProvider);
    ref.invalidate(collectionsSummaryProvider);
    for (final sourceId in selectedIds) {
      ref.invalidate(collectionMetaProvider(sourceId));
      ref.invalidate(collectionUrlsProvider(sourceId));
    }
    ref.invalidate(collectionMetaProvider(target.id));
    ref.invalidate(collectionUrlsProvider(target.id));
    if (!context.mounted) return;

    showAutoDismissSnackBarVia(
      messenger,
      SnackBar(
        content: Text(
          movedCount == 0
              ? '${selected.length == 1 ? 'Collection' : 'Collections'} moved '
                    'to ${target.name}'
              : 'Moved $movedCount ${movedCount == 1 ? 'link' : 'links'} to '
                    '${target.name} and deleted '
                    '${selected.length == 1 ? 'the source collection' : 'the source collections'}',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmDeleteCollections(
    BuildContext context,
    List<CollectionSummary> selected,
    BulkSelectionNotifier selectionNotifier,
    CollectionsPreferencesNotifier preferences,
  ) async {
    final count = selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          count == 1
              ? 'Delete “${selected.single.collection.name}”?'
              : 'Delete $count collections?',
        ),
        content: Text(
          count == 1
              ? 'Its saved links will stay in your library. Only the '
                    'collection will be removed.'
              : 'Their saved links will stay in your library. Only the '
                    'collections will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ids = selected
        .map((summary) => summary.collection.id)
        .toList(growable: false);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(isarServiceProvider).deleteCollections(ids);
    await preferences.removeCollections(ids);
    selectionNotifier.clear();
    ref.invalidate(collectionsListProvider);
    ref.invalidate(collectionsSummaryProvider);
    if (!context.mounted) return;
    showAutoDismissSnackBarVia(
      messenger,
      SnackBar(
        content: Text(
          count == 1 ? 'Collection deleted' : '$count collections deleted',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _createCollection(BuildContext context) async {
    final collection = await showCreateCollectionSheet(context);
    if (collection == null || !context.mounted) return;
    ref.invalidate(collectionsListProvider);
    ref.invalidate(collectionsSummaryProvider);
    context.push('/collections/${collection.id}');
  }
}

class _CollectionsOptionsMenu extends StatelessWidget {
  const _CollectionsOptionsMenu({
    required this.preferences,
    required this.canReorder,
    required this.onSelected,
  });

  final CollectionsPreferencesState preferences;
  final bool canReorder;
  final ValueChanged<_CollectionsMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CollectionsMenuAction>(
      tooltip: 'Collection options',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _CollectionsMenuAction.viewGrid,
          padding: EdgeInsets.zero,
          child: _CollectionsMenuRow(
            icon: Icons.grid_view_rounded,
            label: 'Grid',
            selected: preferences.layout == CollectionsLayout.grid,
          ),
        ),
        PopupMenuItem(
          value: _CollectionsMenuAction.viewList,
          padding: EdgeInsets.zero,
          child: _CollectionsMenuRow(
            icon: Icons.view_list_rounded,
            label: 'List',
            selected: preferences.layout == CollectionsLayout.list,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _CollectionsMenuAction.sortManual,
          padding: EdgeInsets.zero,
          child: _CollectionsMenuRow(
            icon: Icons.swap_vert_rounded,
            label: 'Manual',
            selected: preferences.sort == CollectionsSort.manual,
          ),
        ),
        PopupMenuItem(
          value: _CollectionsMenuAction.sortNewest,
          padding: EdgeInsets.zero,
          child: _CollectionsMenuRow(
            icon: Icons.schedule_rounded,
            label: 'Newest',
            selected: preferences.sort == CollectionsSort.newest,
          ),
        ),
        PopupMenuItem(
          value: _CollectionsMenuAction.sortName,
          padding: EdgeInsets.zero,
          child: _CollectionsMenuRow(
            icon: Icons.sort_by_alpha_rounded,
            label: 'A–Z',
            selected: preferences.sort == CollectionsSort.name,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _CollectionsMenuAction.reorder,
          enabled: canReorder,
          padding: EdgeInsets.zero,
          child: _CollectionsMenuRow(
            icon: Icons.drag_indicator_rounded,
            label: 'Reorder',
            enabled: canReorder,
          ),
        ),
      ],
    );
  }
}

class _CollectionsMenuRow extends StatelessWidget {
  const _CollectionsMenuRow({
    required this.icon,
    required this.label,
    this.selected = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = enabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurface.withValues(alpha: 0.38);
    final textColor = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.38);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: textColor)),
          ),
          if (selected) ...[
            const SizedBox(width: 12),
            Icon(Icons.check_rounded, size: 20, color: colorScheme.primary),
          ],
        ],
      ),
    );
  }
}

class _CollectionsEmptyState extends StatelessWidget {
  const _CollectionsEmptyState({
    required this.colorScheme,
    required this.textTheme,
    required this.onCreate,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/empty_collection.png',
                width: 132,
                height: 132,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              Text(
                'Create your first collection',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Group links into calm, focused spaces.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const AppIcon(AppIcons.addToCollection),
                label: const Text('New collection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
