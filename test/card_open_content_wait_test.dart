import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/widgets/card_open_transition.dart';
import 'package:go_router/go_router.dart';

class _LoadingPage extends StatefulWidget {
  const _LoadingPage({required this.content});

  final Future<String> content;

  @override
  State<_LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<_LoadingPage> {
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    CardOpenRoute.waitForContent(context, widget.content);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FutureBuilder<String>(
      future: widget.content,
      builder: (context, snapshot) => Text(snapshot.data ?? 'loading'),
    ),
  );
}

void main() {
  const cardRect = Rect.fromLTWH(16, 300, 368, 92);

  Future<GoRouter> pumpApp(WidgetTester tester, Future<String> content) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Stack(
              children: [
                Positioned.fromRect(
                  rect: cardRect,
                  child: CardOpenOrigin(
                    child: GestureDetector(
                      onTap: () => context.push('/page'),
                      child: const ColoredBox(
                        color: Colors.teal,
                        child: Center(child: Text('card')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/page',
          pageBuilder: (context, state) => CardOpenPage(
            key: state.pageKey,
            child: _LoadingPage(content: content),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    return router;
  }

  Rect window(WidgetTester tester, String text) => tester.getRect(
    find.ancestor(of: find.text(text), matching: find.byType(ClipRRect)).first,
  );

  testWidgets('the card holds until the page has its content', (tester) async {
    final content = Completer<String>();
    await pumpApp(tester, content.future);

    await tester.tap(find.text('card'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Still waiting: opened in place, not moving.
    expect(window(tester, 'loading'), cardRect);

    content.complete('the list');
    await tester.pump();
    await tester.pump();
    expect(window(tester, 'the list'), cardRect);
    await tester.pump(const Duration(milliseconds: 80));
    // Built and painted under the card, then off it goes.
    expect(window(tester, 'the list').height, greaterThan(cardRect.height));

    await tester.pumpAndSettle();
    expect(find.text('the list'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a slow load doesn\'t hold the card for long', (tester) async {
    final never = Completer<String>();
    await pumpApp(tester, never.future);

    await tester.tap(find.text('card'));
    await tester.pump();
    await tester.pump();
    // The wait runs out at 200ms; a frame to paint, then it opens anyway.
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 80));
    expect(window(tester, 'loading').height, greaterThan(cardRect.height));

    await tester.pumpAndSettle();
    expect(find.text('loading'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
