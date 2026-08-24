import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/database/isar_service.dart';
import 'package:glimpse/core/models/saved_url.dart';
import 'package:glimpse/core/models/url_processing_status.dart';
import 'package:glimpse/core/services/url_enrichment_job.dart';

void main() {
  test('enrichment job round-trips through WorkManager input data', () {
    const job = UrlEnrichmentJob(
      savedUrlId: 42,
      processingId: 'processing-42',
      outputLocale: 'pt-BR',
      notifyOnCompletion: true,
      evaluateNavigationDiscovery: true,
      isPro: true,
    );

    final decoded = UrlEnrichmentJob.fromInputData(job.toInputData());

    expect(decoded, isNotNull);
    expect(decoded!.savedUrlId, 42);
    expect(decoded.processingId, 'processing-42');
    expect(decoded.outputLocale, 'pt-BR');
    expect(decoded.notifyOnCompletion, isTrue);
    expect(decoded.evaluateNavigationDiscovery, isTrue);
    expect(decoded.isPro, isTrue);
    expect(decoded.uniqueWorkName, 'glimpse_url_enrichment_42');
  });

  test('invalid enrichment job input is rejected', () {
    expect(UrlEnrichmentJob.fromInputData(null), isNull);
    expect(UrlEnrichmentJob.fromInputData({'savedUrlId': 0}), isNull);
  });

  test('durable recovery waits for the retained app-process attempt', () {
    expect(UrlEnrichmentScheduler.recoveryDelay, const Duration(minutes: 2));
  });

  test('startup recovery schedules only old queued work', () async {
    final now = DateTime(2026, 8, 24, 10);
    final oldQueued = SavedUrl()
      ..id = 42
      ..rawUrl = 'https://example.com/old'
      ..savedAt = now.subtract(const Duration(minutes: 5))
      ..processingStatus = UrlProcessingStatus.queued
      ..processingId = 'processing-42'
      ..processingUpdatedAt = now.subtract(const Duration(minutes: 5));
    final freshQueued = SavedUrl()
      ..id = 43
      ..rawUrl = 'https://example.com/fresh'
      ..savedAt = now
      ..processingStatus = UrlProcessingStatus.queued
      ..processingId = 'processing-43'
      ..processingUpdatedAt = now;
    final completed = SavedUrl()
      ..id = 44
      ..rawUrl = 'https://example.com/done'
      ..savedAt = now.subtract(const Duration(days: 1))
      ..processingStatus = UrlProcessingStatus.completed
      ..processingUpdatedAt = now.subtract(const Duration(days: 1));
    final scheduled = <UrlEnrichmentJob>[];

    final count = await UrlEnrichmentScheduler.recoverPending(
      _FakeIsarService([oldQueued, freshQueued, completed]),
      currentTime: now,
      outputLocale: 'en',
      isPro: false,
      scheduleJob: (job) async {
        scheduled.add(job);
        return true;
      },
    );

    expect(count, 1);
    expect(scheduled.single.savedUrlId, 42);
    expect(scheduled.single.processingId, 'processing-42');
    expect(scheduled.single.notifyOnCompletion, isFalse);
    expect(scheduled.single.evaluateNavigationDiscovery, isFalse);
  });
}

class _FakeIsarService implements IsarService {
  const _FakeIsarService(this.urls);

  final List<SavedUrl> urls;

  @override
  Future<List<SavedUrl>> getAllUrls() async => urls;

  @override
  Future<void> updateUrl(SavedUrl url) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected Isar call: ${invocation.memberName}');
  }
}
