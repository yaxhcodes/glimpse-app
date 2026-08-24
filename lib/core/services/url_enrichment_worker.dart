import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_environment.dart';
import '../database/isar_service.dart';
import '../models/url_processing_status.dart';
import '../providers/service_providers.dart';
import '../../features/rediscover/rediscover_topic_pulse_provider.dart';
import '../../features/shell/navigation_discovery_provider.dart';
import 'ai/app_attestation_service.dart';
import 'ai_proxy_config.dart';
import 'digest_notifications.dart';
import 'entitlement_service.dart';
import 'rediscover_utility_profile.dart';
import 'supabase_auth_service.dart';
import 'url_enrichment_job.dart';
import 'url_enrichment_notification_guard.dart';
import 'url_save_notifications.dart';

class UrlEnrichmentWorker {
  UrlEnrichmentWorker._();

  static const _attemptKeyPrefix = 'url_enrichment_worker_attempt_';
  static const _aiLimitKeyPrefix = 'url_enrichment_ai_limit_';
  static const _maxWorkerAttempts = 2;

  static Future<bool> run(UrlEnrichmentJob job) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final attemptKey = '$_attemptKeyPrefix${job.processingId}';
    final attempt = (preferences.getInt(attemptKey) ?? 0) + 1;
    await preferences.setInt(attemptKey, attempt);

    try {
      final result = await _runOnce(job);
      await preferences.remove(attemptKey);
      developer.log(
        'Background enrichment ${result.outcome.name} for ${job.savedUrlId}.',
        name: 'UrlEnrichmentWorker',
      );
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Background enrichment worker attempt $attempt failed for '
        '${job.savedUrlId}.',
        name: 'UrlEnrichmentWorker',
        error: error,
        stackTrace: stackTrace,
      );
      if (attempt < _maxWorkerAttempts) return false;

      await preferences.remove(attemptKey);
      await _markWorkerFailure(job);
      return true;
    }
  }

  static Future<UrlEnrichmentResult> _runOnce(UrlEnrichmentJob job) async {
    await Future.wait([
      AppEnvironment.initPackageInfo(),
      AiProxyConfig.initUserId(),
      SupabaseAuthService.initializeSupabaseClient(),
    ]);
    await AppAttestationService.initialize();
    await DigestNotifications.initForBackground();

    final isarService = IsarService();
    await isarService.ensureInitialized();
    final existing = await isarService.getUrlById(job.savedUrlId);
    if (existing == null || existing.isInBin) {
      return const UrlEnrichmentResult(
        outcome: UrlEnrichmentTerminalOutcome.missing,
      );
    }
    final shouldNotify = await UrlEnrichmentNotificationGuard.shouldDeliverFor(
      job.processingId,
      notifyOnCompletion: job.notifyOnCompletion,
    );

    final container = ProviderContainer(
      overrides: [
        isarServiceProvider.overrideWithValue(isarService),
        isProUserProvider.overrideWithValue(job.isPro),
      ],
    );
    try {
      if (UrlProcessingStatus.isSuccessfulTerminal(existing.processingStatus)) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.reload();
        final aiLimitReached =
            preferences.getBool('$_aiLimitKeyPrefix${job.processingId}') ??
            false;
        if (shouldNotify) {
          await UrlEnrichmentNotificationGuard.deliverOnce(
            job.processingId,
            aiLimitReached
                ? UrlEnrichmentNotificationOutcome.aiLimitReached
                : UrlEnrichmentNotificationOutcome.ready,
            () => aiLimitReached
                ? UrlSaveNotifications.showAiLimitReached(
                    isPro: job.isPro,
                    savedUrlId: job.savedUrlId,
                  )
                : UrlSaveNotifications.showCaptureReady(existing),
          );
        }
        return UrlEnrichmentResult(
          outcome: aiLimitReached
              ? UrlEnrichmentTerminalOutcome.aiLimitReached
              : UrlEnrichmentTerminalOutcome.ready,
          savedUrl: existing,
        );
      }

      final enricher = container.read(enrichmentServiceProvider)(
        outputLocale: job.outputLocale,
      );
      final failedTasks = <String>[];
      if (!await enricher.enrichMetadata(job.savedUrlId)) {
        failedTasks.add('metadata_failed');
      }
      final enrichmentResult = await enricher.enrichSingle(
        job.savedUrlId,
        initialFailures: failedTasks,
      );
      final enriched = await isarService.getUrlById(job.savedUrlId);
      if (enriched == null || enriched.isInBin) {
        return const UrlEnrichmentResult(
          outcome: UrlEnrichmentTerminalOutcome.missing,
        );
      }

      final successful = UrlProcessingStatus.isSuccessfulTerminal(
        enriched.processingStatus,
      );
      if (job.evaluateNavigationDiscovery && successful) {
        await container
            .read(navigationDiscoveryProvider.notifier)
            .recordCompletedNewSave(job.savedUrlId);
      }
      await _recordTopicPulse(isarService, job.savedUrlId);

      if (enrichmentResult.aiLimitReached) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setBool(
          '$_aiLimitKeyPrefix${job.processingId}',
          true,
        );
        if (shouldNotify) {
          await UrlEnrichmentNotificationGuard.deliverOnce(
            job.processingId,
            UrlEnrichmentNotificationOutcome.aiLimitReached,
            () => UrlSaveNotifications.showAiLimitReached(
              isPro: job.isPro,
              savedUrlId: job.savedUrlId,
            ),
          );
        }
        return UrlEnrichmentResult(
          outcome: UrlEnrichmentTerminalOutcome.aiLimitReached,
          savedUrl: enriched,
        );
      }
      if (successful) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.remove('$_aiLimitKeyPrefix${job.processingId}');
        if (shouldNotify) {
          await UrlEnrichmentNotificationGuard.deliverOnce(
            job.processingId,
            UrlEnrichmentNotificationOutcome.ready,
            () => UrlSaveNotifications.showCaptureReady(enriched),
          );
        }
        return UrlEnrichmentResult(
          outcome: UrlEnrichmentTerminalOutcome.ready,
          savedUrl: enriched,
        );
      }

      if (shouldNotify) {
        await UrlEnrichmentNotificationGuard.deliverOnce(
          job.processingId,
          UrlEnrichmentNotificationOutcome.failed,
          () => UrlSaveNotifications.showCaptureFailed(enriched),
        );
      }
      return UrlEnrichmentResult(
        outcome: UrlEnrichmentTerminalOutcome.failed,
        savedUrl: enriched,
      );
    } finally {
      container.dispose();
    }
  }

  static Future<void> _recordTopicPulse(
    IsarService isarService,
    int savedUrlId,
  ) async {
    final pulse = await detectAndPersistTopicPulseForSave(
      isar: isarService,
      sourceId: savedUrlId,
    );
    if (pulse == null) return;
    await RediscoverUtilityProfileStore.recordTopicSave(
      pulse.topicKey,
      at: pulse.detectedAt,
    );
  }

  static Future<void> _markWorkerFailure(UrlEnrichmentJob job) async {
    final isarService = IsarService();
    await isarService.ensureInitialized();
    final url = await isarService.getUrlById(job.savedUrlId);
    if (url == null || url.isInBin) return;
    url
      ..processingStatus = UrlProcessingStatus.failed
      ..processingError = 'background_worker_failed'
      ..processingUpdatedAt = DateTime.now();
    await isarService.updateUrl(url);
    await DigestNotifications.initForBackground();
    if (await UrlEnrichmentNotificationGuard.shouldDeliverFor(
      job.processingId,
      notifyOnCompletion: job.notifyOnCompletion,
    )) {
      await UrlEnrichmentNotificationGuard.deliverOnce(
        job.processingId,
        UrlEnrichmentNotificationOutcome.failed,
        () => UrlSaveNotifications.showCaptureFailed(url),
      );
    }
  }
}
