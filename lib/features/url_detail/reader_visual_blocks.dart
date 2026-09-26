import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart' show Math, MathStyle;
import 'package:intl/intl.dart' show NumberFormat;

import '../../core/services/transcript_enrichment_service.dart';
import '../../l10n/l10n.dart';

/// Draws one table, chart, formula or timeline from a save's enrichment.
class ReaderVisualBlock extends StatelessWidget {
  const ReaderVisualBlock({super.key, required this.visual});

  final EnrichedVisual visual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final body = switch (visual) {
      final EnrichedTable table => _TableView(table: table),
      final EnrichedChart chart => switch (chart.type) {
        EnrichedChartType.bar => _BarChart(chart: chart),
        EnrichedChartType.line => _LineChart(chart: chart),
        EnrichedChartType.share => _ShareChart(chart: chart),
      },
      final EnrichedFormula formula => _FormulaView(formula: formula),
      final EnrichedTimeline timeline => _TimelineView(timeline: timeline),
    };
    final title = visual.title?.trim() ?? '';
    final caption = visual.caption?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
          ],
          body,
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table

class _TableView extends StatelessWidget {
  const _TableView({required this.table});

  final EnrichedTable table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final cellStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.35);
    final leadStyle = cellStyle?.copyWith(fontWeight: FontWeight.w600);
    final divider = BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6));

    Widget cell(String text, TextStyle? style, {required bool wide}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: wide
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(text, style: style),
                )
              : Text(text, style: style),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Three narrow columns fit a phone; wider tables scroll sideways
        // rather than squeezing every value onto four lines.
        final fits = table.columns.length <= 3;
        final built = Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          columnWidths: fits
              ? {
                  for (var i = 0; i < table.columns.length; i++)
                    i: FlexColumnWidth(i == 0 ? 1.3 : 1),
                }
              : null,
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(horizontalInside: divider),
          children: [
            TableRow(
              decoration: BoxDecoration(border: Border(bottom: divider)),
              children: [
                for (final column in table.columns)
                  cell(column, headerStyle, wide: !fits),
              ],
            ),
            for (final row in table.rows)
              TableRow(
                children: [
                  for (var i = 0; i < row.length; i++)
                    cell(
                      row[i].isEmpty ? '—' : row[i],
                      i == 0 ? leadStyle : cellStyle,
                      wide: !fits,
                    ),
                ],
              ),
          ],
        );
        if (fits) return built;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: built,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Charts

/// "$45", "12.5%", "5,100 mAh": the unit where the source put it.
String formatChartValue(double value, String? unit, {String? locale}) {
  final number = NumberFormat.decimalPattern(locale).format(
    value == value.roundToDouble() ? value.round() : value,
  );
  final u = unit?.trim() ?? '';
  if (u.isEmpty) return number;
  if (u == '%') return '$number%';
  if (RegExp(r'^[$€£¥₹₩₽₺฿]|^[A-Z]{3}$').hasMatch(u) && u.length <= 3) {
    return u.length == 3 ? '$u $number' : '$u$number';
  }
  return '$number $u';
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.chart});

  final EnrichedChart chart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final values = chart.points.map((point) => point.value);
    final maxValue = math.max(0.0, values.reduce(math.max));
    final minValue = math.min(0.0, values.reduce(math.min));
    final span = maxValue - minValue == 0 ? 1.0 : maxValue - minValue;
    final zero = -minValue / span;

    return Semantics(
      label: chart.points
          .map(
            (point) =>
                '${point.label} ${formatChartValue(point.value, chart.unit, locale: locale)}',
          )
          .join(', '),
      excludeSemantics: true,
      child: Column(
        children: [
          for (final point in chart.points)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          point.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatChartValue(
                          point.value,
                          chart.unit,
                          locale: locale,
                        ),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final length = (point.value.abs() / span) * width;
                      final negative = point.value < 0;
                      return SizedBox(
                        height: 10,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: cs.onSurface.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            Positioned(
                              left: negative
                                  ? zero * width - length
                                  : zero * width,
                              top: 0,
                              bottom: 0,
                              width: math.max(2, length),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  // Rounded at the data end, square at the
                                  // baseline.
                                  borderRadius: negative
                                      ? const BorderRadius.horizontal(
                                          left: Radius.circular(4),
                                        )
                                      : const BorderRadius.horizontal(
                                          right: Radius.circular(4),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LineChart extends StatefulWidget {
  const _LineChart({required this.chart});

  final EnrichedChart chart;

  @override
  State<_LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<_LineChart> {
  int? _active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final points = widget.chart.points;
    String format(double value) =>
        formatChartValue(value, widget.chart.unit, locale: locale);
    final active = _active;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 22,
          child: active == null
              ? null
              : Text.rich(
                  TextSpan(
                    text: '${points[active].label}  ',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(
                        text: format(points[active].value),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            void pick(Offset position) {
              final step = points.length < 2
                  ? 0.0
                  : _LinePainter.plotWidth(constraints.maxWidth) /
                        (points.length - 1);
              final index = step == 0
                  ? 0
                  : ((position.dx - _LinePainter.leftInset) / step)
                        .round()
                        .clamp(0, points.length - 1);
              if (index != _active) setState(() => _active = index);
            }

            return Semantics(
              label: points
                  .map((point) => '${point.label} ${format(point.value)}')
                  .join(', '),
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => pick(details.localPosition),
                onHorizontalDragStart: (details) =>
                    pick(details.localPosition),
                onHorizontalDragUpdate: (details) =>
                    pick(details.localPosition),
                onHorizontalDragEnd: (_) => setState(() => _active = null),
                onTapUp: (_) => Future.delayed(
                  const Duration(seconds: 2),
                  () => mounted ? setState(() => _active = null) : null,
                ),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 168),
                  painter: _LinePainter(
                    points: points,
                    active: active,
                    line: cs.primary,
                    grid: cs.outlineVariant.withValues(alpha: 0.5),
                    surface: cs.surfaceContainerLow,
                    labelStyle: theme.textTheme.labelSmall!.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    valueStyle: theme.textTheme.labelMedium!.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    format: format,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.active,
    required this.line,
    required this.grid,
    required this.surface,
    required this.labelStyle,
    required this.valueStyle,
    required this.format,
  });

  static const leftInset = 4.0;
  static const rightInset = 28.0;
  static const topInset = 18.0;
  static const bottomInset = 22.0;

  static double plotWidth(double width) => width - leftInset - rightInset;

  final List<EnrichedChartPoint> points;
  final int? active;
  final Color line;
  final Color grid;
  final Color surface;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final String Function(double) format;

  @override
  void paint(Canvas canvas, Size size) {
    final width = plotWidth(size.width);
    final height = size.height - topInset - bottomInset;
    final values = points.map((point) => point.value);
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    if (lo > 0 && lo / (hi == 0 ? 1 : hi) < 0.5) lo = 0;
    if (hi == lo) {
      hi += 1;
      lo -= 1;
    }
    Offset at(int index) => Offset(
      leftInset +
          (points.length == 1 ? 0 : width * index / (points.length - 1)),
      topInset + height * (1 - (points[index].value - lo) / (hi - lo)),
    );

    // Three recessive hairlines.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = topInset + height * i / 2;
      canvas.drawLine(
        Offset(leftInset, y),
        Offset(leftInset + width, y),
        gridPaint,
      );
    }

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(path)
      ..lineTo(at(points.length - 1).dx, topInset + height)
      ..lineTo(at(0).dx, topInset + height)
      ..close();
    canvas.drawPath(area, Paint()..color = line.withValues(alpha: 0.1));
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    if (active case final index?) {
      final x = at(index).dx;
      canvas.drawLine(
        Offset(x, topInset),
        Offset(x, topInset + height),
        Paint()
          ..color = line.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
    }

    // End dot (and the touched one) with a surface ring.
    for (final index in {points.length - 1, ?active}) {
      final center = at(index);
      canvas.drawCircle(center, 6, Paint()..color = surface);
      canvas.drawCircle(center, 4, Paint()..color = line);
    }

    void text(String value, TextStyle style, Offset anchor, {double dx = 0}) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(40, width / 2));
      final left = (anchor.dx - painter.width * dx).clamp(
        0.0,
        size.width - painter.width,
      );
      painter.paint(canvas, Offset(left, anchor.dy));
    }

    // Label the last value only; the touch readout carries the rest.
    final last = at(points.length - 1);
    text(
      format(points.last.value),
      valueStyle,
      Offset(last.dx, last.dy - 22),
      dx: 1,
    );

    // X labels: every point when few, otherwise the ends and the middle.
    final labelIndexes = points.length <= 5
        ? List.generate(points.length, (i) => i)
        : [0, points.length ~/ 2, points.length - 1];
    for (final index in labelIndexes) {
      final x = at(index).dx;
      final align = index == 0
          ? 0.0
          : index == points.length - 1
          ? 1.0
          : 0.5;
      text(
        points[index].label,
        labelStyle,
        Offset(x, topInset + height + 6),
        dx: align,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.points != points ||
      old.active != active ||
      old.line != line ||
      old.surface != surface;
}

/// Reference categorical palette (validated for CVD in both modes), used in
/// fixed order. Parts beyond six fold into "Other".
const _shareLight = [
  Color(0xFF2A78D6),
  Color(0xFFEB6834),
  Color(0xFF1BAF7A),
  Color(0xFFEDA100),
  Color(0xFFE87BA4),
  Color(0xFF008300),
];
const _shareDark = [
  Color(0xFF3987E5),
  Color(0xFFD95926),
  Color(0xFF199E70),
  Color(0xFFC98500),
  Color(0xFFD55181),
  Color(0xFF008300),
];

class _ShareChart extends StatelessWidget {
  const _ShareChart({required this.chart});

  final EnrichedChart chart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final palette = cs.brightness == Brightness.dark ? _shareDark : _shareLight;
    var parts = [
      for (final point in chart.points)
        if (point.value > 0) (label: point.label, value: point.value),
    ];
    if (parts.length > palette.length) {
      final kept = parts.take(palette.length - 1).toList();
      final rest = parts
          .skip(palette.length - 1)
          .fold(0.0, (total, part) => total + part.value);
      parts = [...kept, (label: context.l10n.chartOther, value: rest)];
    }
    final total = parts.fold(0.0, (sum, part) => sum + part.value);
    if (total <= 0) return const SizedBox.shrink();
    final percent = NumberFormat.percentPattern(locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final (index, part) in parts.indexed) ...[
                  // The 2px surface gap separates neighbours.
                  if (index > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: math.max(1, (part.value / total * 1000).round()),
                    child: ColoredBox(color: palette[index]),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final (index, part) in parts.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: palette[index],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    part.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Text(
                  formatChartValue(part.value, chart.unit, locale: locale),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (chart.unit?.trim() != '%') ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: Text(
                      percent.format(part.value / total),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Formula

class _FormulaView extends StatelessWidget {
  const _FormulaView({required this.formula});

  final EnrichedFormula formula;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mathStyle = theme.textTheme.titleLarge?.copyWith(
      color: cs.onSurface,
    );

    Widget tex(String source, TextStyle? style) => Math.tex(
      source,
      mathStyle: MathStyle.display,
      textStyle: style,
      onErrorFallback: (_) => Text(
        source,
        style: style?.copyWith(fontFamily: 'monospace'),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Center(child: tex(formula.latex, mathStyle)),
          ),
        ),
        if (formula.explanation?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            formula.explanation!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
        if (formula.variables.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.formulaWhere,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          for (final variable in formula.variables)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Math.tex(
                          variable.symbol,
                          textStyle: theme.textTheme.bodyLarge,
                          onErrorFallback: (_) => Text(
                            variable.symbol,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      variable.meaning,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline

class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.timeline});

  final EnrichedTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final events = timeline.events;
    return Column(
      children: [
        for (final (index, event) in events.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Container(
                        width: 2,
                        height: 6,
                        color: index == 0
                            ? Colors.transparent
                            : cs.outlineVariant,
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.surfaceContainerLow,
                            width: 2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: 2,
                          color: index == events.length - 1
                              ? Colors.transparent
                              : cs.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.when,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.what,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
