import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/features/collections/collections_provider.dart';
import 'package:glimpse/features/collections/collections_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('embedded collections stay above the shell navigation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final summaries = List.generate(20, (index) {
      final collection = UserCollection()
        ..id = index + 1
        ..name = 'Collection ${index + 1}'
        ..emoji = '📚'
        ..createdAt = DateTime(2026)
        ..urlIds = const [];
      return CollectionSummary(collection: collection, linkCount: 0);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionsSummaryProvider.overrideWith((ref) async => summaries),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            extendBody: true,
            body: const CollectionsScreen(embedded: true),
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.collections_outlined),
                  label: 'Collections',
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

    final fabRect = tester.getRect(find.byType(FloatingActionButton));
    final navigationRect = tester.getRect(find.byType(NavigationBar));
    expect(fabRect.bottom, lessThanOrEqualTo(navigationRect.top));

    await tester.drag(find.byType(GridView), const Offset(0, -10000));
    await tester.pumpAndSettle();
    final lastCollectionRect = tester.getRect(find.text('Collection 20'));
    expect(lastCollectionRect.bottom, lessThanOrEqualTo(navigationRect.top));

    await tester.tap(find.byIcon(Icons.view_agenda_outlined));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -10000));
    await tester.pumpAndSettle();
    final lastListCollectionRect = tester.getRect(find.text('Collection 20'));
    expect(
      lastListCollectionRect.bottom,
      lessThanOrEqualTo(navigationRect.top),
    );
  });
}
