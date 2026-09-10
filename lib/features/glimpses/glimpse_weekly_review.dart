import '../../core/models/saved_url.dart';
import 'glimpse.dart';
import 'glimpse_store.dart';

StoredGlimpse? latestWeeklyReview(List<StoredGlimpse> all, DateTime now) {
  final weeks = all.where((s) => s.glimpse.kind == GlimpseKind.weekly).toList()
    ..sort((a, b) => b.glimpse.createdAt.compareTo(a.glimpse.createdAt));
  return weeks
          .where((s) => !(s.glimpse.periodEnd?.isAfter(now) ?? true))
          .firstOrNull ??
      weeks.firstOrNull;
}

List<StoredGlimpse> weeklyReviewsInMonth(
  List<StoredGlimpse> all,
  DateTime month,
) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  return all.where((item) {
    final g = item.glimpse;
    if (g.kind != GlimpseKind.weekly) return false;
    final weekStart = g.periodStart ?? g.createdAt;
    final weekEnd =
        g.periodEnd ??
        DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    return weekStart.isBefore(end) && weekEnd.isAfter(start);
  }).toList()..sort(
    (a, b) => (b.glimpse.periodStart ?? b.glimpse.createdAt).compareTo(
      a.glimpse.periodStart ?? a.glimpse.createdAt,
    ),
  );
}

class GlimpseWeeklyReview {
  const GlimpseWeeklyReview({
    required this.week,
    this.start,
    this.evidence,
    this.connection,
  });
  final Glimpse week;
  final SavedUrl? start;
  final GlimpseEvidence? evidence;
  final Glimpse? connection;

  static GlimpseWeeklyReview build(
    Glimpse week,
    List<StoredGlimpse> all,
    Map<int, SavedUrl> urls,
  ) {
    final connections =
        all
            .map((s) => s.glimpse)
            .where(
              (g) =>
                  g.kind == GlimpseKind.connection &&
                  g.strong &&
                  week.sourceIds.contains(g.sourceIds.first) &&
                  g.sourceIds.every(
                    (id) => urls[id] != null && !urls[id]!.isInBin,
                  ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    final connection = connections.firstOrNull;
    final evidence =
        week.evidence
            .where(
              (e) =>
                  urls[e.sourceId] != null &&
                  !urls[e.sourceId]!.isInBin &&
                  !urls[e.sourceId]!.isDone &&
                  !urls[e.sourceId]!.isProcessingActive,
            )
            .toList()
          ..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    final selected = evidence.firstOrNull;
    final start = selected == null
        ? week.sourceIds
              .map((id) => urls[id])
              .whereType<SavedUrl>()
              .where((u) => !u.isInBin && !u.isDone && !u.isProcessingActive)
              .firstOrNull
        : urls[selected.sourceId];
    return GlimpseWeeklyReview(
      week: week,
      start: start,
      evidence: selected,
      connection: connection,
    );
  }
}
