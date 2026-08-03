import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/backup/backup_models.dart';
import 'package:glimpse/core/services/backup/backup_service.dart';

void main() {
  final service = BackupService(isarService: _UnusedIsarService());

  test('version 3 round-trip preserves current saved-link state', () {
    final savedAt = DateTime.utc(2026, 7, 1);
    final processingUpdatedAt = DateTime.utc(2026, 7, 2);
    final dismissedAt = DateTime.utc(2026, 7, 3);
    final intentSetAt = DateTime.utc(2026, 7, 4);
    final revisitAfter = DateTime.utc(2026, 7, 8);

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

    expect(BackupData.currentVersion, 3);
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
}

class _UnusedIsarService implements IsarService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Database access is not expected in this test.');
  }
}
