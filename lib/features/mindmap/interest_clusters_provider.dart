import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/service_providers.dart';
import '../../core/services/bundled_keys.dart';
import '../../core/services/gemini_service.dart';
import '../home/home_provider.dart';
import 'cluster_theme.dart';
import 'interest_cluster_service.dart';

/// Semantic interest clusters (embedding + cache + optional Gemini labels).
final interestClusterThemesProvider =
    FutureProvider.autoDispose<List<ClusterTheme>>((ref) async {
  ref.watch(
    urlStreamProvider.select(
      (async) => async.whenOrNull(data: (urls) => urls.length),
    ),
  );

  final isar = ref.read(isarServiceProvider);
  final prefs = await SharedPreferences.getInstance();
  final gemini = BundledKeys.hasGemini
      ? GeminiService(BundledKeys.geminiKey)
      : null;

  return loadOrBuildInterestClusterThemes(
    isar: isar,
    prefs: prefs,
    gemini: gemini,
  );
});

/// Clears persisted cluster snapshot (e.g. after “Clear all data”).
Future<void> clearInterestClusterCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kInterestClustersJsonKey);
  await prefs.remove(kInterestClusterUrlCountKey);
}
