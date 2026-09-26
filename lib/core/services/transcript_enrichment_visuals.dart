part of 'transcript_enrichment_service.dart';

/// A plan the source lays out in order: days of stops, each stop naming a
/// place from the same save's places.
class EnrichedItinerary {
  const EnrichedItinerary({
    this.title,
    required this.days,
    this.tips = const [],
  });

  final String? title;
  final List<EnrichedItineraryDay> days;
  final List<String> tips;

  int get stopCount => days.fold(0, (total, day) => total + day.stops.length);

  bool get isMultiDay => days.length > 1;

  static EnrichedItinerary? fromJsonOrNull(Object? raw) {
    if (raw is! Map) return null;
    final rawDays = raw['days'];
    if (rawDays is! List) return null;
    final days = <EnrichedItineraryDay>[];
    for (final (index, rawDay) in rawDays.indexed) {
      final day = EnrichedItineraryDay.fromJsonOrNull(rawDay, index + 1);
      if (day != null) days.add(day);
    }
    days.sort((a, b) => a.day.compareTo(b.day));
    final itinerary = EnrichedItinerary(
      title: TranscriptEnrichmentService._cleanNullableText(raw['title']),
      days: List.unmodifiable(days),
      tips: TranscriptEnrichmentService._extractStringList(raw['tips']),
    );
    return itinerary.stopCount >= 2 ? itinerary : null;
  }

  Map<String, dynamic> toJson() => {
    'title': ?title,
    'days': days.map((day) => day.toJson()).toList(),
    if (tips.isNotEmpty) 'tips': tips,
  };
}

class EnrichedItineraryDay {
  const EnrichedItineraryDay({
    required this.day,
    this.title,
    required this.stops,
  });

  final int day;
  final String? title;
  final List<EnrichedItineraryStop> stops;

  static EnrichedItineraryDay? fromJsonOrNull(Object? raw, int fallbackDay) {
    if (raw is! Map || raw['stops'] is! List) return null;
    final stops = [
      for (final rawStop in raw['stops'] as List)
        ?EnrichedItineraryStop.fromJsonOrNull(rawStop),
    ];
    if (stops.isEmpty) return null;
    return EnrichedItineraryDay(
      day:
          TranscriptEnrichmentService._extractPositiveInt(raw['day']) ??
          fallbackDay,
      title: TranscriptEnrichmentService._cleanNullableText(raw['title']),
      stops: List.unmodifiable(stops),
    );
  }

  Map<String, dynamic> toJson() => {
    'day': day,
    'title': ?title,
    'stops': stops.map((stop) => stop.toJson()).toList(),
  };
}

class EnrichedItineraryStop {
  const EnrichedItineraryStop({
    required this.name,
    this.time,
    this.duration,
    this.travel,
    this.note,
  });

  final String name;
  final String? time;
  final String? duration;
  final String? travel;
  final String? note;

  static EnrichedItineraryStop? fromJsonOrNull(Object? raw) {
    final object = raw is Map ? raw : {'name': raw};
    final name = TranscriptEnrichmentService._cleanText(
      object['name'] ?? object['place'],
    );
    if (name.isEmpty) return null;
    String? text(String key) =>
        TranscriptEnrichmentService._cleanNullableText(object[key]);
    return EnrichedItineraryStop(
      name: name,
      time: text('time'),
      duration: text('duration'),
      travel: text('travel'),
      note: text('note'),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'time': ?time,
    'duration': ?duration,
    'travel': ?travel,
    'note': ?note,
  };
}

/// Data the source itself contains, drawn instead of written out: a table,
/// chart, formula or timeline.
sealed class EnrichedVisual {
  const EnrichedVisual({this.title, this.caption});

  final String? title;
  final String? caption;

  String get kind;

  Map<String, dynamic> get _body;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'title': ?title,
    'caption': ?caption,
    ..._body,
  };

  static List<EnrichedVisual> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    return List.unmodifiable([
      for (final item in raw) ?EnrichedVisual.fromJsonOrNull(item),
    ]);
  }

  static EnrichedVisual? fromJsonOrNull(Object? raw) {
    if (raw is! Map) return null;
    String? text(Object? value) =>
        TranscriptEnrichmentService._cleanNullableText(value);
    final title = text(raw['title']);
    final caption = text(raw['caption']);
    switch (TranscriptEnrichmentService._cleanText(raw['kind']).toLowerCase()) {
      case 'table':
        final columns = [
          for (final column
              in raw['columns'] is List ? raw['columns'] as List : const [])
            text(column) ?? '',
        ];
        if (columns.length < 2) return null;
        final rows = <List<String>>[
          for (final row
              in raw['rows'] is List ? raw['rows'] as List : const [])
            if (row is List)
              [
                for (var i = 0; i < columns.length; i++)
                  i < row.length ? text(row[i]) ?? '' : '',
              ],
        ].where((row) => row.any((cell) => cell.isNotEmpty)).toList();
        if (rows.isEmpty) return null;
        return EnrichedTable(
          title: title,
          caption: caption,
          columns: List.unmodifiable(columns),
          rows: List.unmodifiable(rows),
        );
      case 'chart':
        final points = <EnrichedChartPoint>[
          for (final point
              in raw['points'] is List ? raw['points'] as List : const [])
            if (point is Map)
              if ((
                    text(point['label']),
                    TranscriptEnrichmentService._toDouble(point['value']),
                  )
                  case (final label?, final value?) when value.isFinite)
                EnrichedChartPoint(label: label, value: value),
        ];
        if (points.length < 2) return null;
        final type = switch (text(raw['chart_type'])?.toLowerCase()) {
          'line' => EnrichedChartType.line,
          'share' when points.every((point) => point.value >= 0) =>
            EnrichedChartType.share,
          _ => EnrichedChartType.bar,
        };
        return EnrichedChart(
          title: title,
          caption: caption,
          type: type,
          unit: text(raw['unit']),
          points: List.unmodifiable(points),
        );
      case 'formula':
        // Raw: the HTML-aware cleaner would rewrite LaTeX escapes.
        final latex = raw['latex'] is String
            ? (raw['latex'] as String).trim()
            : '';
        if (latex.isEmpty) return null;
        return EnrichedFormula(
          title: title,
          caption: caption,
          latex: latex,
          explanation: text(raw['explanation']),
          variables: List.unmodifiable([
            for (final variable
                in raw['variables'] is List
                    ? raw['variables'] as List
                    : const [])
              if (variable is Map)
                if ((text(variable['symbol']), text(variable['meaning'])) case (
                  final symbol?,
                  final meaning?,
                ))
                  (symbol: symbol, meaning: meaning),
          ]),
        );
      case 'timeline':
        final events = [
          for (final event
              in raw['events'] is List ? raw['events'] as List : const [])
            if (event is Map)
              if ((text(event['when']), text(event['what'])) case (
                final at?,
                final what?,
              ))
                (when: at, what: what),
        ];
        if (events.length < 2) return null;
        return EnrichedTimeline(
          title: title,
          caption: caption,
          events: List.unmodifiable(events),
        );
    }
    return null;
  }
}

class EnrichedTable extends EnrichedVisual {
  const EnrichedTable({
    super.title,
    super.caption,
    required this.columns,
    required this.rows,
  });

  final List<String> columns;
  final List<List<String>> rows;

  @override
  String get kind => 'table';

  @override
  Map<String, dynamic> get _body => {'columns': columns, 'rows': rows};
}

enum EnrichedChartType { bar, line, share }

class EnrichedChartPoint {
  const EnrichedChartPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class EnrichedChart extends EnrichedVisual {
  const EnrichedChart({
    super.title,
    super.caption,
    required this.type,
    this.unit,
    required this.points,
  });

  final EnrichedChartType type;
  final String? unit;
  final List<EnrichedChartPoint> points;

  @override
  String get kind => 'chart';

  @override
  Map<String, dynamic> get _body => {
    'chart_type': type.name,
    'unit': ?unit,
    'points': [
      for (final point in points) {'label': point.label, 'value': point.value},
    ],
  };
}

class EnrichedFormula extends EnrichedVisual {
  const EnrichedFormula({
    super.title,
    super.caption,
    required this.latex,
    this.explanation,
    this.variables = const [],
  });

  final String latex;
  final String? explanation;
  final List<({String symbol, String meaning})> variables;

  @override
  String get kind => 'formula';

  @override
  Map<String, dynamic> get _body => {
    'latex': latex,
    'explanation': ?explanation,
    if (variables.isNotEmpty)
      'variables': [
        for (final variable in variables)
          {'symbol': variable.symbol, 'meaning': variable.meaning},
      ],
  };
}

class EnrichedTimeline extends EnrichedVisual {
  const EnrichedTimeline({super.title, super.caption, required this.events});

  final List<({String when, String what})> events;

  @override
  String get kind => 'timeline';

  @override
  Map<String, dynamic> get _body => {
    'events': [
      for (final event in events) {'when': event.when, 'what': event.what},
    ],
  };
}
