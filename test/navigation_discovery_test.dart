import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/features/mindmap/interest_cluster_service.dart';
import 'package:glimpse/features/shell/navigation_discovery_icon.dart';
import 'package:glimpse/features/shell/navigation_discovery_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('navigation discovery evaluation', () {
    test('a unique Library entity badges Collections', () async {
      final evaluation = await evaluateNavigationDiscovery(
        urls: [
          _plainSave(1),
          _entitySave(2, title: 'Dune', type: 'book'),
        ],
        newSaveId: 2,
      );

      expect(evaluation.hasNewCollections, isTrue);
      expect(evaluation.hasNewInterests, isFalse);
    });

    test('a repeated Library entity stays quiet', () async {
      final evaluation = await evaluateNavigationDiscovery(
        urls: [
          _entitySave(1, title: 'Arrival', type: 'movie'),
          _entitySave(2, title: 'Arrival', type: 'movie'),
        ],
        newSaveId: 2,
      );

      expect(evaluation.hasNewCollections, isFalse);
    });

    test('catalog resolution of an existing entity stays quiet', () async {
      final resolved = _entitySave(2, title: 'Dune', type: 'book');
      final payload =
          jsonDecode(resolved.enrichmentJson!) as Map<String, dynamic>;
      final mention =
          (payload['mentions'] as List).single as Map<String, dynamic>;
      mention['catalog_id'] = 'OL893415W';
      mention['catalog_source'] = 'open_library';
      resolved.enrichmentJson = jsonEncode(payload);

      final evaluation = await evaluateNavigationDiscovery(
        urls: [
          _entitySave(1, title: 'Dune', type: 'book'),
          resolved,
        ],
        newSaveId: 2,
      );

      expect(evaluation.hasNewCollections, isFalse);
    });

    test('hidden Library entities stay quiet', () async {
      final save = _entitySave(2, title: 'Piranesi', type: 'book');
      final provisionalKey = 'book:piranesi|';

      final evaluation = await evaluateNavigationDiscovery(
        urls: [_plainSave(1), save],
        newSaveId: 2,
        hiddenLibraryEntityKeys: {provisionalKey},
      );

      expect(evaluation.hasNewCollections, isFalse);
    });

    test('maturing a singleton into a real interest creates a badge', () async {
      final evaluation = await evaluateNavigationDiscovery(
        urls: [
          _interestSave(1, category: 'Health', embedding: [1, 0]),
          _interestSave(2, category: 'Technology', embedding: [1, 0]),
          _interestSave(3, category: 'Health', embedding: [0.99, 0.01]),
        ],
        newSaveId: 3,
      );

      expect(evaluation.hasNewInterests, isTrue);
    });

    test('ordinary growth of an existing interest stays quiet', () async {
      final evaluation = await evaluateNavigationDiscovery(
        urls: [
          _interestSave(1, category: 'Health', embedding: [1, 0]),
          _interestSave(2, category: 'Health', embedding: [0.99, 0.01]),
          _interestSave(3, category: 'Technology', embedding: [1, 0]),
          _interestSave(4, category: 'Health', embedding: [0.98, 0.02]),
        ],
        newSaveId: 4,
      );

      expect(evaluation.hasNewInterests, isFalse);
    });

    test('a second meaningful interest creates a badge', () async {
      final evaluation = await evaluateNavigationDiscovery(
        urls: [
          _interestSave(1, category: 'Health', embedding: [1, 0]),
          _interestSave(2, category: 'Health', embedding: [0.99, 0.01]),
          _interestSave(3, category: 'Travel', embedding: [0, 1]),
          _interestSave(4, category: 'Travel', embedding: [0.01, 0.99]),
        ],
        newSaveId: 4,
      );

      expect(evaluation.hasNewInterests, isTrue);
    });

    test('a new valid subtopic is structural while cluster growth is not', () {
      final previous = InterestTopologySnapshot(
        embeddedCount: 6,
        topClusters: [
          {'a', 'b', 'c', 'd', 'e', 'f'},
        ],
        subtopics: [
          {'a', 'b', 'c'},
        ],
      );
      final withSubtopic = InterestTopologySnapshot(
        embeddedCount: 7,
        topClusters: [
          {'a', 'b', 'c', 'd', 'e', 'f', 'g'},
        ],
        subtopics: [
          {'a', 'b', 'c'},
          {'d', 'e', 'f'},
        ],
      );
      final growthOnly = InterestTopologySnapshot(
        embeddedCount: 7,
        topClusters: [
          {'a', 'b', 'c', 'd', 'e', 'f', 'g'},
        ],
        subtopics: [
          {'a', 'b', 'c', 'g'},
        ],
      );

      expect(withSubtopic.addsMeaningfulStructureComparedTo(previous), isTrue);
      expect(growthOnly.addsMeaningfulStructureComparedTo(previous), isFalse);
    });
  });

  group('persisted discovery state', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'existing data is a quiet baseline and pending state persists',
      () async {
        final urls = [_plainSave(1)];
        final first = ProviderContainer(
          overrides: [
            navigationDiscoveryUrlsLoaderProvider.overrideWithValue(
              () async => List.of(urls),
            ),
          ],
        );
        final firstNotifier = first.read(navigationDiscoveryProvider.notifier);
        await firstNotifier.ready;

        expect(
          first.read(navigationDiscoveryProvider).hasNewCollections,
          isFalse,
        );

        urls.add(_entitySave(2, title: 'Dune', type: 'book'));
        await firstNotifier.recordCompletedNewSave(2);
        expect(
          first.read(navigationDiscoveryProvider).hasNewCollections,
          isTrue,
        );

        first.dispose();
        final restored = ProviderContainer(
          overrides: [
            navigationDiscoveryUrlsLoaderProvider.overrideWithValue(
              () async => List.of(urls),
            ),
          ],
        );
        addTearDown(restored.dispose);
        final restoredNotifier = restored.read(
          navigationDiscoveryProvider.notifier,
        );
        await restoredNotifier.ready;

        expect(
          restored.read(navigationDiscoveryProvider).hasNewCollections,
          isTrue,
        );

        await restoredNotifier.acknowledgeCollections();
        expect(
          restored.read(navigationDiscoveryProvider).hasNewCollections,
          isFalse,
        );
      },
    );

    test('data reset removes pending indicators', () async {
      SharedPreferences.setMockInitialValues({
        navigationDiscoveryPrefsKey: jsonEncode({
          'hasNewCollections': true,
          'hasNewInterests': true,
          'libraryFingerprint': 'library',
          'interestFingerprint': 'interests',
        }),
      });
      final container = ProviderContainer(
        overrides: [
          navigationDiscoveryUrlsLoaderProvider.overrideWithValue(
            () async => const [],
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(navigationDiscoveryProvider.notifier);
      await notifier.ready;

      await notifier.resetAfterDataClear();

      final state = container.read(navigationDiscoveryProvider);
      expect(state.hasNewCollections, isFalse);
      expect(state.hasNewInterests, isFalse);
    });
  });

  group('navigation discovery icon', () {
    testWidgets('uses a quiet primary dot in a NavigationBar', (tester) async {
      await _pumpNavigationIcon(tester, rail: false);

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);
      expect(badge.backgroundColor, const Color(0xFF6750A4));
      expect(_hasSemanticsLabel('Collections, New discovery'), isTrue);
    });

    testWidgets('uses the same dot in a NavigationRail', (tester) async {
      await _pumpNavigationIcon(tester, rail: true);

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);
      expect(badge.backgroundColor, const Color(0xFF6750A4));
      expect(_hasSemanticsLabel('Interests, New discovery'), isTrue);
    });
  });
}

bool _hasSemanticsLabel(String label) {
  return find
      .byType(Semantics)
      .evaluate()
      .map((element) => element.widget)
      .whereType<Semantics>()
      .any((semantics) => semantics.properties.label == label);
}

Future<void> _pumpNavigationIcon(
  WidgetTester tester, {
  required bool rail,
}) async {
  const primary = Color(0xFF6750A4);
  final icon = NavigationDiscoveryIcon(
    semanticsLabel: rail ? 'Interests' : 'Collections',
    discoveryLabel: 'New discovery',
    showBadge: true,
    icon: Icon(rail ? Icons.interests_outlined : Icons.collections_outlined),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
        ).copyWith(primary: primary),
      ),
      home: Scaffold(
        body: rail
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: 0,
                    destinations: [
                      NavigationRailDestination(
                        icon: icon,
                        label: const Text('Interests'),
                      ),
                    ],
                  ),
                  const Expanded(child: SizedBox()),
                ],
              )
            : const SizedBox(),
        bottomNavigationBar: rail
            ? null
            : NavigationBar(
                destinations: [
                  NavigationDestination(icon: icon, label: 'Collections'),
                  const NavigationDestination(
                    icon: Icon(Icons.search_outlined),
                    label: 'Search',
                  ),
                ],
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SavedUrl _plainSave(int id) {
  return SavedUrl()
    ..id = id
    ..rawUrl = 'https://example.com/$id'
    ..domain = 'example.com'
    ..title = 'Save $id'
    ..description = ''
    ..category = 'Other'
    ..categoryEmoji = ''
    ..categories = const ['Other']
    ..tags = const []
    ..savedAt = DateTime(2026, 8, id);
}

SavedUrl _entitySave(int id, {required String title, required String type}) {
  return _plainSave(id)
    ..enrichmentJson = jsonEncode({
      'schema_version': 3,
      'meaningful_title': 'Save $id',
      'summary': 'Summary',
      'category': 'Other',
      'tags': <String>[],
      'mentions': [
        {'title': title, 'type': type, 'subtype': type},
      ],
    });
}

SavedUrl _interestSave(
  int id, {
  required String category,
  required List<double> embedding,
}) {
  return _plainSave(id)
    ..category = category
    ..categories = [category]
    ..tags = [category.toLowerCase()]
    ..embedding = embedding;
}
