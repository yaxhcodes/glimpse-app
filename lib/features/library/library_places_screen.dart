import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/place_itinerary.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import 'library_entity.dart';
import 'library_places_map.dart';
import 'library_places_model.dart';
import 'library_provider.dart';
import 'library_widgets.dart';
import 'place_itinerary_editor_screen.dart';
import 'place_itinerary_provider.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

class LibraryPlacesScreen extends ConsumerStatefulWidget {
  const LibraryPlacesScreen({super.key});

  @override
  ConsumerState<LibraryPlacesScreen> createState() =>
      _LibraryPlacesScreenState();
}

class _LibraryPlacesScreenState extends ConsumerState<LibraryPlacesScreen> {
  static const _initialSheetSize = 0.34;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ValueNotifier<double> _sheetExtent = ValueNotifier(_initialSheetSize);
  final TextEditingController _searchController = TextEditingController();
  String? _selectedKey;
  String _selectedAreaKey = allPlacesAreaKey;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_handleSheetExtentChanged);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_handleSheetExtentChanged);
    _sheetController.dispose();
    _sheetExtent.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(librarySnapshotProvider);
    final plans = ref.watch(placeItinerariesProvider).valueOrNull ?? const [];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.l10n.libraryPlaces),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.82),
        scrolledUnderElevation: 0,
        actions: [
          if (snapshot.valueOrNull
                  ?.ofKind(LibraryEntityKind.place)
                  .isNotEmpty ==
              true)
            IconButton(
              tooltip: context.l10n.planAnItinerary,
              onPressed: () => _createPlanForFocusedArea(
                snapshot.value!.ofKind(LibraryEntityKind.place),
              ),
              icon: const Icon(AppIcons.route),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: ExpressiveLoadingIndicator()),
        error: (_, _) => Center(child: Text(context.l10n.couldNotOpenLibrary)),
        data: (data) {
          final places = data.ofKind(LibraryEntityKind.place);
          if (places.isEmpty) return const _PlacesEmptyState();
          final areas = PlaceAreaIndex.byCountry(places);
          if (_selectedAreaKey != allPlacesAreaKey &&
              areas.every((area) => area.key != _selectedAreaKey)) {
            _selectedAreaKey = allPlacesAreaKey;
          }
          final areaEntities = places
              .where(
                (entity) => PlaceAreaIndex.contains(_selectedAreaKey, entity),
              )
              .toList(growable: false);
          final visible = _filter(areaEntities);
          if (_selectedKey == null ||
              visible.every((entity) => entity.key != _selectedKey)) {
            _selectedKey = visible.firstOrNull?.key;
          }
          final mapped = visible
              .where((entity) => entity.mention.hasCoordinates)
              .toList(growable: false);
          return _PlacesExperience(
            allPlaces: places,
            visiblePlaces: visible,
            mappedPlaces: mapped,
            areas: areas,
            plans: plans,
            selectedKey: _selectedKey,
            selectedAreaKey: _selectedAreaKey,
            query: _query,
            searchController: _searchController,
            sheetController: _sheetController,
            sheetExtent: _sheetExtent,
            onAreaSelected: _selectArea,
            onQueryChanged: (value) => setState(() => _query = value),
            onClearQuery: () {
              _searchController.clear();
              setState(() => _query = '');
            },
            onSelected: (entity) => setState(() => _selectedKey = entity.key),
            onShowOnMap: _showOnMap,
            onOpen: _open,
            onOpenPlan: _openPlan,
            onCreatePlan: _createPlan,
          );
        },
      ),
    );
  }

  List<LibraryEntity> _filter(List<LibraryEntity> entities) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return entities;
    return entities
        .where((entity) {
          return [entity.title, entity.mention.city, entity.mention.country]
              .whereType<String>()
              .any((value) => value.toLowerCase().contains(query));
        })
        .toList(growable: false);
  }

  void _handleSheetExtentChanged() {
    if (_sheetController.isAttached) {
      _sheetExtent.value = _sheetController.size;
    }
  }

  void _selectArea(String key) {
    setState(() {
      _selectedAreaKey = key;
      _selectedKey = null;
      _query = '';
      _searchController.clear();
    });
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .trackEvent(AnalyticsEvent.libraryPlaceAreaSelected),
    );
  }

  void _showOnMap(LibraryEntity entity) {
    setState(() => _selectedKey = entity.key);
    if (_sheetController.isAttached) {
      unawaited(
        _sheetController.animateTo(
          _initialSheetSize,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _open(LibraryEntity entity) {
    context.push('/library/entity/${Uri.encodeComponent(entity.key)}');
  }

  void _openPlan(PlaceItinerary plan) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .trackEvent(AnalyticsEvent.placeItineraryOpened),
    );
    context.push('/library/places/itinerary/${plan.id}');
  }

  void _createPlanForFocusedArea(List<LibraryEntity> places) {
    final focused = places
        .where((entity) => entity.key == _selectedKey)
        .firstOrNull;
    final areas = PlaceAreaIndex.byCountry(places);
    final anchor = focused ?? places.first;
    final area = _selectedAreaKey != allPlacesAreaKey
        ? areas.firstWhere((candidate) => candidate.key == _selectedAreaKey)
        : areas.firstWhere(
            (candidate) => PlaceAreaIndex.contains(candidate.key, anchor),
          );
    _createPlan(area, focusedEntityKey: focused?.key);
  }

  void _createPlan(PlaceArea area, {String? focusedEntityKey}) {
    context.push(
      '/library/places/itinerary/new',
      extra: PlaceItineraryDraft(
        areaKey: area.key,
        areaTitle: area.title,
        country: area.subtitle,
        focusedEntityKey: focusedEntityKey,
      ),
    );
  }
}

class _PlacesExperience extends StatelessWidget {
  const _PlacesExperience({
    required this.allPlaces,
    required this.visiblePlaces,
    required this.mappedPlaces,
    required this.areas,
    required this.plans,
    required this.selectedKey,
    required this.selectedAreaKey,
    required this.query,
    required this.searchController,
    required this.sheetController,
    required this.sheetExtent,
    required this.onAreaSelected,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onSelected,
    required this.onShowOnMap,
    required this.onOpen,
    required this.onOpenPlan,
    required this.onCreatePlan,
  });

  final List<LibraryEntity> allPlaces;
  final List<LibraryEntity> visiblePlaces;
  final List<LibraryEntity> mappedPlaces;
  final List<PlaceArea> areas;
  final List<PlaceItinerary> plans;
  final String? selectedKey;
  final String selectedAreaKey;
  final String query;
  final TextEditingController searchController;
  final DraggableScrollableController sheetController;
  final ValueNotifier<double> sheetExtent;
  final ValueChanged<String> onAreaSelected;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<LibraryEntity> onSelected;
  final ValueChanged<LibraryEntity> onShowOnMap;
  final ValueChanged<LibraryEntity> onOpen;
  final ValueChanged<PlaceItinerary> onOpenPlan;
  final void Function(PlaceArea area, {String? focusedEntityKey}) onCreatePlan;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= AppLayout.expandedWidth;
        return Stack(
          fit: StackFit.expand,
          children: [
            LibraryPlacesMap(
              entities: mappedPlaces,
              selectedKey: selectedKey,
              onEntityTapped: onSelected,
              showAttribution: false,
              bottomObstructionFraction: isTablet ? null : sheetExtent,
              avoidTopSystemUi: true,
            ),
            ValueListenableBuilder<double>(
              valueListenable: sheetExtent,
              builder: (context, extent, _) => Positioned(
                right: isTablet ? 452 : 8,
                bottom: isTablet ? 8 : constraints.maxHeight * extent + 8,
                child: const _MapAttribution(),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(
                width: isTablet ? 440 : constraints.maxWidth,
                child: DraggableScrollableSheet(
                  controller: sheetController,
                  initialChildSize: _LibraryPlacesScreenState._initialSheetSize,
                  minChildSize: isTablet ? 0.34 : 0.22,
                  maxChildSize: isTablet ? 0.86 : 0.8,
                  snap: true,
                  snapSizes: const [
                    _LibraryPlacesScreenState._initialSheetSize,
                    0.8,
                  ],
                  builder: (context, scrollController) => _PlacesSheet(
                    allPlaces: allPlaces,
                    visiblePlaces: visiblePlaces,
                    areas: areas,
                    plans: plans,
                    selectedKey: selectedKey,
                    selectedAreaKey: selectedAreaKey,
                    query: query,
                    searchController: searchController,
                    extent: sheetExtent,
                    scrollController: scrollController,
                    onAreaSelected: onAreaSelected,
                    onQueryChanged: onQueryChanged,
                    onClearQuery: onClearQuery,
                    onSelected: onSelected,
                    onShowOnMap: onShowOnMap,
                    onOpen: onOpen,
                    onOpenPlan: onOpenPlan,
                    onCreatePlan: onCreatePlan,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlacesSheet extends StatelessWidget {
  const _PlacesSheet({
    required this.allPlaces,
    required this.visiblePlaces,
    required this.areas,
    required this.plans,
    required this.selectedKey,
    required this.selectedAreaKey,
    required this.query,
    required this.searchController,
    required this.extent,
    required this.scrollController,
    required this.onAreaSelected,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onSelected,
    required this.onShowOnMap,
    required this.onOpen,
    required this.onOpenPlan,
    required this.onCreatePlan,
  });

  final List<LibraryEntity> allPlaces;
  final List<LibraryEntity> visiblePlaces;
  final List<PlaceArea> areas;
  final List<PlaceItinerary> plans;
  final String? selectedKey;
  final String selectedAreaKey;
  final String query;
  final TextEditingController searchController;
  final ValueNotifier<double> extent;
  final ScrollController scrollController;
  final ValueChanged<String> onAreaSelected;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<LibraryEntity> onSelected;
  final ValueChanged<LibraryEntity> onShowOnMap;
  final ValueChanged<LibraryEntity> onOpen;
  final ValueChanged<PlaceItinerary> onOpenPlan;
  final void Function(PlaceArea area, {String? focusedEntityKey}) onCreatePlan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedArea = areas
        .where((area) => area.key == selectedAreaKey)
        .firstOrNull;
    return Material(
      elevation: 8,
      shadowColor: cs.shadow.withValues(alpha: 0.16),
      color: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ValueListenableBuilder<double>(
        valueListenable: extent,
        builder: (context, value, _) {
          final expanded = value >= 0.5;
          final focused = visiblePlaces
              .where((entity) => entity.key == selectedKey)
              .firstOrNull;
          final groups = _visibleGroups();
          final images = uniquePlaceImageUrls(visiblePlaces);
          final visiblePlans = plans
              .where(
                (plan) =>
                    PlaceAreaIndex.planInArea(plan.areaKey, selectedAreaKey),
              )
              .toList(growable: false);
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedArea?.title ?? context.l10n.yourPlaces,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            selectedArea == null
                                ? context.l10n.placesAreasSummary(
                                    areas.length,
                                    visiblePlaces.length,
                                  )
                                : context.l10n.libraryPlaceCount(
                                    visiblePlaces.length,
                                  ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (selectedArea != null)
                      IconButton(
                        tooltip: context.l10n.planThisArea,
                        onPressed: () => onCreatePlan(
                          selectedArea,
                          focusedEntityKey: focused?.key,
                        ),
                        icon: const Icon(AppIcons.route),
                      ),
                  ],
                ),
              ),
              _AreaSelector(
                areas: areas,
                selectedKey: selectedAreaKey,
                onSelected: onAreaSelected,
              ),
              if (!expanded && visiblePlaces.isNotEmpty)
                _PlaceCarousel(
                  places: visiblePlaces,
                  images: images,
                  selectedKey: selectedKey,
                  onSelected: onSelected,
                  onOpen: onOpen,
                ),
              if (expanded) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                  child: SearchBar(
                    controller: searchController,
                    hintText: context.l10n.searchSavedPlaces,
                    leading: const AppIcon(AppIcons.search),
                    trailing: [
                      if (query.isNotEmpty)
                        IconButton(
                          tooltip: context.l10n.clearSearch,
                          onPressed: onClearQuery,
                          icon: const Icon(AppIcons.close),
                        ),
                    ],
                    onChanged: onQueryChanged,
                  ),
                ),
                if (visiblePlans.isNotEmpty) ...[
                  _SectionHeading(title: context.l10n.yourPlans),
                  for (final plan in visiblePlans)
                    _ItineraryRow(plan: plan, onTap: () => onOpenPlan(plan)),
                ],
                if (visiblePlaces.isEmpty)
                  const _NoPlaceResults()
                else
                  for (final group in groups) ...[
                    if (selectedArea == null)
                      _SectionHeading(
                        title: group.title,
                        subtitle: context.l10n.libraryPlaceCount(
                          group.entities.length,
                        ),
                        trailing: group.key == unsortedPlacesAreaKey
                            ? null
                            : TextButton.icon(
                                onPressed: () => onCreatePlan(group),
                                icon: const Icon(AppIcons.route, size: 18),
                                label: Text(context.l10n.plan),
                              ),
                      )
                    else
                      const SizedBox(height: 8),
                    for (final entity in group.entities)
                      _PlaceListRow(
                        entity: entity,
                        imageUrl: images[entity.key],
                        showCountry: group.key == unsortedPlacesAreaKey,
                        onOpen: () => onOpen(entity),
                        onShowOnMap: entity.mention.hasCoordinates
                            ? () => onShowOnMap(entity)
                            : null,
                      ),
                  ],
              ],
            ],
          );
        },
      ),
    );
  }

  List<PlaceArea> _visibleGroups() {
    final visibleKeys = visiblePlaces.map((entity) => entity.key).toSet();
    return areas
        .where(
          (area) =>
              selectedAreaKey == allPlacesAreaKey ||
              area.key == selectedAreaKey,
        )
        .map(
          (area) => PlaceArea(
            key: area.key,
            title: area.title,
            subtitle: area.subtitle,
            entities: area.entities
                .where((entity) => visibleKeys.contains(entity.key))
                .toList(growable: false),
          ),
        )
        .where((area) => area.entities.isNotEmpty)
        .toList(growable: false);
  }
}

/// Swipe through the places in view; the map follows, and a pin tapped on
/// the map brings its card to the front.
class _PlaceCarousel extends StatefulWidget {
  const _PlaceCarousel({
    required this.places,
    required this.images,
    required this.selectedKey,
    required this.onSelected,
    required this.onOpen,
  });

  final List<LibraryEntity> places;
  final Map<String, String?> images;
  final String? selectedKey;
  final ValueChanged<LibraryEntity> onSelected;
  final ValueChanged<LibraryEntity> onOpen;

  @override
  State<_PlaceCarousel> createState() => _PlaceCarouselState();
}

class _PlaceCarouselState extends State<_PlaceCarousel> {
  late final PageController _controller = PageController(
    viewportFraction: 0.86,
    initialPage: _selectedIndex,
  );

  int get _selectedIndex {
    final index = widget.places.indexWhere(
      (entity) => entity.key == widget.selectedKey,
    );
    return index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(covariant _PlaceCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.hasClients) return;
    final target = _selectedIndex;
    final current = _controller.page?.round() ?? target;
    if (target == current) return;
    if ((target - current).abs() > 3 ||
        MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(target);
    } else {
      unawaited(
        _controller.animateToPage(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: PageView.builder(
        controller: _controller,
        padEnds: false,
        itemCount: widget.places.length,
        onPageChanged: (index) => widget.onSelected(widget.places[index]),
        itemBuilder: (context, index) {
          final entity = widget.places[index];
          return Padding(
            padding: EdgeInsets.fromLTRB(index == 0 ? 16 : 6, 8, 6, 8),
            child: _PlaceCard(
              entity: entity,
              imageUrl: widget.images[entity.key],
              selected: entity.key == widget.selectedKey,
              onTap: () => widget.onOpen(entity),
            ),
          );
        },
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.entity,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  final LibraryEntity entity;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final why = entity.mention.whyMentioned?.trim() ?? '';
    final locality = _placeLocality(context, entity, withCountry: false);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? cs.primary.withValues(alpha: 0.55) : cs.surface,
          width: 1.5,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 0.92,
                child: LibraryArtwork(
                  entity: entity,
                  imageUrlOverride: imageUrl ?? '',
                  borderRadius: BorderRadius.zero,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entity.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (locality.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          locality,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (why.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          why,
                          maxLines: locality.isEmpty ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaSelector extends StatelessWidget {
  const _AreaSelector({
    required this.areas,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<PlaceArea> areas;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget chip({
      required String label,
      int? count,
      required bool selected,
      required VoidCallback onTap,
    }) => ChoiceChip(
      showCheckmark: false,
      side: BorderSide.none,
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text.rich(
        TextSpan(
          text: label,
          children: [
            if (count != null)
              TextSpan(
                text: '  $count',
                style: TextStyle(
                  color: selected
                      ? cs.onSecondaryContainer.withValues(alpha: 0.7)
                      : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          chip(
            label: context.l10n.all,
            selected: selectedKey == allPlacesAreaKey,
            onTap: () => onSelected(allPlacesAreaKey),
          ),
          for (final area in areas) ...[
            const SizedBox(width: 8),
            chip(
              label: area.title,
              count: area.entities.length,
              selected: selectedKey == area.key,
              onTap: () => onSelected(area.key),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceListRow extends StatelessWidget {
  const _PlaceListRow({
    required this.entity,
    required this.imageUrl,
    required this.showCountry,
    required this.onOpen,
    required this.onShowOnMap,
  });

  final LibraryEntity entity;
  final String? imageUrl;
  final bool showCountry;
  final VoidCallback onOpen;
  final VoidCallback? onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final why = entity.mention.whyMentioned?.trim() ?? '';
    final locality = _placeLocality(context, entity, withCountry: showCountry);
    final meta = [
      if (locality.isNotEmpty) locality,
      ?_statusLabel(context, entity),
    ].join(' · ');
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 64,
              child: LibraryArtwork(
                entity: entity,
                imageUrlOverride: imageUrl ?? '',
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  if (why.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      why,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onShowOnMap != null)
              IconButton(
                tooltip: context.l10n.showOnMap,
                onPressed: onShowOnMap,
                icon: const Icon(AppIcons.showOnMap),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

/// Only states the person chose; "saved" is every row, so it says nothing.
String? _statusLabel(BuildContext context, LibraryEntity entity) =>
    switch (entity.status) {
      LibraryItemStatus.planning => context.l10n.wantToVisit,
      LibraryItemStatus.completed => context.l10n.libraryVisited,
      _ => null,
    };

/// City, or the region when the city repeats the name ("Kyrgyzstan,
/// Kyrgyzstan" said nothing twice).
String _placeLocality(
  BuildContext context,
  LibraryEntity entity, {
  required bool withCountry,
}) {
  final title = entity.title.trim().toLowerCase();
  final parts = <String>[];
  for (final value in [
    entity.mention.city,
    if (withCountry) entity.mention.country,
  ]) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) continue;
    final lower = text.toLowerCase();
    if (lower == title || parts.any((part) => part.toLowerCase() == lower)) {
      continue;
    }
    parts.add(text);
  }
  final locality = parts.join(', ');
  // Says why the place has no pin and no "show on map".
  if (!entity.mention.hasCoordinates) {
    return locality.isEmpty
        ? context.l10n.locationUnavailable
        : '$locality · ${context.l10n.locationUnavailable}';
  }
  return locality;
}

class _ItineraryRow extends StatelessWidget {
  const _ItineraryRow({required this.plan, required this.onTap});

  final PlaceItinerary plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstImage = plan.stops
        .map((stop) => stop.imageUrl?.trim() ?? '')
        .where((url) => url.isNotEmpty)
        .firstOrNull;
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox.square(
          dimension: 54,
          child: firstImage == null
              ? ColoredBox(
                  color: cs.surfaceContainerHigh,
                  child: const Icon(AppIcons.route),
                )
              : CachedNetworkImage(
                  imageUrl: firstImage,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => ColoredBox(
                    color: cs.surfaceContainerHigh,
                    child: const Icon(AppIcons.route),
                  ),
                ),
        ),
      ),
      title: Text(
        plan.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${context.l10n.libraryStopCount(plan.stops.length)}${plan.date == null ? '' : ' · ${MaterialLocalizations.of(context).formatMediumDate(plan.date!)}'}',
      ),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: onTap,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          width: 34,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle?.trim().isNotEmpty == true)
                  Text(
                    subtitle!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          '© Geoapify · © OpenStreetMap',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 9,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _NoPlaceResults extends StatelessWidget {
  const _NoPlaceResults();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: Text(context.l10n.noSavedPlacesMatch)),
    );
  }
}

class _PlacesEmptyState extends StatelessWidget {
  const _PlacesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.explorePlaces,
              size: 52,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.noPlacesDiscovered,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.placesMentionedGatherHere,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
