import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/l10n.dart';
import 'glimpse_day_navigation.dart';
import 'glimpse_activity.dart';
import 'glimpse_source_sheet.dart';

class GlimpseActivityChart extends StatefulWidget {
  const GlimpseActivityChart({
    super.key,
    required this.period,
    required this.now,
  });
  final GlimpsePeriod period;
  final DateTime now;
  @override
  State<GlimpseActivityChart> createState() => _GlimpseActivityChartState();
}

class _GlimpseActivityChartState extends State<GlimpseActivityChart> {
  int? _selected;
  int get _days =>
      DateTime(widget.period.start.year, widget.period.start.month + 1, 0).day;
  int get _available =>
      widget.now.year == widget.period.start.year &&
          widget.now.month == widget.period.start.month
      ? widget.now.day
      : _days;
  int get _day {
    final active =
        widget.period.days.keys.where((d) => d.day <= _available).toList()
          ..sort();
    return (_selected ?? active.lastOrNull?.day ?? _available).clamp(
      1,
      _available,
    );
  }

  @override
  void didUpdateWidget(GlimpseActivityChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period.start != widget.period.start) _selected = null;
  }

  void _select(double x, double width, TextDirection direction) {
    final fraction = (x / width).clamp(0.0, .999);
    final index = direction == TextDirection.rtl ? 1 - fraction : fraction;
    setState(
      () => _selected = (index * _days + 1).floor().clamp(1, _available),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.period;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final date = DateTime(p.start.year, p.start.month, _day);
    final ids = p.days[date] ?? const <int>[];
    final label = MaterialLocalizations.of(context).formatMediumDate(date);
    final counts = [
      for (var d = 1; d <= _days; d++)
        p.days[DateTime(p.start.year, p.start.month, d)]?.length ?? 0,
    ];
    final direction = Directionality.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.glimpsesActivity,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          label: l.glimpsesActivity,
          value: '$label, ${l.saveCount(ids.length)}',
          increasedValue: _day < _available ? '${_day + 1}' : null,
          decreasedValue: _day > 1 ? '${_day - 1}' : null,
          onIncrease: _day < _available
              ? () => setState(() => _selected = _day + 1)
              : null,
          onDecrease: _day > 1
              ? () => setState(() => _selected = _day - 1)
              : null,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapDown: (d) =>
                  _select(d.localPosition.dx, constraints.maxWidth, direction),
              onHorizontalDragUpdate: (d) =>
                  _select(d.localPosition.dx, constraints.maxWidth, direction),
              child: SizedBox(
                height: 104,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ActivityPainter(
                    counts,
                    _day,
                    _available,
                    cs.primary,
                    cs.outlineVariant,
                    direction,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final d in [1, 8, 15, 22, _days])
              Text(
                '$d',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: 14),
        GlimpseDayNavigation(
          dateLabel: label,
          countLabel: l.saveCount(ids.length),
          onPrevious: _day > 1
              ? () => setState(() => _selected = _day - 1)
              : null,
          onNext: _day < _available
              ? () => setState(() => _selected = _day + 1)
              : null,
          onOpen: () => showGlimpseSources(
            context,
            title: label,
            sources: p.sources.where((u) => ids.contains(u.id)).toList(),
          ),
        ),
      ],
    );
  }
}

class _ActivityPainter extends CustomPainter {
  const _ActivityPainter(
    this.counts,
    this.selected,
    this.available,
    this.color,
    this.grid,
    this.direction,
  );
  final List<int> counts;
  final int selected;
  final int available;
  final Color color;
  final Color grid;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final maximum = math.max(1, counts.reduce(math.max));
    final paint = Paint();
    // One quiet baseline; the bars carry the rest.
    paint
      ..color = grid.withValues(alpha: .5)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - .5),
      Offset(size.width, size.height - .5),
      paint,
    );
    final slot = size.width / counts.length;
    final barWidth = slot * .62;
    for (var i = 0; i < counts.length; i++) {
      final x =
          (direction == TextDirection.rtl ? counts.length - i - 1 : i) * slot;
      final day = i + 1;
      final left = x + (slot - barWidth) / 2;
      if (day > available) {
        // Days still to come: a faint dot on the baseline.
        paint.color = grid.withValues(alpha: .6);
        canvas.drawCircle(
          Offset(x + slot / 2, size.height - 3),
          math.min(1.5, barWidth / 2),
          paint,
        );
        continue;
      }
      if (day == selected) {
        paint.color = color.withValues(alpha: .08);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 0, slot, size.height),
            const Radius.circular(6),
          ),
          paint,
        );
      }
      final height = counts[i] == 0
          ? 3.0
          : math.max(6.0, counts[i] / maximum * (size.height - 10));
      paint.color = counts[i] == 0
          ? grid.withValues(alpha: .7)
          : color.withValues(alpha: day == selected ? 1 : .38);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          topLeft: Radius.circular(barWidth / 2),
          topRight: Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ActivityPainter old) =>
      !listEquals(old.counts, counts) ||
      old.selected != selected ||
      old.available != available ||
      old.color != color ||
      old.grid != grid ||
      old.direction != direction;
}
