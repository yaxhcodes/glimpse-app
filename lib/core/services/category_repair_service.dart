import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import 'category_resolver.dart';
import 'category_taxonomy.dart';
import 'domain_centroid_service.dart';

/// One-time local repair for category decisions that can be corrected from
/// data already stored on the save. It makes no network or AI calls.
class CategoryRepairService {
  CategoryRepairService({required IsarService isarService})
    : _isar = isarService;

  final IsarService _isar;

  static const _doneKey = 'glimpse_category_repair_v3_done';

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
    'AI & ML',
    'Software Development',
    'Gadgets & Hardware',
    'Apps & Tools',
    'Cybersecurity',
    'Data & Analytics',
    'Startups',
    'Marketing & Growth',
    'Creator Economy',
    'Personal Finance',
    'Investing',
    'Crypto',
    'Space & Astronomy',
    'Biology & Medicine',
    'Fitness',
    'Nutrition',
    'Mental Health',
    'Language Learning',
    'Math',
    'World Affairs',
    'Law & Policy',
    'Art & Illustration',
    'Photography',
    'Architecture',
    'History & Culture',
    'Spirituality & Philosophy',
    'Relationships',
    'Career',
    'Productivity',
    'Nature & Environment',
    'Parenting & Family',
    'DIY & Making',
    'Restaurants & Cafes',
    'Outdoors & Adventure',
    'Movies & TV',
    'Gaming',
    'Fashion & Beauty',
    'Vehicles',
    'Books & Literature',
    'Documentation',
    'Reference',
  };

  /// Returns how many saves had a stale category pruned (0 if already done).
  Future<int> repairIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey) ?? false) return 0;

    final urls = await _isar.getAllUrls();
    var changed = 0;
    var restoredPrimaryCategories = 0;

    for (final url in urls) {
      final restored = repairUnsafeCentroidCategory(url);
      final pruned = _prunedCategories(url);
      if (pruned != null) {
        url.categories = pruned;
      }
      if (restored || pruned != null) {
        await _isar.updateUrl(url);
        changed++;
      }
      if (restored) restoredPrimaryCategories++;
    }

    await prefs.setBool(_doneKey, true);
    developer.log(
      'Category repair: updated $changed/${urls.length} save(s), '
      'restored $restoredPrimaryCategories unsafe centroid correction(s).',
      name: 'CategoryRepair',
    );
    return changed;
  }

  /// Restores the pre-centroid category when an older automatic correction did
  /// not meet the current safety gates. The enrichment envelope keeps the
  /// original validation decision for provenance and future centroid exclusion.
  static bool repairUnsafeCentroidCategory(SavedUrl url) {
    final raw = url.enrichmentJson;
    if (raw == null || raw.trim().isEmpty) return false;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final data = Map<String, dynamic>.from(decoded);
      final rawValidation = data['category_validation'];
      if (rawValidation is! Map) return false;
      final validation = Map<String, dynamic>.from(rawValidation);
      if (validation['method'] != 'embedding_centroid') return false;

      final storedFinalCategory = data['category']?.toString().trim() ?? '';
      final currentCategory = url.category.trim();
      if (storedFinalCategory != currentCategory) return false;

      final suggestedCategory = CategoryTaxonomy.normalize(
        category: validation['suggested_category']?.toString() ?? '',
      ).name;
      if (suggestedCategory != currentCategory) return false;

      final originalCategory = CategoryTaxonomy.normalize(
        category: data['original_gemini_category']?.toString() ?? '',
      );
      if (originalCategory.name == currentCategory) return false;

      final claimedSampleSize = _asInt(validation['centroid_sample_size']);
      final suggestedSimilarity = _asDouble(validation['suggested_similarity']);
      final wasUnsafe =
          claimedSampleSize <
              DomainCentroidService.minSampleSizeForReliableCentroid ||
          suggestedSimilarity < DomainCentroidService.correctionSimilarityFloor;
      if (!wasUnsafe) return false;

      final previousCategory = currentCategory;
      url
        ..category = originalCategory.name
        ..categoryEmoji = originalCategory.emoji
        ..categories = CategoryResolver.buildCategories(
          primaryCategory: originalCategory.name,
          additionalCategories: url.categories
              .where(
                (category) =>
                    category != previousCategory &&
                    category != originalCategory.name,
              )
              .toList(),
        );
      data
        ..['category'] = originalCategory.name
        ..['category_needs_review'] = originalCategory.name == 'Other'
        ..['category_repair'] = {
          'method': 'restore_unsafe_centroid_correction',
          'previous_category': previousCategory,
          'restored_category': originalCategory.name,
        };
      url.enrichmentJson = jsonEncode(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Returns the cleaned category list, or `null` if nothing changed.
  List<String>? _prunedCategories(SavedUrl url) {
    final text = [url.title, url.summary ?? '', url.description].join(' ');
    final stillValid = CategoryTaxonomy.curateSourceCategories(
      categories: url.categories,
      primaryCategory: url.category,
      tags: url.tags,
      text: text,
    ).toSet();

    final kept = <String>[];
    var removed = false;
    for (final category in url.categories) {
      final isAutoInferable =
          _inferableTopics.contains(category) && category != url.category;
      if (isAutoInferable && !stillValid.contains(category)) {
        removed = true; // stale auto-inferred topic (e.g. bogus "Vehicles")
        continue;
      }
      kept.add(category);
    }

    return removed ? kept : null;
  }
}
