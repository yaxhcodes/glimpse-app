import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/place_itinerary.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../ask/ask_launch_request.dart';
import 'library_entity.dart';
import 'library_places_model.dart';
import 'library_provider.dart';
import 'place_itinerary_provider.dart';

class PlaceItineraryDraft {
  const PlaceItineraryDraft({
    required this.areaKey,
    required this.areaTitle,
    this.country,
    this.focusedEntityKey,
  });

  final String areaKey;
  final String areaTitle;
  final String? country;
  final String? focusedEntityKey;
}

class PlaceItineraryEditorScreen extends ConsumerStatefulWidget {
  const PlaceItineraryEditorScreen({super.key, this.itineraryId, this.draft});

  final int? itineraryId;
  final PlaceItineraryDraft? draft;

  @override
  ConsumerState<PlaceItineraryEditorScreen> createState() =>
      _PlaceItineraryEditorScreenState();
}

class _PlaceItineraryEditorScreenState
    extends ConsumerState<PlaceItineraryEditorScreen> {
  final TextEditingController _nameController = TextEditingController();
  final List<PlaceItineraryStop> _stops = [];
  Timer? _saveTimer;
  bool _initialized = false;
  bool _initialStatusApplied = false;
  bool _saving = false;
  bool _allowPop = false;
  int? _savedId;
  String? _areaKey;
  String? _areaTitle;
  String? _country;
  DateTime? _date;
  DateTime? _createdAt;

  @override
  void dispose() {
    _saveTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(librarySnapshotProvider);
    final itinerariesAsync = ref.watch(placeItinerariesProvider);
    return snapshotAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: ExpressiveLoadingIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Could not open this plan'))),
      data: (snapshot) {
        final itinerary = widget.itineraryId == null
            ? null
            : itinerariesAsync.valueOrNull
                  ?.where((plan) => plan.id == widget.itineraryId)
                  .firstOrNull;
        if (!_initialized) {
          if (widget.itineraryId != null && itinerary == null) {
            if (itinerariesAsync.isLoading) {
              return const Scaffold(
                body: Center(child: ExpressiveLoadingIndicator()),
              );
            }
            return const Scaffold(
              body: Center(child: Text('This itinerary is unavailable.')),
            );
          }
          _initialize(snapshot, itinerary);
        }
        final places = snapshot.ofKind(LibraryEntityKind.place);
        if (!_initialStatusApplied) {
          _initialStatusApplied = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _markStopsWantToVisit(places),
          );
        }
        return PopScope(
          canPop: _allowPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_saveBeforePop());
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(_savedId == null ? 'New itinerary' : 'Your plan'),
              actions: [
                if (_savedId != null)
                  IconButton(
                    tooltip: 'Delete itinerary',
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                TextButton(
                  onPressed: () => _done(places),
                  child: const Text('Done'),
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 116),
                      buildDefaultDragHandles: false,
                      header: _EditorHeader(
                        nameController: _nameController,
                        areaTitle: _areaTitle ?? 'Saved places',
                        date: _date,
                        stopCount: _stops.length,
                        onNameChanged: (_) => _scheduleSave(),
                        onChooseDate: _chooseDate,
                        onAskGlimpse: _openAskGlimpse,
                      ),
                      itemCount: _stops.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final stop = _stops.removeAt(oldIndex);
                          _stops.insert(newIndex, stop);
                        });
                        _scheduleSave();
                      },
                      itemBuilder: (context, index) {
                        final stop = _stops[index];
                        final entity = resolveItineraryStop(stop, places);
                        return _StopRow(
                          key: ValueKey(
                            '${stop.entityKey}|${stop.provisionalKey}|$index',
                          ),
                          index: index,
                          stop: stop,
                          entity: entity,
                          isLast: index == _stops.length - 1,
                          canRemove: _stops.length > 1,
                          onOpen: entity == null
                              ? null
                              : () => context.push(
                                  '/library/entity/${Uri.encodeComponent(entity.key)}',
                                ),
                          onRemove: () => _removeStop(index),
                        );
                      },
                    ),
                  ),
                  _EditorActions(
                    saving: _saving,
                    hasStops: _stops.isNotEmpty,
                    routeSegments: routeSegments(_stops).length,
                    unmappedCount: _stops
                        .where((stop) => !stop.hasCoordinates)
                        .length,
                    onAddStops: () => _chooseStops(places),
                    onOpenRoute: _openRoute,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _initialize(LibrarySnapshot snapshot, PlaceItinerary? itinerary) {
    _initialized = true;
    if (itinerary != null) {
      _savedId = itinerary.id;
      _areaKey = itinerary.areaKey;
      _areaTitle = itinerary.areaTitle;
      _country = itinerary.country;
      _date = itinerary.date;
      _createdAt = itinerary.createdAt;
      _nameController.text = itinerary.name;
      _stops.addAll(itinerary.stops.map(_cloneStop));
      return;
    }

    final draft = widget.draft;
    _areaKey = draft?.areaKey ?? unsortedPlacesAreaKey;
    _areaTitle = draft?.areaTitle ?? 'Saved places';
    _country = draft?.country;
    _createdAt = DateTime.now();
    _nameController.text = _areaTitle == 'Unsorted places'
        ? 'Places to explore'
        : 'A day in $_areaTitle';
    final places = snapshot
        .ofKind(LibraryEntityKind.place)
        .where((entity) => PlaceAreaIndex.keyFor(entity) == _areaKey)
        .where(
          (entity) =>
              entity.key == draft?.focusedEntityKey ||
              entity.status == LibraryItemStatus.planning,
        );
    _stops.addAll(places.map(itineraryStopFromEntity));
  }

  PlaceItineraryStop _cloneStop(PlaceItineraryStop source) {
    return PlaceItineraryStop()
      ..entityKey = source.entityKey
      ..provisionalKey = source.provisionalKey
      ..catalogId = source.catalogId
      ..catalogSource = source.catalogSource
      ..sourceUrlIds = List<int>.from(source.sourceUrlIds)
      ..title = source.title
      ..city = source.city
      ..country = source.country
      ..latitude = source.latitude
      ..longitude = source.longitude
      ..imageUrl = source.imageUrl;
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selected == null || !mounted) return;
    setState(() => _date = selected);
    _scheduleSave();
  }

  void _openAskGlimpse() {
    final area = _areaTitle?.trim().isNotEmpty == true
        ? _areaTitle!.trim()
        : 'this area';
    context.push(
      '/ask',
      extra: AskLaunchRequest(
        initialPrompt:
            'Build an editable one-day itinerary for $area using only places from my saves. Put the stops in a practical order and keep the day realistic.',
      ),
    );
  }

  Future<void> _chooseStops(List<LibraryEntity> places) async {
    final candidates = places
        .where((entity) => PlaceAreaIndex.keyFor(entity) == _areaKey)
        .toList(growable: false);
    final selectedKeys = _stops.map((stop) => stop.entityKey).toSet();
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _StopPicker(entities: candidates, initialKeys: selectedKeys),
    );
    if (selected == null || !mounted) return;

    final previousKeys = _stops.map((stop) => stop.entityKey).toSet();
    final existing = {
      for (final stop in _stops)
        if (selected.contains(stop.entityKey)) stop.entityKey: stop,
    };
    final updated = <PlaceItineraryStop>[
      for (final stop in _stops)
        if (selected.contains(stop.entityKey)) stop,
      for (final entity in candidates)
        if (selected.contains(entity.key) && !existing.containsKey(entity.key))
          itineraryStopFromEntity(entity),
    ];
    setState(() {
      _stops
        ..clear()
        ..addAll(updated);
    });
    _scheduleSave();

    var statusFailures = 0;
    for (final entity in candidates.where(
      (entity) =>
          selected.contains(entity.key) && !previousKeys.contains(entity.key),
    )) {
      if (entity.status == LibraryItemStatus.planning) continue;
      try {
        await ref
            .read(libraryEntityActionsProvider)
            .setStatus(entity, LibraryItemStatus.planning);
      } catch (_) {
        statusFailures++;
      }
    }
    if (statusFailures > 0 && mounted) {
      _showSnack(
        'Plan saved, but $statusFailures ${statusFailures == 1 ? 'place' : 'places'} could not be marked Want to visit.',
      );
    }
  }

  Future<void> _markStopsWantToVisit(List<LibraryEntity> places) async {
    for (final stop in _stops) {
      final entity = resolveItineraryStop(stop, places);
      if (entity == null || entity.status != LibraryItemStatus.unlisted) {
        continue;
      }
      try {
        await ref
            .read(libraryEntityActionsProvider)
            .setStatus(entity, LibraryItemStatus.planning);
      } catch (_) {
        if (mounted) {
          _showSnack(
            'This plan is ready, but ${entity.title} could not be marked Want to visit.',
          );
        }
      }
    }
  }

  void _removeStop(int index) {
    if (_stops.length <= 1) {
      _showSnack('An itinerary needs at least one stop.');
      return;
    }
    setState(() => _stops.removeAt(index));
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    if (_stops.isEmpty || _nameController.text.trim().isEmpty) return;
    _saveTimer = Timer(const Duration(milliseconds: 650), _save);
  }

  Future<bool> _save() async {
    if (_stops.isEmpty || _nameController.text.trim().isEmpty) return false;
    if (_saving) return true;
    setState(() => _saving = true);
    final isNew = _savedId == null;
    final itinerary = PlaceItinerary()
      ..id = _savedId ?? PlaceItinerary().id
      ..name = _nameController.text.trim()
      ..areaKey = _areaKey
      ..areaTitle = _areaTitle
      ..country = _country
      ..date = _date
      ..createdAt = _createdAt ?? DateTime.now()
      ..updatedAt = DateTime.now()
      ..stops = _stops.map(_cloneStop).toList(growable: false);
    try {
      final id = await ref.read(placeItineraryActionsProvider).save(itinerary);
      if (isNew) {
        unawaited(
          ref
              .read(analyticsServiceProvider)
              .trackEvent(AnalyticsEvent.placeItineraryCreated),
        );
      }
      if (!mounted) return true;
      setState(() {
        _savedId = id;
        _saving = false;
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _saving = false);
      _showSnack('Could not save this itinerary.');
      return false;
    }
  }

  Future<void> _done(List<LibraryEntity> places) async {
    _saveTimer?.cancel();
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Give this itinerary a name.');
      return;
    }
    if (_stops.isEmpty) {
      await _chooseStops(places);
      if (_stops.isEmpty) return;
    }
    if (await _save() && mounted) {
      setState(() => _allowPop = true);
      context.pop();
    }
  }

  Future<void> _saveBeforePop() async {
    if (_saving) return;
    _saveTimer?.cancel();
    final hasDraft =
        _stops.isNotEmpty && _nameController.text.trim().isNotEmpty;
    if (hasDraft && !await _save()) return;
    if (!mounted) return;
    setState(() => _allowPop = true);
    context.pop();
  }

  Future<void> _delete() async {
    final id = _savedId;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete itinerary?'),
        content: const Text(
          'The plan will be removed. Your saved places and their statuses will stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(placeItineraryActionsProvider).delete(id);
    if (mounted) {
      setState(() => _allowPop = true);
      context.pop();
    }
  }

  Future<void> _openRoute() async {
    final segments = routeSegments(_stops);
    if (segments.isEmpty) {
      _showSnack('Add at least two mapped stops to open a route.');
      return;
    }
    var index = 0;
    if (segments.length > 1) {
      final selected = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Open a route segment'),
                subtitle: Text(
                  'Long plans are split so every stop opens reliably in Maps.',
                ),
              ),
              for (
                var segmentIndex = 0;
                segmentIndex < segments.length;
                segmentIndex++
              )
                ListTile(
                  leading: CircleAvatar(child: Text('${segmentIndex + 1}')),
                  title: Text(
                    '${segments[segmentIndex].first.title} to ${segments[segmentIndex].last.title}',
                  ),
                  subtitle: Text('${segments[segmentIndex].length} stops'),
                  onTap: () => Navigator.pop(context, segmentIndex),
                ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      index = selected;
    }
    final opened = await launchUrl(
      googleMapsRouteUri(segments[index]),
      mode: LaunchMode.externalApplication,
    );
    if (opened) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .trackEvent(AnalyticsEvent.placeItineraryRouteOpened),
      );
    }
    if (!opened && mounted) _showSnack('Could not open this route.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.nameController,
    required this.areaTitle,
    required this.date,
    required this.stopCount,
    required this.onNameChanged,
    required this.onChooseDate,
    required this.onAskGlimpse,
  });

  final TextEditingController nameController;
  final String areaTitle;
  final DateTime? date;
  final int stopCount;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onChooseDate;
  final VoidCallback onAskGlimpse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAY PLAN',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: nameController,
            onChanged: onNameChanged,
            textCapitalization: TextCapitalization.sentences,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Name your itinerary',
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          Text(
            '$areaTitle · $stopCount ${stopCount == 1 ? 'stop' : 'stops'}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: onChooseDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(
                  date == null
                      ? 'Add a date'
                      : MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(date!),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onAskGlimpse,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Plan with Ask Glimpse'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Stops',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (stopCount == 0) ...[
            const SizedBox(height: 8),
            Text(
              'Choose saved places from this area to start your day plan.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    super.key,
    required this.index,
    required this.stop,
    required this.entity,
    required this.isLast,
    required this.canRemove,
    required this.onOpen,
    required this.onRemove,
  });

  final int index;
  final PlaceItineraryStop stop;
  final LibraryEntity? entity;
  final bool isLast;
  final bool canRemove;
  final VoidCallback? onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final image = entity?.placeImageUrl ?? stop.imageUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        color: cs.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox.square(
                            dimension: 70,
                            child: image?.trim().isNotEmpty == true
                                ? CachedNetworkImage(
                                    imageUrl: image!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => _StopFallback(
                                      mapped: stop.hasCoordinates,
                                    ),
                                    errorWidget: (_, _, _) => _StopFallback(
                                      mapped: stop.hasCoordinates,
                                    ),
                                  )
                                : _StopFallback(mapped: stop.hasCoordinates),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entity?.title ?? stop.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                      entity?.mention.city ?? stop.city,
                                      entity?.mention.country ?? stop.country,
                                      if (!stop.hasCoordinates)
                                        'Location unavailable',
                                      if (entity == null) 'Saved snapshot',
                                    ]
                                    .whereType<String>()
                                    .where((value) => value.isNotEmpty)
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (canRemove)
                          PopupMenuButton<String>(
                            tooltip: 'Stop options',
                            icon: const Icon(Icons.more_horiz_rounded),
                            onSelected: (_) => onRemove(),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'remove',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.remove_circle_outline),
                                  title: Text('Remove stop'),
                                ),
                              ),
                            ],
                          ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.drag_handle_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopFallback extends StatelessWidget {
  const _StopFallback({required this.mapped});

  final bool mapped;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Icon(
        mapped ? Icons.place_rounded : Icons.location_off_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _EditorActions extends StatelessWidget {
  const _EditorActions({
    required this.saving,
    required this.hasStops,
    required this.routeSegments,
    required this.unmappedCount,
    required this.onAddStops,
    required this.onOpenRoute,
  });

  final bool saving;
  final bool hasStops;
  final int routeSegments;
  final int unmappedCount;
  final VoidCallback onAddStops;
  final VoidCallback onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: cs.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (unmappedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '$unmappedCount ${unmappedCount == 1 ? 'stop has' : 'stops have'} no mapped location and will be left out of the route.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: saving ? null : onAddStops,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(hasStops ? 'Edit stops' : 'Choose stops'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: routeSegments > 0 && !saving
                          ? onOpenRoute
                          : null,
                      icon: const Icon(Icons.route_rounded),
                      label: Text(
                        routeSegments > 1 ? 'Route parts' : 'Open route',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopPicker extends StatefulWidget {
  const _StopPicker({required this.entities, required this.initialKeys});

  final List<LibraryEntity> entities;
  final Set<String> initialKeys;

  @override
  State<_StopPicker> createState() => _StopPickerState();
}

class _StopPickerState extends State<_StopPicker> {
  late final Set<String> _selected = {...widget.initialKeys};

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose stops',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.entities.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No saved places are available in this area.',
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.entities.length,
                    itemBuilder: (context, index) {
                      final entity = widget.entities[index];
                      return CheckboxListTile(
                        value: _selected.contains(entity.key),
                        secondary: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox.square(
                            dimension: 48,
                            child:
                                entity.placeImageUrl?.trim().isNotEmpty == true
                                ? CachedNetworkImage(
                                    imageUrl: entity.placeImageUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : const _StopFallback(mapped: true),
                          ),
                        ),
                        title: Text(entity.title),
                        subtitle: Text(
                          [
                            entity.mention.city,
                            entity.mention.country,
                          ].whereType<String>().join(', '),
                        ),
                        onChanged: (selected) => setState(() {
                          if (selected == true) {
                            _selected.add(entity.key);
                          } else {
                            _selected.remove(entity.key);
                          }
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
