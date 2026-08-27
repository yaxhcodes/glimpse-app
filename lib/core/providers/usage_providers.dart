import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_environment.dart';
import '../../core/services/ai_quota_service.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/usage_service.dart';

/// Provider for the [UsageService] singleton.
///
/// Wired with [AiQuotaService] so production AI saves are gated by the
/// worker's server-side plan quota, which survives reinstall.
///
/// A dev build with effective Pro access uses the separate local Pro counter.
/// RevenueCat correctly reports the developer account's real plan, so asking
/// the worker for its verified plan while Force Pro is active would otherwise
/// make the simulation inherit an exhausted Free allowance.
final usageServiceProvider = Provider<UsageService>((ref) {
  final useLocalDevProQuota =
      AppEnvironment.isDevContext && ref.watch(isProUserProvider);
  return UsageService(
    aiQuota: useLocalDevProQuota ? null : AiQuotaService.instance,
    useDevProAiSaveCounter: useLocalDevProQuota,
  );
});

/// Bumped after every increment so [usageProvider] / [remainingUsageProvider]
/// / [limitReachedProvider] rebuild reactively.
final usageRevisionProvider = StateProvider<int>((ref) => 0);

/// Current usage count for a [UsageFeature].
final usageProvider = FutureProvider.family<int, UsageFeature>((
  ref,
  feature,
) async {
  ref.watch(usageRevisionProvider);
  final isPro = ref.watch(isProUserProvider);
  return ref.read(usageServiceProvider).getUsage(feature, isPro: isPro);
});

/// Remaining uses for a [UsageFeature] in the active plan window.
final remainingUsageProvider = FutureProvider.family<int, UsageFeature>((
  ref,
  feature,
) async {
  ref.watch(usageRevisionProvider);
  final isPro = ref.watch(isProUserProvider);
  return ref.read(usageServiceProvider).getRemaining(feature, isPro);
});

/// Whether the account can currently spend an AI save.
///
/// Pro is available immediately. Free accounts become eligible only after the
/// authoritative remaining-usage lookup confirms a refreshed allowance.
final aiSaveAvailableProvider = Provider<bool>((ref) {
  if (ref.watch(isProUserProvider)) return true;
  final remaining = ref.watch(remainingUsageProvider(UsageFeature.aiSave));
  return (remaining.valueOrNull ?? 0) > 0;
});

/// Whether the active plan limit has been reached for a [UsageFeature].
final limitReachedProvider = FutureProvider.family<bool, UsageFeature>((
  ref,
  feature,
) async {
  ref.watch(usageRevisionProvider);
  final isPro = ref.watch(isProUserProvider);
  return ref.read(usageServiceProvider).hasReachedLimit(feature, isPro);
});

/// Whether usage is at or above the 80 % soft-warning threshold.
final nearLimitProvider = FutureProvider.family<bool, UsageFeature>((
  ref,
  feature,
) async {
  ref.watch(usageRevisionProvider);
  final isPro = ref.watch(isProUserProvider);
  return ref.read(usageServiceProvider).isNearLimit(feature, isPro);
});
