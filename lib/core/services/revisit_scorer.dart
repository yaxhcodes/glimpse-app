import '../database/isar_service.dart';
import '../models/saved_url.dart';

/// A scored rediscovery candidate: a ranking [score] plus the human "why now".
class RevisitScore {
  const RevisitScore(this.score, this.reason);

  final double score;
  final String reason;

  /// Candidates at or below this score are not worth resurfacing.
  static const excludedThreshold = -1e8;

  bool get isExcluded => score <= excludedThreshold;
}

/// The single on-device ranking core shared by every Rediscovery surface and
/// the revisit-due notification. It blends the user's explicit intent signals
/// (queued / done, captured from the Details chips) with the implicit signals
/// the app already had (embeddings, category/tag overlap, age, never-opened).
///
/// Pure Dart math — nothing leaves the device.
class RevisitScorer {
  RevisitScorer._();

  /// Score [candidate] against the user's [seeds] (their most recent saves,
  /// the current interest signal). [now] is injectable for tests.
  static RevisitScore score(
    SavedUrl candidate, {
    required List<SavedUrl> seeds,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();

    // ── Hard exclusions ──────────────────────────────────────────────────
    // Finished or explicitly dismissed items never resurface.
    if (candidate.isDone || candidate.rediscoverDismissedAt != null) {
      return const RevisitScore(RevisitScore.excludedThreshold, '');
    }
    final revisitDue =
        candidate.isQueued &&
        (candidate.revisitAfter == null || !candidate.revisitAfter!.isAfter(clock));
    // Queued-but-not-yet-due: hold it back until the user's chosen moment.
    if (candidate.isQueued && !revisitDue) {
      return const RevisitScore(RevisitScore.excludedThreshold, '');
    }

    // ── Explicit intent: the strongest possible signal ───────────────────
    if (revisitDue) {
      // Float queued-due items to the very top, freshest first among them.
      final recency = -clock.difference(candidate.savedAt).inMinutes / 1e6;
      return RevisitScore(1000 + recency, _queuedReason(candidate));
    }

    double s = 0;
    String reason = 'Worth revisiting';

    // ── On-this-day anniversary ──────────────────────────────────────────
    final anniversary = onThisDayLabel(candidate, now: clock);
    if (anniversary != null) {
      s += 40;
      reason = anniversary;
    }

    // ── Embedding similarity vs recent saves ─────────────────────────────
    final cEmb = candidate.embedding;
    if (cEmb != null && cEmb.isNotEmpty) {
      double maxSim = 0;
      for (final seed in seeds) {
        final sEmb = seed.embedding;
        if (sEmb == null || sEmb.isEmpty) continue;
        final sim = IsarService.cosineSimilarity(sEmb, cEmb);
        if (sim > maxSim) maxSim = sim;
      }
      if (maxSim >= 0.45) {
        s += maxSim * 30;
        if (anniversary == null) reason = 'Matches your recent saves';
      }
    }

    // ── Category + tag overlap with recent saves ─────────────────────────
    final seedCats = seeds.expand((u) => u.effectiveCategories).toSet();
    final seedTags =
        seeds.expand((u) => u.tags).map((t) => t.toLowerCase()).toSet();
    var overlap = 0.0;
    for (final cat in candidate.effectiveCategories) {
      if (seedCats.contains(cat)) overlap += 2.0;
    }
    for (final tag in candidate.tags) {
      if (seedTags.contains(tag.toLowerCase())) overlap += 1.0;
    }
    if (overlap > 0) {
      s += overlap;
      if (anniversary == null && reason == 'Worth revisiting') {
        reason = 'Based on recent activity';
      }
    }

    // ── Never opened (the real backlog) ──────────────────────────────────
    if (candidate.openedAt == null) {
      s += 6;
      if (reason == 'Worth revisiting') reason = 'Never opened';
    }

    // ── Age: older saves are more "rediscoverable" ───────────────────────
    final ageDays = clock.difference(candidate.savedAt).inDays;
    if (ageDays >= 90) {
      s += 4;
    } else if (ageDays >= 30) {
      s += 2;
    }

    // ── Recently resurfaced: damp to avoid repeats ───────────────────────
    final r = candidate.resurfacedAt;
    if (r != null && clock.difference(r).inDays < 14) {
      s -= 12;
    }

    return RevisitScore(s, reason);
  }

  /// Why a queued item is surfacing, derived from the chip the user tapped.
  static String _queuedReason(SavedUrl url) {
    switch (url.intentAction) {
      case 'watch_later':
      case 'add_to_watchlist':
        return 'Time to watch this';
      case 'read_later':
      case 'add_to_reading_list':
        return 'Time to read this';
      case 'try_this_weekend':
        return 'You wanted to try this';
      case 'practice_later':
        return 'You wanted to practice this';
      default:
        return 'You wanted to come back to this';
    }
  }

  /// Anniversary label (≈1mo / 3mo / 6mo / 1yr) or null.
  static String? onThisDayLabel(SavedUrl u, {DateTime? now}) {
    final days = (now ?? DateTime.now()).difference(u.savedAt).inDays;
    bool near(int anchor) => (days - anchor).abs() <= 3;
    if (near(365)) return 'A year ago today';
    if (near(180)) return '6 months ago';
    if (near(90)) return '3 months ago';
    if (near(30)) return 'A month ago';
    return null;
  }
}
