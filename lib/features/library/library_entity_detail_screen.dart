import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/analytics_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/source_logo.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/music_actions.dart';
import 'library_entity.dart';
import 'library_localization.dart';
import 'library_places_map.dart';
import 'library_places_model.dart';
import 'library_provider.dart';
import 'library_reading_progress.dart';
import 'library_status_picker.dart';
import 'library_widgets.dart';
import 'place_itinerary_editor_screen.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

class LibraryEntityDetailScreen extends ConsumerStatefulWidget {
  const LibraryEntityDetailScreen({
    super.key,
    required this.entityKey,
    this.siblingKeys = const [],
  });

  final String entityKey;

  /// The grid this page was opened from, in its order; swiping sideways
  /// moves through it. Empty when opened from anywhere else.
  final List<String> siblingKeys;

  @override
  ConsumerState<LibraryEntityDetailScreen> createState() =>
      _LibraryEntityDetailScreenState();
}

class _LibraryEntityDetailScreenState
    extends ConsumerState<LibraryEntityDetailScreen> {
  late final List<String> _keys = widget.siblingKeys.contains(widget.entityKey)
      ? widget.siblingKeys
      : [widget.entityKey];
  late final PageController _pages = PageController(
    initialPage: _keys.indexOf(widget.entityKey),
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(librarySnapshotProvider);
    return snapshot.when(
      loading: () =>
          const Scaffold(body: Center(child: ExpressiveLoadingIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$error')),
      ),
      data: (data) {
        if (_keys.length == 1) return _page(context, data, _keys.single);
        return PageView.builder(
          controller: _pages,
          itemCount: _keys.length,
          itemBuilder: (context, index) => _page(context, data, _keys[index]),
        );
      },
    );
  }

  Widget _page(BuildContext context, LibrarySnapshot data, String key) {
    final entity = data.byKey(key);
    if (entity == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.l10n.libraryItemUnavailable)),
      );
    }
    return _EntityDetail(
      key: ValueKey(key),
      entity: entity,
      onStatusChanged: (status) => _setStatus(context, ref, entity, status),
      onReadingPageChanged: (page) =>
          _setReadingPage(context, ref, entity, page),
      onHide: () => _hideWithUndo(context, ref, entity),
    );
  }

  Future<void> _setReadingPage(
    BuildContext context,
    WidgetRef ref,
    LibraryEntity entity,
    int page,
  ) async {
    try {
      await ref.read(libraryEntityActionsProvider).setReadingPage(entity, page);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotUpdateBookmark)),
      );
    }
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
        SnackBar(content: Text(context.l10n.couldNotUpdateLibraryItem)),
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
          content: Text(context.l10n.hiddenFromLibrary(entity.title)),
          action: SnackBarAction(
            label: context.l10n.undo,
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
    super.key,
    required this.entity,
    required this.onStatusChanged,
    required this.onReadingPageChanged,
    required this.onHide,
  });

  final LibraryEntity entity;
  final Future<void> Function(LibraryItemStatus status) onStatusChanged;
  final Future<void> Function(int page) onReadingPageChanged;
  final Future<void> Function() onHide;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPlace = entity.kind == LibraryEntityKind.place;
    final reasons = entity.sources
        .map((source) => source.mention.whyMentioned?.trim() ?? '')
        .where((reason) => reason.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final plot = entity.mention.plot?.trim() ?? '';
    final sections = <Widget>[
      if (entity.kind == LibraryEntityKind.book &&
          entity.status == LibraryItemStatus.active)
        LibraryReadingProgressCard(
          entity: entity,
          onPageChanged: onReadingPageChanged,
        ),
      if (isPlace && entity.genres.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final genre in entity.genres) LibraryGenreChip(label: genre),
          ],
        ),
      if (entity.kind == LibraryEntityKind.movie && plot.isNotEmpty)
        _DetailSection(title: context.l10n.plot, child: _BodyText(plot)),
      if (reasons.isNotEmpty)
        _DetailSection(
          title: context.l10n.whyItMattered,
          child: _WhyItMattered(reasons: reasons),
        ),
      _DetailSection(
        title: context.l10n.foundInYourSaves,
        child: _SourceSaves(entity: entity),
      ),
    ];
    return Scaffold(
      extendBodyBehindAppBar: !isPlace,
      appBar: AppBar(
        // Clear over the cover wash, solid once the page scrolls under it.
        backgroundColor: isPlace
            ? null
            : WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.scrolledUnder)
                    ? cs.surfaceContainer
                    : Colors.transparent,
              ),
        surfaceTintColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(AppIcons.more),
            tooltip: context.l10n.libraryItemOptions,
            onSelected: (value) {
              if (value == 'hide') onHide();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'hide',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(AppIcons.visibilityOff),
                  title: Text(context.l10n.hideFromLibrary),
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: isPlace
                ? _Constrained(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: _PlaceHeader(
                      entity: entity,
                      onStatusChanged: onStatusChanged,
                    ),
                  )
                : _MediaHero(entity: entity, onStatusChanged: onStatusChanged),
          ),
          SliverToBoxAdapter(
            child: _Constrained(
              padding: EdgeInsets.fromLTRB(20, isPlace ? 24 : 4, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < sections.length; index++) ...[
                    if (index > 0) const SizedBox(height: 28),
                    sections[index],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Constrained extends StatelessWidget {
  const _Constrained({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// The page opens like a title card: the cover, heavily blurred, fills the
/// top of the screen behind the status bar and melts into the page, with the
/// cover itself centred on it. Titles without art wash in their printed ink.
class _MediaHero extends StatelessWidget {
  const _MediaHero({required this.entity, required this.onStatusChanged});

  final LibraryEntity entity;
  final Future<void> Function(LibraryItemStatus status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final width = MediaQuery.sizeOf(context).width;
    final isMusic = entity.kind == LibraryEntityKind.music;
    final coverWidth = isMusic
        ? (width * 0.56).clamp(180.0, 260.0)
        : (width * 0.4).clamp(140.0, 200.0);
    final rating = entity.kind == LibraryEntityKind.movie
        ? entity.mention.imdbRating
        : null;
    final hasRating =
        rating != null && rating.isFinite && rating > 0 && rating <= 10;
    final metadata = _metadata(context, entity);
    final metaStyle = tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    return Stack(
      children: [
        Positioned.fill(child: _CoverWash(entity: entity)),
        _Constrained(
          padding: EdgeInsets.fromLTRB(24, top + 8, 24, 28),
          child: Column(
            children: [
              Container(
                width: coverWidth,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.5 : 0.22),
                      blurRadius: 36,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: libraryArtworkAspectRatio(entity.kind),
                  child: Hero(
                    tag: 'library-artwork-${entity.key}',
                    child: LibraryArtwork(
                      entity: entity,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                entity.title,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.editorial(
                  tt.headlineMedium,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: metadata),
                    if (hasRating) ...[
                      const TextSpan(text: ' · '),
                      TextSpan(
                        text: rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: ' IMDb'),
                    ],
                  ],
                ),
                textAlign: TextAlign.center,
                style: metaStyle,
              ),
              if (entity.genres.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final genre in entity.genres) _GenrePill(label: genre),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              if (isMusic)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: MusicOpenButton(
                    title: entity.title,
                    artist: entity.mention.creator,
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: entity.status == LibraryItemStatus.unlisted
                      ? FilledButton.icon(
                          onPressed: () => _chooseStatus(context),
                          icon: AppIcon(
                            libraryStatusIcon(entity.status, entity.kind),
                          ),
                          label: Text(_statusLabel(context)),
                        )
                      : FilledButton.tonalIcon(
                          onPressed: () => _chooseStatus(context),
                          icon: AppIcon(
                            libraryStatusIcon(entity.status, entity.kind),
                          ),
                          label: Text(_statusLabel(context)),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(BuildContext context) =>
      entity.status == LibraryItemStatus.unlisted
      ? entity.kind == LibraryEntityKind.book
            ? context.l10n.addToReadingList
            : context.l10n.addToWatchlist
      : localizedLibraryStatus(context.l10n, entity.status, entity.kind);

  Future<void> _chooseStatus(BuildContext context) async {
    final selected = await showLibraryStatusPicker(context, entity: entity);
    if (selected == null || selected == entity.status) return;
    await onStatusChanged(selected);
  }
}

class _CoverWash extends StatelessWidget {
  const _CoverWash({required this.entity});

  final LibraryEntity entity;

  @override
  Widget build(BuildContext context) {
    // The page colour, not cs.surface: on the black theme they differ and
    // the wash would end in a visible seam.
    final page = Theme.of(context).scaffoldBackgroundColor;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final artwork = entity.artworkUrl?.trim() ?? '';
    final Widget wash = artwork.isEmpty
        ? ColoredBox(
            color: libraryFallbackTone(
              entity.title,
              0.3,
            ).withValues(alpha: dark ? 0.55 : 0.3),
          )
        : Opacity(
            opacity: dark ? 0.6 : 0.42,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 48,
                sigmaY: 48,
                tileMode: TileMode.clamp,
              ),
              child: CachedNetworkImage(
                imageUrl: artwork,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          );
    // The blur paints past its box; clip it to the hero.
    return IgnorePointer(
      child: ClipRect(
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: page),
              wash,
              // Melt into the page so there is no edge where the wash stops.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      page.withValues(alpha: dark ? 0.1 : 0.2),
                      page.withValues(alpha: 0.35),
                      page,
                    ],
                    stops: const [0, 0.55, 1],
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

class _GenrePill extends StatelessWidget {
  const _GenrePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: cs.onSurface.withValues(alpha: 0.16)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        child: Text(
          localizedLibraryGenre(context.l10n, label),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
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
          child: LibraryPlacesMap(
            entities: [entity],
            selectedKey: entity.key,
            onEntityTapped: (_) {},
            borderRadius: BorderRadius.circular(24),
          ),
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
          _metadata(context, entity),
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              avatar: const Icon(AppIcons.bookmarkAdd, size: 18),
              label: Text(context.l10n.wantToVisit),
              selected: entity.status == LibraryItemStatus.planning,
              side: BorderSide.none,
              onSelected: (selected) => onStatusChanged(
                selected
                    ? LibraryItemStatus.planning
                    : LibraryItemStatus.unlisted,
              ),
            ),
            FilterChip(
              avatar: const Icon(AppIcons.checkCircle, size: 18),
              label: Text(context.l10n.libraryVisited),
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
                icon: const Icon(AppIcons.route),
                label: Text(context.l10n.planAVisit),
              ),
            ),
            if (entity.mention.hasCoordinates) ...[
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: () => _openInMaps(entity),
                icon: const Icon(AppIcons.map),
                label: Text(context.l10n.maps),
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

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.8),
        height: 1.5,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < reasons.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: _BodyText(reasons[index])),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SourceSaves extends StatelessWidget {
  const _SourceSaves({required this.entity});

  final LibraryEntity entity;

  static String _sourceName(String domain) {
    final host = domain.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final label = host.split('.').first;
    return switch (label) {
      'youtu' || 'm' when host.contains('youtu') => 'youtube',
      'instagr' => 'instagram',
      _ => label,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < entity.sources.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                indent: 60,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            InkWell(
              onTap: () => context.push('/url/${entity.sources[index].urlId}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SourceLogo(
                        name: _sourceName(entity.sources[index].domain),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entity.sources[index].title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entity.sources[index].domain,
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      AppIcons.chevronRight,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _metadata(BuildContext context, LibraryEntity entity) {
  final values = switch (entity.kind) {
    LibraryEntityKind.book => [entity.mention.creator, entity.mention.year],
    LibraryEntityKind.movie => [
      entity.mention.year,
      localizedLibrarySubtype(context.l10n, entity.mention.subtype),
    ],
    LibraryEntityKind.place => [entity.mention.city, entity.mention.country],
    LibraryEntityKind.music => [entity.mention.creator, entity.mention.year],
  };
  final label = values
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .join(' · ');
  return label.isEmpty
      ? localizedLibraryKindSingular(context.l10n, entity.kind)
      : label;
}
