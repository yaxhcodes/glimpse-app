import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/providers/usage_providers.dart';
import 'package:glimpse/features/collections/collections_provider.dart';
import 'package:glimpse/features/home/home_provider.dart';
import 'package:glimpse/features/search/search_provider.dart';
import 'package:glimpse/features/search/search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('embedded results scroll above the shell navigation bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final urls = List.generate(12, _savedUrl);
    final results = [for (final url in urls) SearchResult(url: url, score: 1)];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchProvider.overrideWith(() => _StaticSearch(results)),
          collectionsSummaryProvider.overrideWith((ref) async => const []),
          urlStreamProvider.overrideWith((ref) => Stream.value(urls)),
          aiSaveAvailableProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            extendBody: true,
            body: const SearchScreen(embedded: true, initialQuery: 'wildlife'),
            bottomNavigationBar: NavigationBar(
              selectedIndex: 1,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
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

    await tester.drag(find.byType(ListView), const Offset(0, -10000));
    await tester.pumpAndSettle();

    final lastResult = tester.getRect(find.byKey(const ValueKey(12)));
    final navigation = tester.getRect(find.byType(NavigationBar));
    expect(lastResult.bottom, lessThan(navigation.top));
  });
}

class _StaticSearch extends Search {
  _StaticSearch(this.results);

  final List<SearchResult> results;

  @override
  AsyncValue<List<SearchResult>> build() => AsyncValue.data(results);

  @override
  Future<void> search(String query) async {}
}

SavedUrl _savedUrl(int index) {
  final id = index + 1;
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = 'Wildlife result $id'
    ..description = ''
    ..category = 'Nature'
    ..categoryEmoji = '🌿'
    ..categories = const ['Nature']
    ..tags = const ['wildlife', 'conservation']
    ..savedAt = DateTime(2026, 9, 7);
}
