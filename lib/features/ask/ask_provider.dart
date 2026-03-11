import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/embedding_service.dart';
import '../../core/services/bundled_keys.dart';
import '../../core/services/subscription_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<SavedUrl> sources;
  final List<ChatMessageSection> sections;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
    this.sections = const [],
  });
}

class ChatMessageSection {
  final String heading;
  final String summary;
  final SavedUrl source;

  const ChatMessageSection({
    required this.heading,
    required this.summary,
    required this.source,
  });
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

  String _friendlyErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('503') ||
        text.contains('high demand') ||
        text.contains('overloaded') ||
        text.contains('unavailable')) {
      return 'Glimpse could not reach Gemini right now because the model is under heavy load. Please try again in a few seconds.';
    }
    if (text.contains('api key') || text.contains('api_key') ||
        text.contains('invalid') || text.contains('401') ||
        text.contains('403')) {
      return 'Your Gemini API key appears to be invalid or expired. Please check it in Settings → AI & API Keys.';
    }
    if (text.contains('quota') || text.contains('429') ||
        text.contains('rate') || text.contains('limit')) {
      return 'Your API key has hit its usage limit. Please wait a bit or check your Google AI Studio billing.';
    }
    if (text.contains('not found') || text.contains('404')) {
      return 'The AI model could not be reached. This may be a temporary issue — please try again.';
    }
    return 'Something went wrong while generating the answer. Please try again.';
  }

  ChatMessage _buildLocalFallbackAnswer(
    String question,
    List<SavedUrl> contextUrls,
  ) {
    final sections = contextUrls.take(3).map((url) {
      final sourceSummary = (url.summary ?? url.description).trim();
      return ChatMessageSection(
        heading: url.title.isNotEmpty ? url.title : url.domain,
        summary: sourceSummary.isNotEmpty
            ? sourceSummary
            : 'This saved link appears relevant to "$question", but there is not enough extracted text yet to summarize it better.',
        source: url,
      );
    }).toList();

    return ChatMessage(
      text:
          'Glimpse could not reach Gemini right now, so here are the most relevant saved links and what they contain.',
      isUser: false,
      sources: sections.map((section) => section.source).toList(),
      sections: sections,
    );
  }

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

    final isarService = _ref.read(isarServiceProvider);

    try {
      // Check subscription
      final tier = await SubscriptionService().getTier();
      if (!SubscriptionService.isAvailable(PremiumFeature.askChat, tier)) {
        _addBotMessage(
          'Ask Your Bookmarks is a premium feature. Upgrade to Glimpse Premium to unlock it.',
        );
        return;
      }

      if (!BundledKeys.hasGemini) {
        _addBotMessage(
          'AI is not configured for this build. Please update the app.',
        );
        return;
      }

      // Retrieve relevant context
      List<SavedUrl> contextUrls;
      if (BundledKeys.hasVoyage) {
        try {
          final embeddingService = EmbeddingService(BundledKeys.voyageKey);
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

      final geminiService = GeminiService(BundledKeys.geminiKey);
      final answer = await geminiService.chat(
        question: question,
        contextUrls: contextUrls,
      );

      final sections = answer.sections
          .map((section) => ChatMessageSection(
                heading: section.heading,
                summary: section.summary,
                source: contextUrls[section.sourceIndex - 1],
              ))
          .toList();

      _addBotMessage(
        answer.intro,
        sources: sections.map((section) => section.source).toList(),
        sections: sections,
      );
    } catch (e) {
      developer.log('Ask AI error: $e', name: 'AskNotifier');
      // Try local fallback for any AI failure
      try {
        final fallbackUrls = await _fallbackContext(question);
        if (fallbackUrls.isNotEmpty) {
          state = state.copyWith(
            messages: [
              ...state.messages,
              _buildLocalFallbackAnswer(question, fallbackUrls),
            ],
            isLoading: false,
          );
          return;
        }
      } catch (_) {
        // Failed to build fallback too
      }
      _addBotMessage(_friendlyErrorMessage(e));
    }
  }

  Future<List<SavedUrl>> _fallbackContext(String question) async {
    final isarService = _ref.read(isarServiceProvider);
    final urls = await isarService.fuzzySearchUrls(question);
    return urls.isEmpty ? await isarService.getAllUrls() : urls;
  }

  void _addBotMessage(
    String text, {
    List<SavedUrl> sources = const [],
    List<ChatMessageSection> sections = const [],
  }) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          text: text,
          isUser: false,
          sources: sources,
          sections: sections,
        ),
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
