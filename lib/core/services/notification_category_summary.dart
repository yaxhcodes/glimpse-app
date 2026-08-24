import '../models/saved_url.dart';
import 'category_resolver.dart';
import 'category_taxonomy.dart';

/// Builds ranked, content-only category counts for notification copy.
class NotificationCategorySummary {
  static List<NotificationCategoryCount> ranked(Iterable<SavedUrl> urls) {
    final counts = <String, int>{};
    final labels = <String, String>{};
    final firstSeen = <String, int>{};
    var nextOrder = 0;

    for (final url in urls) {
      final seenForUrl = <String>{};
      for (final rawCategory in url.effectiveCategories) {
        final trimmed = rawCategory.trim();
        if (trimmed.isEmpty || CategoryResolver.isPlatformName(trimmed)) {
          continue;
        }

        final normalized = CategoryTaxonomy.normalize(category: trimmed).name;
        final label = normalized == 'Other' && trimmed.toLowerCase() != 'other'
            ? trimmed
            : normalized;
        final key = label.toLowerCase();

        // "Other" is a storage fallback, not a useful description of a bundle.
        if (key == 'other' || !seenForUrl.add(key)) continue;

        labels.putIfAbsent(key, () => label);
        firstSeen.putIfAbsent(key, () => nextOrder++);
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final rankedKeys = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        if (byCount != 0) return byCount;
        return firstSeen[a]!.compareTo(firstSeen[b]!);
      });
    return rankedKeys
        .map(
          (key) => NotificationCategoryCount(
            label: labels[key]!,
            count: counts[key]!,
          ),
        )
        .toList(growable: false);
  }
}

class NotificationCategoryCount {
  const NotificationCategoryCount({required this.label, required this.count});

  final String label;
  final int count;
}
