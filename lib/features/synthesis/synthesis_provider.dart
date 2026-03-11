import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/bundled_keys.dart';
import '../../core/services/subscription_service.dart';

class SynthesisState {
  final List<SavedUrl> selectedUrls;
  final bool isLoading;
  final String? result;
  final String? error;

  const SynthesisState({
    this.selectedUrls = const [],
    this.isLoading = false,
    this.result,
    this.error,
  });

  SynthesisState copyWith({
    List<SavedUrl>? selectedUrls,
    bool? isLoading,
    String? result,
    String? error,
  }) {
    return SynthesisState(
      selectedUrls: selectedUrls ?? this.selectedUrls,
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error,
    );
  }
}

class SynthesisNotifier extends StateNotifier<SynthesisState> {
  final Ref _ref;

  SynthesisNotifier(this._ref) : super(const SynthesisState());

  void setUrls(List<SavedUrl> urls) {
    state = state.copyWith(selectedUrls: urls, result: null, error: null);
  }

  Future<void> synthesize({String? question}) async {
    if (state.selectedUrls.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null, result: null);

    try {
      // Premium check
      final tier = await SubscriptionService().getTier();
      if (!SubscriptionService.isAvailable(PremiumFeature.synthesis, tier)) {
        state = state.copyWith(
          isLoading: false,
          error: 'Multi-Link Synthesis is a premium feature. Upgrade to unlock it.',
        );
        return;
      }

      if (!BundledKeys.hasGemini) {
        state = state.copyWith(
          isLoading: false,
          error: 'AI is not configured for this build.',
        );
        return;
      }

      final geminiService = GeminiService(BundledKeys.geminiKey);
      final result = await geminiService.synthesize(
        urls: state.selectedUrls,
        question: question,
      );
      state = state.copyWith(isLoading: false, result: result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Synthesis failed: $e');
    }
  }

  void reset() {
    state = const SynthesisState();
  }
}

final synthesisProvider =
    StateNotifierProvider<SynthesisNotifier, SynthesisState>((ref) {
  return SynthesisNotifier(ref);
});
