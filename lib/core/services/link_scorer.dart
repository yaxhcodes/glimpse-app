import '../models/saved_url.dart';

/// Scores a SavedUrl for notification eligibility.
/// Only links scoring 4+ should be featured in notifications.
class LinkScorer {
  LinkScorer._();

  static const _shortlinkDomains = {
    't.co', 'bit.ly', 'linktr.ee', 'goo.gl', 'tinyurl.com',
    'ow.ly', 'buff.ly', 'is.gd', 'v.gd', 'rb.gy',
  };

  static int score(SavedUrl link) {
    // Finished saves are never featured in notifications.
    if (link.isDone) return 0;
    var s = 0;
    if ((link.summary ?? '').isNotEmpty) s += 3;
    if (link.tags.length >= 3) s += 2;
    if (link.effectiveCategories.first != 'Other') s += 2;
    if (link.description.isNotEmpty) s += 1;
    if (link.openedAt == null) s += 2;
    final age = DateTime.now().difference(link.savedAt).inDays;
    if (age >= 7) s += 1;
    if (!_shortlinkDomains.contains(link.domain.toLowerCase())) s += 1;
    return s;
  }

  static const minEligibleScore = 4;

  static bool isEligible(SavedUrl link) => score(link) >= minEligibleScore;
}
