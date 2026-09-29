import 'dart:async';

import 'package:flutter/material.dart';
import 'package:glimpse/shared/widgets/app_menu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/place_itinerary.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../ask/ask_launch_request.dart';
import 'library_entity.dart';
import 'library_places_model.dart';
import 'library_provider.dart';
import 'place_itinerary_provider.dart';
import 'package:glimpse/shared/theme/app_icons.dart';
import '../../core/services/app_haptics.dart';

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

  /// The save this plan was laid out from; its order is the reel's.
  int? _sourceUrlId;
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
                    icon: const AppIcon(AppIcons.clearData),
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
                        dayCount: _days.length,
                        estimate: estimateStops(_stops),
                        onSplitIntoDays: () {
                          AppHaptics.play(AppHaptics.tap);
                          _splitIntoDays();
                        },
                        onNameChanged: (_) => _scheduleSave(),
                        onChooseDate: () {
                          AppHaptics.play(AppHaptics.tick);
                          _chooseDate();
                        },
                        onAskGlimpse: _openAskGlimpse,
                      ),
                      itemCount: _stops.length,
                      onReorder: (oldIndex, newIndex) {
                        AppHaptics.play(AppHaptics.land);
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final stop = _stops.removeAt(oldIndex);
                          _stops.insert(newIndex, stop);
                          // A moved stop joins the day it lands in.
                          final neighbour = newIndex > 0
                              ? _stops[newIndex - 1]
                              : _stops.length > 1
                              ? _stops[1]
                              : null;
                          if (neighbour != null) stop.day = neighbour.day;
                        });
                        _scheduleSave();
                      },
                      itemBuilder: (context, index) {
                        final stop = _stops[index];
                        final entity = resolveItineraryStop(stop, places);
                        final days = _days;
                        final startsDay =
                            index == 0 ||
                            _stops[index - 1].dayNumber != stop.dayNumber;
                        final endsDay =
                            index == _stops.length - 1 ||
                            _stops[index + 1].dayNumber != stop.dayNumber;
                        var numberInDay = 1;
                        for (var i = index - 1; i >= 0; i--) {
                          if (_stops[i].dayNumber != stop.dayNumber) break;
                          numberInDay++;
                        }
                        return _StopRow(
                          key: ValueKey(
                            '${stop.entityKey}|${stop.provisionalKey}|$index',
                          ),
                          index: index,
                          number: numberInDay,
                          dayHeader: days.length > 1 && startsDay
                              ? stop.dayNumber
                              : null,
                          dayDetail: days.length > 1 && startsDay
                              ? describeEstimate(
                                  estimateDay(_stops, stop.dayNumber),
                                )
                              : null,
                          stop: stop,
                          entity: entity,
                          isLast: endsDay,
                          canRemove: _stops.length > 1,
                          dayChoices: [
                            for (final day in [
                              ...days,
                              days.isEmpty ? 1 : days.last + 1,
                            ])
                              if (day != stop.dayNumber) day,
                          ],
                          onMoveToDay: (day) => _moveToDay(index, day),
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
                    onAddStops: () {
                      AppHaptics.play(AppHaptics.tick);
                      _chooseStops(places);
                    },
                    onOpenRoute: () {
                      AppHaptics.play(AppHaptics.tap);
                      _openRoute();
                    },
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
      _sourceUrlId = itinerary.sourceUrlId;
      _areaKey = itinerary.areaKey;
      _areaTitle = itinerary.areaTitle;
      _country = itinerary.country;
      _date = itinerary.date;
      _createdAt = itinerary.createdAt;
      _nameController.text = itinerary.name;
      _stops.addAll(itinerary.stops.map(_cloneStop));
      _retireDayName();
      return;
    }

    final draft = widget.draft;
    _areaKey = draft?.areaKey ?? unsortedPlacesAreaKey;
    _areaTitle = draft?.areaTitle ?? 'Saved places';
    _country = draft?.country;
    _createdAt = DateTime.now();
    _nameController.text = _areaTitle == 'Unsorted places'
        ? 'Places to explore'
        : '$_areaTitle trip';
    final places = snapshot
        .ofKind(LibraryEntityKind.place)
        .where(
          (entity) =>
              PlaceAreaIndex.contains(_areaKey ?? allPlacesAreaKey, entity),
        )
        .where(
          (entity) =>
              entity.key == draft?.focusedEntityKey ||
              entity.status == LibraryItemStatus.planning,
        );
    final stops = places.map(itineraryStopFromEntity).toList();
    // An area's places have no order of their own; when they are more than
    // a day, route them and split by time instead of calling it a day.
    if (estimateStops(stops).exceedsADay) {
      final routed = routeOrder(stops);
      assignDays(routed);
      _stops.addAll(routed);
    } else {
      _stops.addAll(stops);
    }
  }

  void _splitIntoDays() {
    setState(() {
      // A reel's order is its route; a hand-picked set gets a drivable one
      // first, or the days zig-zag across the country.
      if (_sourceUrlId == null) {
        final routed = routeOrder(_stops);
        _stops
          ..clear()
          ..addAll(routed);
      }
      assignDays(_stops);
      _retireDayName();
    });
    _scheduleSave();
  }

  /// Plans were once named "A day in Kyrgyzstan" whatever they held; once a
  /// plan runs to several days that name is wrong, so it becomes a trip.
  void _retireDayName() {
    final name = _nameController.text.trim();
    const prefix = 'a day in ';
    if (_days.length > 1 && name.toLowerCase().startsWith(prefix)) {
      _nameController.text = '${name.substring(prefix.length)} trip';
      _scheduleSave();
    }
  }

  /// The plan's days in order; one day when stops carry none.
  List<int> get _days =>
      ({for (final stop in _stops) stop.dayNumber}.toList()..sort());

  void _moveToDay(int index, int day) {
    setState(() {
      final stop = _stops.removeAt(index)..day = day;
      // After the last stop of that day, or where the day would begin.
      var insertAt = _stops.lastIndexWhere((other) => other.dayNumber == day);
      if (insertAt < 0) {
        insertAt = _stops.lastIndexWhere((other) => other.dayNumber < day);
      }
      _stops.insert(insertAt + 1, stop);
    });
    _scheduleSave();
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
      ..imageUrl = source.imageUrl
      ..day = source.day
      ..time = source.time
      ..travel = source.travel
      ..note = source.note;
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      switchToInputEntryModeIcon: const Icon(AppIcons.edit),
      switchToCalendarEntryModeIcon: const AppMaterialIcon(AppIcons.calendar),
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
        .where(
          (entity) =>
              PlaceAreaIndex.contains(_areaKey ?? allPlacesAreaKey, entity),
        )
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
    final lastDay = _days.isEmpty ? null : _days.last;
    final updated = <PlaceItineraryStop>[
      for (final stop in _stops)
        // A stop the Library never resolved is not in the picker; keep it.
        if (stop.entityKey.isEmpty || selected.contains(stop.entityKey)) stop,
      for (final entity in candidates)
        if (selected.contains(entity.key) && !existing.containsKey(entity.key))
          itineraryStopFromEntity(entity)..day = lastDay,
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
      ..sourceUrlId = _sourceUrlId
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
    AppHaptics.play(AppHaptics.success);
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
    AppHaptics.play(AppHaptics.tick);
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
            onPressed: () {
              AppHaptics.play(AppHaptics.tap);
              Navigator.pop(context, true);
            },
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
    final days = _days;
    final segments = days.length > 1
        ? [
            for (final day in days)
              ...routeSegments(_stops.where((stop) => stop.dayNumber == day)),
          ]
        : routeSegments(_stops);
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
                  onTap: () {
                    AppHaptics.play(AppHaptics.tick);
                    Navigator.pop(context, segmentIndex);
                  },
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
    required this.dayCount,
    required this.estimate,
    required this.onSplitIntoDays,
    required this.onNameChanged,
    required this.onChooseDate,
    required this.onAskGlimpse,
  });

  final TextEditingController nameController;
  final String areaTitle;
  final DateTime? date;
  final int stopCount;
  final int dayCount;
  final ItineraryEstimate estimate;
  final VoidCallback onSplitIntoDays;
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
            dayCount > 1 ? '$dayCount-DAY TRIP' : 'DAY PLAN',
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
            [
              areaTitle,
              '$stopCount ${stopCount == 1 ? 'stop' : 'stops'}',
              if (dayCount > 1) ...[
                '$dayCount days',
                if (estimate.km >= 5)
                  describeEstimate(estimate).split(' · ').last,
              ] else if (stopCount > 0)
                describeEstimate(estimate),
            ].join(' · '),
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
                icon: const AppIcon(AppIcons.calendar, size: 18),
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
                icon: const Icon(AppIcons.sparkle, size: 18),
                label: const Text('Plan with Ask Glimpse'),
              ),
            ],
          ),
          // One "day" that cannot be one day: say so, and offer the fix.
          if (dayCount == 1 && estimate.exceedsADay) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About ${estimate.days} days, not one',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Visiting $stopCount places with ${describeEstimate(estimate)} of travel and sightseeing is more than a day holds.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onTertiaryContainer,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: onSplitIntoDays,
                    icon: const AppIcon(AppIcons.calendar, size: 18),
                    label: const Text('Split into days'),
                  ),
                ],
              ),
            ),
          ],
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
              'Choose saved places from this area to start your plan.',
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
    required this.number,
    required this.dayHeader,
    this.dayDetail,
    required this.stop,
    required this.entity,
    required this.isLast,
    required this.canRemove,
    required this.dayChoices,
    required this.onMoveToDay,
    required this.onOpen,
    required this.onRemove,
  });

  final int index;

  /// The stop's place within its day.
  final int number;

  /// The day this stop opens, when the plan has more than one.
  final int? dayHeader;

  /// "about 6 h · 180 km" for the day this stop opens.
  final String? dayDetail;
  final PlaceItineraryStop stop;
  final LibraryEntity? entity;
  final bool isLast;
  final bool canRemove;
  final List<int> dayChoices;
  final ValueChanged<int> onMoveToDay;
  final VoidCallback? onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final stated = [
      ?stop.time,
      if (stop.travel?.trim().isNotEmpty == true && number > 1) stop.travel!,
    ].join(' · ');
    final row = Padding(
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
                      '$number',
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
                        // Text first: a place's "photo" was the reel's
                        // thumbnail, which looked cheap repeated per stop.
                        const SizedBox(width: 6),
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
                              if (stated.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  stated,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.labelMedium?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (stop.note?.trim().isNotEmpty == true) ...[
                                const SizedBox(height: 3),
                                Text(
                                  stop.note!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<int>(
                          tooltip: 'Stop options',
                          icon: const Icon(AppIcons.moreHorizontal),
                          onSelected: (value) {
                            AppHaptics.play(AppHaptics.tick);
                            value < 0 ? onRemove() : onMoveToDay(value);
                          },
                          itemBuilder: (context) => [
                            for (final day in dayChoices)
                              appMenuItem(
                                value: day,
                                icon: AppIcons.calendar,
                                label:
                                    'Move to ${context.l10n.itineraryDay(day)}',
                              ),
                            if (canRemove) ...[
                              appMenuDivider,
                              appMenuItem(
                                value: -1,
                                icon: AppIcons.removeCircle,
                                label: 'Remove stop',
                                destructive: true,
                              ),
                            ],
                          ],
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(AppIcons.dragHandle),
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
    final day = dayHeader;
    if (day == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: index == 0 ? 4 : 14, bottom: 10),
          child: Text.rich(
            TextSpan(
              text: context.l10n.itineraryDay(day),
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              children: [
                if (dayDetail != null)
                  TextSpan(
                    text: '  $dayDetail',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
        row,
      ],
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
                      icon: const Icon(AppIcons.add),
                      label: Text(hasStops ? 'Edit stops' : 'Choose stops'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: routeSegments > 0 && !saving
                          ? onOpenRoute
                          : null,
                      icon: const Icon(AppIcons.route),
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
                      : () {
                          AppHaptics.play(AppHaptics.tap);
                          Navigator.pop(context, _selected);
                        },
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
                        title: Text(entity.title),
                        subtitle: Text(
                          [
                            entity.mention.city,
                            entity.mention.country,
                          ].whereType<String>().join(', '),
                        ),
                        onChanged: (selected) {
                          AppHaptics.play(AppHaptics.tick);
                          setState(() {
                            if (selected == true) {
                              _selected.add(entity.key);
                            } else {
                              _selected.remove(entity.key);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
