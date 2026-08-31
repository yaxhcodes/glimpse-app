import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/scroll_capture_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.shinrinyoku.glimpse/scroll_capture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<Object?> callDart(MethodCall call) async {
    final response = Completer<ByteData?>();
    unawaited(
      messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(call),
        response.complete,
      ),
    );
    final envelope = await response.future;
    return channel.codec.decodeEnvelope(envelope!);
  }

  testWidgets(
    'captures offscreen content and restores the original scroll offset',
    (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: ScrollCaptureCoordinator(
            child: Scaffold(
              body: ListView.builder(
                controller: controller,
                itemExtent: 100,
                itemCount: 30,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final metricsFuture = callDart(const MethodCall('getMetrics'));
      await tester.pump();
      await tester.pump();
      final metrics = await metricsFuture;
      expect(metrics, isA<Map<Object?, Object?>>());
      final bounds = metrics! as Map<Object?, Object?>;
      final viewportHeight =
          (bounds['bottom']! as num).round() - (bounds['top']! as num).round();
      expect(viewportHeight, greaterThan(0));
      expect(await callDart(const MethodCall('start')), isTrue);

      final captureFuture = callDart(
        MethodCall('capture', {
          'left': 0,
          'top': viewportHeight,
          'right': bounds['right'],
          'bottom': viewportHeight * 2,
        }),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      final capture = await captureFuture as Map<Object?, Object?>;

      expect(capture['top'], viewportHeight);
      expect(capture['bottom'], viewportHeight * 2);
      expect(capture['scrollDelta'], viewportHeight);
      expect(controller.offset, viewportHeight / tester.view.devicePixelRatio);

      final endFuture = callDart(const MethodCall('end'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await endFuture;
      expect(controller.offset, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('publishes active scroll metrics to the Android root view', (
    tester,
  ) async {
    final nativeCalls = <MethodCall>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      return null;
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: ScrollCaptureCoordinator(
            child: ScrollCaptureViewportScope(
              bottomObstruction: 72,
              child: ListView.builder(
                itemExtent: 100,
                itemCount: 30,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final update = nativeCalls.lastWhere(
        (call) => call.method == 'updateViewMetrics',
      );
      expect(nativeCalls.first.method, 'resetProxy');
      final metrics = update.arguments! as Map<Object?, Object?>;
      expect(metrics['minimumOffset'], 0);
      expect(metrics['maximumOffset'], greaterThan(0));
      expect(metrics['offset'], 0);
      expect(metrics['viewportDimension'], greaterThan(0));
      expect(metrics['viewportTopInset'], 0);
      expect(metrics['viewportBottomInset'], 72 * tester.view.devicePixelRatio);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('publishes the body top edge below fixed route chrome', (
    tester,
  ) async {
    final nativeCalls = <MethodCall>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      return null;
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: ScrollCaptureCoordinator(
            child: Scaffold(
              appBar: AppBar(title: const Text('Details')),
              body: ListView.builder(
                itemExtent: 100,
                itemCount: 30,
                itemBuilder: (context, index) => Text('Item $index'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final update = nativeCalls.lastWhere(
        (call) => call.method == 'updateViewMetrics',
      );
      final metrics = update.arguments! as Map<Object?, Object?>;
      expect(
        metrics['viewportTopInset'],
        kToolbarHeight * tester.view.devicePixelRatio,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('ignores mounted scrollables in inactive shell tabs', (
    tester,
  ) async {
    final inactiveController = ScrollController();
    final activeController = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: ScrollCaptureCoordinator(
          child: IndexedStack(
            index: 1,
            children: [
              ScrollCaptureVisibilityScope(
                isVisible: false,
                child: ListView.builder(
                  controller: inactiveController,
                  itemExtent: 100,
                  itemCount: 100,
                  itemBuilder: (context, index) => Text('Inactive $index'),
                ),
              ),
              ScrollCaptureVisibilityScope(
                isVisible: true,
                child: ListView.builder(
                  controller: activeController,
                  itemExtent: 100,
                  itemCount: 30,
                  itemBuilder: (context, index) => Text('Active $index'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final proxyScroll = callDart(
      MethodCall('proxyScrollTo', 300 * tester.view.devicePixelRatio),
    );
    for (var frame = 0; frame < 6; frame += 1) {
      await tester.pump();
    }

    expect(await proxyScroll, isTrue);
    expect(activeController.offset, 300);
    expect(inactiveController.offset, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    inactiveController.dispose();
    activeController.dispose();
  });

  testWidgets('resets the OEM proxy immediately when capture UI closes', (
    tester,
  ) async {
    final nativeCalls = <MethodCall>[];
    final controller = ScrollController();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      return null;
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: ScrollCaptureCoordinator(
            child: ListView.builder(
              controller: controller,
              itemExtent: 100,
              itemCount: 30,
              itemBuilder: (context, index) => Text('Item $index'),
            ),
          ),
        ),
      );
      await tester.pump();

      final proxyScroll = callDart(
        MethodCall('proxyScrollTo', 300 * tester.view.devicePixelRatio),
      );
      for (var frame = 0; frame < 6; frame += 1) {
        await tester.pump();
      }
      expect(await proxyScroll, isTrue);
      expect(controller.offset, 300);

      nativeCalls.clear();
      final proxyEnd = callDart(const MethodCall('proxyScrollEnd'));
      for (var frame = 0; frame < 8; frame += 1) {
        await tester.pump();
      }
      expect(await proxyEnd, isTrue);
      expect(controller.offset, 0);

      final update = nativeCalls.lastWhere(
        (call) => call.method == 'updateViewMetrics',
      );
      final metrics = update.arguments! as Map<Object?, Object?>;
      expect(metrics['offset'], 0);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('prefers the substantive range in a nested-scroll subtree', (
    tester,
  ) async {
    final contentController = ScrollController();
    final headerController = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: ScrollCaptureCoordinator(
          child: IndexedStack(
            children: [
              ListView.builder(
                controller: contentController,
                itemExtent: 100,
                itemCount: 40,
                itemBuilder: (context, index) => Text('Content $index'),
              ),
              ListView.builder(
                controller: headerController,
                itemExtent: 100,
                itemCount: 8,
                itemBuilder: (context, index) => Text('Header $index'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final proxyScroll = callDart(
      MethodCall('proxyScrollTo', 500 * tester.view.devicePixelRatio),
    );
    for (var frame = 0; frame < 6; frame += 1) {
      await tester.pump();
    }

    expect(await proxyScroll, isTrue);
    expect(contentController.offset, 500);
    expect(headerController.offset, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    contentController.dispose();
    headerController.dispose();
  });

  testWidgets('removes fixed chrome for search and restores it if OEM aborts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScrollCaptureCoordinator(
          child: Builder(
            builder: (context) => Stack(
              children: [
                ListView.builder(
                  itemExtent: 100,
                  itemCount: 30,
                  itemBuilder: (context, index) => Text('Item $index'),
                ),
                Text(
                  ScrollCaptureScope.isCapturingOf(context)
                      ? 'capturing'
                      : 'idle',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('idle'), findsOneWidget);

    final metricsFuture = callDart(const MethodCall('getMetrics'));
    await tester.pump();
    await tester.pump();
    expect(await metricsFuture, isNotNull);
    expect(find.text('capturing'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('idle'), findsOneWidget);
  });

  test('Android bridge exposes official and OEM-native scroll targets', () {
    final bridge = File(
      'android/app/src/main/kotlin/com/shinrinyoku/glimpse/'
      'ScrollCaptureBridge.kt',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/shinrinyoku/glimpse/MainActivity.kt',
    ).readAsStringSync();
    final shell = File('lib/features/shell/main_shell.dart').readAsStringSync();
    final rootLayout = File(
      'android/app/src/main/kotlin/com/shinrinyoku/glimpse/'
      'ScrollCaptureRootLayout.kt',
    ).readAsStringSync();

    expect(bridge, contains('window.registerScrollCaptureCallback(callback)'));
    expect(
      bridge,
      contains('window.unregisterScrollCaptureCallback(callback)'),
    );
    expect(bridge, contains('"proxyScrollTo"'));
    expect(bridge, contains('"proxyScrollEnd"'));
    expect(rootLayout, contains('class ScrollCaptureProxyView'));
    expect(bridge, contains('PixelCopy.request('));
    expect(bridge, contains('session.positionInWindow'));
    expect(activity, contains('Build.VERSION_CODES.S'));
    expect(activity, contains('ScrollCaptureBridge('));
    expect(activity, contains('override fun provideRootLayout'));
    expect(activity, contains('attachRootLayout(it)'));
    expect(bridge, contains('fun attachRootLayout'));
    expect(rootLayout, contains('ScrollCaptureProxyView(context)'));
    expect(rootLayout, contains(': ScrollView(context)'));
    expect(bridge, contains('"updateViewMetrics"'));
    expect(bridge, contains('"resetProxy"'));
    expect(shell, contains('ScrollCaptureVisibilityScope('));
    expect(shell, contains('bottomObstruction:'));
    expect(rootLayout, contains('viewportBottomInset'));
    expect(rootLayout, contains('dispatchQueuedScrollRequest'));
    expect(rootLayout, contains('onWindowFocusChanged'));
    expect(rootLayout, contains('finishLongshotSession'));
    expect(rootLayout, contains('sessionGeneration'));
    expect(rootLayout, contains('SCROLL_CAPTURE_HINT_EXCLUDE'));
    expect(rootLayout, contains('POST_SCROLL_CAPTURE_DELAY_MS'));
    expect(bridge, contains('postOnAnimationDelayed'));
    expect(bridge, contains('onComplete(result == true)'));
  });
}
