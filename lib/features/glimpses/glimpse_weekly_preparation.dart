import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/usage_providers.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/network_status_service.dart';
import '../../l10n/l10n.dart';
import 'glimpse_service.dart';
import 'glimpse_synthesis.dart';
import 'glimpse_weekly_review.dart';

class WeeklyReviewPreferences {
  static const enabledKey = 'glimpse_weekly_ai_enabled_v1';
  static const attemptKey = 'glimpse_weekly_ai_attempt_v1';

  static Future<bool> enabled() async =>
      (await SharedPreferences.getInstance()).getBool(enabledKey) ?? false;

  static Future<void> setEnabled(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(enabledKey, value);
  }

  static Future<bool> claimWeek(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(attemptKey) == key) return false;
    await prefs.setString(attemptKey, key);
    return true;
  }
}

final weeklyReviewEnabledProvider = FutureProvider<bool>(
  (ref) => WeeklyReviewPreferences.enabled(),
);

/// One foreground preparation per week. The preference is explicit cloud consent.
final prepareWeeklyReviewProvider = FutureProvider<void>((ref) async {
  if (!await ref.watch(weeklyReviewEnabledProvider.future)) return;
  final all = await ref.watch(glimpsesProvider.future);
  final now = DateTime.now();
  final week = latestWeeklyReview(all, now)?.glimpse;
  if (week?.periodEnd == null ||
      week!.periodEnd!.isAfter(now) ||
      now.difference(week.periodEnd!).inDays >= 7 ||
      GlimpseSynthesis.excerpts(week, includeNotes: false).length < 2) {
    return;
  }
  final locale = appLocaleTag(await loadEffectiveAppLocale());
  ref.watch(effectiveAppLocaleProvider);
  final entry = all.firstWhere((s) => s.glimpse.key == week.key);
  if (entry.record.synthesisKey ==
      GlimpseSynthesis.cacheKey(week, locale, false)) {
    return;
  }
  try {
    if (await NetworkStatusService().isDefinitelyOffline()) return;
    if (!await WeeklyReviewPreferences.enabled()) return;
    if (!await WeeklyReviewPreferences.claimWeek(week.key)) return;
    final synthesis = GlimpseSynthesis(
      ref.read(glimpseServiceProvider).store,
      ref.read(usageServiceProvider),
      ref.read(isProUserProvider),
    );
    await synthesis.generate(week, locale: locale, includeNotes: false);
    ref.read(usageRevisionProvider.notifier).state++;
    ref.invalidate(glimpsesProvider);
  } on Object catch (error, stack) {
    developer.log(
      'Weekly review stays available locally',
      name: 'WeeklyReview',
      error: error,
      stackTrace: stack,
    );
  }
});
