import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/embedding_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  const ChatMessage({required this.text, required this.isUser});
}

class AskState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const AskState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  AskState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return AskState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AskNotifier extends StateNotifier<AskState> {
  final Ref _ref;

  AskNotifier(this._ref) : super(const AskState());

  Future<void> ask(String question) async {
    if (question.trim().isEmpty) return;

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(text: question, isUser: true),
      ],
      isLoading: true,
      error: null,
    );

    final apiKeyService = _ref.read(apiKeyServiceProvider);
    final isarService = _ref.read(isarServiceProvider);

    try {
      final geminiKey = await apiKeyService.getGeminiKey();
      if (geminiKey == null || geminiKey.isEmpty) {
        _addBotMessage(
          'Please set your Gemini API key in Settings → AI & API Keys to use this feature.',
        );
        return;
      }

      // Retrieve relevant context
      List<SavedUrl> contextUrls;
      final voyageKey = await apiKeyService.getVoyageKey();
      if (voyageKey != null && voyageKey.isNotEmpty) {
        try {
          final embeddingService = EmbeddingService(voyageKey);
          final queryEmbedding =
              await embeddingService.generateEmbedding(question);
          if (queryEmbedding.isNotEmpty) {
            contextUrls = await isarService.semanticSearchUrls(
              queryEmbedding,
              limit: 6,
            );
          } else {
            contextUrls = await isarService.fuzzySearchUrls(question);
          }
        } catch (_) {
          contextUrls = await isarService.fuzzySearchUrls(question);
        }
      } else {
        contextUrls = await isarService.fuzzySearchUrls(question);
      }

      if (contextUrls.isEmpty) {
        _addBotMessage(
          "I couldn't find any relevant saved links for that question. Try saving some links first!",
        );
        return;
      }

      final geminiService = GeminiService(geminiKey);
      final answer = await geminiService.chat(
        question: question,
        contextUrls: contextUrls,
      );

      _addBotMessage(answer);
    } catch (e) {
      _addBotMessage('Something went wrong. Please try again.');
    }
  }

  void _addBotMessage(String text) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(text: text, isUser: false),
      ],
      isLoading: false,
    );
  }

  void clearHistory() {
    state = const AskState();
  }
}

final askProvider = StateNotifierProvider<AskNotifier, AskState>((ref) {
  return AskNotifier(ref);
});
