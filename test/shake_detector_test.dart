import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/shake_detector.dart';

void main() {
  final t0 = DateTime(2026, 10, 2, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  /// Samples every 20 ms (sensor game rate) with [peaks] at the given times.
  List<bool> feed(
    ShakeDetector detector, {
    required int durationMs,
    required double base,
    Map<int, double> peaks = const {},
  }) {
    final fired = <bool>[];
    for (var ms = 0; ms <= durationMs; ms += 20) {
      final value = peaks[ms] ?? base;
      fired.add(detector.add(value, 0, 0, at(ms)));
    }
    return fired;
  }

  test('a firm back-and-forth fires once', () {
    final detector = ShakeDetector();
    final fired = feed(
      detector,
      durationMs: 1000,
      base: 2,
      peaks: {200: 28, 220: 30, 400: -27, 600: 29},
    );
    expect(fired.where((f) => f), hasLength(1));
  });

  test('walking, running and a bumpy ride never fire', () {
    expect(
      feed(ShakeDetector(), durationMs: 10000, base: 5).contains(true),
      isFalse,
      reason: 'walking',
    );
    final bumpy = {for (var ms = 0; ms <= 10000; ms += 300) ms: 15.0};
    expect(
      feed(
        ShakeDetector(),
        durationMs: 10000,
        base: 3,
        peaks: bumpy,
      ).contains(true),
      isFalse,
      reason: 'a car on a bad road stays under the threshold',
    );
  });

  test(
    'one hard jolt, like dropping the phone onto a table, does not fire',
    () {
      final fired = feed(
        ShakeDetector(),
        durationMs: 2000,
        base: 1,
        peaks: {500: 40, 520: 38, 540: 35},
      );
      expect(fired.contains(true), isFalse);
    },
  );

  test('peaks spread too far apart do not add up', () {
    final fired = feed(
      ShakeDetector(),
      durationMs: 5000,
      base: 1,
      peaks: {0: 30, 1500: 30, 3000: 30, 4500: 30},
    );
    expect(fired.contains(true), isFalse);
  });

  test('stays quiet during the cooldown, then can fire again', () {
    final detector = ShakeDetector();
    expect(detector.add(30, 0, 0, at(0)), isFalse);
    expect(detector.add(30, 0, 0, at(200)), isFalse);
    expect(detector.add(30, 0, 0, at(400)), isTrue);
    for (var ms = 600; ms < 3400; ms += 200) {
      expect(detector.add(30, 0, 0, at(ms)), isFalse, reason: '$ms ms');
    }
    expect(detector.add(30, 0, 0, at(3600)), isFalse);
    expect(detector.add(30, 0, 0, at(3800)), isFalse);
    expect(detector.add(30, 0, 0, at(4000)), isTrue);
  });
}
