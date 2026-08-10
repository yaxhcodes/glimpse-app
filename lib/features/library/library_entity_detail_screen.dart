import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/providers/analytics_provider.dart';
import '../../core/services/analytics_service.dart';
import 'library_entity.dart';
import 'library_places_map.dart';
import 'library_places_model.dart';
import 'library_provider.dart';
import 'library_status_picker.dart';
import 'library_widgets.dart';
import 'place_itinerary_editor_screen.dart';

class LibraryEntityDetailScreen extends ConsumerWidget {
  const LibraryEntityDetailScreen({super.key, required this.entityKey});

  final String entityKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(librarySnapshotProvider);
    return snapshot.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$error')),
      ),
      data: (data) {
        final entity = data.byKey(entityKey);
        if (entity == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('This Library item is unavailable.'),
            ),
          );
        }
        return _EntityDetail(
          entity: entity,
          onStatusChanged: (status) => _setStatus(context, ref, entity, status),
          onHide: () => _hideWithUndo(context, ref, entity),
        );
      },
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    LibraryEntity entity,
    LibraryItemStatus status,
  ) async {
    try {
      await ref.read(libraryEntityActionsProvider).setStatus(entity, status);
      if (entity.kind == LibraryEntityKind.place) {
        unawaited(
          ref
              .read(analyticsServiceProvider)
              .trackEvent(AnalyticsEvent.libraryPlaceStatusChanged),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this Library item.')),
      );
    }
  }

  Future<void> _hideWithUndo(
    BuildContext context,
    WidgetRef ref,
    LibraryEntity entity,
  ) async {
    final preferences = ref.read(libraryPreferencesProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    await preferences.hide(entity.key, provisionalKey: entity.provisionalKey);
    if (!context.mounted) return;
    context.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${entity.title} hidden from Library'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => preferences.unhide(
              entity.key,
              provisionalKey: entity.provisionalKey,
            ),
          ),
        ),
      );
  }
}

class _EntityDetail extends StatelessWidget {
  const _EntityDetail({
    required this.entity,
    required this.onStatusChanged,
    required this.onHide,
  });

  final LibraryEntity entity;
  final Future<void> Function(LibraryItemStatus status) onStatusChanged;
  final Future<void> Function() onHide;

  @override
  Widget build(BuildContext context) {
    final reasons = entity.sources
        .map((source) => source.mention.whyMentioned?.trim() ?? '')
        .where((reason) => reason.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Library item options',
            onSelected: (value) {
              if (value == 'hide') onHide();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'hide',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.visibility_off_outlined),
                  title: Text('Hide from Library'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entity.kind == LibraryEntityKind.place)
                        _PlaceHeader(
                          entity: entity,
                          onStatusChanged: onStatusChanged,
                        )
                      else
                        _MediaHeader(
                          entity: entity,
                          onStatusChanged: onStatusChanged,
                        ),
                      if (entity.kind == LibraryEntityKind.place &&
                          entity.genres.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final genre in entity.genres)
                              LibraryGenreChip(label: genre),
                          ],
                        ),
                      ],
                      if (reasons.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _WhyItMattered(reasons: reasons),
                      ],
                      const SizedBox(height: 20),
                      _SourceSaves(entity: entity),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaHeader extends StatelessWidget {
  const _MediaHeader({required this.entity, required this.onStatusChanged});

  final LibraryEntity entity;
  final Future<void> Function(LibraryItemStatus status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final artworkWidth = constraints.maxWidth < 360 ? 112.0 : 132.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: artworkWidth,
              child: AspectRatio(
                aspectRatio: 0.68,
                child: Hero(
                  tag: 'library-artwork-${entity.key}',
                  child: LibraryArtwork(
                    entity: entity,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity.title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.08,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _metadata(entity),
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (entity.genres.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final genre in entity.genres)
                          LibraryGenreChip(label: genre),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _chooseStatus(context),
                      icon: Icon(libraryStatusIcon(entity.status, entity.kind)),
                      label: Text(
                        entity.status == LibraryItemStatus.unlisted
                            ? entity.kind == LibraryEntityKind.book
                                  ? 'Add to your reading list'
                                  : 'Add to your watchlist'
                            : entity.status.labelFor(entity.kind),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _chooseStatus(BuildContext context) async {
    final selected = await showLibraryStatusPicker(context, entity: entity);
    if (selected == null || selected == entity.status) return;
    await onStatusChanged(selected);
  }
}

class _PlaceHeader extends StatelessWidget {
  const _PlaceHeader({required this.entity, required this.onStatusChanged});

  final LibraryEntity entity;
  final Future<void> Function(LibraryItemStatus status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 248,
          width: double.infinity,
          child: _PlaceDetailHero(entity: entity),
        ),
        const SizedBox(height: 22),
        Text(
          entity.title,
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _metadata(entity),
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Want to visit'),
              selected: entity.status == LibraryItemStatus.planning,
              side: BorderSide.none,
              onSelected: (selected) => onStatusChanged(
                selected
                    ? LibraryItemStatus.planning
                    : LibraryItemStatus.unlisted,
              ),
            ),
            FilterChip(
              avatar: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Visited'),
              selected: entity.status == LibraryItemStatus.completed,
              side: BorderSide.none,
              onSelected: (selected) => onStatusChanged(
                selected
                    ? LibraryItemStatus.completed
                    : LibraryItemStatus.unlisted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _planVisit(context),
                icon: const Icon(Icons.route_rounded),
                label: const Text('Plan a visit'),
              ),
            ),
            if (entity.mention.hasCoordinates) ...[
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: () => _openInMaps(entity),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Maps'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _planVisit(BuildContext context) {
    final area = PlaceAreaIndex.build([entity]).single;
    context.push(
      '/library/places/itinerary/new',
      extra: PlaceItineraryDraft(
        areaKey: area.key,
        areaTitle: area.title,
        country: area.subtitle,
        focusedEntityKey: entity.key,
      ),
    );
  }

  Future<void> _openInMaps(LibraryEntity entity) async {
    final latitude = entity.mention.latitude;
    final longitude = entity.mention.longitude;
    if (latitude == null || longitude == null) return;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _PlaceDetailHero extends StatelessWidget {
  const _PlaceDetailHero({required this.entity});

  final LibraryEntity entity;

  @override
  Widget build(BuildContext context) {
    final imageUrl = entity.placeImageUrl?.trim() ?? '';
    final map = LibraryPlacesMap(
      entities: [entity],
      selectedKey: entity.key,
      onEntityTapped: (_) {},
      borderRadius: BorderRadius.circular(24),
      showFitAllControl: false,
    );
    if (imageUrl.isEmpty) return map;
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, _) => ColoredBox(
          color: cs.surfaceContainerHigh,
          child: Center(
            child: Icon(
              Icons.landscape_outlined,
              size: 42,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        errorWidget: (_, _, _) => map,
      ),
    );
  }
}

class _WhyItMattered extends StatelessWidget {
  const _WhyItMattered({required this.reasons});

  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why it mattered',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < reasons.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              Text(
                reasons[index],
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.42,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceSaves extends StatelessWidget {
  const _SourceSaves({required this.entity});

  final LibraryEntity entity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: const Icon(Icons.link_rounded),
          title: const Text('Found in your saves'),
          subtitle: Text(
            '${entity.sources.length} ${entity.sources.length == 1 ? 'save' : 'saves'}',
          ),
          children: [
            for (final source in entity.sources)
              ListTile(
                dense: true,
                title: Text(
                  source.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(source.domain),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/url/${source.urlId}'),
              ),
          ],
        ),
      ),
    );
  }
}

String _metadata(LibraryEntity entity) {
  final values = switch (entity.kind) {
    LibraryEntityKind.book => [entity.mention.creator, entity.mention.year],
    LibraryEntityKind.movie => [
      entity.mention.year,
      _titleCase(entity.mention.subtype),
    ],
    LibraryEntityKind.place => [entity.mention.city, entity.mention.country],
  };
  final label = values
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .join(' · ');
  return label.isEmpty ? entity.kind.singularLabel : label;
}

String? _titleCase(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return '${text[0].toUpperCase()}${text.substring(1)}';
}
