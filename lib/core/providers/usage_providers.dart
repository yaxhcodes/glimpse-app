import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/ai_quota_service.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/usage_service.dart';

/// Provider for the [UsageService] singleton.
///
/// Wired with [AiQuotaService] so costly features (AI saves) are gated by the
/// worker's server-side monthly quota, which survives reinstall.
final usageServiceProvider = Provider<UsageService>(
  (ref) => UsageService(aiQuota: AiQuotaService.instance),
);

/// Bumped after every increment so [usageProvider] / [remainingUsageProvider]
/// / [limitReachedProvider] rebuild reactively.
final usageRevisionProvider = StateProvider<int>((ref) => 0);

/// Current usage count for a [UsageFeature].
final usageProvider = FutureProvider.family<int, UsageFeature>((ref, feature) async {
  ref.watch(usageRevisionProvider);
  return ref.read(usageServiceProvider).getUsage(feature);
});

/// Remaining uses for a [UsageFeature] (accounts for Pro = unlimited).
final remainingUsageProvider = FutureProvider.family<int, UsageFeature>((ref, feature) async {
  ref.watch(usageRevisionProvider);
  final isPro = ref.watch(isProUserProvider);
  return ref.read(usageServiceProvider).getRemaining(feature, isPro);
});

/// Whether the monthly limit has been reached for a [UsageFeature].
final limitReachedProvider = FutureProvider.family<bool, UsageFeature>((ref, feature) async {
  ref.watch(usageRevisionProvider);
  final isPro = ref.watch(isProUserProvider);
  return ref.read(usageServiceProvider).hasReachedLimit(feature, isPro);
});

/// Whether usage is at or above the 80 % soft-warning threshold.
final nearLimitProvider = FutureProvider.family<bool, UsageFeature>((ref, feature) async {
  ref.watch(usageRevisionProvider);
  final isPro = ref.watch(isProUserProvider);
  return ref.read(usageServiceProvider).isNearLimit(feature, isPro);
});
