import 'category_taxonomy.dart';
import 'domain_categorizer.dart';

/// Resolves category presentation metadata and category list composition.
class CategoryResolver {
  static List<String> buildCategories({
    required String primaryCategory,
    String? platformCategory,
    List<String> additionalCategories = const [],
  }) {
    final ordered = <String>[];

    void addCategory(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) return;
      if (!ordered.contains(trimmed)) {
        ordered.add(trimmed);
      }
    }

    addCategory(primaryCategory);
    if (platformCategory != null &&
        platformCategory.isNotEmpty &&
        platformCategory != 'Web') {
      addCategory(platformCategory);
    }
    for (final category in additionalCategories) {
      addCategory(category);
    }

    if (ordered.isEmpty) {
      ordered.add('Other');
    }

    return ordered;
  }

  static String emojiForCategory(String category, {String? fallbackEmoji}) {
    final taxonomyCategory = CategoryTaxonomy.tryByName(category);
    if (taxonomyCategory != null) {
      return taxonomyCategory.emoji;
    }

    final platformCategory = DomainCategorizer.infoForCategory(category);
    if (platformCategory != null) {
      return platformCategory.emoji;
    }

    return fallbackEmoji ?? '📁';
  }

  static String displaySourceName({
    required String rawUrl,
    required String fallbackDomain,
  }) {
    final platform = DomainCategorizer.categorize(rawUrl);
    if (platform.category != 'Web') {
      return platform.category;
    }
    return fallbackDomain;
  }
}
