import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/bundled_keys.dart';
import '../../core/services/subscription_service.dart';

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
      // Premium check
      final tier = await SubscriptionService().getTier();
      if (!SubscriptionService.isAvailable(PremiumFeature.recap, tier)) {
        state = state.copyWith(
          isLoading: false,
          error: 'Weekly Recap is a premium feature. Upgrade to unlock it.',
        );
        return;
      }

      final now = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 7));
      final urls = await isarService.getUrlsInDateRange(weekStart, now);

      // Build topic counts
      final topicCounts = <String, int>{};
      for (final u in urls) {
        topicCounts[u.category] = (topicCounts[u.category] ?? 0) + 1;
      }

      String? narrative;
      if (BundledKeys.hasGemini) {
        try {
          final geminiService = GeminiService(BundledKeys.geminiKey);
          narrative = await geminiService.generateRecap(urls);
        } catch (_) {
          narrative = null;
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
