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
