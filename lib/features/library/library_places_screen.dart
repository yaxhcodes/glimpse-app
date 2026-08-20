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

class LibraryPlacesScreen extends ConsumerStatefulWidget {
  const LibraryPlacesScreen({super.key});

  @override
  ConsumerState<LibraryPlacesScreen> createState() =>
      _LibraryPlacesScreenState();
}

class _LibraryPlacesScreenState extends ConsumerState<LibraryPlacesScreen> {
  static const _initialSheetSize = 0.3;

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
              icon: const Icon(Icons.route_rounded),
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
          final areas = PlaceAreaIndex.build(places);
          if (_selectedAreaKey != allPlacesAreaKey &&
              areas.every((area) => area.key != _selectedAreaKey)) {
            _selectedAreaKey = allPlacesAreaKey;
          }
          final areaEntities = _selectedAreaKey == allPlacesAreaKey
              ? places
              : areas
                    .firstWhere((area) => area.key == _selectedAreaKey)
                    .entities;
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
    final key = _selectedAreaKey != allPlacesAreaKey
        ? _selectedAreaKey
        : focused == null
        ? PlaceAreaIndex.keyFor(places.first)
        : PlaceAreaIndex.keyFor(focused);
    final area = PlaceAreaIndex.build(
      places,
    ).firstWhere((candidate) => candidate.key == key);
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
                  minChildSize: isTablet ? 0.3 : 0.22,
                  maxChildSize: isTablet ? 0.86 : 0.78,
                  snap: true,
                  snapSizes: const [0.3, 0.78],
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
  final ValueChanged<LibraryEntity> onOpen;
  final ValueChanged<PlaceItinerary> onOpenPlan;
  final void Function(PlaceArea area, {String? focusedEntityKey}) onCreatePlan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          final expanded = value >= 0.46;
          final focused = visiblePlaces
              .where((entity) => entity.key == selectedKey)
              .firstOrNull;
          final groups = _visibleGroups();
          final images = uniquePlaceImageUrls(visiblePlaces);
          final visiblePlans = selectedAreaKey == allPlacesAreaKey
              ? plans
              : plans
                    .where((plan) => plan.areaKey == selectedAreaKey)
                    .toList(growable: false);
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedAreaKey == allPlacesAreaKey
                                ? context.l10n.yourPlaces
                                : areas
                                      .firstWhere(
                                        (area) => area.key == selectedAreaKey,
                                      )
                                      .title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            context.l10n.placesAreasSummary(
                              areas.length,
                              visiblePlaces.length,
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (selectedAreaKey != allPlacesAreaKey)
                      IconButton(
                        tooltip: context.l10n.planThisArea,
                        onPressed: () => onCreatePlan(
                          areas.firstWhere(
                            (area) => area.key == selectedAreaKey,
                          ),
                          focusedEntityKey: focused?.key,
                        ),
                        icon: const Icon(Icons.route_rounded),
                      ),
                  ],
                ),
              ),
              if (!expanded && focused != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: _FocusedPlace(
                    entity: focused,
                    imageUrl: images[focused.key],
                    onTap: () => onOpen(focused),
                  ),
                ),
              _AreaSelector(
                areas: areas,
                selectedKey: selectedAreaKey,
                onSelected: onAreaSelected,
              ),
              if (expanded) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                  child: SearchBar(
                    controller: searchController,
                    hintText: context.l10n.searchSavedPlaces,
                    leading: const Icon(Icons.search_rounded),
                    trailing: [
                      if (query.isNotEmpty)
                        IconButton(
                          tooltip: context.l10n.clearSearch,
                          onPressed: onClearQuery,
                          icon: const Icon(Icons.close_rounded),
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
                    _SectionHeading(
                      title: group.title,
                      subtitle: group.subtitle,
                      trailing: selectedAreaKey == allPlacesAreaKey
                          ? TextButton.icon(
                              onPressed: () => onCreatePlan(group),
                              icon: const Icon(
                                Icons.add_road_rounded,
                                size: 18,
                              ),
                              label: Text(context.l10n.plan),
                            )
                          : null,
                    ),
                    for (final entity in group.entities)
                      _PlaceListRow(
                        entity: entity,
                        imageUrl: images[entity.key],
                        selected: entity.key == selectedKey,
                        onSelect: () => onSelected(entity),
                        onOpen: () => onOpen(entity),
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
    if (selectedAreaKey != allPlacesAreaKey) {
      final selected = areas.firstWhere((area) => area.key == selectedAreaKey);
      return [
        PlaceArea(
          key: selected.key,
          title: selected.title,
          subtitle: selected.subtitle,
          entities: visiblePlaces,
        ),
      ];
    }
    final visibleKeys = visiblePlaces.map((entity) => entity.key).toSet();
    return areas
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

class _FocusedPlace extends StatelessWidget {
  const _FocusedPlace({
    required this.entity,
    required this.imageUrl,
    required this.onTap,
  });

  final LibraryEntity entity;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 112,
          child: Row(
            children: [
              SizedBox(
                width: 126,
                child: LibraryArtwork(
                  entity: entity,
                  imageUrlOverride: imageUrl ?? '',
                  borderRadius: BorderRadius.zero,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entity.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _placeMetadata(context, entity),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PlaceStatusLabel(entity: entity),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.chevron_right_rounded),
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
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          ChoiceChip(
            label: Text(context.l10n.all),
            selected: selectedKey == allPlacesAreaKey,
            side: BorderSide.none,
            onSelected: (_) => onSelected(allPlacesAreaKey),
          ),
          const SizedBox(width: 8),
          for (final area in areas) ...[
            ChoiceChip(
              avatar: const Icon(Icons.location_on_outlined, size: 17),
              label: Text('${area.title}  ${area.entities.length}'),
              selected: selectedKey == area.key,
              side: BorderSide.none,
              onSelected: (_) => onSelected(area.key),
            ),
            const SizedBox(width: 8),
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
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });

  final LibraryEntity entity;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? cs.surfaceContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 76,
                  child: LibraryArtwork(
                    entity: entity,
                    imageUrlOverride: imageUrl ?? '',
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entity.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entity.mention.hasCoordinates
                            ? _placeMetadata(context, entity)
                            : '${_placeMetadata(context, entity)} · ${context.l10n.locationUnavailable}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _PlaceStatusLabel(entity: entity),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.openNamedItem(entity.title),
                  onPressed: onOpen,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceStatusLabel extends StatelessWidget {
  const _PlaceStatusLabel({required this.entity});

  final LibraryEntity entity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, label) = switch (entity.status) {
      LibraryItemStatus.planning => (
        Icons.bookmark_added_rounded,
        context.l10n.wantToVisit,
      ),
      LibraryItemStatus.completed => (
        Icons.check_circle_rounded,
        context.l10n.libraryVisited,
      ),
      _ => (Icons.bookmark_border_rounded, context.l10n.savedPlace),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
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
                  child: const Icon(Icons.route_rounded),
                )
              : CachedNetworkImage(
                  imageUrl: firstImage,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => ColoredBox(
                    color: cs.surfaceContainerHigh,
                    child: const Icon(Icons.route_rounded),
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
      trailing: const Icon(Icons.chevron_right_rounded),
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
              Icons.travel_explore_rounded,
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

String _placeMetadata(BuildContext context, LibraryEntity entity) {
  final label = [
    entity.mention.city,
    entity.mention.country,
  ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
  return label.isEmpty ? context.l10n.savedPlace : label;
}
