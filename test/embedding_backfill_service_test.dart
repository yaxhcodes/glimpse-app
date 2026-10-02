import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/services/embedding_backfill_service.dart';
import 'package:glimpse/core/services/embedding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedUrl _save(int id) => SavedUrl()
  ..id = id
  ..rawUrl = 'https://example.com/$id'
  ..domain = 'example.com'
  ..title = 'Save $id'
  ..description = ''
  ..category = 'Other'
  ..categoryEmoji = ''
  ..categories = ['Other']
  ..tags = []
  ..savedAt = DateTime(2026, 9, 1);

class _FakeIsar implements IsarService {
  _FakeIsar(this.missing);

  final List<SavedUrl> missing;
  final written = <int>[];

  @override
  Future<List<SavedUrl>> getUrlsWithoutEmbedding() async =>
      missing.where((u) => !written.contains(u.id)).toList();

  @override
  Future<void> updateEmbedding({
    required int id,
    required List<double> embedding,
  }) async => written.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Embeds every save except the ids in [rejects].
class _FakeEmbeddings extends EmbeddingService {
  _FakeEmbeddings({this.rejects = const {}});

  final Set<String> rejects;
  int calls = 0;
  final sent = <String>[];

  @override
  Future<List<List<double>>> generateEmbeddingsBatch(
    List<String> texts, {
    Object? inputType,
  }) async {
    calls++;
    sent.addAll(texts);
    return [
      for (final text in texts)
        rejects.any(text.contains) ? <double>[] : <double>[0.1, 0.2],
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a save that keeps failing is retried on a widening schedule', () async {
    final isar = _FakeIsar([_save(1), _save(2)]);
    final voyage = _FakeEmbeddings(rejects: {'Save 2'});
    var now = DateTime(2026, 10, 2, 9);
    final service = EmbeddingBackfillService(
      isarService: isar,
      embeddingService: voyage,
      now: () => now,
    );

    expect(await service.backfillIfNeeded(), 1);
    expect(isar.written, [1]);
    expect(voyage.calls, 1);

    // Next launches the same day: nothing is sent.
    now = now.add(const Duration(hours: 6));
    expect(await service.backfillIfNeeded(), 0);
    expect(voyage.calls, 1);

    // A day later it is tried again, then waits two days.
    now = now.add(const Duration(days: 1));
    await service.backfillIfNeeded();
    expect(voyage.calls, 2);
    now = now.add(const Duration(days: 1));
    await service.backfillIfNeeded();
    expect(voyage.calls, 2, reason: 'second failure waits 2 days');
    now = now.add(const Duration(days: 1));
    await service.backfillIfNeeded();
    expect(voyage.calls, 3);
  });

  test(
    'a save that embeds later is forgotten and new saves go straight through',
    () async {
      final isar = _FakeIsar([_save(1)]);
      var rejects = {'Save 1'};
      var now = DateTime(2026, 10, 2);
      final service = EmbeddingBackfillService(
        isarService: isar,
        embeddingService: _FakeEmbeddings(rejects: rejects),
        now: () => now,
      );
      await service.backfillIfNeeded();
      expect(isar.written, isEmpty);

      // The save is fixed (say, re-enriched) and its retry comes due.
      now = now.add(const Duration(days: 1));
      final fixed = EmbeddingBackfillService(
        isarService: isar,
        embeddingService: _FakeEmbeddings(rejects: rejects = {}),
        now: () => now,
      );
      expect(await fixed.backfillIfNeeded(), 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('embedding_backfill_attempts_v1'), isNull);

      isar.missing.add(_save(3));
      expect(
        await fixed.backfillIfNeeded(),
        1,
        reason: 'never failed, no wait',
      );
    },
  );
}
