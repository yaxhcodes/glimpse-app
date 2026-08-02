import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/features/mindmap/cluster_theme.dart';
import 'package:glimpse/features/mindmap/interest_clusters_provider.dart';
import 'package:glimpse/features/mindmap/mindmap_screen.dart';

void main() {
  testWidgets('embedded interests stay above the shell navigation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final themes = List.generate(
      12,
      (index) => ClusterTheme(
        index: index,
        label: 'Interest ${index + 1}',
        summary: '',
        urls: List.generate(
          3,
          (urlIndex) => _savedUrl(index * 3 + urlIndex + 1),
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          interestClusterThemesProvider.overrideWith((ref) async => themes),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            extendBody: true,
            body: const MindmapScreen(embedded: true),
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.interests_outlined),
                  label: 'Interests',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  label: 'Search',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -10000));
    await tester.pumpAndSettle();

    final lastInterestRect = tester.getRect(find.text('Interest 12'));
    final navigationRect = tester.getRect(find.byType(NavigationBar));
    expect(lastInterestRect.bottom, lessThanOrEqualTo(navigationRect.top));
  });
}

SavedUrl _savedUrl(int id) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = 'Saved item $id'
    ..description = ''
    ..category = 'Other'
    ..categoryEmoji = '🔖'
    ..categories = const ['Other']
    ..tags = const ['Topic']
    ..savedAt = DateTime(2026);
}
