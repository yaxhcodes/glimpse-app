import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/isar_service.dart';
import '../services/ai_proxy_config.dart';
import '../services/app_update_service.dart';
import '../services/backup/backup_service.dart';
import '../services/backup/backup_storage_service.dart';
import '../services/bundled_keys.dart';
import '../services/embedding_service.dart';
import '../services/enrichment_service.dart';
import '../services/gemini_service.dart';
import '../services/link_preview_service.dart';
import '../services/network_status_service.dart';
import '../services/recipe_nutrition_service.dart';
import '../services/saved_highlights_service.dart';
import '../services/saved_notes_service.dart';
import '../services/transcript_enrichment_service.dart';
import '../services/entitlement_service.dart';
import 'usage_providers.dart';
import '../../l10n/l10n.dart';

/// Global provider for the Isar database service.
final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService();
});

final savedNotesServiceProvider = Provider<SavedNotesService>((ref) {
  return SavedNotesService(ref.read(isarServiceProvider));
});

final savedHighlightsServiceProvider = Provider<SavedHighlightsService>((ref) {
  return SavedHighlightsService(ref.read(isarServiceProvider));
});

/// Global provider for the backup service.
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(isarService: ref.read(isarServiceProvider));
});

/// Bridge to the persistent backup-folder feature (Android SAF). Stateless
/// — all state lives in SharedPreferences on the native side.
final backupStorageServiceProvider = Provider<BackupStorageService>((ref) {
  return BackupStorageService();
});

/// Global provider for the link preview service.
final linkPreviewServiceProvider = Provider<LinkPreviewService>((ref) {
  return LinkPreviewService();
});

final networkStatusServiceProvider = Provider<NetworkStatusService>((ref) {
  return NetworkStatusService();
});

final transcriptEnrichmentServiceProvider =
    Provider<TranscriptEnrichmentService>((ref) {
      return TranscriptEnrichmentService();
    });

final recipeNutritionServiceProvider = Provider<RecipeNutritionService>((ref) {
  const usdaApiKey = String.fromEnvironment(
    'USDA_FDC_API_KEY',
    defaultValue: 'DEMO_KEY',
  );
  return RecipeNutritionService(
    dataSource: CachedNutritionDataSource(
      remote: UsdaFoodDataCentralDataSource(dio: Dio(), apiKey: usdaApiKey),
    ),
  );
});

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final service = AppUpdateService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

/// Single shared Voyage embedding client.
///
/// Returns `null` when there is no Voyage key AND the AI proxy is not
/// enabled, so call sites can gracefully degrade to keyword paths.
final embeddingServiceProvider = Provider<EmbeddingService?>((ref) {
  BundledKeys.debugLogAvailability();
  if (!BundledKeys.hasVoyage) {
    developer.log(
      'EmbeddingService: SKIP — no direct Voyage key and proxy not enabled '
      '(proxyEnabled=${AiProxyConfig.enabled}, '
      'userId=${AiProxyConfig.userId.isNotEmpty ? "set" : "MISSING"})',
      name: 'ServiceProviders',
    );
    return null;
  }
  developer.log(
    'EmbeddingService: INIT '
    '(proxy=${AiProxyConfig.enabled}, '
    'userId=${AiProxyConfig.userId.isNotEmpty ? "set" : "MISSING"})',
    name: 'ServiceProviders',
  );
  return EmbeddingService();
});

/// Single shared Gemini client.
///
/// Returns `null` when Gemini is unavailable (no key AND no proxy),
/// so call sites can skip AI-only features without try/catching missing keys.
final geminiServiceProvider = Provider<GeminiService?>((ref) {
  if (!BundledKeys.hasGemini) {
    developer.log(
      'GeminiService: SKIP — no direct Gemini key and proxy not enabled '
      '(proxyEnabled=${AiProxyConfig.enabled}, '
      'userId=${AiProxyConfig.userId.isNotEmpty ? "set" : "MISSING"})',
      name: 'ServiceProviders',
    );
    return null;
  }
  developer.log(
    'GeminiService: INIT '
    '(proxy=${AiProxyConfig.enabled}, '
    'userId=${AiProxyConfig.userId.isNotEmpty ? "set" : "MISSING"})',
    name: 'ServiceProviders',
  );
  final outputLocale = appLocaleTag(ref.watch(effectiveAppLocaleProvider));
  return GeminiService(null, outputLocale);
});

/// Enrichment service factory. Creates a fresh instance each time because
/// [isPro] status and the [onEnriched] callback may differ per call site.
///
/// Usage:
///   final enricher = ref.read(enrichmentServiceProvider);
///   final service = enricher(onEnriched: () { ref.invalidate(...); });
final enrichmentServiceProvider =
    Provider<
      EnrichmentService Function({
        void Function()? onEnriched,
        String? outputLocale,
      })
    >((ref) {
      return ({void Function()? onEnriched, String? outputLocale}) {
        final effectiveOutputLocale =
            outputLocale ?? appLocaleTag(ref.read(effectiveAppLocaleProvider));
        final sharedGeminiService = ref.read(geminiServiceProvider);
        final localizedGeminiService =
            sharedGeminiService == null ||
                sharedGeminiService.outputLocale == effectiveOutputLocale
            ? sharedGeminiService
            : GeminiService(null, effectiveOutputLocale);
        return EnrichmentService(
          isarService: ref.read(isarServiceProvider),
          geminiService: localizedGeminiService,
          embeddingService: ref.read(embeddingServiceProvider),
          linkService: ref.read(linkPreviewServiceProvider),
          transcriptEnrichmentService: ref.read(
            transcriptEnrichmentServiceProvider,
          ),
          recipeNutritionService: ref.read(recipeNutritionServiceProvider),
          usageService: ref.read(usageServiceProvider),
          isPro: ref.read(isProUserProvider),
          outputLocale: effectiveOutputLocale,
          onEnriched: onEnriched,
        );
      };
    });

Future<EnrichmentService> createLocalizedEnrichmentService(
  Ref ref, {
  void Function()? onEnriched,
}) async {
  String outputLocale;
  try {
    outputLocale = appLocaleTag(await loadEffectiveAppLocale());
  } catch (error, stackTrace) {
    developer.log(
      'Could not reload the saved app language before enrichment.',
      name: 'ServiceProviders',
      error: error,
      stackTrace: stackTrace,
    );
    outputLocale = appLocaleTag(ref.read(effectiveAppLocaleProvider));
  }
  return ref.read(enrichmentServiceProvider)(
    outputLocale: outputLocale,
    onEnriched: onEnriched,
  );
}
