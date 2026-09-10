import '../../core/models/saved_url.dart';
import '../../core/services/saved_url_subject_resolver.dart';
import 'glimpse.dart';

class GlimpseTopic {
  const GlimpseTopic(this.subject, this.sourceIds);
  final SavedUrlSubject subject;
  final List<int> sourceIds;
}

class GlimpsePeriod {
  const GlimpsePeriod({
    required this.start,
    required this.end,
    required this.sources,
    required this.topics,
    required this.days,
  });
  final DateTime start;
  final DateTime end;
  final List<SavedUrl> sources;
  final List<GlimpseTopic> topics;
  final Map<DateTime, List<int>> days;
}

/// Subject resolution runs once in an isolate. Period views reuse that index.
class GlimpseActivity {
  GlimpseActivity(this.sources, this.subjects, this.now);
  final List<SavedUrl> sources;
  final Map<int, SavedUrlSubject?> subjects;
  final DateTime now;
  final _periods = <(DateTime, DateTime), GlimpsePeriod>{};

  GlimpsePeriod month(DateTime date) => period(
    DateTime(date.year, date.month),
    DateTime(date.year, date.month + 1),
  );

  GlimpsePeriod forGlimpse(Glimpse g) {
    final start = g.periodStart ?? g.createdAt;
    final end =
        g.periodEnd ??
        switch (g.kind) {
          GlimpseKind.monthly => DateTime(start.year, start.month + 1),
          GlimpseKind.weekly => DateTime(
            start.year,
            start.month,
            start.day + 7,
          ),
          _ => DateTime(start.year, start.month, start.day + 1),
        };
    return period(start, end);
  }

  GlimpsePeriod period(
    DateTime start,
    DateTime end,
  ) => _periods.putIfAbsent((start, end), () {
    final saves = sources
        .where((u) => !u.savedAt.isBefore(start) && u.savedAt.isBefore(end))
        .toList();
    final grouped = <String, List<int>>{};
    final labels = <String, SavedUrlSubject>{};
    final days = <DateTime, List<int>>{};
    for (final u in saves) {
      final day = DateTime(u.savedAt.year, u.savedAt.month, u.savedAt.day);
      days.putIfAbsent(day, () => []).add(u.id);
      final subject = subjects[u.id];
      if (subject == null) continue;
      labels[subject.key] = subject;
      grouped.putIfAbsent(subject.key, () => []).add(u.id);
    }
    final topics =
        [for (final e in grouped.entries) GlimpseTopic(labels[e.key]!, e.value)]
          ..sort((a, b) {
            final count = b.sourceIds.length.compareTo(a.sourceIds.length);
            return count != 0 ? count : a.subject.key.compareTo(b.subject.key);
          });
    return GlimpsePeriod(
      start: start,
      end: end,
      sources: saves,
      topics: topics,
      days: days,
    );
  });
}

GlimpseActivity buildGlimpseActivity((List<SavedUrl>, DateTime) request) {
  final (urls, now) = request;
  final sources = {
    for (final u in urls)
      if (!u.isInBin && !u.savedAt.isAfter(now)) u.id: u,
  }.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  final index = SavedUrlSubjectIndex();
  return GlimpseActivity(sources, {
    for (final u in sources) u.id: index.resolve(u),
  }, now);
}
