import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/user_collection.dart';
import 'package:glimpse/core/models/place_itinerary.dart';
import 'package:glimpse/core/services/backup/backup_models.dart';
import 'package:glimpse/core/services/backup/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('version 4 backup data round-trips place itineraries', () {
    final backup = BackupData(
      version: 4,
      createdAt: DateTime(2026, 8, 10).toIso8601String(),
      appVersion: '1.0.0',
      links: const [],
      collections: const [],
      placeItineraries: [
        PlaceItineraryBackup(
          name: 'A day in Kyoto',
          areaKey: 'kyoto|japan',
          areaTitle: 'Kyoto',
          country: 'Japan',
          createdAt: DateTime(2026, 8, 10).toIso8601String(),
          updatedAt: DateTime(2026, 8, 10).toIso8601String(),
          stops: const [
            PlaceItineraryStopBackup(
              entityKey: 'place:1',
              provisionalKey: 'place:kinkakuji|kyoto|japan',
              title: 'Kinkaku-ji',
              latitude: 35.0394,
              longitude: 135.7292,
            ),
          ],
        ),
      ],
      saveSessions: const [],
      settings: SettingsBackup(),
    );

    final restored = BackupData.fromJson(backup.toJson());

    expect(restored.version, 4);
    expect(restored.placeItineraries.single.name, 'A day in Kyoto');
    expect(restored.placeItineraries.single.stops.single.title, 'Kinkaku-ji');
  });

  final service = BackupService(isarService: _UnusedIsarService());

  test('current-version round-trip preserves current saved-link state', () {
    final savedAt = DateTime.utc(2026, 7, 1);
    final processingUpdatedAt = DateTime.utc(2026, 7, 2);
    final dismissedAt = DateTime.utc(2026, 7, 3);
    final intentSetAt = DateTime.utc(2026, 7, 4);
    final revisitAfter = DateTime.utc(2026, 7, 8);
    final deletedAt = DateTime.utc(2026, 7, 9);

    final original = SavedUrl()
      ..rawUrl = 'https://example.com/article'
      ..domain = 'example.com'
      ..title = 'Example article'
      ..description = 'Description'
      ..category = 'Technology'
      ..categoryEmoji = '💻'
      ..categories = ['Technology']
      ..tags = ['flutter']
      ..savedAt = savedAt
      ..deletedAt = deletedAt
      ..processingStatus = 'COMPLETED'
      ..processingId = 'process-1'
      ..processingAttempt = 2
      ..processingUpdatedAt = processingUpdatedAt
      ..processingError = 'previous_attempt_failed'
      ..rediscoverDismissedAt = dismissedAt
      ..intentStatus = 'queued'
      ..intentAction = 'read_later'
      ..intentSetAt = intentSetAt
      ..revisitAfter = revisitAfter
      ..askNotes = [
        SavedAskNote()
          ..id = 'ask-1'
          ..sourceMessageId = 'message-1'
          ..question = 'Why did this matter?'
          ..body = 'Because it explains the tradeoff clearly.'
          ..createdAt = DateTime.utc(2026, 7, 5),
      ];

    final json = service.toBackup(original).toJson();
    final restored = service.fromBackup(SavedUrlBackup.fromJson(json));

    expect(BackupData.currentVersion, 5);
    expect(restored.deletedAt, deletedAt);
    expect(restored.processingStatus, original.processingStatus);
    expect(restored.processingId, original.processingId);
    expect(restored.processingAttempt, original.processingAttempt);
    expect(restored.processingUpdatedAt, processingUpdatedAt);
    expect(restored.processingError, original.processingError);
    expect(restored.rediscoverDismissedAt, dismissedAt);
    expect(restored.intentStatus, original.intentStatus);
    expect(restored.intentAction, original.intentAction);
    expect(restored.intentSetAt, intentSetAt);
    expect(restored.revisitAfter, revisitAfter);
    expect(restored.askNotes, hasLength(1));
    expect(restored.askNotes.single.id, 'ask-1');
    expect(restored.askNotes.single.sourceMessageId, 'message-1');
    expect(restored.askNotes.single.question, 'Why did this matter?');
  });

  test(
    'version 1 backups remain valid and restore with optional state null',
    () async {
      final backup = await service.validateBackup(
        jsonEncode({
          'version': 1,
          'createdAt': '2026-07-31T16:25:08.256634',
          'appVersion': '1.0.7-dev',
          'links': [
            {
              'rawUrl': 'https://example.com/legacy',
              'domain': 'example.com',
              'title': 'Legacy link',
              'description': '',
              'category': 'Other',
              'categoryEmoji': '🔖',
              'categories': ['Other'],
              'tags': <String>[],
              'savedAt': '2026-07-01T10:00:00.000',
            },
          ],
          'collections': <Object>[],
          'saveSessions': <Object>[],
          'settings': <String, Object>{},
        }),
      );

      expect(backup.version, 1);
      expect(backup.links.single.intentStatus, isNull);
      expect(backup.links.single.processingStatus, isNull);
      expect(backup.links.single.deletedAt, isNull);
    },
  );

  test('validation rejects overlapping duplicate link records', () async {
    final link = {
      'rawUrl': 'https://example.com/duplicate',
      'domain': 'example.com',
      'title': 'Duplicate link',
      'description': '',
      'savedAt': '2026-07-01T10:00:00.000',
    };

    expect(
      () => service.validateBackup(
        jsonEncode({
          'version': BackupData.currentVersion,
          'createdAt': '2026-07-31T16:25:08.256634',
          'appVersion': '1.0.7',
          'links': [link, link],
          'collections': <Object>[],
          'saveSessions': <Object>[],
          'settings': <String, Object>{},
        }),
      ),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.message,
          'message',
          contains('same link appears more than once'),
        ),
      ),
    );
  });

  test('validation rejects collection references to missing links', () async {
    expect(
      () => service.validateBackup(
        jsonEncode({
          'version': BackupData.currentVersion,
          'createdAt': '2026-07-31T16:25:08.256634',
          'appVersion': '1.0.7',
          'links': <Object>[],
          'collections': [
            {
              'name': 'Reading',
              'emoji': '📚',
              'createdAt': '2026-07-01T10:00:00.000',
              'linkUrls': ['https://example.com/missing'],
            },
          ],
          'saveSessions': <Object>[],
          'settings': <String, Object>{},
        }),
      ),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.message,
          'message',
          contains('refers to a missing link'),
        ),
      ),
    );
  });

  test('merge never moves an active local link into Bin', () async {
    final local = _backupTestUrl()..deletedAt = null;
    final incoming = _backupTestUrl()..deletedAt = DateTime.utc(2026, 8, 1);
    final database = _MemoryBackupIsarService(local);
    final backupService = BackupService(isarService: database);

    await backupService.restoreBackup(
      _singleLinkBackup(backupService.toBackup(incoming)),
      RestoreMode.merge,
    );

    expect(database.url.deletedAt, isNull);
  });

  test('merge restores a local binned link when backup is active', () async {
    final local = _backupTestUrl()..deletedAt = DateTime.utc(2026, 8, 1);
    final incoming = _backupTestUrl()..deletedAt = null;
    final database = _MemoryBackupIsarService(local);
    final backupService = BackupService(isarService: database);

    await backupService.restoreBackup(
      _singleLinkBackup(backupService.toBackup(incoming)),
      RestoreMode.merge,
    );

    expect(database.url.deletedAt, isNull);
  });
}

SavedUrl _backupTestUrl() => SavedUrl()
  ..id = 7
  ..rawUrl = 'https://example.com/merge'
  ..domain = 'example.com'
  ..title = 'Merge link'
  ..description = ''
  ..category = 'Other'
  ..categoryEmoji = 'O'
  ..categories = ['Other']
  ..tags = []
  ..savedAt = DateTime.utc(2026, 7, 1);

BackupData _singleLinkBackup(SavedUrlBackup link) => BackupData(
  createdAt: DateTime.utc(2026, 8, 2).toIso8601String(),
  appVersion: '1.0.0',
  links: [link],
  collections: const [],
  saveSessions: const [],
  settings: SettingsBackup(),
);

class _UnusedIsarService implements IsarService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Database access is not expected in this test.');
  }
}

class _MemoryBackupIsarService implements IsarService {
  _MemoryBackupIsarService(this.url);

  SavedUrl url;

  @override
  Future<List<SavedUrl>> getAllUrlsIncludingBin() async => [url];

  @override
  Future<List<UserCollection>> getAllCollections() async => const [];

  @override
  Future<List<PlaceItinerary>> getAllPlaceItineraries() async => const [];

  @override
  Future<void> updateUrl(SavedUrl updated) async {
    url = updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      '${invocation.memberName} is not used in this test.',
    );
  }
}
