import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/shared/widgets/startup_reveal.dart';
import 'package:glimpse/shared/widgets/startup_mascot.dart';

void main() {
  testWidgets('mascot begins tucked and rises without dipping first', (
    tester,
  ) async {
    var previousOffset = double.infinity;
    for (final progress in [0.0, 0.1, 0.25, 0.4, 0.65, 0.8, 1.0]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.square(
            dimension: StartupMascot.size,
            child: StartupMascot(progress: progress),
          ),
        ),
      );
      final transform = tester.widget<Transform>(find.byType(Transform));
      final offset = transform.transform.getTranslation().y;
      if (progress == 0) expect(offset, greaterThan(0));
      expect(offset, lessThanOrEqualTo(previousOffset));
      expect(offset, greaterThanOrEqualTo(0));
      previousOffset = offset;
    }
    expect(previousOffset, 0);
    expect(tester.takeException(), isNull);
  });

  group('splash geometry matches the system splash', () {
    test('Android 12+ hidden gesture bar: branding 60dp from the edge', () {
      final g = StartupReveal.splashGeometry(
        edgeToEdgeSplash: true,
        viewHeight: 941,
        screenHeight: 941,
        bottomPadding: 0,
      );
      expect(g.overhang, 0);
      expect(g.brandingBottom, 60);
    });

    test('Android 15+ edge to edge ignores the nav bar padding', () {
      final g = StartupReveal.splashGeometry(
        edgeToEdgeSplash: true,
        viewHeight: 915,
        screenHeight: 915,
        bottomPadding: 48,
      );
      expect(g.overhang, 0);
      expect(g.brandingBottom, 60);
    });

    test('Android 12-14 nav bar: overlay reaches under it', () {
      final g = StartupReveal.splashGeometry(
        edgeToEdgeSplash: true,
        viewHeight: 867,
        screenHeight: 915,
        bottomPadding: 0,
      );
      expect(g.overhang, 48);
      expect(g.brandingBottom, 60);
    });

    test('short windows shrink, then hide, the branding like AOSP', () {
      final short = StartupReveal.splashGeometry(
        edgeToEdgeSplash: true,
        viewHeight: 411,
        screenHeight: 411,
        bottomPadding: 0,
      );
      expect(short.brandingBottom, closeTo(14.75, 0.01));
      final tiny = StartupReveal.splashGeometry(
        edgeToEdgeSplash: true,
        viewHeight: 300,
        screenHeight: 300,
        bottomPadding: 0,
      );
      expect(tiny.brandingBottom, isNull);
    });

    test('pre-12 launch background keeps 40dp above the nav bar', () {
      final g = StartupReveal.splashGeometry(
        edgeToEdgeSplash: false,
        viewHeight: 867,
        screenHeight: 915,
        bottomPadding: 0,
      );
      expect(g.overhang, 0);
      expect(g.brandingBottom, 40);
    });
  });

  testWidgets('keeps the destination mounted and plays only once', (
    tester,
  ) async {
    var prepared = 0;
    var mounts = 0;
    var ready = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return StartupReveal(
              ready: ready,
              onPrepared: () => prepared++,
              child: _Destination(onMount: () => mounts++),
            );
          },
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(mounts, 1);
    expect(prepared, 0);
    update(() => ready = true);
    await tester.pumpAndSettle();
    expect(prepared, 1);
    expect(mounts, 1);
    expect(find.byType(ClipPath), findsNothing);
    update(() {});
    await tester.pumpAndSettle();
    expect(prepared, 1);
    expect(mounts, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion skips the reveal without holding startup', (
    tester,
  ) async {
    var prepared = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StartupReveal(
            ready: true,
            onPrepared: () => prepared++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(prepared, 1);
    expect(find.byType(ClipPath), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Destination extends StatefulWidget {
  const _Destination({required this.onMount});
  final VoidCallback onMount;
  @override
  State<_Destination> createState() => _DestinationState();
}

class _DestinationState extends State<_Destination> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
