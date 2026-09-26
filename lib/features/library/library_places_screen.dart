import 'dart:async';

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
import 'place_geography.dart';
import 'place_itinerary_editor_screen.dart';
import 'place_locality_provider.dart';
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
  String _selectedRegionKey = allPlacesAreaKey;
  String _query = '';
  String _lookupFingerprint = '';

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
    final localities = ref.watch(placeLocalitiesProvider);
    PlaceLocality? localityOf(LibraryEntity entity) =>
        switch (PlaceLocalitiesNotifier.keyOf(entity)) {
          final key? => localities[key],
          null => null,
        };
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
          final pinned = data.ofKind(LibraryEntityKind.place);
          _lookUpRegions(pinned);
          final places = [
            for (final entity in pinned)
              if (!PlaceSubdivisions.isWholeRegion(entity, localityOf(entity)))
                entity,
          ];
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
          // Within one country, browse by state / prefecture / province.
          final regions =
              _selectedAreaKey == allPlacesAreaKey ||
                  _selectedAreaKey == unsortedPlacesAreaKey
              ? const <PlaceRegionGroup>[]
              : PlaceSubdivisions.group(areaEntities, localityOf: localityOf);
          if (_selectedRegionKey != allPlacesAreaKey &&
              regions.every((region) => region.key != _selectedRegionKey)) {
            _selectedRegionKey = allPlacesAreaKey;
          }
          final regionEntities = regions.isEmpty
              ? areaEntities
              : [
                  for (final region in regions)
                    if (_selectedRegionKey == allPlacesAreaKey ||
                        region.key == _selectedRegionKey)
                      ...region.entities,
                ];
          final visible = _filter(regionEntities, localityOf);
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
            regions: regions,
            localityOf: localityOf,
            plans: plans,
            selectedKey: _selectedKey,
            selectedAreaKey: _selectedAreaKey,
            selectedRegionKey: _selectedRegionKey,
            query: _query,
            searchController: _searchController,
            sheetController: _sheetController,
            sheetExtent: _sheetExtent,
            onAreaSelected: _selectArea,
            onRegionSelected: _selectRegion,
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

  List<LibraryEntity> _filter(
    List<LibraryEntity> entities,
    PlaceLocality? Function(LibraryEntity entity) localityOf,
  ) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return entities;
    return entities
        .where((entity) {
          final locality = localityOf(entity);
          return [
            entity.title,
            entity.mention.city,
            entity.mention.country,
            locality?.region,
            locality?.city,
          ].whereType<String>().any(
            (value) => value.toLowerCase().contains(query),
          );
        })
        .toList(growable: false);
  }

  /// Geocodes regions for pins that lack one, after this frame. Keyed on the
  /// pinned set so rebuilds while browsing do not re-enter.
  void _lookUpRegions(List<LibraryEntity> places) {
    final fingerprint = places
        .map(PlaceLocalitiesNotifier.keyOf)
        .nonNulls
        .join('|');
    if (fingerprint.isEmpty || fingerprint == _lookupFingerprint) return;
    _lookupFingerprint = fingerprint;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(placeLocalitiesProvider.notifier).ensure(places));
    });
  }

  void _handleSheetExtentChanged() {
    if (_sheetController.isAttached) {
      _sheetExtent.value = _sheetController.size;
    }
  }

  void _selectRegion(String key) {
    setState(() {
      _selectedRegionKey = key;
      _selectedKey = null;
    });
  }

  void _selectArea(String key) {
    setState(() {
      _selectedAreaKey = key;
      _selectedRegionKey = allPlacesAreaKey;
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
    required this.regions,
    required this.localityOf,
    required this.plans,
    required this.selectedKey,
    required this.selectedAreaKey,
    required this.selectedRegionKey,
    required this.query,
    required this.searchController,
    required this.sheetController,
    required this.sheetExtent,
    required this.onAreaSelected,
    required this.onRegionSelected,
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
  final List<PlaceRegionGroup> regions;
  final PlaceLocality? Function(LibraryEntity entity) localityOf;
  final List<PlaceItinerary> plans;
  final String? selectedKey;
  final String selectedAreaKey;
  final String selectedRegionKey;
  final String query;
  final TextEditingController searchController;
  final DraggableScrollableController sheetController;
  final ValueNotifier<double> sheetExtent;
  final ValueChanged<String> onAreaSelected;
  final ValueChanged<String> onRegionSelected;
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
                    regions: regions,
                    localityOf: localityOf,
                    plans: plans,
                    selectedKey: selectedKey,
                    selectedAreaKey: selectedAreaKey,
                    selectedRegionKey: selectedRegionKey,
                    query: query,
                    searchController: searchController,
                    extent: sheetExtent,
                    scrollController: scrollController,
                    onAreaSelected: onAreaSelected,
                    onRegionSelected: onRegionSelected,
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
    required this.regions,
    required this.localityOf,
    required this.plans,
    required this.selectedKey,
    required this.selectedAreaKey,
    required this.selectedRegionKey,
    required this.query,
    required this.searchController,
    required this.extent,
    required this.scrollController,
    required this.onAreaSelected,
    required this.onRegionSelected,
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
  final List<PlaceRegionGroup> regions;
  final PlaceLocality? Function(LibraryEntity entity) localityOf;
  final List<PlaceItinerary> plans;
  final String? selectedKey;
  final String selectedAreaKey;
  final String selectedRegionKey;
  final String query;
  final TextEditingController searchController;
  final ValueNotifier<double> extent;
  final ScrollController scrollController;
  final ValueChanged<String> onAreaSelected;
  final ValueChanged<String> onRegionSelected;
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
          final regionGroups = _visibleRegionGroups();
          final showRegionHeadings = regionGroups.length >= 2;
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
                                : [
                                    context.l10n.libraryPlaceCount(
                                      visiblePlaces.length,
                                    ),
                                    if (namedRegions >= 2)
                                      _regionCount(
                                        context,
                                        selectedArea.title,
                                        namedRegions,
                                      ),
                                  ].join(' · '),
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
                key: const ValueKey('places-area-selector'),
                areas: areas,
                selectedKey: selectedAreaKey,
                onSelected: onAreaSelected,
              ),
              if (namedRegions >= 2)
                _RegionSelector(
                  key: const ValueKey('places-region-selector'),
                  regions: regions,
                  selectedKey: selectedRegionKey,
                  onSelected: onRegionSelected,
                ),
              if (!expanded && visiblePlaces.isNotEmpty)
                _PlaceCarousel(
                  key: const ValueKey('places-carousel'),
                  places: visiblePlaces,
                  localityOf: localityOf,
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
                else if (selectedArea != null && regionGroups.isNotEmpty)
                  for (final region in regionGroups) ...[
                    if (showRegionHeadings)
                      _SectionHeading(
                        title: region.title ?? context.l10n.otherPlaces,
                        subtitle: context.l10n.libraryPlaceCount(region.length),
                      )
                    else
                      const SizedBox(height: 8),
                    for (final city in region.cities) ...[
                      if (region.cities.length >= 2)
                        _CityHeading(
                          title: city.title ?? context.l10n.otherPlaces,
                          count: city.entities.length,
                        ),
                      for (final entity in city.entities)
                        _PlaceListRow(
                          entity: entity,
                          showCountry: false,
                          // A named city heading already says where it is.
                          showCity:
                              region.cities.length < 2 || city.title == null,
                          onOpen: () => onOpen(entity),
                          onShowOnMap: entity.mention.hasCoordinates
                              ? () => onShowOnMap(entity)
                              : null,
                        ),
                    ],
                  ]
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
                        showCountry: group.key == unsortedPlacesAreaKey,
                        region: PlaceSubdivisions.regionOf(
                          entity,
                          localityOf(entity),
                        ),
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

  int get namedRegions =>
      regions.where((region) => region.title != null).length;

  /// The selected country's regions, cut down to what the search and region
  /// chip leave visible.
  List<PlaceRegionGroup> _visibleRegionGroups() {
    final visibleKeys = visiblePlaces.map((entity) => entity.key).toSet();
    return [
      for (final region in regions)
        if (selectedRegionKey == allPlacesAreaKey ||
            region.key == selectedRegionKey)
          PlaceRegionGroup(
            key: region.key,
            title: region.title,
            cities: [
              for (final city in region.cities)
                if (city.entities
                        .where((entity) => visibleKeys.contains(entity.key))
                        .toList(growable: false)
                    case final members when members.isNotEmpty)
                  PlaceCityGroup(
                    key: city.key,
                    title: city.title,
                    entities: members,
                  ),
            ],
          ),
    ].where((region) => region.cities.isNotEmpty).toList(growable: false);
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
    super.key,
    required this.places,
    required this.localityOf,
    required this.selectedKey,
    required this.onSelected,
    required this.onOpen,
  });

  final List<LibraryEntity> places;
  final PlaceLocality? Function(LibraryEntity entity) localityOf;
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

  /// True while the carousel moves itself to follow the selection, so the
  /// pages it passes are not reported back as new selections.
  bool _following = false;

  @override
  void didUpdateWidget(covariant _PlaceCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Never move the page view here: moving it reports a page change, which
    // sets state on the Places screen mid-build and corrupts the sheet's
    // list (it happened whenever regions arriving reordered the places).
    WidgetsBinding.instance.addPostFrameCallback((_) => _followSelection());
  }

  Future<void> _followSelection() async {
    if (!mounted || _following || !_controller.hasClients) return;
    final target = _selectedIndex;
    final current = _controller.page?.round() ?? target;
    if (target == current) return;
    _following = true;
    try {
      if ((target - current).abs() > 3 ||
          MediaQuery.disableAnimationsOf(context)) {
        _controller.jumpToPage(target);
      } else {
        await _controller.animateToPage(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      _following = false;
    }
    // The selection may have moved again while animating.
    if (mounted && _selectedIndex != _controller.page?.round()) {
      unawaited(_followSelection());
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
        onPageChanged: (index) {
          if (!_following) widget.onSelected(widget.places[index]);
        },
        itemBuilder: (context, index) {
          final entity = widget.places[index];
          return Padding(
            padding: EdgeInsets.fromLTRB(index == 0 ? 16 : 6, 8, 6, 8),
            child: _PlaceCard(
              entity: entity,
              region: PlaceSubdivisions.regionOf(
                entity,
                widget.localityOf(entity),
              ),
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
    required this.region,
    required this.selected,
    required this.onTap,
  });

  final LibraryEntity entity;
  final String? region;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final why = entity.mention.whyMentioned?.trim() ?? '';
    final locality = _placeLocality(
      context,
      entity,
      withCountry: false,
      region: region,
    );
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
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
    super.key,
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

/// "4 prefectures" in English, the localized "4 regions" elsewhere.
String _regionCount(BuildContext context, String country, int count) {
  final english = Localizations.localeOf(context).languageCode == 'en'
      ? englishRegionCount(country, count)
      : null;
  return english ?? context.l10n.placeRegionCount(count);
}

/// A second chip row inside a country: its states, prefectures or provinces.
class _RegionSelector extends StatelessWidget {
  const _RegionSelector({
    super.key,
    required this.regions,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<PlaceRegionGroup> regions;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget chip({
      required String label,
      int? count,
      required bool selected,
      required VoidCallback onTap,
    }) => ChoiceChip(
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(
        color: selected ? Colors.transparent : cs.outlineVariant,
      ),
      backgroundColor: Colors.transparent,
      selectedColor: cs.tertiaryContainer,
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: tt.labelMedium?.copyWith(
        color: selected ? cs.onTertiaryContainer : cs.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      label: Text(count == null ? label : '$label  $count'),
    );
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
        children: [
          chip(
            label: context.l10n.all,
            selected: selectedKey == allPlacesAreaKey,
            onTap: () => onSelected(allPlacesAreaKey),
          ),
          for (final region in regions) ...[
            const SizedBox(width: 6),
            chip(
              label: region.title ?? context.l10n.otherPlaces,
              count: region.length,
              selected: selectedKey == region.key,
              onTap: () => onSelected(region.key),
            ),
          ],
        ],
      ),
    );
  }
}

/// A city inside a region section: quieter than the region heading.
class _CityHeading extends StatelessWidget {
  const _CityHeading({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      child: Row(
        children: [
          AppIcon(AppIcons.place, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PlaceListRow extends StatelessWidget {
  const _PlaceListRow({
    required this.entity,
    required this.showCountry,
    this.showCity = true,
    this.region,
    required this.onOpen,
    required this.onShowOnMap,
  });

  final LibraryEntity entity;
  final bool showCountry;
  final bool showCity;
  final String? region;
  final VoidCallback onOpen;
  final VoidCallback? onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final why = entity.mention.whyMentioned?.trim() ?? '';
    final locality = _placeLocality(
      context,
      entity,
      withCountry: showCountry,
      withCity: showCity,
      region: region,
    );
    final meta = [
      if (locality.isNotEmpty) locality,
      ?_statusLabel(context, entity),
    ].join(' · ');
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
        child: Row(
          children: [
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

/// City and region, skipping any part that repeats another or the place's
/// own name ("Kyrgyzstan, Kyrgyzstan" said nothing twice).
String _placeLocality(
  BuildContext context,
  LibraryEntity entity, {
  required bool withCountry,
  bool withCity = true,
  String? region,
}) {
  final title = entity.title.trim().toLowerCase();
  final parts = <String>[];
  for (final value in [
    if (withCity) entity.mention.city,
    region,
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
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AppIcon(AppIcons.route, color: cs.onSecondaryContainer),
      ),
      title: Text(
        plan.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          context.l10n.libraryStopCount(plan.stops.length),
          if ({for (final stop in plan.stops) stop.dayNumber}.length
              case final days when days > 1)
            context.l10n.itineraryDayCount(days)
          else if (plan.stops.isNotEmpty)
            describeEstimate(estimateStops(plan.stops)),
          if (plan.date != null)
            MaterialLocalizations.of(context).formatMediumDate(plan.date!),
        ].join(' · '),
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
