import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/service_providers.dart';
import '../home/home_provider.dart';
import 'cluster_theme.dart';
import 'interest_cluster_service.dart';

/// Semantic interest clusters (embedding + cache + optional Gemini labels).
///
/// Uses [keepAlive] so that the provider is not disposed while the refresh
/// button awaits [clearInterestClusterCache] — without this, autoDispose would
/// tear down the provider between the clear and the invalidate, causing the
/// next build to hit a stale SharedPreferences instance from a previous call.
final interestClusterThemesProvider = FutureProvider<List<ClusterTheme>>((
  ref,
) async {
  // Keep alive so a manual refresh (clear + invalidate) never races with
  // autoDispose tearing this provider down mid-flight.
  final link = ref.keepAlive();

  // Re-watch url count so the provider rebuilds when new URLs are added.
  ref.watch(
    urlStreamProvider.select(
      (async) => async.whenOrNull(data: (urls) => urls.length),
    ),
  );

  final isar = ref.read(isarServiceProvider);

  // SharedPreferences is a process-wide singleton, so the in-memory state here
  // already reflects keys removed by clearInterestClusterCache() earlier in this
  // same refresh. We must NOT call prefs.reload(): that re-reads from disk and
  // races with the pending remove() write, which can resurrect the cache we
  // just cleared — making the manual refresh button appear to do nothing.
  final prefs = await SharedPreferences.getInstance();

  final gemini = ref.read(geminiServiceProvider);

  final result = await loadOrBuildInterestClusterThemes(
    isar: isar,
    prefs: prefs,
    gemini: gemini,
  );

  // Release the keepAlive once the build is done so memory is not leaked
  // when this screen is popped and the provider is no longer watched.
  link.close();

  return result;
});

/// Clears persisted cluster snapshot (e.g. after manual refresh or "Clear all data").
Future<void> clearInterestClusterCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kInterestClustersJsonKey);
  await prefs.remove(kInterestClusterUrlCountKey);
}
