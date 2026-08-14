import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/category_order_provider.dart';
import '../../core/providers/dev_simulation_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/category_taxonomy.dart';

/// Provider for the home screen — all URLs grouped by category.
final allUrlsProvider = FutureProvider<List<SavedUrl>>((ref) async {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.getAllUrls();
});

/// Provider for the list of categories (with emoji and count).
final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.getCategories();
});

/// Categories sorted by user-defined order.
final orderedCategoriesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final categories = ref.watch(displayedCategoriesProvider).valueOrNull ?? [];
  final order = ref.watch(categoryOrderProvider);
  if (order.isEmpty) return categories;
  final byName = <String, Map<String, dynamic>>{
    for (final c in categories) c['category'] as String: c,
  };
  return [
    for (final name in order)
      if (byName.containsKey(name)) byName[name]!,
    for (final c in categories)
      if (!order.contains(c['category'] as String)) c,
  ];
});

/// Provider to stream all URLs for real-time updates.
final urlStreamProvider = StreamProvider<List<SavedUrl>>((ref) {
  final isarService = ref.watch(isarServiceProvider);
  return isarService.watchAllUrls();
});

/// URLs displayed in the UI. Respects the dev-only "Force Empty Library" flag
/// so testers can preview the first-time user experience without deleting data.
///
/// Also respects "Simulate First Save": when enabled and the session has not
/// yet started the list appears empty; after the first save in that session
/// only the most recently saved link is shown.
final displayedUrlsProvider = Provider<AsyncValue<List<SavedUrl>>>((ref) {
  final urlsAsync = ref.watch(urlStreamProvider);
  final forceEmpty = ref.watch(forceEmptyLibraryProvider);
  final simulateFirstSave = ref.watch(simulateFirstSaveProvider);
  final hasSimulatedInSession = ref.watch(
    hasSimulatedFirstSaveInSessionProvider,
  );

  if (simulateFirstSave) {
    if (!hasSimulatedInSession) return const AsyncValue.data([]);
    final urls = urlsAsync.valueOrNull ?? [];
    if (urls.isNotEmpty) return AsyncValue.data([urls.first]);
    return const AsyncValue.data([]);
  }

  if (forceEmpty) return const AsyncValue.data([]);

  // Exclude "done" (archived) saves from the main library list.
  return urlsAsync.whenData((urls) => urls.where((u) => !u.isDone).toList());
});

/// Categories displayed in the UI. Respects the dev-only "Force Empty Library" flag.
final displayedCategoriesProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
      final catsAsync = ref.watch(categoriesProvider);
      final forceEmpty = ref.watch(forceEmptyLibraryProvider);
      final simulateFirstSave = ref.watch(simulateFirstSaveProvider);
      final hasSimulatedInSession = ref.watch(
        hasSimulatedFirstSaveInSessionProvider,
      );
      if (simulateFirstSave && !hasSimulatedInSession) {
        return const AsyncValue.data([]);
      }
      if (simulateFirstSave) {
        final urls = ref.watch(displayedUrlsProvider).valueOrNull ?? [];
        return AsyncValue.data(_categoriesFromUrls(urls));
      }
      if (forceEmpty) return const AsyncValue.data([]);
      return catsAsync;
    });

List<Map<String, dynamic>> _categoriesFromUrls(List<SavedUrl> urls) {
  final categoryMap = <String, Map<String, dynamic>>{};
  for (final url in urls) {
    for (final category in url.effectiveCategories) {
      final interest = CategoryTaxonomy.normalize(
        category: category,
        tags: url.tags,
      );
      final name = interest.name;
      final existing = categoryMap[name];
      if (existing != null) {
        existing['count'] = (existing['count'] as int) + 1;
      } else {
        categoryMap[name] = {
          'category': name,
          'emoji': interest.emoji,
          'count': 1,
        };
      }
    }
  }
  return categoryMap.values.toList();
}

/// Lowercase tag → occurrence count across the library (specificity / ordering).
/// Uses [urlStreamProvider] (real data) so tag frequencies are never affected
/// by dev simulation overrides.
final _tagOccurrenceCacheProvider = Provider<TagOccurrenceCache>(
  (ref) => TagOccurrenceCache(),
);

final tagOccurrenceMapProvider = Provider<Map<String, int>>((ref) {
  final urls = ref.watch(urlStreamProvider).valueOrNull ?? const <SavedUrl>[];
  return ref.watch(_tagOccurrenceCacheProvider).build(urls);
});

/// Reuses tag counts when a URL stream emission changed only processing state.
class TagOccurrenceCache {
  final Map<int, List<String>> _tagsByUrlId = {};
  Map<String, int> _counts = const {};

  Map<String, int> build(List<SavedUrl> urls) {
    var changed = urls.length != _tagsByUrlId.length;
    for (final url in urls) {
      if (!listEquals(_tagsByUrlId[url.id], url.tags)) changed = true;
    }
    if (!changed) return _counts;

    final counts = <String, int>{};
    for (final url in urls) {
      for (final tag in url.tags) {
        final key = tag.toLowerCase().trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    _tagsByUrlId
      ..clear()
      ..addEntries(
        urls.map(
          (url) => MapEntry(url.id, List<String>.unmodifiable(url.tags)),
        ),
      );
    _counts = Map.unmodifiable(counts);
    return _counts;
  }
}

/// Incremented when the Home destination is tapped while Home is already
/// selected, so the embedded Home screen can return to the top.
final homeScrollToTopSignalProvider = StateProvider<int>((ref) => 0);
