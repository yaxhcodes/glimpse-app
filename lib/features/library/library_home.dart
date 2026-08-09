import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/analytics_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../shared/theme/app_layout.dart';
import 'library_entity.dart';
import 'library_provider.dart';
import 'library_widgets.dart';

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
      loading: () => const Center(child: CircularProgressIndicator()),
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
                padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 4),
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
                12,
                horizontal,
                widget.bottomPadding,
              ),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.crossAxisExtent >= 800 ? 3 : 1;
                  if (columns == 1) {
                    return SliverList.separated(
                      itemCount: LibraryEntityKind.values.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final kind = LibraryEntityKind.values[index];
                        return SizedBox(
                          height: 330,
                          child: _LibraryDestinationCard(
                            kind: kind,
                            entities: snapshot.ofKind(kind),
                            onTap: () => _openKind(context, kind),
                          ),
                        );
                      },
                    );
                  }
                  return SliverGrid.builder(
                    itemCount: LibraryEntityKind.values.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.88,
                    ),
                    itemBuilder: (context, index) {
                      final kind = LibraryEntityKind.values[index];
                      return _LibraryDestinationCard(
                        kind: kind,
                        entities: snapshot.ofKind(kind),
                        onTap: () => _openKind(context, kind),
                      );
                    },
                  );
                },
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

class _LibraryDestinationCard extends StatelessWidget {
  const _LibraryDestinationCard({
    required this.kind,
    required this.entities,
    required this.onTap,
  });

  final LibraryEntityKind kind;
  final List<LibraryEntity> entities;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: kind == LibraryEntityKind.place
                      ? _PlacesPreview(entities: entities)
                      : _ArtworkMosaic(entities: entities),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kind.label,
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entities.isEmpty
                                ? 'Nothing recognized yet'
                                : '${entities.length} $noun',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: entities.isEmpty
                          ? cs.onSurface.withValues(alpha: 0.3)
                          : cs.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkMosaic extends StatelessWidget {
  const _ArtworkMosaic({required this.entities});

  final List<LibraryEntity> entities;

  @override
  Widget build(BuildContext context) {
    if (entities.isEmpty) {
      return _DestinationPlaceholder(
        icon: Icons.auto_awesome_mosaic_rounded,
        label: 'Recognized titles will gather here',
      );
    }
    final preview = entities.take(3).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          alignment: Alignment.center,
          children: [
            for (var index = 0; index < preview.length; index++)
              Transform.translate(
                offset: Offset(
                  (index - (preview.length - 1) / 2) * width * 0.2,
                  0,
                ),
                child: Transform.rotate(
                  angle: (index - (preview.length - 1) / 2) * 0.07,
                  child: SizedBox(
                    width: width * 0.42,
                    child: AspectRatio(
                      aspectRatio: 0.68,
                      child: LibraryArtwork(
                        entity: preview[index],
                        borderRadius: BorderRadius.circular(14),
                      ),
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
        ? 'Organizing Library details'
        : serviceUnavailable
        ? 'Extra details are temporarily unavailable'
        : '${state.failed} ${state.failed == 1 ? 'item' : 'items'} couldn’t be refreshed';
    final supportingText = state.isRunning
        ? 'Your books and movies are already available.'
        : serviceUnavailable
        ? 'Your Library still works with details already saved on this device.'
        : 'Check your connection and try again.';
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (state.isRunning)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                serviceUnavailable
                    ? Icons.info_outline_rounded
                    : Icons.cloud_off_rounded,
                size: 22,
                color: cs.onSurfaceVariant,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    supportingText,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!state.isRunning && state.failed > 0 && !serviceUnavailable)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilledButton.tonal(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ),
          ],
        ),
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
              'Your Library will build itself',
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
