import 'dart:io';
import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/engagement_event.dart';
import 'package:glimpse/core/models/place_itinerary.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/user_collection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Isar database;
  late IsarService service;

  setUpAll(() async {
    final pubCache =
        Platform.environment['PUB_CACHE'] ??
        (Platform.isWindows
            ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache'
            : '${Platform.environment['HOME']}/.pub-cache');
    final packageRoot =
        '$pubCache${Platform.pathSeparator}hosted${Platform.pathSeparator}pub.dev'
        '${Platform.pathSeparator}isar_flutter_libs-3.1.0+1';
    final libraryPath = Platform.isWindows
        ? '$packageRoot${Platform.pathSeparator}windows${Platform.pathSeparator}isar.dll'
        : Platform.isMacOS
        ? '$packageRoot${Platform.pathSeparator}macos${Platform.pathSeparator}libisar.dylib'
        : '$packageRoot${Platform.pathSeparator}linux${Platform.pathSeparator}libisar.so';
    await Isar.initializeIsarCore(libraries: {Abi.current(): libraryPath});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('glimpse-bin-test-');
    database = await Isar.open([
      SavedUrlSchema,
      UserCollectionSchema,
      EngagementEventSchema,
      PlaceItinerarySchema,
    ], directory: tempDirectory.path);
    service = IsarService();
    await service.ensureInitialized();
  });

  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'existing rows default to active and the schema indexes deletedAt',
    () async {
      final url = _url('https://example.com/old');
      await service.saveUrl(url);

      expect(url.deletedAt, isNull);
      expect(url.isInBin, isFalse);
      expect(await service.getAllUrls(), hasLength(1));
      expect(SavedUrlSchema.indexes, contains('deletedAt'));
    },
  );

  test(
    'move and direct restore preserve lifecycle and collection membership',
    () async {
      final originalSavedAt = DateTime.utc(2026, 1, 2);
      final url = _url('https://example.com/done', savedAt: originalSavedAt)
        ..intentStatus = 'done'
        ..intentAction = 'already_read';
      await service.saveUrl(url);
      final collection = await service.createCollection(
        name: 'Read',
        emoji: 'R',
      );
      await service.addUrlToCollection(
        collectionId: collection.id,
        urlId: url.id,
      );

      expect(await service.moveUrlToBin(url.id), isTrue);
      expect(await service.getAllUrls(), isEmpty);
      expect(await service.getArchivedUrls(), isEmpty);
      expect(await service.getUrlsInCollection(collection.id), isEmpty);
      expect((await service.getCollectionById(collection.id))!.urlIds, [
        url.id,
      ]);

      expect(await service.restoreUrlFromBin(url.id), isTrue);
      final restored = await service.getUrlById(url.id);
      expect(restored, isNotNull);
      expect(restored!.savedAt.isAtSameMomentAs(originalSavedAt), isTrue);
      expect(restored.isDone, isTrue);
      expect(await service.getUrlsInCollection(collection.id), hasLength(1));
    },
  );

  test(
    're-saving a binned URL reactivates the same record as recent',
    () async {
      final url = _url('https://example.com/resave')
        ..intentStatus = 'done'
        ..rediscoverDismissedAt = DateTime.utc(2026, 1, 3);
      await service.saveUrl(url);
      await service.moveUrlToBin(url.id);
      final resavedAt = DateTime.utc(2026, 2, 1);

      final restored = await service.resaveUrlFromBin(
        url.id,
        savedAt: resavedAt,
      );

      expect(restored!.id, url.id);
      expect(restored.savedAt, resavedAt);
      expect(restored.deletedAt, isNull);
      expect(restored.intentStatus, isNull);
      expect(restored.rediscoverDismissedAt, isNull);
      expect(await service.getAllUrls(), hasLength(1));
      expect((await service.findByRawUrl(url.rawUrl))!.id, restored.id);
    },
  );

  test('canonical URL index tracks saves and permanent deletion', () async {
    final first = _url('https://example.com/article?utm_source=share');
    await service.saveUrl(first);

    expect(
      (await service.findByRawUrl('https://example.com/article#notes'))!.id,
      first.id,
    );

    // Saving after the lazy index has been built must update the cache without
    // requiring another full-library scan.
    final second = _url('https://example.com/second?ref=share');
    await service.saveUrl(second);
    expect(
      (await service.findByRawUrl('https://example.com/second'))!.id,
      second.id,
    );

    await service.deleteUrlPermanently(first.id);
    expect(await service.findByRawUrl('https://example.com/article'), isNull);
  });

  test(
    '30-day purge expires the boundary and batch-cleans memberships',
    () async {
      final now = DateTime.utc(2026, 3, 31, 12);
      final expired = _url('https://example.com/expired');
      final retained = _url('https://example.com/retained');
      await service.saveUrl(expired);
      await service.saveUrl(retained);
      final collection = await service.createCollection(
        name: 'Saved',
        emoji: 'S',
      );
      await service.addUrlsToCollection(
        collectionId: collection.id,
        urlIds: [expired.id, retained.id],
      );
      await service.moveUrlToBin(
        expired.id,
        deletedAt: now.subtract(IsarService.binRetention),
      );
      await service.moveUrlToBin(
        retained.id,
        deletedAt: now
            .subtract(IsarService.binRetention)
            .add(const Duration(microseconds: 1)),
      );

      expect(await service.purgeExpiredBinItems(now: now), [expired.id]);
      expect(await service.getAnyUrlById(expired.id), isNull);
      expect(await service.getAnyUrlById(retained.id), isNotNull);
      expect((await service.getCollectionById(collection.id))!.urlIds, [
        retained.id,
      ]);
    },
  );
}

SavedUrl _url(String rawUrl, {DateTime? savedAt}) {
  return SavedUrl()
    ..rawUrl = rawUrl
    ..domain = Uri.parse(rawUrl).host
    ..title = 'Saved link'
    ..description = ''
    ..category = 'Other'
    ..categoryEmoji = 'O'
    ..categories = ['Other']
    ..tags = []
    ..savedAt = savedAt ?? DateTime.utc(2026, 1, 1);
}
