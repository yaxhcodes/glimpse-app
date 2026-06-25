import '../models/saved_url.dart';
import 'category_resolver.dart';
import 'category_taxonomy.dart';
import 'domain_categorizer.dart';

/// Shared membership rules for the Sources library and source/category results.
class SourceMembership {
  static String originFor(SavedUrl url) {
    return CategoryResolver.displaySourceName(
      rawUrl: url.rawUrl,
      fallbackDomain: url.domain,
    );
  }

  static bool containsOrigin(SavedUrl url, String source) {
    final target = source.trim().toLowerCase();
    if (target.isEmpty) return false;
    return originFor(url).toLowerCase() == target;
  }

  static List<String> categoriesFor(SavedUrl url) {
    final sources = <String>[];

    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == 'Web' || trimmed == 'Other') return;
      if (!sources.contains(trimmed)) sources.add(trimmed);
    }

    final text = '${url.title} ${url.summary ?? ''} ${url.description}';
    for (final source in CategoryTaxonomy.curateSourceCategories(
      categories: url.effectiveCategories,
      primaryCategory: url.category,
      tags: url.tags,
      text: text,
    )) {
      add(source);
    }

    for (final category in url.effectiveCategories) {
      if (DomainCategorizer.infoForCategory(category) != null) {
        add(category);
      }
    }

    final platform = DomainCategorizer.categorize(url.rawUrl).category;
    if (DomainCategorizer.infoForCategory(platform) != null) {
      add(platform);
    }

    return sources.isEmpty ? const ['Other'] : sources;
  }

  static bool contains(SavedUrl url, String source) {
    final target = source.trim();
    if (target.isEmpty) return false;
    return categoriesFor(url).contains(target);
  }
}
