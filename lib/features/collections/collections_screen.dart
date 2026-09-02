import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/bulk_selection_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/scroll_capture_service.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/bulk_selection_toolbar.dart';
import '../../shared/widgets/expressive_fab.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/expressive_tap_scale.dart';
import '../library/library_entity.dart';
import '../library/library_provider.dart';
import '../library/library_widgets.dart';
import '../shell/shell_chrome_provider.dart';
import 'collection_card.dart';
import 'collection_reorder_sheet.dart';
import 'collections_provider.dart';
import 'collections_preferences_provider.dart';
import 'create_collection_sheet.dart';
import 'move_collection_contents_sheet.dart';
import '../../l10n/l10n.dart';

enum _CollectionsMenuAction {
  viewGrid,
  viewList,
  sortManual,
  sortNewest,
  sortName,
  reorder,
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
    final librarySnapshot = ref.watch(librarySnapshotProvider).valueOrNull;
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
    final shellChromeVisible = ref.watch(shellChromeVisibilityProvider);
    final usesRail = AppLayout.usesNavigationRail(
      MediaQuery.sizeOf(context).width,
    );
    final shellBottomInset = widget.embedded && !usesRail
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;
    final scrollBottomPadding = 24.0 + shellBottomInset;
    final scrollCaptureActive = ScrollCaptureScope.isCapturingOf(context);
    final shellOverlayObstruction =
        (Theme.of(context).navigationBarTheme.height ?? 80) +
        MediaQuery.viewPaddingOf(context).bottom +
        kFloatingActionButtonMargin +
        56;

    return PopScope(
      canPop: !selectionState.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectionState.isActive) {
          selectionNotifier.clear();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        body: ScrollCaptureFixedOverlayScope(
          bottomObstruction: hasCollections ? shellOverlayObstruction : 0,
          child: NestedScrollView(
            floatHeaderSlivers: !usesRail && !scrollCaptureActive,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: usesRail || selectionState.isActive,
                floating: !usesRail && !scrollCaptureActive,
                snap: !usesRail && !scrollCaptureActive,
                titleSpacing: selectionState.isActive
                    ? null
                    : widget.embedded
                    ? 20
                    : null,
                automaticallyImplyLeading:
                    !selectionState.isActive && !widget.embedded,
                leading: selectionState.isActive
                    ? IconButton(
                        tooltip: context.l10n.exitSelection,
                        onPressed: selectionNotifier.clear,
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
                title: selectionState.isActive
                    ? BulkSelectionTitle(count: selectedCollections.length)
                    : Text(
                        context.l10n.collections,
                        key: const ValueKey('collections-surface-title'),
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                actions: selectionState.isActive
                    ? [
                        IconButton(
                          tooltip: context.l10n.selectAll,
                          onPressed: () => selectionNotifier.selectAll(
                            orderedCollections.map(
                              (summary) => summary.collection.id,
                            ),
                          ),
                          icon: const Icon(Icons.select_all_rounded),
                        ),
                        if (selectedCollections.length == 1)
                          IconButton(
                            tooltip: context.l10n.editCollection,
                            onPressed: () => _editCollection(
                              context,
                              selectedCollections.single,
                              selectionNotifier,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        IconButton(
                          tooltip: context.l10n.moveContents,
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
                          tooltip: context.l10n.deleteSelectedCollections,
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
                        if (hasCollections)
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
                        if (hasCollections) const SizedBox(width: 8),
                      ],
              ),
            ],
            body: async.when(
              loading: () => const Center(child: ExpressiveLoadingIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (rawCollections) {
                _scheduleCollectionStateSync(
                  rawCollections,
                  preferences,
                  preferencesNotifier,
                  selectionNotifier,
                );
                final collections = preferences.sortSummaries(rawCollections);
                if (collections.isEmpty) {
                  return _CollectionsEmptyLayout(
                    entities: librarySnapshot?.entities ?? const [],
                    libraryEnabled: !selectionState.isActive,
                    onLibraryTap: () => context.push('/library'),
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    child: CustomScrollView(
                      key: ValueKey(
                        preferences.layout == CollectionsLayout.grid
                            ? 'collections-grid'
                            : 'collections-list',
                      ),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          sliver: SliverToBoxAdapter(
                            child: _LibraryGatewayCard(
                              entities: librarySnapshot?.entities ?? const [],
                              enabled: !selectionState.isActive,
                              onTap: () => context.push('/library'),
                            ),
                          ),
                        ),
                        if (preferences.layout == CollectionsLayout.grid)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              scrollBottomPadding,
                            ),
                            sliver: SliverGrid.builder(
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
                                    key: ValueKey('collection-card-$id'),
                                    summary: summary,
                                    selectionMode: selectionState.isActive,
                                    isSelected: selectionState.isSelected(id),
                                    onSelectionStart: () =>
                                        selectionNotifier.startWith(id),
                                    onSelectionToggle: () =>
                                        selectionNotifier.toggle(id),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.only(
                              bottom: scrollBottomPadding,
                            ),
                            sliver: SliverList.builder(
                              itemCount: collections.length,
                              itemBuilder: (context, i) {
                                final summary = collections[i];
                                final id = summary.collection.id;
                                return ExpressiveTapScale(
                                  child: CollectionListCard(
                                    key: ValueKey('collection-list-card-$id'),
                                    summary: summary,
                                    selectionMode: selectionState.isActive,
                                    isSelected: selectionState.isSelected(id),
                                    onSelectionStart: () =>
                                        selectionNotifier.startWith(id),
                                    onSelectionToggle: () =>
                                        selectionNotifier.toggle(id),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        floatingActionButton:
            hasCollections &&
                !selectionState.isActive &&
                (usesRail || shellChromeVisible)
            ? Padding(
                padding: EdgeInsets.only(bottom: shellBottomInset),
                child: ExpressiveFab(
                  heroTag: 'collections-create',
                  tooltip: context.l10n.newCollection,
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
              ? context.l10n.movedToCollection(target.name)
              : context.l10n.movedLinksAndDeletedSources(
                  movedCount,
                  target.name,
                  selected.length,
                ),
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
              ? context.l10n.deleteCollectionNamed(
                  selected.single.collection.name,
                )
              : context.l10n.deleteCollectionsCount(count),
        ),
        content: Text(
          count == 1
              ? context.l10n.deleteCollectionDescription
              : context.l10n.deleteCollectionsDescription,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.delete),
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
        content: Text(context.l10n.collectionsDeleted(count)),
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

class _CollectionsEmptyLayout extends StatelessWidget {
  const _CollectionsEmptyLayout({
    required this.entities,
    required this.libraryEnabled,
    required this.onLibraryTap,
    required this.onCreate,
  });

  final List<LibraryEntity> entities;
  final bool libraryEnabled;
  final VoidCallback onLibraryTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryCard = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: _LibraryGatewayCard(
        entities: entities,
        enabled: libraryEnabled,
        onTap: onLibraryTap,
      ),
    );
    final emptyState = _CollectionsEmptyState(
      colorScheme: theme.colorScheme,
      textTheme: theme.textTheme,
      onCreate: onCreate,
    );

    return LayoutBuilder(
      key: const ValueKey('collections-empty'),
      builder: (context, constraints) {
        final useSequentialLayout =
            constraints.maxHeight < 600 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4;
        if (useSequentialLayout) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: libraryCard),
              SliverFillRemaining(hasScrollBody: false, child: emptyState),
            ],
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            emptyState,
            Align(alignment: Alignment.topCenter, child: libraryCard),
          ],
        );
      },
    );
  }
}

class _LibraryGatewayCard extends StatelessWidget {
  const _LibraryGatewayCard({
    required this.entities,
    required this.enabled,
    required this.onTap,
  });

  final List<LibraryEntity> entities;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strings = context.l10n;
    final artworkEntities = entities
        .where((entity) => (entity.artworkUrl ?? '').trim().isNotEmpty)
        .take(3)
        .toList(growable: false);
    final itemLabel = entities.isEmpty
        ? strings.buildsQuietly
        : strings.itemCount(entities.length);

    return Semantics(
      button: enabled,
      label: '${strings.library}, ${strings.libraryDescription}, $itemLabel',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  cs.secondaryContainer.withValues(alpha: 0.52),
                  cs.surfaceContainerLow,
                ),
                cs.surfaceContainerLow,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('library-gateway-card'),
              onTap: enabled ? onTap : null,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useStackedLayout =
                      constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.4;
                  final details = _LibraryGatewayDetails(itemLabel: itemLabel);
                  final artwork = SizedBox(
                    width: useStackedLayout ? 148 : 112,
                    height: 86,
                    child: _LibraryGatewayArtwork(entities: artworkEntities),
                  );
                  final arrow = Icon(
                    Icons.arrow_forward_rounded,
                    size: 22,
                    color: cs.onSurfaceVariant,
                  );

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                    child: useStackedLayout
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: details),
                                  const SizedBox(width: 12),
                                  arrow,
                                ],
                              ),
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: artwork,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: details),
                              const SizedBox(width: 12),
                              artwork,
                              const SizedBox(width: 4),
                              arrow,
                            ],
                          ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryGatewayDetails extends StatelessWidget {
  const _LibraryGatewayDetails({required this.itemLabel});

  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.library,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.titleMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          context.l10n.libraryDescription,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          itemLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

class _LibraryGatewayArtwork extends StatelessWidget {
  const _LibraryGatewayArtwork({required this.entities});

  final List<LibraryEntity> entities;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (entities.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          Icons.auto_awesome_mosaic_rounded,
          size: 34,
          color: cs.onSurfaceVariant,
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        for (var index = 0; index < entities.length; index++)
          Positioned(
            left: 5 + index * 22,
            top: index.isOdd ? 2 : 7,
            width: 56,
            height: 76,
            child: Transform.rotate(
              angle: (index - (entities.length - 1) / 2) * 0.055,
              child: LibraryArtwork(
                entity: entities[index],
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
      ],
    );
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
      tooltip: context.l10n.collectionOptions,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _CollectionsMenuAction.viewGrid,
          padding: EdgeInsets.zero,
          child: _CollectionsMenuRow(
            icon: Icons.grid_view_rounded,
            label: context.l10n.grid,
            selected: preferences.layout == CollectionsLayout.grid,
          ),
        ),
        PopupMenuItem(
          value: _CollectionsMenuAction.viewList,
          padding: EdgeInsets.zero,
          child: _CollectionsMenuRow(
            icon: Icons.view_list_rounded,
            label: context.l10n.list,
            selected: preferences.layout == CollectionsLayout.list,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _CollectionsMenuAction.sortManual,
          padding: EdgeInsets.zero,
          child: _CollectionsMenuRow(
            icon: Icons.swap_vert_rounded,
            label: context.l10n.manual,
            selected: preferences.sort == CollectionsSort.manual,
          ),
        ),
        PopupMenuItem(
          value: _CollectionsMenuAction.sortNewest,
          padding: EdgeInsets.zero,
          child: _CollectionsMenuRow(
            icon: Icons.schedule_rounded,
            label: context.l10n.newest,
            selected: preferences.sort == CollectionsSort.newest,
          ),
        ),
        PopupMenuItem(
          value: _CollectionsMenuAction.sortName,
          padding: EdgeInsets.zero,
          child: _CollectionsMenuRow(
            icon: Icons.sort_by_alpha_rounded,
            label: context.l10n.alphabetical,
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
            label: context.l10n.reorder,
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
          key: const ValueKey('collections-empty-content'),
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
                context.l10n.createFirstCollection,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.collectionEmptyDescription,
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
                label: Text(context.l10n.newCollection),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
