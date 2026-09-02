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
      messenger.setMockMethodCallHandler(channel, (_) async => null);
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

      final position = controller.position;
      final viewportHeight =
          (position.viewportDimension * tester.view.devicePixelRatio).round();
      final startFuture = callDart(const MethodCall('start'));
      await tester.pumpAndSettle();
      expect(await startFuture, isTrue);
      expect(viewportHeight, greaterThan(0));

      final captureFuture = callDart(
        MethodCall('capture', {
          'left': 0,
          'top': viewportHeight,
          'right': tester.view.physicalSize.width.round(),
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
      await tester.pumpAndSettle();
      await endFuture;
      expect(controller.offset, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      messenger.setMockMethodCallHandler(channel, null);
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
      expect(metrics['right'], tester.view.physicalSize.width);
      expect(
        metrics['bottom'],
        tester.view.physicalSize.height - 72 * tester.view.devicePixelRatio,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('keeps fixed shell overlays outside the moving viewport', (
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
            child: ScrollCaptureFixedOverlayScope(
              bottomObstruction: 152,
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
      final metrics = update.arguments! as Map<Object?, Object?>;
      const shellOverlayObstruction = 80.0 + 16.0 + 56.0;
      expect(
        metrics['viewportBottomInset'],
        shellOverlayObstruction * tester.view.devicePixelRatio,
      );
      expect(
        metrics['bottom'],
        tester.view.physicalSize.height -
            shellOverlayObstruction * tester.view.devicePixelRatio,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('refreshes the current route before the OEM proxy is armed', (
    tester,
  ) async {
    final nativeCalls = <MethodCall>[];
    final navigatorKey = GlobalKey<NavigatorState>();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      return null;
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => ScrollCaptureCoordinator(child: child!),
          home: ListView.builder(
            itemExtent: 100,
            itemCount: 100,
            itemBuilder: (context, index) => Text('Home $index'),
          ),
          routes: {
            '/details': (context) => ListView.builder(
              itemExtent: 100,
              itemCount: 20,
              itemBuilder: (context, index) => Text('Details $index'),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      final homeUpdate = nativeCalls.lastWhere(
        (call) => call.method == 'updateViewMetrics',
      );
      final homeMaximum =
          (homeUpdate.arguments! as Map<Object?, Object?>)['maximumOffset']
              as num;

      navigatorKey.currentState!.pushNamed('/details');
      await tester.pumpAndSettle();
      nativeCalls.clear();

      final prepare = callDart(const MethodCall('proxyPrepare'));
      for (var frame = 0; frame < 6; frame += 1) {
        await tester.pump();
      }
      expect(await prepare, isTrue);

      final detailsUpdate = nativeCalls.lastWhere(
        (call) => call.method == 'updateViewMetrics',
      );
      final detailsMaximum =
          (detailsUpdate.arguments! as Map<Object?, Object?>)['maximumOffset']
              as num;
      expect(detailsMaximum, lessThan(homeMaximum));
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

  testWidgets(
    'keeps Flutter chrome stable during OEM compatibility scrolling',
    (tester) async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
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

      final startFuture = callDart(const MethodCall('proxyPrepare'));
      await tester.pumpAndSettle();
      expect(await startFuture, isTrue);
      expect(find.text('idle'), findsOneWidget);

      final proxyScroll = callDart(
        MethodCall('proxyScrollTo', 300 * tester.view.devicePixelRatio),
      );
      for (var frame = 0; frame < 6; frame += 1) {
        await tester.pump();
      }
      expect(await proxyScroll, isTrue);
      expect(find.text('idle'), findsOneWidget);

      final endFuture = callDart(const MethodCall('end'));
      await tester.pumpAndSettle();
      await endFuture;
      expect(find.text('idle'), findsOneWidget);
      messenger.setMockMethodCallHandler(channel, null);
    },
  );

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
    final callbackDeclaration = bridge.indexOf('private val callback');
    final initializationBlock = bridge.indexOf('\n    init {');
    final activeSessionGuard = rootLayout.indexOf(
      'if (acceptsLongshotGestures) return',
    );
    final metricsAssignment = rootLayout.indexOf('metrics = value');
    final scrollChangedDeclaration = rootLayout.indexOf(
      'override fun onScrollChanged',
    );
    final dispatchDeclaration = rootLayout.indexOf(
      'private fun dispatchQueuedScrollRequest',
    );
    final scrollChangedBody = rootLayout.substring(
      scrollChangedDeclaration,
      dispatchDeclaration,
    );

    expect(
      bridge,
      contains('val target = layout.preferredScrollCaptureTarget()'),
    );
    expect(bridge, contains('layout.setScrollCaptureCallback(rootCallback)'));
    expect(bridge, contains('target.setScrollCaptureCallback(callback)'));
    expect(
      bridge,
      isNot(contains('window.registerScrollCaptureCallback(callback)')),
    );
    expect(bridge, contains('"proxyScrollTo"'));
    expect(bridge, contains('"proxyPrepare"'));
    expect(bridge, contains('"proxyScrollEnd"'));
    expect(rootLayout, contains('class ScrollCaptureProxyView'));
    expect(bridge, contains('PixelCopy.request('));
    expect(bridge, contains('session.positionInWindow'));
    expect(activity, contains('Build.VERSION_CODES.S'));
    expect(activity, contains('ScrollCaptureBridge('));
    expect(activity, contains('also { it.registerWhenReady() }'));
    expect(activity, contains('override fun provideRootLayout'));
    expect(activity, contains('attachRootLayout(it)'));
    expect(bridge, contains('fun attachRootLayout'));
    expect(rootLayout, contains('ScrollCaptureProxyView(context)'));
    expect(rootLayout, contains(': ScrollView(context)'));
    expect(bridge, contains('"updateViewMetrics"'));
    expect(bridge, contains('"resetProxy"'));
    expect(bridge, contains('this.rootLayout?.updateVerticalScrollMetrics('));
    expect(bridge, contains('this.rootLayout?.resetProxySession()'));
    expect(shell, contains('ScrollCaptureVisibilityScope('));
    expect(shell, contains('bottomObstruction:'));
    expect(rootLayout, contains('viewportBottomInset'));
    expect(rootLayout, contains('currentScrollCaptureBounds'));
    expect(rootLayout, contains('currentRootScrollCaptureBounds'));
    expect(bridge, contains('currentScrollCaptureBounds()'));
    expect(bridge, contains('currentRootScrollCaptureBounds()'));
    expect(bridge, isNot(contains('invokeMethod("getMetrics"')));
    expect(rootLayout, contains('dispatchQueuedScrollRequest'));
    expect(rootLayout, contains('ScrollCaptureImageMirrorView'));
    expect(rootLayout, contains('FlutterImageView'));
    expect(rootLayout, contains('TextureView'));
    expect(rootLayout, contains('updateImageMirror'));
    expect(rootLayout, isNot(contains('source.bitmap')));
    expect(rootLayout, isNot(contains('TextureView.draw')));
    expect(
      rootLayout,
      isNot(contains('scrollTo(0, target.coerceIn(0, maximumScrollY()))')),
    );
    expect(activity, contains('override fun getRenderMode()'));
    expect(activity, contains('RenderMode.image'));
    expect(rootLayout, contains('onWindowFocusChanged'));
    expect(rootLayout, contains('setOnProxySessionPreparing'));
    expect(rootLayout, contains('beginPreparedLongshotSession'));
    expect(rootLayout, contains('beginPotentialLongshotSession'));
    expect(rootLayout, contains('finishLongshotSession'));
    expect(rootLayout, contains('sessionGeneration'));
    expect(rootLayout, isNot(contains('SCROLL_CAPTURE_HINT_EXCLUDE')));
    expect(rootLayout, isNot(contains('POST_SCROLL_CAPTURE_DELAY_MS')));
    expect(bridge, contains('postOnAnimationDelayed'));
    expect(bridge, contains('onComplete(result == true)'));
    expect(bridge, contains('target.setScrollCaptureCallback(null)'));
    expect(bridge, contains('layout.setScrollCaptureCallback(null)'));
    expect(
      bridge,
      contains('target.scrollCaptureHint = View.SCROLL_CAPTURE_HINT_INCLUDE'),
    );
    expect(
      bridge,
      isNot(contains('View.SCROLL_CAPTURE_HINT_EXCLUDE_DESCENDANTS')),
    );
    expect(bridge, contains('isOplusFamilyDevice()'));
    expect(rootLayout, contains('getLocationInWindow(locationInWindow)'));
    expect(rootLayout, contains('bounds.intersect(viewportBounds)'));
    expect(callbackDeclaration, greaterThanOrEqualTo(0));
    expect(initializationBlock, greaterThan(callbackDeclaration));
    expect(activeSessionGuard, greaterThanOrEqualTo(0));
    expect(activeSessionGuard, lessThan(metricsAssignment));
    expect(scrollChangedBody, isNot(contains('updateScrollOffset(top)')));
    expect(rootLayout, contains('postOnAnimation(dispatchQueuedOnAnimation)'));
    expect(
      rootLayout,
      contains('newerTarget != null && newerTarget != target'),
    );
    expect(rootLayout, contains('dispatchScrollRequest(newerTarget)'));
    expect(rootLayout, contains('presentFlutterFrame(target)'));
    expect(
      rootLayout,
      contains('if (scrollProxy.isLongshotSessionActive) return'),
    );
    expect(rootLayout, contains('mirrorTop = target'));
    expect(rootLayout, contains('PixelCopy.request('));
    expect(rootLayout, contains('source.getBitmap(bitmap)'));
    expect(rootLayout, contains('displayedBitmap = bitmap'));
    expect(rootLayout, isNot(contains('acquireLatestImage()')));
    expect(rootLayout, isNot(contains('MAX_IMAGE_ACQUIRE_ATTEMPTS')));
  });
}
