import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/ask/ask_greeting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimeBucket mapping', () {
    Future<TimeBucket> _bucketAt(int hour, [int minute = 0]) async {
      final service = AskGreetingService(
        now: DateTime(2024, 1, 1, hour, minute),
        store: MemoryGreetingStore(),
      );
      final greeting = await service.build(savedUrlCount: 5);
      return greeting.phase;
    }

    test('lateNight covers 00:00–04:59', () async {
      expect(await _bucketAt(0), TimeBucket.lateNight);
      expect(await _bucketAt(4, 59), TimeBucket.lateNight);
    });

    test('earlyMorning covers 05:00–07:59', () async {
      expect(await _bucketAt(5), TimeBucket.earlyMorning);
      expect(await _bucketAt(7, 59), TimeBucket.earlyMorning);
    });

    test('morning covers 08:00–11:59', () async {
      expect(await _bucketAt(8), TimeBucket.morning);
      expect(await _bucketAt(11, 59), TimeBucket.morning);
    });

    test('afternoon covers 12:00–15:59', () async {
      expect(await _bucketAt(12), TimeBucket.afternoon);
      expect(await _bucketAt(15, 59), TimeBucket.afternoon);
    });

    test('evening covers 16:00–18:59', () async {
      expect(await _bucketAt(16), TimeBucket.evening);
      expect(await _bucketAt(18, 59), TimeBucket.evening);
    });

    test('night covers 19:00–22:29', () async {
      expect(await _bucketAt(19), TimeBucket.night);
      expect(await _bucketAt(22, 29), TimeBucket.night);
    });

    test('lateNight covers 22:30–23:59', () async {
      expect(await _bucketAt(22, 30), TimeBucket.lateNight);
      expect(await _bucketAt(23, 59), TimeBucket.lateNight);
    });
  });

  group('AskGreetingService behaviour', () {
    test('newcomer shows hint', () async {
      final service = AskGreetingService(
        now: DateTime(2024, 1, 1, 10),
        store: MemoryGreetingStore(),
      );
      final greeting = await service.build(savedUrlCount: 0);
      expect(greeting.context, UserContext.newcomer);
      expect(greeting.hint, 'Save your first link');
    });

    test('appends name on first session of day', () async {
      final store = MemoryGreetingStore();
      await store.record(DateTime(2024, 1, 1, 9), 'Morning');

      final service = AskGreetingService(
        now: DateTime(2024, 1, 2, 10), // next day
        random: Random(1), // seed: picks eligible greeting + nextDouble < 0.35
        store: store,
      );
      final greeting = await service.build(
        savedUrlCount: 5,
        userName: 'Alex',
      );
      expect(greeting.line, contains('Alex'));
      expect(greeting.line, endsWith('.'));
    });

    test('does not append name to stylized greetings', () async {
      final service = AskGreetingService(
        now: DateTime(2024, 1, 1, 2),
        random: Random(42),
        store: MemoryGreetingStore(),
      );
      final greeting = await service.build(
        savedUrlCount: 5,
        userName: 'Alex',
      );
      expect(greeting.phase, TimeBucket.lateNight);
      expect(greeting.line, isNot(contains('Alex')));
    });

    test('avoids repeating the last greeting', () async {
      for (var i = 0; i < 20; i++) {
        final store = MemoryGreetingStore();
        await store.record(DateTime(2024, 1, 1, 9), 'Good morning');

        final service = AskGreetingService(
          now: DateTime(2024, 1, 1, 10),
          random: Random(i),
          store: store,
        );
        final greeting = await service.build(savedUrlCount: 5);
        expect(greeting.line, isNot('Good morning.'));
      }
    });

    test('varies greeting across a full day', () async {
      final lines = <String>{};
      final phases = <TimeBucket>{};

      for (var h = 0; h < 24; h++) {
        final service = AskGreetingService(
          now: DateTime(2024, 1, 1, h),
          random: Random(h),
          store: MemoryGreetingStore(),
        );
        final greeting = await service.build(savedUrlCount: 5);
        lines.add(greeting.line);
        phases.add(greeting.phase);
      }

      expect(phases.length, greaterThanOrEqualTo(4));
      expect(lines.length, greaterThan(1));
    });

    test('no name for active user on same day', () async {
      final store = MemoryGreetingStore();
      await store.record(DateTime(2024, 1, 1, 8), 'Morning');

      final service = AskGreetingService(
        now: DateTime(2024, 1, 1, 10),
        random: Random(0),
        store: store,
      );
      final greeting = await service.build(
        savedUrlCount: 5,
        userName: 'Alex',
      );
      expect(greeting.context, UserContext.active);
      expect(greeting.line, isNot(contains('Alex')));
    });
  });
}
