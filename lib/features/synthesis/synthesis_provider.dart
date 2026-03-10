import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/gemini_service.dart';

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

    final apiKeyService = _ref.read(apiKeyServiceProvider);

    try {
      final geminiKey = await apiKeyService.getGeminiKey();
      if (geminiKey == null || geminiKey.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Please set your Gemini API key in Settings → AI & API Keys.',
        );
        return;
      }

      final geminiService = GeminiService(geminiKey);
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
