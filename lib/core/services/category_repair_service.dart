import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import 'category_taxonomy.dart';

/// One-time, **local** repair of each save's `categories` list after the
/// `inferAdditionalCategories` substring bug — which mis-tagged food saves as
/// "Design" because the needle `'ui'` matched "q**ui**ck" in recipe summaries.
///
/// It is deliberately **prune-only**: for every save it recomputes the inferred
/// topic categories with the fixed (word-aware) logic and removes any
/// *auto-inferable* topic category that the fix no longer produces (e.g. the
/// bogus "Design"). It never adds, reorders, or touches the primary category,
/// platform buckets, tags, title, summary or embedding — and it makes **no
/// network / AI calls**. Future saves are already correct via the inference fix.
class CategoryRepairService {
  CategoryRepairService({required IsarService isarService})
      : _isar = isarService;

  final IsarService _isar;

  static const _doneKey = 'glimpse_category_repair_v1_done';

  /// Topic categories that [CategoryTaxonomy.inferAdditionalCategories] can
  /// auto-add. Only these are eligible for pruning, so manually-set categories
  /// and platform buckets (Instagram, YouTube, …) are always preserved.
  static const _inferableTopics = <String>{
    'Food & Cooking',
    'Health',
    'Technology',
    'Design',
    'Travel',
    'Entertainment',
  };

  /// Returns how many saves had a stale category pruned (0 if already done).
  Future<int> repairIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey) ?? false) return 0;

    final urls = await _isar.getAllUrls();
    var changed = 0;

    for (final url in urls) {
      final pruned = _prunedCategories(url);
      if (pruned != null) {
        url.categories = pruned;
        await _isar.updateUrl(url);
        changed++;
      }
    }

    await prefs.setBool(_doneKey, true);
    developer.log(
      'Category repair: pruned stale categories on $changed/${urls.length} save(s).',
      name: 'CategoryRepair',
    );
    return changed;
  }

  /// Returns the cleaned category list, or `null` if nothing changed.
  List<String>? _prunedCategories(SavedUrl url) {
    final text = [url.title, url.summary ?? '', url.description].join(' ');
    final stillInferred = CategoryTaxonomy.inferAdditionalCategories(
      tags: url.tags,
      text: text,
    ).toSet();

    final kept = <String>[];
    var removed = false;
    for (final category in url.categories) {
      final isAutoInferable = _inferableTopics.contains(category) &&
          category != url.category;
      if (isAutoInferable && !stillInferred.contains(category)) {
        removed = true; // a stale auto-inferred topic (e.g. bogus "Design")
        continue;
      }
      kept.add(category);
    }

    return removed ? kept : null;
  }
}
