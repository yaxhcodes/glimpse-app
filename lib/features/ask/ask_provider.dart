import 'dart:developer' as developer;
import 'dart:math' show Random;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_environment.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/ask_retrieval_service.dart';
import '../../core/services/embedding_service.dart';
import '../../core/providers/usage_providers.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/usage_service.dart';
import '../home/home_provider.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final List<SavedUrl> sources;
  final List<ChatMessageSection> sections;
  final String? proactiveTip;
  final ChatAction action;
  final String? label;
  final String? originalQuestion;
  final bool actionConsumed;

  static int _idCounter = 0;
  static String _generateId() {
    _idCounter++;
    return 'msg_${_idCounter}_${DateTime.now().millisecondsSinceEpoch}';
  }

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    this.sources = const [],
    this.sections = const [],
    this.proactiveTip,
    this.action = ChatAction.none,
    this.label,
    this.originalQuestion,
    this.actionConsumed = false,
  }) : id = id ?? _generateId();

  ChatMessage copyWith({bool? actionConsumed}) {
    return ChatMessage(
      id: id,
      text: text,
      isUser: isUser,
      sources: sources,
      sections: sections,
      proactiveTip: proactiveTip,
      action: action,
      label: label,
      originalQuestion: originalQuestion,
      actionConsumed: actionConsumed ?? this.actionConsumed,
    );
  }
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

enum ChatAction { saveToCollection, synthesize, buildPlan, none }

/// Feature that hit a usage limit (for UI upgrade gate display).
enum UsageLimitHit { ask, search, aiSave }

class AskState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final UsageLimitHit? limitReached;

  const AskState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.limitReached,
  });

  AskState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    UsageLimitHit? limitReached,
  }) {
    return AskState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      limitReached: limitReached,
    );
  }
}

bool _isGreeting(String message) {
  final normalized = message.trim().toLowerCase();
  const greetings = {
    'hi',
    'hey',
    'hello',
    'hii',
    'hiii',
    'yo',
    'sup',
    "what's up",
    'whats up',
    'good morning',
    'good evening',
    'good afternoon',
    'howdy',
    'greetings',
  };
  return greetings.contains(normalized);
}

const _greetingReplies = [
  "Hey! What do you want to dig into today?",
  "Hi! What's on your mind?",
  "Hey there! Ask me anything about your saves.",
  "Hello! What shall we explore?",
];

class AskNotifier extends StateNotifier<AskState> {
  final Ref _ref;

  AskNotifier(this._ref) : super(const AskState());

  String _friendlyErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('503') ||
        text.contains('high demand') ||
        text.contains('overloaded') ||
        text.contains('unavailable')) {
      return 'Glimpse could not reach the AI right now because the model is under heavy load. Please try again in a few seconds.';
    }
    if (text.contains('quota') ||
        text.contains('429') ||
        text.contains('rate') ||
        text.contains('limit')) {
      return 'The AI service has hit its usage limit. Please try again in a bit.';
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
          'Glimpse could not reach the AI right now, so here are the most relevant saved links and what they contain.',
      isUser: false,
      sources: sections.map((section) => section.source).toList(),
      sections: sections,
    );
  }

  Future<void> ask(
    String question, {
    List<SavedUrl>? preloadedSources,
    String? originalQuestion,
    bool usePreloadedAsContext = false,
    int? saveAnswerToUrlId,
  }) async {
    if (question.trim().isEmpty) return;

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(text: question, isUser: true),
      ],
      isLoading: true,
      error: null,
    );

    // Instant local response for greetings — no API call, no loading flash.
    if (_isGreeting(question)) {
      final reply = _greetingReplies[Random().nextInt(_greetingReplies.length)];
      _addBotMessage(reply);
      return;
    }

    final isarService = _ref.read(isarServiceProvider);

    try {
      // Usage-based gating: free users get 5 Ask queries/month.
      // Pro (or dev override) users bypass the limit entirely.
      final isPro = _ref.read(isProUserProvider);
      final usageService = _ref.read(usageServiceProvider);
      final hasReached = await usageService.hasReachedLimit(
        UsageFeature.ask,
        isPro,
      );
      if (hasReached) {
        developer.log('Ask limit reached (isPro=$isPro)', name: 'AskNotifier');
        state = state.copyWith(
          isLoading: false,
          limitReached: UsageLimitHit.ask,
        );
        return;
      }

      final gemini = _ref.read(geminiServiceProvider);
      if (gemini == null) {
        _addBotMessage(
          AppEnvironment.allowsLocalProOverride
              ? 'AI is not configured in this build. '
                    'Set AI_PROXY_BASE_URL to the Cloudflare Worker proxy; '
                    '“Force Pro” only unlocks in-app gates, not API access.'
              : 'AI is not configured for this build. Please update the app.',
        );
        return;
      }

      if (usePreloadedAsContext &&
          preloadedSources != null &&
          preloadedSources.isNotEmpty) {
        await _answerWithFixedContext(
          question: question,
          contextUrls: preloadedSources,
          saveAnswerToUrlId: saveAnswerToUrlId,
          usageService: usageService,
          gemini: gemini,
        );
        return;
      }

      // Preloaded sources skip RAG and go straight to synthesize / plan.
      if (preloadedSources != null && preloadedSources.isNotEmpty) {
        final isPlan = question.toLowerCase().contains('plan');
        final text = isPlan
            ? await gemini.plan(
                urls: preloadedSources,
                originalQuestion: originalQuestion ?? question,
              )
            : await gemini.synthesize(urls: preloadedSources);

        await usageService.incrementUsage(UsageFeature.ask);
        _ref.read(usageRevisionProvider.notifier).state++;

        _addBotMessage(text, label: isPlan ? '📋 Plan' : null);
        return;
      }

      // Retrieve relevant context with lexical matches first and semantic
      // matches as a recall boost. Ask should never force unrelated nearest
      // neighbors into the model just because embeddings exist.
      final embeddings = _ref.read(embeddingServiceProvider);
      final allUrls = await isarService.getAllUrls();
      var semanticScored = <MapEntry<SavedUrl, double>>[];
      if (embeddings != null) {
        try {
          final queryEmbedding = await embeddings.generateEmbedding(question);
          if (queryEmbedding.isNotEmpty) {
            semanticScored = await isarService.semanticSearchScored(
              queryEmbedding,
              limit: 18,
              minScore: AskRetrievalService.semanticMinScore,
            );
          }
        } on EmbeddingException {
          semanticScored = const [];
        }
      }
      final contextUrls = AskRetrievalService.retrieve(
        query: question,
        allUrls: allUrls,
        semanticScored: semanticScored,
        limit: 6,
      );

      if (contextUrls.isEmpty) {
        _addBotMessage(
          "I couldn't find any relevant saved links for that question. Try saving some links first!",
        );
        return;
      }

      // Build conversation history from previous messages, cap at 6 exchanges.
      final history = state.messages
          .where((m) => m.text.trim().isNotEmpty)
          .map(
            (m) => {'role': m.isUser ? 'User' : 'Glimpse', 'content': m.text},
          )
          .toList();
      final recentHistory = history.length > 12
          ? history.sublist(history.length - 12)
          : history;

      final answer = await gemini.chat(
        question: question,
        contextUrls: contextUrls,
        conversationHistory: recentHistory,
        contextMode: ChatContextMode.retrieved,
      );

      final sections = answer.sections
          .map(
            (section) => ChatMessageSection(
              heading: section.heading,
              summary: section.summary,
              source: contextUrls[section.sourceIndex - 1],
            ),
          )
          .toList();

      final actionSources = answer.sections
          .where(
            (s) => s.sourceIndex > 0 && s.sourceIndex <= contextUrls.length,
          )
          .map((s) => contextUrls[s.sourceIndex - 1])
          .toList();

      final action = _resolveAction(answer, question);

      await usageService.incrementUsage(UsageFeature.ask);
      _ref.read(usageRevisionProvider.notifier).state++;

      _addBotMessage(
        answer.intro,
        sources: actionSources,
        sections: sections,
        proactiveTip: answer.proactiveTip,
        action: action,
        originalQuestion: question,
      );
    } catch (e) {
      developer.log('Ask AI error: $e', name: 'AskNotifier');
      // Try local fallback for any AI failure.
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

  ChatAction _resolveAction(ChatResponse response, String userQuestion) {
    if (response.sections.isEmpty) return ChatAction.none;

    final q = userQuestion.toLowerCase();
    if (q.contains('plan') ||
        q.contains('build') ||
        q.contains('project') ||
        q.contains('weekend')) {
      return ChatAction.buildPlan;
    }

    if (response.proactiveTip != null && response.sections.length >= 3) {
      return ChatAction.synthesize;
    }

    return ChatAction.saveToCollection;
  }

  Future<void> _answerWithFixedContext({
    required String question,
    required List<SavedUrl> contextUrls,
    required UsageService usageService,
    required GeminiService gemini,
    int? saveAnswerToUrlId,
  }) async {
    final history = state.messages
        .where((m) => m.text.trim().isNotEmpty)
        .map((m) => {'role': m.isUser ? 'User' : 'Glimpse', 'content': m.text})
        .toList();
    final recentHistory = history.length > 12
        ? history.sublist(history.length - 12)
        : history;

    final answer = await gemini.chat(
      question: question,
      contextUrls: contextUrls,
      conversationHistory: recentHistory,
      contextMode: ChatContextMode.focusedSave,
    );

    final sections = answer.sections
        .map(
          (section) => ChatMessageSection(
            heading: section.heading,
            summary: section.summary,
            source: contextUrls[section.sourceIndex - 1],
          ),
        )
        .toList();
    final sources = answer.sections
        .where((s) => s.sourceIndex > 0 && s.sourceIndex <= contextUrls.length)
        .map((s) => contextUrls[s.sourceIndex - 1])
        .toList();

    await usageService.incrementUsage(UsageFeature.ask);
    _ref.read(usageRevisionProvider.notifier).state++;

    if (saveAnswerToUrlId != null) {
      await _appendAskNote(
        urlId: saveAnswerToUrlId,
        question: question,
        answer: answer.intro,
        sections: sections,
      );
    }

    _addBotMessage(
      answer.intro,
      sources: sources.isEmpty ? contextUrls.take(1).toList() : sources,
      sections: sections,
      proactiveTip: answer.proactiveTip,
      originalQuestion: question,
    );
  }

  Future<void> _appendAskNote({
    required int urlId,
    required String question,
    required String answer,
    required List<ChatMessageSection> sections,
  }) async {
    final isarService = _ref.read(isarServiceProvider);
    final url = await isarService.getUrlById(urlId);
    if (url == null) return;

    final existing = url.userNotes?.trimRight() ?? '';
    final details = sections
        .map((section) => '${section.heading}: ${section.summary}')
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
    final timestamp = DateTime.now();
    final block = [
      '## Ask Glimpse',
      'Asked: ${_formatNoteTimestamp(timestamp)}',
      'Question: ${question.trim()}',
      '',
      answer.trim(),
      if (details.isNotEmpty) '',
      if (details.isNotEmpty) details,
    ].join('\n');

    url.userNotes = existing.isEmpty ? block : '$existing\n\n$block';
    await isarService.updateUrl(url);
    _ref.invalidate(urlStreamProvider);
  }

  String _formatNoteTimestamp(DateTime when) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${when.year}-${two(when.month)}-${two(when.day)} '
        '${two(when.hour)}:${two(when.minute)}';
  }

  Future<List<SavedUrl>> _fallbackContext(String question) async {
    final isarService = _ref.read(isarServiceProvider);
    final allUrls = await isarService.getAllUrls();
    final urls = AskRetrievalService.retrieve(
      query: question,
      allUrls: allUrls,
      limit: 3,
    );
    return urls.isEmpty ? allUrls.take(3).toList() : urls;
  }

  void _addBotMessage(
    String text, {
    List<SavedUrl> sources = const [],
    List<ChatMessageSection> sections = const [],
    String? proactiveTip,
    ChatAction action = ChatAction.none,
    String? label,
    String? originalQuestion,
  }) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          text: text,
          isUser: false,
          sources: sources,
          sections: sections,
          proactiveTip: proactiveTip,
          action: action,
          label: label,
          originalQuestion: originalQuestion,
        ),
      ],
      isLoading: false,
    );
  }

  void clearHistory() {
    state = const AskState();
  }

  void consumeAction(String messageId) {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    state = state.copyWith(
      messages: [
        ...state.messages.sublist(0, idx),
        state.messages[idx].copyWith(actionConsumed: true),
        ...state.messages.sublist(idx + 1),
      ],
    );
  }

  /// Clear only the limit-reached flag so the gate doesn't re-appear
  /// on every rebuild, while preserving the conversation history.
  void clearLimitReached() {
    if (state.limitReached != null) {
      state = state.copyWith(limitReached: null);
    }
  }
}

final askProvider = StateNotifierProvider<AskNotifier, AskState>((ref) {
  return AskNotifier(ref);
});
