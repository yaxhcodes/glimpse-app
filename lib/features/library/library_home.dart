import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/analytics_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import 'library_entity.dart';
import 'library_provider.dart';
import 'library_widgets.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
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
    };
    final event = switch (kind) {
      LibraryEntityKind.book => AnalyticsEvent.libraryBooksOpened,
      LibraryEntityKind.movie => AnalyticsEvent.libraryMoviesOpened,
      LibraryEntityKind.place => AnalyticsEvent.libraryPlacesOpened,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Found in your saves',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Recognized and organized by type',
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final expanded = constraints.maxWidth >= AppLayout.mediumWidth;
            if (expanded) {
              return SizedBox(
                height: 246,
                child: Row(
                  children: [
                    for (final kind in LibraryEntityKind.values) ...[
                      Expanded(
                        child: _LibraryDestinationCard(
                          kind: kind,
                          entities: snapshot.ofKind(kind),
                          onTap: () => onOpen(kind),
                        ),
                      ),
                      if (kind != LibraryEntityKind.place)
                        const SizedBox(width: 14),
                    ],
                  ],
                ),
              );
            }
            return Column(
              children: [
                SizedBox(
                  height: 224,
                  child: Row(
                    children: [
                      Expanded(
                        child: _LibraryDestinationCard(
                          kind: LibraryEntityKind.book,
                          entities: snapshot.ofKind(LibraryEntityKind.book),
                          onTap: () => onOpen(LibraryEntityKind.book),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LibraryDestinationCard(
                          kind: LibraryEntityKind.movie,
                          entities: snapshot.ofKind(LibraryEntityKind.movie),
                          onTap: () => onOpen(LibraryEntityKind.movie),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 166,
                  child: _LibraryDestinationCard(
                    kind: LibraryEntityKind.place,
                    entities: snapshot.ofKind(LibraryEntityKind.place),
                    onTap: () => onOpen(LibraryEntityKind.place),
                    horizontal: true,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LibraryDestinationCard extends StatelessWidget {
  const _LibraryDestinationCard({
    required this.kind,
    required this.entities,
    required this.onTap,
    this.horizontal = false,
  });

  final LibraryEntityKind kind;
  final List<LibraryEntity> entities;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final noun = switch (kind) {
      LibraryEntityKind.book => entities.length == 1 ? 'book' : 'books',
      LibraryEntityKind.movie => entities.length == 1 ? 'movie' : 'movies',
      LibraryEntityKind.place => entities.length == 1 ? 'place' : 'places',
    };
    return Semantics(
      button: true,
      label: '${kind.label}, ${entities.length} $noun',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: cs.surfaceContainerLow,
        child: InkWell(
          onTap: entities.isEmpty ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: horizontal
                ? Row(
                    children: [
                      Expanded(child: _PlacesPreview(entities: entities)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DestinationLabel(
                          kind: kind,
                          count: entities.length,
                          noun: noun,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: kind == LibraryEntityKind.place
                            ? _PlacesPreview(entities: entities)
                            : _EditorialArtworkPreview(entities: entities),
                      ),
                      const SizedBox(height: 12),
                      _DestinationLabel(
                        kind: kind,
                        count: entities.length,
                        noun: noun,
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
    required this.noun,
  });

  final LibraryEntityKind kind;
  final int count;
  final String noun;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kind.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                count == 0 ? 'Nothing recognized yet' : '$count $noun',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_rounded,
          size: 22,
          color: count == 0 ? cs.onSurface.withValues(alpha: 0.28) : cs.primary,
        ),
      ],
    );
  }
}

class _EditorialArtworkPreview extends StatelessWidget {
  const _EditorialArtworkPreview({required this.entities});

  final List<LibraryEntity> entities;

  @override
  Widget build(BuildContext context) {
    if (entities.isEmpty) {
      return _DestinationPlaceholder(
        icon: Icons.auto_awesome_mosaic_rounded,
        label: 'Recognized titles will gather here',
      );
    }
    final preview = entities
        .where((entity) => (entity.artworkUrl ?? '').trim().isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (preview.isEmpty) {
      return _DestinationPlaceholder(
        icon: Icons.auto_awesome_mosaic_rounded,
        label: '${entities.length} recognized',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          alignment: Alignment.center,
          children: [
            if (preview.length > 1)
              Transform.translate(
                offset: Offset(width * 0.12, 0),
                child: Opacity(
                  opacity: 0.48,
                  child: FractionallySizedBox(
                    widthFactor: 0.58,
                    child: LibraryArtwork(
                      entity: preview[1],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(preview.length > 1 ? -width * 0.08 : 0, 0),
              child: FractionallySizedBox(
                widthFactor: 0.62,
                child: LibraryArtwork(
                  entity: preview.first,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlacesPreview extends StatelessWidget {
  const _PlacesPreview({required this.entities});

  final List<LibraryEntity> entities;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.tertiaryContainer, cs.primaryContainer],
          ),
        ),
        child: CustomPaint(
          painter: _MapPreviewPainter(
            line: cs.onTertiaryContainer.withValues(alpha: 0.18),
            pin: cs.primary,
            pinCount: entities
                .where((entity) => entity.mention.hasCoordinates)
                .length
                .clamp(0, 6),
          ),
          child: entities.isEmpty
              ? const _DestinationPlaceholder(
                  icon: Icons.map_rounded,
                  label: 'Saved places will appear on a map',
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  const _MapPreviewPainter({
    required this.line,
    required this.pin,
    required this.pinCount,
  });

  final Color line;
  final Color pin;
  final int pinCount;

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
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
    const positions = <Offset>[
      Offset(0.22, 0.34),
      Offset(0.52, 0.22),
      Offset(0.76, 0.54),
      Offset(0.38, 0.68),
      Offset(0.67, 0.79),
      Offset(0.14, 0.76),
    ];
    final pinPaint = Paint()..color = pin;
    for (final position in positions.take(pinCount)) {
      final center = Offset(
        position.dx * size.width,
        position.dy * size.height,
      );
      canvas.drawCircle(center, 7, pinPaint);
      canvas.drawCircle(center, 2.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPreviewPainter oldDelegate) =>
      oldDelegate.line != line ||
      oldDelegate.pin != pin ||
      oldDelegate.pinCount != pinCount;
}

class _DestinationPlaceholder extends StatelessWidget {
  const _DestinationPlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: cs.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
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
        ? 'Adding details'
        : serviceUnavailable
        ? 'Extra details are temporarily unavailable'
        : '${state.failed} ${state.failed == 1 ? 'item' : 'items'} couldn’t be refreshed';
    final supportingText = state.isRunning
        ? '${state.completed.clamp(0, state.total)} of ${state.total}'
        : serviceUnavailable
        ? 'Saved details remain available'
        : '${state.failed} waiting to retry';
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
            TextButton(onPressed: onRetry, child: const Text('Retry')),
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
              'It builds as you save',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Save recommendations for books, movies, and places. Glimpse will organize the things inside them here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
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
        'Library is unavailable right now',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
