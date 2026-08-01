import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/sources/sources_provider.dart';

void main() {
  test('returns only the five sources with the most saves', () {
    final ranked = topSourceClusters([
      _cluster('Medium', 4),
      _cluster('YouTube', 12),
      _cluster('GitHub', 8),
      _cluster('Instagram', 15),
      _cluster('Reddit', 7),
      _cluster('Substack', 3),
      _cluster('Empty', 0),
    ]);

    expect(ranked.map((cluster) => cluster.name), [
      'Instagram',
      'YouTube',
      'GitHub',
      'Reddit',
      'Medium',
    ]);
  });

  test('uses source name as a stable tie-breaker', () {
    final ranked = topSourceClusters([
      _cluster('YouTube', 5),
      _cluster('GitHub', 5),
      _cluster('Instagram', 5),
    ]);

    expect(ranked.map((cluster) => cluster.name), [
      'GitHub',
      'Instagram',
      'YouTube',
    ]);
  });
}

SourceCluster _cluster(String name, int count) {
  return SourceCluster(
    name: name,
    count: count,
    mostlyAbout: const [],
    themeCount: 0,
    memoryStripUrls: const [],
    savesThisWeek: 0,
  );
}
