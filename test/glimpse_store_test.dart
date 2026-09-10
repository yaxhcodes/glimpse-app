import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/engagement_event.dart';
import 'package:glimpse/core/models/glimpse_record.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/features/glimpses/glimpse.dart';
import 'package:glimpse/features/glimpses/glimpse_service.dart';
import 'package:glimpse/features/glimpses/glimpse_store.dart';

import 'glimpse_engine_test.dart' show candidate, save;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Isar database;
  late IsarService isar;
  late GlimpseStore store;

  setUpAll(() async {
    final cache =
        Platform.environment['PUB_CACHE'] ??
        (Platform.isWindows
            ? '${Platform.environment['LOCALAPPDATA']}/Pub/Cache'
            : '${Platform.environment['HOME']}/.pub-cache');
    final package = '$cache/hosted/pub.dev/isar_flutter_libs-3.1.0+1';
    final library = Platform.isWindows
        ? '$package/windows/isar.dll'
        : Platform.isMacOS
        ? '$package/macos/libisar.dylib'
        : '$package/linux/libisar.so';
    await Isar.initializeIsarCore(libraries: {Abi.current(): library});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('glimpse-engine-test-');
    database = await Isar.open([
      SavedUrlSchema,
      UserCollectionSchema,
      EngagementEventSchema,
      GlimpseRecordSchema,
    ], directory: directory.path);
    isar = IsarService();
    await isar.ensureInitialized();
    store = GlimpseStore(isar);
  });
  tearDown(() async {
    await database.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  test(
    'rebuilding preserves interaction state and invalidates edited synthesis',
    () async {
      final now = DateTime(2026, 9, 8, 19);
      final g = candidate();
      await store.reconcile([g], now);
      await store.mutate(g.key, (r) {
        r.retiredAt = now;
        r.synthesisKey = 'old';
        r.synthesisJson = '{}';
      });
      final changed = Glimpse.fromJson({...g.toJson(), 'evidence': [
        {...g.evidence.single.toJson(), 'text': 'A changed source excerpt with different evidence about decision making.'},
      ]});
      await store.reconcile([changed], now);
      final record = (await store.load()).single.record;
      expect(record.retiredAt, now);
      expect(record.synthesisJson, isNull);
    },
  );

  test(
    'two concurrent workers can reserve only one automatic delivery',
    () async {
      final now = DateTime(2026, 9, 8, 19);
      await store.reconcile([
        candidate(),
        candidate(key: 'idea:2', ids: [2]),
      ], now);
      final result = await Future.wait([
        store.claim('idea:1', now),
        store.claim('idea:2', now),
      ]);
      expect(result.where((r) => r), hasLength(1));
    },
  );

  test(
    'deleting a source removes its excerpts and cached explanation',
    () async {
      final g = candidate();
      await store.reconcile([g], DateTime(2026, 9, 8));
      await store.mutate(
        g.key,
        (r) => r.synthesisJson = 'private source content',
      );
      await store.removeSources({});
      expect(await store.load(), isEmpty);
    },
  );

  test(
    'Got it retires a glimpse without completing its saved sources',
    () async {
      final url = save(1, DateTime(2026, 8, 1));
      await isar.saveUrl(url);
      final g = candidate();
      await store.reconcile([g], DateTime.now());
      await GlimpseService(isar).act(g, GlimpseAction.gotIt);
      expect((await isar.getUrlById(1))!.intentStatus, isNull);
      expect((await store.load()).single.record.retiredAt, isNotNull);
    },
  );

  test(
    'replayed Later uses the original action time and does not dislike a topic',
    () async {
      final url = save(1, DateTime(2026, 8, 1));
      await isar.saveUrl(url);
      final g = candidate();
      final at = DateTime(2026, 9, 8, 19);
      await store.reconcile([g], at);
      final service = GlimpseService(isar);
      await service.act(g, GlimpseAction.later, at: at);
      await service.act(g, GlimpseAction.later, at: at);
      expect(
        (await store.load()).single.record.snoozedUntil,
        at.add(const Duration(days: 3)),
      );
      final events = await isar.recentEvents();
      expect(
        events.where((e) => e.type == EngagementEventType.cardSnoozed),
        hasLength(1),
      );
      expect(
        events.where((e) => e.type == EngagementEventType.cardDismissed),
        isEmpty,
      );
    },
  );

  test('Done completes only an explicit single-source intention', () async {
    await isar.saveUrl(save(1, DateTime(2026, 8, 1))..intentStatus = 'queued');
    await isar.saveUrl(save(2, DateTime(2026, 8, 1)));
    final g = candidate(kind: GlimpseKind.intention);
    await store.reconcile([g], DateTime.now());
    await GlimpseService(isar).act(g, GlimpseAction.done);
    expect((await isar.getUrlById(1))!.isDone, isTrue);
    expect((await isar.getUrlById(2))!.isDone, isFalse);
  });
}
