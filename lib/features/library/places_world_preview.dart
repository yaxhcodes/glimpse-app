import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'library_entity.dart';

/// A dot-matrix world with the reader's own places lit on it: the Places
/// destination shows where the saves are, not a stock pin.
class PlacesWorldPreview extends StatelessWidget {
  const PlacesWorldPreview({
    super.key,
    required this.places,
    this.width = 128,
    this.height = 70,
  });

  final List<LibraryEntity> places;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final counts = <(int, int), int>{};
    for (final place in places) {
      final mention = place.mention;
      if (!mention.hasCoordinates) continue;
      final cell = worldCellOf(mention.latitude!, mention.longitude!);
      if (cell == null) continue;
      counts[cell] = (counts[cell] ?? 0) + 1;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: cs.surfaceContainerHigh,
        child: CustomPaint(
          size: Size(width, height),
          painter: _WorldDotsPainter(
            counts: counts,
            land: cs.onSurfaceVariant.withValues(alpha: 0.38),
            place: cs.primary,
          ),
        ),
      ),
    );
  }
}

/// The grid cell (column, row) of a coordinate, or null outside the drawn
/// latitudes.
@visibleForTesting
(int, int)? worldCellOf(double latitude, double longitude) {
  if (latitude > _latTop || latitude < _latBottom) return null;
  final column = ((longitude + 180) / 360 * _columns).floor().clamp(
    0,
    _columns - 1,
  );
  final row = ((_latTop - latitude) / (_latTop - _latBottom) * _rows)
      .floor()
      .clamp(0, _rows - 1);
  return (column, row);
}

class _WorldDotsPainter extends CustomPainter {
  const _WorldDotsPainter({
    required this.counts,
    required this.land,
    required this.place,
  });

  final Map<(int, int), int> counts;
  final Color land;
  final Color place;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 5.0;
    final cellWidth = (size.width - inset * 2) / _columns;
    final cellHeight = (size.height - inset * 2) / _rows;
    Offset center(int column, int row) => Offset(
      inset + (column + 0.5) * cellWidth,
      inset + (row + 0.5) * cellHeight,
    );
    final landRadius = math.min(cellWidth, cellHeight) * 0.3;
    final landPaint = Paint()..color = land;
    for (var row = 0; row < _rows; row++) {
      final line = _landMask[row];
      for (var column = 0; column < _columns; column++) {
        if (line.codeUnitAt(column) == 0x23) {
          canvas.drawCircle(center(column, row), landRadius, landPaint);
        }
      }
    }
    // A lit dot is the land dot grown to about a cell; busier cells grow a
    // little more but never past their neighbours, so the map still reads.
    final placePaint = Paint()..color = place;
    final cell = math.min(cellWidth, cellHeight);
    for (final MapEntry(key: (column, row), value: count) in counts.entries) {
      final radius = cell * (0.5 + math.min(count, 6) * 0.05);
      canvas.drawCircle(center(column, row), radius, placePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WorldDotsPainter old) =>
      old.land != land ||
      old.place != place ||
      old.counts.length != counts.length ||
      old.counts.entries.any((entry) => counts[entry.key] != entry.value);
}

const _columns = 48;
const _rows = 22;
const _latTop = 76.0;
const _latBottom = -56.0;

/// Land cells of Natural Earth's 1:110m land (48x22,
/// 76°N to 56°S, equirectangular). '#' is land.
const _landMask = [
  '#..#...########.######.........#.############...',
  '################.#####...#######################',
  '..##########.###.##.....########################',
  '..#...###########.....#####################.##..',
  '.......##########......####################.....',
  '.......#########......######################....',
  '.......#######........#####################.....',
  '........######........####################......',
  '.........##..#........###################.......',
  '..........#####......###########.######.#.......',
  '...........##.#......##########...#..##.#.......',
  '.............####.....#########...#.##.##.......',
  '.............#####.......#####.......#####......',
  '.............#######.....#####.......########...',
  '.............#######.....#####...........###.#..',
  '..............#####......######.........####....',
  '..............#####.......#####........######...',
  '..............####........###..........######...',
  '..............###.........##...........##.###...',
  '..............##...........................#..##',
  '..............#..................#............#.',
  '..............###...............................',
];
