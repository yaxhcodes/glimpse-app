import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/providers/service_providers.dart';
import 'package:glimpse/core/services/category_resolver.dart';
import 'package:glimpse/features/home/home_provider.dart';
import 'package:glimpse/features/url_detail/reader_enrichment_progress.dart';
import 'package:glimpse/features/url_detail/reader_enrichment_reveal.dart';
import 'package:glimpse/features/url_detail/source_saved_metadata_row.dart';
import 'package:glimpse/features/url_detail/url_detail_provider.dart';
import 'package:glimpse/features/url_detail/url_detail_screen.dart';
import 'package:glimpse/features/rediscover/journey_visual.dart';
import 'package:glimpse/features/rediscover/rediscover_journey_provider.dart';
import 'package:glimpse/shared/widgets/card_open_transition.dart';
import 'package:glimpse/l10n/l10n.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('card opens into the page', () {
    const cardRect = Rect.fromLTWH(16, 300, 368, 92);

    GoRouter buildRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Stack(
              children: [
                Positioned.fromRect(
                  rect: cardRect,
                  child: CardOpenOrigin(
                    openTag: CardOpenOrigin.urlTag(7),
                    child: GestureDetector(
                      onTap: () => context.push('/url/7'),
                      child: const ColoredBox(
                        color: Colors.teal,
                        child: Center(child: Text('card')),
                      ),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: cardRect.shift(const Offset(0, 100)),
                  child: CardOpenOrigin(
                    openTag: CardOpenOrigin.urlTag(8),
                    child: const ColoredBox(
                      color: Colors.orange,
                      child: Center(child: Text('neighbour')),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: TextButton(
                    onPressed: () => context.push('/url/7'),
                    child: const Text('open without card'),
                  ),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/url/:id',
          pageBuilder: (context, state) => CardOpenPage(
            key: state.pageKey,
            urlId: int.parse(state.pathParameters['id']!),
            child: const Scaffold(body: Text('detail page')),
          ),
        ),
      ],
    );

    Rect window(WidgetTester tester) => tester.getRect(
      find
          .ancestor(
            of: find.text('detail page'),
            matching: find.byType(ClipRRect),
          )
          .first,
    );

    Future<(GoRouter, Size)> pumpApp(WidgetTester tester) async {
      final router = buildRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      return (router, tester.view.physicalSize / tester.view.devicePixelRatio);
    }

    testWidgets('opens out of the card at both edges and closes back in', (
      tester,
    ) async {
      final (router, size) = await pumpApp(tester);

      await tester.tap(find.text('card'));
      // The push's offstage frame, then the frame that first paints the
      // page (hidden in the card) before anything moves.
      await tester.pump();
      await tester.pump();
      expect(window(tester), cardRect);
      await tester.pump();
      expect(window(tester), cardRect);

      await tester.pump(const Duration(milliseconds: 80));
      final opening = window(tester);
      expect(opening.top, lessThan(cardRect.top));
      expect(opening.bottom, greaterThan(cardRect.bottom));

      await tester.pumpAndSettle();
      expect(window(tester), Offset.zero & size);

      router.pop();
      await tester.pump();
      // Holds still through the frame that brings the page below back.
      expect(window(tester), Offset.zero & size);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final closing = window(tester);
      expect(closing.top, greaterThan(0));
      expect(closing.bottom, lessThan(size.height));
      expect(closing.top, lessThan(cardRect.top));
      expect(closing.bottom, greaterThan(cardRect.bottom));

      await tester.pump(const Duration(milliseconds: 250));
      final landed = window(tester);
      expect(
        landed.center.dy,
        moreOrLessEquals(cardRect.center.dy, epsilon: 20),
      );

      await tester.pumpAndSettle();
      expect(find.text('detail page'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the card takes the landing and jostles its neighbour', (
      tester,
    ) async {
      final (router, _) = await pumpApp(tester);
      await tester.tap(find.text('card'));
      await tester.pumpAndSettle();

      Iterable<Matrix4> transformsOf(String text) => tester
          .widgetList<Transform>(
            find.ancestor(
              of: find.text(text),
              matching: find.byType(Transform),
            ),
          )
          .map((transform) => transform.transform);
      double squashOf(String text) =>
          transformsOf(text).map((m) => m.entry(0, 0)).fold(1.0, math.min);
      double shiftOf(String text) => transformsOf(
        text,
      ).map((m) => m.getTranslation().y).fold(0.0, math.max);

      router.pop();
      var deepestSquash = 1.0;
      var furthestShift = 0.0;
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 11));
        deepestSquash = math.min(deepestSquash, squashOf('card'));
        furthestShift = math.max(furthestShift, shiftOf('neighbour'));
      }
      expect(deepestSquash, lessThan(0.99));
      // Pushed away from the card, downward, by a few pixels.
      expect(furthestShift, inInclusiveRange(2, 12));

      await tester.pumpAndSettle();
      expect(squashOf('card'), 1);
      expect(shiftOf('neighbour'), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a card it opens out of a line across the middle', (
      tester,
    ) async {
      final (_, size) = await pumpApp(tester);

      await tester.tap(find.text('open without card'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final opening = window(tester);
      expect(opening.center.dy, moreOrLessEquals(size.height / 2, epsilon: 1));
      expect(opening.height, inExclusiveRange(0, size.height));

      await tester.pumpAndSettle();
      expect(window(tester), Offset.zero & size);
    });

    testWidgets('a predictive back swipe pulls the page toward its card', (
      tester,
    ) async {
      final (_, size) = await pumpApp(tester);
      await tester.tap(find.text('card'));
      await tester.pumpAndSettle();

      Future<void> send(String method, [Map<String, Object?>? args]) =>
          tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/backgesture',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, args),
            ),
            (_) {},
          );

      await send('startBackGesture', {
        'touchOffset': [5.0, 300.0],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      await tester.pump();
      await send('updateBackGestureProgress', {
        'touchOffset': [180.0, 300.0],
        'progress': 0.6,
        'swipeEdge': 0,
      });
      await tester.pump();
      await tester.pump();

      final dragged = window(tester);
      expect(dragged.height, lessThan(size.height));
      expect(dragged.height, greaterThan(cardRect.height));
      // The page below shows around it while the finger is down.
      expect(find.text('card'), findsOneWidget);

      await send('commitBackGesture');
      await tester.pump();
      // Carries on from where the finger let go rather than jumping open.
      expect(window(tester).height, lessThanOrEqualTo(dragged.height + 1));
      await tester.pumpAndSettle();
      expect(find.text('detail page'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a Rediscover card flies into its Glimpse like a cover', (
    tester,
  ) async {
    RediscoverArtworkCard card({required bool hero, VoidCallback? onTap}) =>
        RediscoverArtworkCard(
          journey: const RediscoverJourney(
            kind: RediscoverJourneyKind.forgottenGems,
            title: 'Slow travel in Kyoto',
            subtitle: 'You saved three of these',
            icon: Icons.bookmark,
            items: [],
            signal: 1,
            topicAnchor: 'travel',
          ),
          title: 'Slow travel in Kyoto',
          supportingText: 'You saved three of these',
          metadata: '3 saves',
          height: hero ? 252 : 224,
          hero: hero,
          onTap: onTap,
          heroTag: rediscoverCardHeroTag('k'),
        );
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: 300,
              child: card(
                hero: false,
                onTap: () => navigator.currentState!.push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: Padding(
                        padding: const EdgeInsets.all(16),
                        child: card(hero: true),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final start = tester.getRect(find.byType(RediscoverArtworkCard));
    final titleStart = tester.getRect(find.text('Slow travel in Kyoto'));

    await tester.tap(find.byType(RediscoverArtworkCard));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final title = find.text('Slow travel in Kyoto');
    // In flight: both cards, each in its own frozen layout, crossfading.
    expect(title, findsNWidgets(2));
    final flying = tester.getRect(title.first);
    expect(flying.top, lessThan(titleStart.top - 20));
    expect(flying.top, greaterThan(16));

    await tester.pumpAndSettle();
    expect(find.byType(RediscoverArtworkCard), findsOneWidget);
    expect(tester.getRect(find.byType(RediscoverArtworkCard)).top, 16);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(RediscoverArtworkCard)), start);
    expect(tester.takeException(), isNull);
  });

  group('source byline', () {
    testWidgets('the source name is a link to its page', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SourceSavedMetadataRow(
              leading: const SizedBox.square(dimension: 14),
              sourceName: 'Instagram',
              savedLabel: '2 days ago',
              exactDateVisible: false,
              isRead: false,
              sourceColor: Colors.purple,
              onSavedLabelTap: () {},
              onSourceTap: () => taps++,
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('See all saves from Instagram'),
        findsOneWidget,
      );
      await tester.tap(find.text('Instagram'));
      expect(taps, 1);
    });

    Future<GoRouter> pumpDetail(
      WidgetTester tester, {
      required String initialLocation,
      required List<String> visited,
    }) async {
      final database = _MemoryIsarService(_savedUrl());
      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          GoRoute(
            path: '/sources/:name',
            builder: (_, state) {
              visited.add(state.pathParameters['name']!);
              return Scaffold(
                body: Text('source ${state.pathParameters['name']}'),
              );
            },
          ),
          GoRoute(
            path: '/url',
            builder: (_, _) => const UrlDetailScreen(urlId: 5),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isarServiceProvider.overrideWithValue(database),
            urlDetailProvider(5).overrideWith((ref) async => database.url),
            tagOccurrenceMapProvider.overrideWithValue(const {}),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('opens that source in Sources', (tester) async {
      final visited = <String>[];
      final router = await pumpDetail(
        tester,
        initialLocation: '/',
        visited: visited,
      );
      router.push('/url');
      await tester.pumpAndSettle();

      final source = CategoryResolver.displaySourceName(
        rawUrl: _savedUrl().rawUrl,
        fallbackDomain: _savedUrl().domain,
      );
      await tester.tap(find.byKey(const ValueKey('source-page-link')));
      await tester.pumpAndSettle();
      expect(visited, [source]);
      expect(find.text('source $source'), findsOneWidget);
    });

    testWidgets('goes back when it was opened from that source', (
      tester,
    ) async {
      final visited = <String>[];
      final source = CategoryResolver.displaySourceName(
        rawUrl: _savedUrl().rawUrl,
        fallbackDomain: _savedUrl().domain,
      );
      final router = await pumpDetail(
        tester,
        initialLocation: '/sources/${Uri.encodeComponent(source)}',
        visited: visited,
      );
      router.push('/url');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('source-page-link')));
      await tester.pumpAndSettle();
      expect(find.text('source $source'), findsOneWidget);
      // Popped back to it rather than stacking a second copy.
      expect(router.canPop(), isFalse);
    });
  });

  testWidgets('content that lands while reading is revealed, not popped in', (
    tester,
  ) async {
    final url = _savedUrl()
      ..summary = null
      ..processingStatus = 'ENRICHING'
      ..processingUpdatedAt = DateTime.now();
    final database = _MemoryIsarService(url);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarServiceProvider.overrideWithValue(database),
          urlDetailProvider(5).overrideWith((ref) async => database.url),
          tagOccurrenceMapProvider.overrideWithValue(const {}),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const UrlDetailScreen(urlId: 5),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ReaderEnrichmentProgress), findsOneWidget);

    database.url = _savedUrl()
      ..processingStatus = 'COMPLETED'
      ..enrichmentJson = jsonEncode({
        'summary': 'A useful explanation.',
        'content_sections': [
          {
            'title': 'Context',
            'points': ['Source evidence.'],
          },
        ],
      });
    ProviderScope.containerOf(
      tester.element(find.byType(UrlDetailScreen)),
    ).invalidate(urlDetailProvider(5));
    for (
      var i = 0;
      i < 4 && find.byType(EnrichmentReveal).evaluate().isEmpty;
      i++
    ) {
      await tester.pump();
    }

    // How much of the block the surface veil still hides (1 hidden, 0 shown).
    double firstBlockVeil() =>
        _veil(tester, find.byType(EnrichmentReveal).first);

    // In the tree, held back for the reveal.
    expect(find.byType(EnrichmentReveal), findsWidgets);
    expect(firstBlockVeil(), 1);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(firstBlockVeil(), inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(firstBlockVeil(), 0);
    expect(find.byType(ReaderEnrichmentProgress), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a save opened already enriched shows everything at once', (
    tester,
  ) async {
    final database = _MemoryIsarService(
      _savedUrl()
        ..enrichmentJson = jsonEncode({
          'summary': 'A useful explanation.',
          'content_sections': [
            {
              'title': 'Context',
              'points': ['Source evidence.'],
            },
          ],
        }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarServiceProvider.overrideWithValue(database),
          urlDetailProvider(5).overrideWith((ref) async => database.url),
          tagOccurrenceMapProvider.overrideWithValue(const {}),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const UrlDetailScreen(urlId: 5),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final reveals = find.byType(EnrichmentReveal);
    expect(reveals, findsWidgets);
    for (final element in reveals.evaluate()) {
      expect(_veil(tester, find.byWidget(element.widget)), 0);
    }
  });
  testWidgets('the whole page is there while it opens', (tester) async {
    final database = _MemoryIsarService(
      _savedUrl()
        ..enrichmentJson = jsonEncode({
          'summary': 'A useful explanation.',
          'content_sections': [
            {
              'title': 'Context',
              'points': ['Source evidence.'],
            },
          ],
        }),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('list')),
        GoRoute(
          path: '/url',
          pageBuilder: (_, state) => CardOpenPage(
            key: state.pageKey,
            urlId: 5,
            child: const UrlDetailScreen(urlId: 5),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarServiceProvider.overrideWithValue(database),
          urlDetailProvider(5).overrideWith((ref) async => database.url),
          tagOccurrenceMapProvider.overrideWithValue(const {}),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    router.push('/url');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-open: built before the motion started, nothing arrives late.
    expect(find.text('A useful article'), findsOneWidget);
    expect(find.text('Context'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Context'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Details pager keeps one app bar still over the swipe', (
    tester,
  ) async {
    final saves = {
      5: _savedUrl()..title = 'First save',
      6: _savedUrl()
        ..id = 6
        ..title = 'Second save',
    };
    final database = _PagerIsarService(saves);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarServiceProvider.overrideWithValue(database),
          for (final entry in saves.entries)
            urlDetailProvider(
              entry.key,
            ).overrideWith((ref) async => entry.value),
          tagOccurrenceMapProvider.overrideWithValue(const {}),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const UrlDetailPagerScreen(urlIds: [5, 6], initialIndex: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = find.byType(AppBar);
    // One bar for the pager, none per page; the showing save's actions.
    expect(bar, findsOneWidget);
    expect(find.byTooltip('Add to collection'), findsOneWidget);
    final barRect = tester.getRect(bar);
    final titleStart = tester.getRect(find.text('First save')).left;

    // Below the photo, whose own swipes belong to its carousel.
    final gesture = await tester.startGesture(const Offset(200, 700));
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    expect(bar, findsOneWidget);
    expect(tester.getRect(bar), barRect);
    expect(tester.getRect(find.text('First save')).left, lessThan(titleStart));

    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(bar), barRect);
    expect(find.text('Second save'), findsOneWidget);
    expect(find.byTooltip('Add to collection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

double _veil(WidgetTester tester, Finder reveal) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: reveal,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.position == DecorationPosition.foreground,
          ),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color?.a ?? 0;
}

SavedUrl _savedUrl() => SavedUrl()
  ..id = 5
  ..rawUrl = 'https://example.com/article'
  ..domain = 'example.com'
  ..title = 'A useful article'
  ..description = 'A clear description.'
  ..category = 'Technology'
  ..categoryEmoji = '💻'
  ..categories = ['Technology']
  ..tags = <String>[]
  ..processingStatus = 'COMPLETED'
  ..savedAt = DateTime(2026, 8, 1);

class _MemoryIsarService implements IsarService {
  _MemoryIsarService(this.url);

  SavedUrl url;

  @override
  Future<SavedUrl?> getUrlById(int id) async => id == url.id ? url : null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected database call: ${invocation.memberName}',
    );
  }
}

class _PagerIsarService implements IsarService {
  _PagerIsarService(this.urls);

  final Map<int, SavedUrl> urls;

  @override
  Future<SavedUrl?> getUrlById(int id) async => urls[id];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected database call: ${invocation.memberName}',
    );
  }
}
