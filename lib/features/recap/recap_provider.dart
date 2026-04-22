import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/subscription_service.dart';

const _kRecapCacheKey = 'glimpse_recap_narrative';
const _kRecapWeekKey = 'glimpse_recap_week';

/// ISO week number for [date]. Weeks start on Monday.
int _isoWeek(DateTime date) {
  final jan1 = DateTime(date.year, 1, 1);
  final dayOfYear = date.difference(jan1).inDays;
  return ((dayOfYear - date.weekday + 10) / 7).floor();
}

String _weekId(DateTime date) => '${date.year}-W${_isoWeek(date)}';

class RecapState {
  final bool isLoading;
  final String? narrative;
  final List<SavedUrl> urls;
  final Map<String, int> topicCounts;
  final String? error;

  const RecapState({
    this.isLoading = false,
    this.narrative,
    this.urls = const [],
    this.topicCounts = const {},
    this.error,
  });

  RecapState copyWith({
    bool? isLoading,
    String? narrative,
    List<SavedUrl>? urls,
    Map<String, int>? topicCounts,
    String? error,
  }) {
    return RecapState(
      isLoading: isLoading ?? this.isLoading,
      narrative: narrative ?? this.narrative,
      urls: urls ?? this.urls,
      topicCounts: topicCounts ?? this.topicCounts,
      error: error,
    );
  }
}

class RecapNotifier extends StateNotifier<RecapState> {
  final Ref _ref;

  RecapNotifier(this._ref) : super(const RecapState());

  Future<void> loadRecap() async {
    state = state.copyWith(isLoading: true, error: null);

    final isarService = _ref.read(isarServiceProvider);

    try {
      // Read the reactive tier from Riverpod — see comment in ask_provider:
      // SubscriptionService.instance.getTier() hits the RC SDK cache and
      // would show "free" right after purchase.
      final tier = await _ref.read(subscriptionTierProvider.future);
      final devO = await _ref.read(devProOverrideProvider.future);
      if (!EntitlementService.isFeatureUnlocked(
        PremiumFeature.recap,
        revenueCatTier: tier,
        devProOverride: devO,
      )) {
        state = state.copyWith(
          isLoading: false,
          error: 'Weekly Recap is a premium feature. Upgrade to unlock it.',
        );
        return;
      }

      final now = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 7));
      final urls = await isarService.getUrlsInDateRange(weekStart, now);

      // Build topic counts.
      final topicCounts = <String, int>{};
      for (final u in urls) {
        topicCounts[u.category] = (topicCounts[u.category] ?? 0) + 1;
      }

      // Reuse cached narrative if we are in the same ISO week.
      String? narrative;
      final currentWeek = _weekId(now);
      final prefs = await SharedPreferences.getInstance();
      final cachedWeek = prefs.getString(_kRecapWeekKey);
      final cachedNarrative = prefs.getString(_kRecapCacheKey);

      if (cachedWeek == currentWeek &&
          cachedNarrative != null &&
          cachedNarrative.isNotEmpty) {
        narrative = cachedNarrative;
      } else {
        final gemini = _ref.read(geminiServiceProvider);
        if (gemini != null) {
          try {
            narrative = await gemini.generateRecap(urls);
            await prefs.setString(_kRecapCacheKey, narrative);
            await prefs.setString(_kRecapWeekKey, currentWeek);
          } catch (_) {
            narrative = null;
          }
        }
      }

      state = state.copyWith(
        isLoading: false,
        urls: urls,
        topicCounts: topicCounts,
        narrative: narrative,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final recapProvider = StateNotifierProvider<RecapNotifier, RecapState>((ref) {
  return RecapNotifier(ref);
});
