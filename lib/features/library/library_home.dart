import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/analytics_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import 'library_entity.dart';
import 'library_localization.dart';
import 'library_provider.dart';
import 'library_widgets.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.library)),
      body: const LibraryHome(),
    );
  }
}

class LibraryHome extends ConsumerStatefulWidget {
  const LibraryHome({super.key, this.bottomPadding = 24});

  final double bottomPadding;

  @override
  ConsumerState<LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends ConsumerState<LibraryHome> {
  String _lastBackfillFingerprint = '';

  @override
  void initState() {
    super.initState();
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .trackEvent(
            AnalyticsEvent.libraryOpened,
            screen: AnalyticsScreen.collections,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(librarySnapshotProvider);
    final backfill = ref.watch(libraryBackfillProvider);
    return async.when(
      loading: () => const Center(child: ExpressiveLoadingIndicator()),
      error: (_, _) => const _LibraryErrorState(),
      data: (snapshot) {
        _scheduleBackfill(snapshot);
        if (snapshot.entities.isEmpty) {
          return const _LibraryEmptyState();
        }
        final horizontal = AppLayout.pageHorizontalPadding(
          MediaQuery.sizeOf(context).width,
          compactPadding: 16,
        );
        return CustomScrollView(
          key: const PageStorageKey('automatic-library-home'),
          slivers: [
            if (backfill.isRunning || backfill.failed > 0)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 0),
                sliver: SliverToBoxAdapter(
                  child: _BackfillStatus(
                    state: backfill,
                    onRetry: () => ref
                        .read(libraryBackfillProvider.notifier)
                        .retry(snapshot.entities),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                14,
                horizontal,
                widget.bottomPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: _LibraryDashboard(
                  snapshot: snapshot,
                  onOpen: (kind) => _openKind(context, kind),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _scheduleBackfill(LibrarySnapshot snapshot) {
    final fingerprint = snapshot.entities
        .where((entity) => entity.needsResolution)
        .map((entity) => entity.key)
        .join('|');
    if (fingerprint.isEmpty || fingerprint == _lastBackfillFingerprint) return;
    _lastBackfillFingerprint = fingerprint;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(libraryBackfillProvider.notifier).start(snapshot.entities),
      );
    });
  }

  void _openKind(BuildContext context, LibraryEntityKind kind) {
    final route = switch (kind) {
      LibraryEntityKind.book => '/library/books',
      LibraryEntityKind.movie => '/library/movies',
      LibraryEntityKind.place => '/library/places',
      LibraryEntityKind.music => '/library/music',
    };
    final event = switch (kind) {
      LibraryEntityKind.book => AnalyticsEvent.libraryBooksOpened,
      LibraryEntityKind.movie => AnalyticsEvent.libraryMoviesOpened,
      LibraryEntityKind.place => AnalyticsEvent.libraryPlacesOpened,
      LibraryEntityKind.music => AnalyticsEvent.libraryMusicOpened,
    };
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .trackEvent(event, screen: AnalyticsScreen.collections),
    );
    context.push(route);
  }
}

class _LibraryDashboard extends StatelessWidget {
  const _LibraryDashboard({required this.snapshot, required this.onOpen});

  final LibrarySnapshot snapshot;
  final ValueChanged<LibraryEntityKind> onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final places = snapshot.ofKind(LibraryEntityKind.place);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.foundInYourSaves, style: tt.headlineSmall),
        const SizedBox(height: 3),
        Text(
          context.l10n.recognizedOrganizedByType,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final horizontal =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(18) > 25;
            final artworkHeight = ((constraints.maxWidth - 12) / 2 * 0.85)
                .clamp(148.0, 208.0);
            final cards = [
              for (final (kind, entities) in [
                (
                  LibraryEntityKind.book,
                  snapshot.ofKind(LibraryEntityKind.book),
                ),
                (
                  LibraryEntityKind.movie,
                  snapshot.ofKind(LibraryEntityKind.movie),
                ),
              ])
                _LibraryDestinationCard(
                  kind: kind,
                  count: entities.length,
                  onTap: entities.isEmpty ? null : () => onOpen(kind),
                  horizontal: horizontal,
                  preview: SizedBox(
                    width: horizontal ? 72 : null,
                    height: horizontal ? 96 : artworkHeight,
                    child: _EditorialArtworkPreview(
                      kind: kind,
                      entities: entities,
                    ),
                  ),
                ),
            ];
            if (horizontal) {
              return Column(
                children: [cards.first, const SizedBox(height: 12), cards.last],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards.first),
                  const SizedBox(width: 12),
                  Expanded(child: cards.last),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _LibraryDestinationCard(
          kind: LibraryEntityKind.place,
          count: places.length,
          onTap: places.isEmpty ? null : () => onOpen(LibraryEntityKind.place),
          horizontal: true,
          preview: const SizedBox.square(
            dimension: 64,
            child: _PlacesPreview(),
          ),
        ),
        const SizedBox(height: 12),
        _MusicDestinationCard(
          count: snapshot.ofKind(LibraryEntityKind.music).length,
          onTap: () => onOpen(LibraryEntityKind.music),
        ),
      ],
    );
  }
}

class _MusicDestinationCard extends StatelessWidget {
  const _MusicDestinationCard({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _LibraryDestinationCard(
      kind: LibraryEntityKind.music,
      count: count,
      horizontal: true,
      onTap: onTap ?? () => context.push('/library/music'),
      preview: SizedBox.square(
        dimension: 64,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.music_note_rounded, color: cs.primary, size: 28),
        ),
      ),
    );
  }
}

class _LibraryDestinationCard extends StatelessWidget {
  const _LibraryDestinationCard({
    required this.kind,
    required this.count,
    required this.preview,
    required this.onTap,
    this.horizontal = false,
  });

  final LibraryEntityKind kind;
  final int count;
  final Widget preview;
  final VoidCallback? onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Card.filled(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: cs.surfaceContainer,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: horizontal
                ? Row(
                    children: [
                      ExcludeSemantics(child: preview),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DestinationLabel(
                          kind: kind,
                          count: count,
                          enabled: onTap != null,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(child: preview),
                      const SizedBox(height: 16),
                      const Spacer(),
                      _DestinationLabel(
                        kind: kind,
                        count: count,
                        enabled: onTap != null,
                        trailingBelowTitle: true,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _DestinationLabel extends StatelessWidget {
  const _DestinationLabel({
    required this.kind,
    required this.count,
    required this.enabled,
    this.trailingBelowTitle = false,
  });

  final LibraryEntityKind kind;
  final int count;
  final bool enabled;
  final bool trailingBelowTitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = Text(
      localizedLibraryKind(context.l10n, kind),
      style: tt.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: cs.onSurface,
      ),
    );
    final subtitle = Text(
      count == 0
          ? kind == LibraryEntityKind.music
                ? context.l10n.libraryMusicDescription
                : context.l10n.nothingRecognizedYet
          : localizedLibraryCount(context.l10n, kind, count),
      style: tt.bodySmall?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w400,
      ),
    );
    final chevron = Icon(
      Icons.chevron_right_rounded,
      size: 20,
      color: enabled
          ? cs.onSurfaceVariant
          : cs.onSurface.withValues(alpha: 0.38),
    );
    if (trailingBelowTitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(child: subtitle),
              const SizedBox(width: 8),
              chevron,
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 2), subtitle],
          ),
        ),
        const SizedBox(width: 8),
        chevron,
      ],
    );
  }
}

class _EditorialArtworkPreview extends StatelessWidget {
  const _EditorialArtworkPreview({required this.kind, required this.entities});

  final LibraryEntityKind kind;
  final List<LibraryEntity> entities;

  @override
  Widget build(BuildContext context) {
    if (entities.isEmpty) {
      return Center(
        child: Icon(
          kind == LibraryEntityKind.book
              ? Icons.menu_book_rounded
              : Icons.movie_rounded,
          size: 36,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    final withArtwork = entities
        .where((entity) => (entity.artworkUrl ?? '').trim().isNotEmpty)
        .take(2)
        .toList(growable: false);
    final preview = withArtwork.isEmpty
        ? entities.take(2).toList(growable: false)
        : withArtwork;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackFactor = preview.length > 1 ? 1.28 : 1.0;
        final coverWidth = (constraints.maxHeight * 2 / 3).clamp(
          0.0,
          constraints.maxWidth / stackFactor,
        );
        final coverHeight = coverWidth * 3 / 2;
        return Center(
          child: SizedBox(
            width: coverWidth * stackFactor,
            height: coverHeight,
            child: Stack(
              children: [
                if (preview.length > 1)
                  Positioned(
                    right: 0,
                    top: coverHeight * 0.06,
                    bottom: coverHeight * 0.06,
                    width: coverWidth * 0.88,
                    child: Opacity(
                      opacity: 0.72,
                      child: LibraryArtwork(
                        entity: preview[1],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: coverWidth,
                  child: LibraryArtwork(
                    entity: preview.first,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlacesPreview extends StatelessWidget {
  const _PlacesPreview();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: cs.surfaceContainerHigh,
        child: CustomPaint(
          painter: _MapPreviewPainter(
            line: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          child: Center(
            child: Icon(Icons.place_rounded, color: cs.primary, size: 28),
          ),
        ),
      ),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  const _MapPreviewPainter({required this.line});

  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var index = 0; index < 5; index++) {
      final path = Path()
        ..moveTo(0, size.height * (0.15 + index * 0.18))
        ..cubicTo(
          size.width * 0.3,
          size.height * (0.02 + index * 0.2),
          size.width * 0.62,
          size.height * (0.35 + index * 0.08),
          size.width,
          size.height * (0.1 + index * 0.17),
        );
      canvas.drawPath(path, roadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPreviewPainter oldDelegate) =>
      oldDelegate.line != line;
}

class _BackfillStatus extends StatelessWidget {
  const _BackfillStatus({required this.state, required this.onRetry});

  final LibraryBackfillState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final serviceUnavailable =
        state.issue == LibraryBackfillIssue.serviceUnavailable;
    final title = state.isRunning
        ? context.l10n.addingDetails
        : serviceUnavailable
        ? context.l10n.extraDetailsUnavailable
        : context.l10n.itemsCouldNotRefresh(state.failed);
    final supportingText = state.isRunning
        ? context.l10n.progressOf(
            state.completed.clamp(0, state.total),
            state.total,
          )
        : serviceUnavailable
        ? context.l10n.savedDetailsRemainAvailable
        : context.l10n.waitingToRetry(state.failed);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          if (state.isRunning)
            const SizedBox.square(
              dimension: 16,
              child: ExpressiveLoadingIndicator(size: 16),
            )
          else
            Icon(
              serviceUnavailable
                  ? Icons.info_outline_rounded
                  : Icons.cloud_off_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(
                    text: ' · $supportingText',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.canRetry)
            TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 64, color: cs.primary),
            const SizedBox(height: 20),
            Text(
              context.l10n.libraryBuildsAsYouSave,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.libraryEmptyDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            const _MusicDestinationCard(count: 0),
          ],
        ),
      ),
    );
  }
}

class _LibraryErrorState extends StatelessWidget {
  const _LibraryErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.l10n.libraryUnavailable,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
