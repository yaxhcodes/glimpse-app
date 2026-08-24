import 'dart:developer' as developer;

import 'package:workmanager/workmanager.dart';

import '../database/isar_service.dart';
import '../models/saved_url.dart';
import '../models/url_processing_status.dart';
import '../../l10n/app_locale.dart';
import 'background_work_manager.dart';
import 'entitlement_service.dart';

enum UrlEnrichmentTerminalOutcome { ready, failed, aiLimitReached, missing }

typedef UrlEnrichmentScheduleCallback =
    Future<bool> Function(UrlEnrichmentJob job);

class UrlEnrichmentResult {
  const UrlEnrichmentResult({required this.outcome, this.savedUrl});

  final UrlEnrichmentTerminalOutcome outcome;
  final SavedUrl? savedUrl;
}

class UrlEnrichmentJob {
  const UrlEnrichmentJob({
    required this.savedUrlId,
    required this.processingId,
    required this.outputLocale,
    required this.notifyOnCompletion,
    required this.evaluateNavigationDiscovery,
    required this.isPro,
  });

  static const _savedUrlIdKey = 'savedUrlId';
  static const _processingIdKey = 'processingId';
  static const _outputLocaleKey = 'outputLocale';
  static const _notifyOnCompletionKey = 'notifyOnCompletion';
  static const _evaluateNavigationDiscoveryKey = 'evaluateNavigationDiscovery';
  static const _isProKey = 'isPro';

  final int savedUrlId;
  final String processingId;
  final String outputLocale;
  final bool notifyOnCompletion;
  final bool evaluateNavigationDiscovery;
  final bool isPro;

  String get uniqueWorkName => 'glimpse_url_enrichment_$savedUrlId';

  Map<String, dynamic> toInputData() => {
    _savedUrlIdKey: savedUrlId,
    _processingIdKey: processingId,
    _outputLocaleKey: outputLocale,
    _notifyOnCompletionKey: notifyOnCompletion,
    _evaluateNavigationDiscoveryKey: evaluateNavigationDiscovery,
    _isProKey: isPro,
  };

  static UrlEnrichmentJob? fromInputData(Map<String, dynamic>? inputData) {
    if (inputData == null) return null;
    final savedUrlId = (inputData[_savedUrlIdKey] as num?)?.toInt();
    final processingId = inputData[_processingIdKey] as String?;
    final outputLocale = inputData[_outputLocaleKey] as String?;
    if (savedUrlId == null ||
        savedUrlId <= 0 ||
        processingId == null ||
        processingId.isEmpty ||
        outputLocale == null ||
        outputLocale.isEmpty) {
      return null;
    }
    return UrlEnrichmentJob(
      savedUrlId: savedUrlId,
      processingId: processingId,
      outputLocale: outputLocale,
      notifyOnCompletion: inputData[_notifyOnCompletionKey] == true,
      evaluateNavigationDiscovery:
          inputData[_evaluateNavigationDiscoveryKey] == true,
      isPro: inputData[_isProKey] == true,
    );
  }
}

class UrlEnrichmentScheduler {
  UrlEnrichmentScheduler._();

  static const taskName = 'urlEnrichmentTask';
  static const recoveryDelay = Duration(minutes: 2);
  static const _recoveryMinimumAge = Duration(minutes: 1);
  static const _staleProcessingAge = Duration(minutes: 15);

  static Future<bool> schedule(UrlEnrichmentJob job) async {
    try {
      await BackgroundWorkManager.ready;
      await Workmanager().registerOneOffTask(
        job.uniqueWorkName,
        taskName,
        inputData: job.toInputData(),
        initialDelay: recoveryDelay,
        constraints: Constraints(networkType: NetworkType.connected),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        tag: 'glimpse_url_enrichment',
      );
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Could not schedule enrichment for save ${job.savedUrlId}.',
        name: 'UrlEnrichmentScheduler',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  static Future<void> cancel(int savedUrlId) async {
    try {
      await Workmanager().cancelByUniqueName(
        'glimpse_url_enrichment_$savedUrlId',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Could not cancel recovered enrichment for save $savedUrlId.',
        name: 'UrlEnrichmentScheduler',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<int> recoverPending(
    IsarService isarService, {
    DateTime? currentTime,
    String? outputLocale,
    bool? isPro,
    UrlEnrichmentScheduleCallback? scheduleJob,
  }) async {
    final urls = await isarService.getAllUrls();
    final now = currentTime ?? DateTime.now();
    final effectiveOutputLocale =
        outputLocale ?? appLocaleTag(await loadEffectiveAppLocale());
    final effectiveIsPro =
        isPro ?? await EntitlementService.loadEffectiveProSnapshot();
    final scheduler = scheduleJob ?? schedule;
    var scheduled = 0;

    for (final url in urls) {
      final updatedAt = url.processingUpdatedAt ?? url.savedAt;
      final age = now.difference(updatedAt);
      final queuedLongEnough =
          url.processingStatus == UrlProcessingStatus.queued &&
          age >= _recoveryMinimumAge;
      final staleActive =
          UrlProcessingStatus.isActive(url.processingStatus) &&
          age > _staleProcessingAge;
      if (!queuedLongEnough && !staleActive) continue;

      final processingId = url.processingId?.trim().isNotEmpty == true
          ? url.processingId!
          : 'recovered-${url.id}-${updatedAt.microsecondsSinceEpoch}';
      if (url.processingId != processingId) {
        url.processingId = processingId;
        await isarService.updateUrl(url);
      }
      final didSchedule = await scheduler(
        UrlEnrichmentJob(
          savedUrlId: url.id,
          processingId: processingId,
          outputLocale: effectiveOutputLocale,
          notifyOnCompletion: false,
          evaluateNavigationDiscovery: false,
          isPro: effectiveIsPro,
        ),
      );
      if (didSchedule) scheduled++;
    }
    return scheduled;
  }
}
