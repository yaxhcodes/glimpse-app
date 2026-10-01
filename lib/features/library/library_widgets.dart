import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'library_entity.dart';
import 'library_localization.dart';
import 'library_radial_status_menu.dart';
import 'library_status_picker.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

class LibraryArtwork extends StatelessWidget {
  const LibraryArtwork({
    super.key,
    required this.entity,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.fit = BoxFit.cover,
    this.imageUrlOverride,
  });

  final LibraryEntity entity;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final String? imageUrlOverride;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final artwork =
        imageUrlOverride?.trim() ??
        (entity.kind == LibraryEntityKind.place
            ? entity.placeImageUrl?.trim()
            : entity.artworkUrl?.trim()) ??
        '';
    final fallback = _ArtworkFallback(entity: entity);
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        // A hairline keeps pale covers from bleeding into a light page.
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: cs.onSurface.withValues(alpha: 0.08),
            width: 0.6,
          ),
        ),
        child: ColoredBox(
          color: cs.surfaceContainerHigh,
          child: artwork.isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: artwork,
                  fit: fit,
                  fadeInDuration: const Duration(milliseconds: 180),
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

/// Cover proportions per kind: posters and book jackets are 2:3, album art
/// is square.
double libraryArtworkAspectRatio(LibraryEntityKind kind) =>
    kind == LibraryEntityKind.music ? 1 : 2 / 3;

/// "1988 · Series" for films, "Author · 2004" for books: what sits under a
/// cover. Only known facts; never a placeholder.
String libraryEntityByline(BuildContext context, LibraryEntity entity) {
  final creator = entity.mention.creator?.trim() ?? '';
  final year = entity.mention.year?.trim() ?? '';
  final subtype = entity.kind == LibraryEntityKind.movie
      ? localizedLibrarySubtype(context.l10n, entity.mention.subtype)
      : '';
  final values = entity.kind == LibraryEntityKind.movie
      ? [
          year,
          if (subtype.isNotEmpty && subtype != context.l10n.libraryMovie)
            subtype,
        ]
      : [creator, year];
  return values.where((value) => value.isNotEmpty).join(' · ');
}

class LibraryEntityTile extends StatelessWidget {
  const LibraryEntityTile({
    super.key,
    required this.entity,
    required this.onTap,
    required this.onStatusSelected,
    required this.onStatusMenuRequested,
  });

  final LibraryEntity entity;
  final VoidCallback onTap;
  final ValueChanged<LibraryItemStatus> onStatusSelected;
  final VoidCallback onStatusMenuRequested;

  /// Space under the cover for two title lines and the byline, at the
  /// current text scale.
  static double textBlockHeight(BuildContext context) =>
      12 + MediaQuery.textScalerOf(context).scale(56);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final byline = libraryEntityByline(context, entity);
    Widget artwork({required bool useHero, required bool showStatusBadge}) {
      final artwork = LibraryArtwork(
        entity: entity,
        borderRadius: BorderRadius.circular(10),
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: dark ? 0.4 : 0.14),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (useHero)
              Hero(tag: 'library-artwork-${entity.key}', child: artwork)
            else
              artwork,
            if (showStatusBadge && entity.status != LibraryItemStatus.unlisted)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _LibraryStatusBadge(entity: entity),
                ),
              ),
          ],
        ),
      );
    }

    Widget content({required bool useHero, required bool showStatusBadge}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: libraryArtworkAspectRatio(entity.kind),
              child: artwork(
                useHero: useHero,
                showStatusBadge: showStatusBadge,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              entity.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
            if (byline.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                byline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        );
    return LibraryRadialStatusTarget(
      entity: entity,
      onTap: onTap,
      onStatusSelected: onStatusSelected,
      onStatusMenuRequested: onStatusMenuRequested,
      preview: content(useHero: false, showStatusBadge: false),
      child: content(useHero: true, showStatusBadge: true),
    );
  }
}

class _LibraryStatusBadge extends StatelessWidget {
  const _LibraryStatusBadge({required this.entity});

  final LibraryEntity entity;

  @override
  Widget build(BuildContext context) {
    final label =
        entity.kind == LibraryEntityKind.book &&
            entity.status == LibraryItemStatus.active &&
            entity.currentPage != null
        ? context.l10n.libraryReadingPageStatus(entity.currentPage!)
        : localizedLibraryStatus(context.l10n, entity.status, entity.kind);
    return Semantics(
      label: context.l10n.libraryStatusSemantics(label),
      child: DecoratedBox(
        key: ValueKey('library-status-badge-${entity.key}'),
        decoration: ShapeDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                libraryStatusIcon(entity.status, entity.kind),
                size: 12,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
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

class LibraryGenreChip extends StatelessWidget {
  const LibraryGenreChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        localizedLibraryGenre(context.l10n, label),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Deep, desaturated inks, like spines on a shelf.
const _fallbackHues = [214.0, 352.0, 152.0, 278.0, 32.0, 188.0, 12.0, 238.0];

/// The ink a title without cover art is printed in; stable per title so the
/// grid, the hero and its page wash agree.
Color libraryFallbackTone(String title, double lightness) {
  final hash = title.trim().toLowerCase().codeUnits.fold<int>(
    7,
    (value, unit) => (value * 31 + unit) & 0x7fffffff,
  );
  final hue = _fallbackHues[hash % _fallbackHues.length];
  return HSLColor.fromAHSL(1, hue, 0.3, lightness).toColor();
}

/// A cover for a title the catalogs have no art for, set like a printed
/// poster or a cloth-bound book: a deep ink picked from the title, a thin
/// frame and the title in the editorial serif. It reads as intentional next
/// to real posters rather than as a missing image.
class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.entity});

  final LibraryEntity entity;

  @override
  Widget build(BuildContext context) {
    if (entity.kind == LibraryEntityKind.place) {
      return _PlaceArtworkFallback(icon: placeKindIcon(entity.title));
    }
    final tt = Theme.of(context).textTheme;
    final title = entity.title.trim();
    final isBook = entity.kind == LibraryEntityKind.book;
    final subtype = entity.kind == LibraryEntityKind.movie
        ? localizedLibrarySubtype(context.l10n, entity.mention.subtype)
        : '';
    final kindLabel =
        (subtype.isEmpty
                ? localizedLibraryKindSingular(context.l10n, entity.kind)
                : subtype)
            .toUpperCase();
    final footer = isBook
        ? entity.mention.creator?.trim() ?? ''
        : entity.mention.year?.trim() ?? '';
    const ink = Colors.white;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 84;
        final inset = (width * 0.07).clamp(4.0, 14.0);
        final spine = isBook ? (width * 0.07).clamp(4.0, 12.0) : 0.0;
        // Shrink so the longest word fits a line instead of breaking
        // mid-word ("Iconograph-y"); serif letters average ~0.55em.
        final textWidth = width - spine - inset * 3.8;
        final longestWord = title
            .split(RegExp(r'\s+'))
            .fold<int>(
              0,
              (longest, word) => word.length > longest ? word.length : longest,
            );
        final titleSize = [
          width * 0.125,
          if (longestWord > 0) textWidth / (longestWord * 0.55),
        ].reduce((a, b) => a < b ? a : b).clamp(9.0, 30.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                libraryFallbackTone(title, 0.3),
                libraryFallbackTone(title, 0.17),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isBook)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: spine,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.32),
                          Colors.black.withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border(
                        right: BorderSide(
                          color: ink.withValues(alpha: 0.12),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: spine + inset,
                top: inset,
                right: inset,
                bottom: inset,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ink.withValues(alpha: 0.16),
                      width: 0.8,
                    ),
                  ),
                  child: compact
                      ? Center(
                          child: Text(
                            title.isEmpty
                                ? ''
                                : title.characters.first.toUpperCase(),
                            style: tt.headlineSmall?.copyWith(
                              color: ink.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Padding(
                          padding: EdgeInsets.all(inset * 0.9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kindLabel,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: tt.labelSmall?.copyWith(
                                  color: ink.withValues(alpha: 0.6),
                                  fontSize: (titleSize * 0.42).clamp(7.0, 11.0),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                title,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleLarge?.copyWith(
                                  color: ink.withValues(alpha: 0.94),
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w600,
                                  height: 1.1,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (footer.isNotEmpty) ...[
                                SizedBox(height: titleSize * 0.4),
                                Container(
                                  width: titleSize * 1.2,
                                  height: 0.8,
                                  color: ink.withValues(alpha: 0.3),
                                ),
                                SizedBox(height: titleSize * 0.35),
                                Text(
                                  footer,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.labelSmall?.copyWith(
                                    color: ink.withValues(alpha: 0.66),
                                    fontSize: (titleSize * 0.46).clamp(
                                      8.0,
                                      12.0,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What kind of place a name describes, so a place without a photo still
/// reads as a peak, a lake or a stay instead of one generic pin.
IconData placeKindIcon(String title) {
  final name = ' ${title.toLowerCase()} ';
  bool has(List<String> words) => words.any(name.contains);
  if (has([
    ' hotel',
    ' hostel',
    ' resort',
    ' inn ',
    ' lodge',
    ' guesthouse',
    ' homestay',
    ' auberge',
    ' villa',
  ])) {
    return AppIcons.placeStay;
  }
  if (has([' camp', ' yurt', ' campsite'])) return AppIcons.placeCamp;
  if (has([' cafe', ' café', ' coffee', ' bakery'])) return AppIcons.placeCafe;
  if (has([
    ' restaurant',
    ' dhaba',
    ' bistro',
    ' diner',
    ' eatery',
    ' food',
    ' market',
  ])) {
    return AppIcons.food;
  }
  if (has([
    ' temple',
    ' mandir',
    ' church',
    ' mosque',
    ' monastery',
    ' cathedral',
    ' shrine',
    ' gurudwara',
    ' abbey',
  ])) {
    return AppIcons.placeWorship;
  }
  if (has([
    ' castle',
    ' fort',
    ' palace',
    ' château',
    ' chateau',
    ' citadel',
  ])) {
    return AppIcons.placeCastle;
  }
  if (has([
    ' museum',
    ' gallery',
    ' observatory',
    ' monument',
    ' memorial',
    ' mantar',
  ])) {
    return AppIcons.placeLandmark;
  }
  if (has([
    ' lake',
    ' kul ',
    ' river',
    ' falls',
    ' waterfall',
    ' cascade',
    ' beach',
    ' bay',
    ' sea',
    ' gorge',
    ' gouffre',
    ' lagoon',
    ' fjord',
    ' spring',
  ])) {
    return AppIcons.placeWater;
  }
  if (has([
    ' mount',
    ' mont ',
    ' peak',
    ' valley',
    ' canyon',
    ' pass',
    ' plateau',
    ' hill',
    ' desert',
    ' glacier',
    ' trek',
    ' trail',
    ' rock',
    ' preikestolen',
  ])) {
    return AppIcons.mountains;
  }
  if (has([' park', ' forest', ' sanctuary', ' reserve', ' garden', ' wood'])) {
    return AppIcons.forest;
  }
  if (has([
    ' city',
    ' downtown',
    ' town',
    ' village',
    ' district',
    ' old town',
  ])) {
    return AppIcons.placeCity;
  }
  return AppIcons.place;
}

class _PlaceArtworkFallback extends StatelessWidget {
  const _PlaceArtworkFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _PlaceFallbackPainter(
        background: cs.surfaceContainerHigh,
        road: cs.outlineVariant.withValues(alpha: 0.5),
        pin: cs.onSurfaceVariant.withValues(alpha: 0.4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: AppIcon(
            icon,
            size: (constraints.biggest.shortestSide * 0.36).clamp(18, 44),
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PlaceFallbackPainter extends CustomPainter {
  const _PlaceFallbackPainter({
    required this.background,
    required this.road,
    required this.pin,
  });

  final Color background;
  final Color road;
  final Color pin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()
      ..color = road
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var index = 0; index < 4; index++) {
      final y = size.height * (0.18 + index * 0.24);
      final path = Path()
        ..moveTo(-8, y)
        ..cubicTo(
          size.width * 0.26,
          y - size.height * 0.18,
          size.width * 0.72,
          y + size.height * 0.17,
          size.width + 8,
          y - size.height * 0.05,
        );
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.2),
      3,
      Paint()..color = pin,
    );
  }

  @override
  bool shouldRepaint(covariant _PlaceFallbackPainter oldDelegate) =>
      oldDelegate.background != background ||
      oldDelegate.road != road ||
      oldDelegate.pin != pin;
}
