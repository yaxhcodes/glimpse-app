import 'dart:developer' as developer;
import 'dart:math' show Random, min;

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
  final List<int> citedSourceIds;
  final List<ChatMessageSection> sections;
  final String? proactiveTip;
  final List<String> followUpSuggestions;
  final ChatAction action;
  final String? label;
  final String? originalQuestion;
  final bool actionConsumed;
  final ChatAnswerConfidence confidence;
  final ChatAnswerType answerType;
  final bool canSaveAsNote;
  final bool noteSaved;

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
    List<int>? citedSourceIds,
    this.sections = const [],
    this.proactiveTip,
    this.followUpSuggestions = const [],
    this.action = ChatAction.none,
    this.label,
    this.originalQuestion,
    this.actionConsumed = false,
    this.confidence = ChatAnswerConfidence.medium,
    this.answerType = ChatAnswerType.direct,
    this.canSaveAsNote = false,
    this.noteSaved = false,
  }) : citedSourceIds =
           citedSourceIds ?? sources.map((source) => source.id).toList(),
       id = id ?? _generateId();

  ChatMessage copyWith({bool? actionConsumed, bool? noteSaved}) {
    return ChatMessage(
      id: id,
      text: text,
      isUser: isUser,
      sources: sources,
      citedSourceIds: citedSourceIds,
      sections: sections,
      proactiveTip: proactiveTip,
      followUpSuggestions: followUpSuggestions,
      action: action,
      label: label,
      originalQuestion: originalQuestion,
      actionConsumed: actionConsumed ?? this.actionConsumed,
      confidence: confidence,
      answerType: answerType,
      canSaveAsNote: canSaveAsNote,
      noteSaved: noteSaved ?? this.noteSaved,
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

enum ChatAction { saveToCollection, synthesize, buildPlan, saveItinerary, none }

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

class AskContextPlan {
  const AskContextPlan({
    required this.contextUrls,
    required this.isFollowUp,
    required this.suppressedSourceIds,
  });

  final List<SavedUrl> contextUrls;
  final bool isFollowUp;
  final Set<int> suppressedSourceIds;
}

class AskConversationPlanner {
  static AskContextPlan plan({
    required String question,
    required List<SavedUrl> allUrls,
    required List<ChatMessage> previousMessages,
    List<MapEntry<SavedUrl, double>> semanticScored = const [],
    int limit = 6,
  }) {
    final referencesContext = referencesActiveContext(question);
    final isFollowUp = looksLikeFollowUp(question) || referencesContext;
    final allowRepeats = referencesContext || asksForPreviousSources(question);
    final citedIds = citedSourceIds(previousMessages);
    final suppressedIds = isFollowUp && !allowRepeats ? citedIds : <int>{};

    final candidateUrls = suppressedIds.isEmpty
        ? allUrls
        : allUrls.where((url) => !suppressedIds.contains(url.id)).toList();
    final candidateSemantic = suppressedIds.isEmpty
        ? semanticScored
        : semanticScored
              .where((entry) => !suppressedIds.contains(entry.key.id))
              .toList();

    var contextUrls = referencesContext
        ? latestContext(previousMessages, limit: limit)
        : const <SavedUrl>[];

    if (contextUrls.isEmpty) {
      contextUrls = AskRetrievalService.retrieve(
        query: question,
        allUrls: candidateUrls,
        semanticScored: candidateSemantic,
        limit: limit,
      );
    }

    if (contextUrls.isEmpty && isFollowUp) {
      contextUrls = activeContext(previousMessages, limit: limit);
    }

    return AskContextPlan(
      contextUrls: contextUrls,
      isFollowUp: isFollowUp,
      suppressedSourceIds: suppressedIds,
    );
  }

  static Set<int> citedSourceIds(List<ChatMessage> messages) {
    final ids = <int>{};
    for (final message in messages) {
      if (message.isUser) continue;
      ids.addAll(message.citedSourceIds);
      ids.addAll(message.sources.map((source) => source.id));
      ids.addAll(message.sections.map((section) => section.source.id));
    }
    return ids;
  }

  static List<SavedUrl> activeContext(
    List<ChatMessage> messages, {
    int limit = 6,
  }) {
    final byId = <int, SavedUrl>{};
    for (final message in messages.reversed) {
      if (message.isUser) continue;
      for (final section in message.sections.reversed) {
        byId.putIfAbsent(section.source.id, () => section.source);
      }
      for (final source in message.sources.reversed) {
        byId.putIfAbsent(source.id, () => source);
      }
      if (byId.length >= limit) break;
    }
    return byId.values.take(limit).toList();
  }

  static List<SavedUrl> latestContext(
    List<ChatMessage> messages, {
    int limit = 6,
  }) {
    for (final message in messages.reversed) {
      if (message.isUser) continue;
      final byId = <int, SavedUrl>{};
      for (final section in message.sections) {
        byId.putIfAbsent(section.source.id, () => section.source);
      }
      for (final source in message.sources) {
        byId.putIfAbsent(source.id, () => source);
      }
      if (byId.isNotEmpty) return byId.values.take(limit).toList();
    }
    return const [];
  }

  static bool referencesActiveContext(String question) {
    final q = question.trim().toLowerCase();
    if (RegExp(
      r'\b(these|those|them|both|all (?:two|three|four|of them)|'
      r'the (?:two|three|four)|above|previous (?:ones|sources|saves|links)|'
      r'that (?:one|save|source|link)|this (?:save|source|link))\b',
    ).hasMatch(q)) {
      return true;
    }
    return RegExp(
      r'\b(synthesi[sz]e|summari[sz]e|combine|compare)\b.*\b(all|together)\b',
    ).hasMatch(q);
  }

  static bool looksLikeFollowUp(String question) {
    final q = question.trim().toLowerCase();
    if (q.length <= 32 &&
        RegExp(
          r'\b(more|else|another|continue|expand|deeper|why|how so)\b',
        ).hasMatch(q)) {
      return true;
    }
    return RegExp(
      r'\b(what else|anything else|anything more|tell me more|show me more|go deeper|more like this|another one|another example|expand on that|continue from there)\b',
    ).hasMatch(q);
  }

  static bool asksForPreviousSources(String question) {
    final q = question.trim().toLowerCase();
    return RegExp(
      r'\b(same|that|this|those|previous|earlier|again|it|them)\b',
    ).hasMatch(q);
  }
}

/// Rejects model-generated prompts that are not supported by the retrieved
/// saves or that repeat a question the user has already asked.
class AskSuggestionGuard {
  static const _stopWords = <String>{
    'a',
    'about',
    'an',
    'and',
    'any',
    'are',
    'better',
    'can',
    'choose',
    'could',
    'did',
    'discuss',
    'do',
    'does',
    'explain',
    'examples',
    'for',
    'from',
    'help',
    'how',
    'i',
    'impact',
    'improve',
    'in',
    'into',
    'is',
    'it',
    'know',
    'like',
    'main',
    'me',
    'more',
    'my',
    'of',
    'on',
    'optimize',
    'or',
    'other',
    'our',
    'recommend',
    'recommended',
    'should',
    'since',
    'some',
    'specific',
    'support',
    'tell',
    'that',
    'the',
    'their',
    'them',
    'there',
    'these',
    'this',
    'those',
    'through',
    'to',
    'versus',
    'want',
    'we',
    'what',
    'when',
    'which',
    'who',
    'why',
    'with',
    'would',
    'you',
    'your',
  };

  static List<String> filter({
    required List<String> candidates,
    required List<SavedUrl> evidence,
    required List<ChatMessage> previousMessages,
    required String currentQuestion,
    String? topicText,
  }) {
    final evidenceTokens = _tokens(
      evidence
          .map(
            (url) => [
              url.title,
              url.summary ?? '',
              url.description,
              url.category,
              ...url.tags,
              url.userNotes ?? '',
              url.enrichmentJson ?? '',
            ].join(' '),
          )
          .join(' '),
    );
    final asked = <String>[
      ...previousMessages
          .where((message) => message.isUser)
          .map((message) => message.text),
      currentQuestion,
    ];
    final topicTokens = topicText == null
        ? const <String>{}
        : _tokens(topicText);
    final accepted = <String>[];

    for (final candidate in candidates) {
      final clean = candidate.trim();
      if (clean.isEmpty || !clean.endsWith('?')) continue;
      if (!_isGrounded(clean, evidenceTokens)) continue;
      if (topicTokens.isNotEmpty &&
          _tokens(clean).intersection(topicTokens).isEmpty) {
        continue;
      }
      if (asked.any((question) => _isNearDuplicate(clean, question))) continue;
      if (accepted.any((question) => _isNearDuplicate(clean, question))) {
        continue;
      }
      accepted.add(clean);
      if (accepted.length == 3) break;
    }
    return accepted;
  }

  static List<SavedUrl> citedEvidence({
    required ChatResponse answer,
    required List<SavedUrl> retrievedEvidence,
  }) {
    final cited = <int, SavedUrl>{};
    for (final section in answer.sections) {
      final index = section.sourceIndex - 1;
      if (index < 0 || index >= retrievedEvidence.length) continue;
      final source = retrievedEvidence[index];
      cited.putIfAbsent(source.id, () => source);
    }
    return cited.values.toList();
  }

  static bool _isGrounded(String question, Set<String> evidenceTokens) {
    final questionTokens = _tokens(question);
    if (questionTokens.isEmpty || evidenceTokens.isEmpty) return false;
    final matched = questionTokens.where(evidenceTokens.contains).length;
    return matched / questionTokens.length >= 0.7;
  }

  static bool _isNearDuplicate(String a, String b) {
    final normalizedA = _normalize(a);
    final normalizedB = _normalize(b);
    if (normalizedA == normalizedB) return true;

    final aTokens = _tokens(a);
    final bTokens = _tokens(b);
    if (aTokens.length < 2 || bTokens.length < 2) return false;
    final shared = aTokens.intersection(bTokens).length;
    return shared / min(aTokens.length, bTokens.length) >= 0.8;
  }

  static Set<String> _tokens(String value) => RegExp(r'[a-z0-9]+')
      .allMatches(value.toLowerCase())
      .map((match) => match.group(0)!)
      .where((token) => !_stopWords.contains(token))
      .map(_stem)
      .where((token) => token.length > 2 && !_stopWords.contains(token))
      .toSet();

  static String _normalize(String value) => RegExp(
    r'[a-z0-9]+',
  ).allMatches(value.toLowerCase()).map((match) => match.group(0)!).join(' ');

  static String _stem(String token) {
    if (token.length > 5 && token.endsWith('ies')) {
      return '${token.substring(0, token.length - 3)}y';
    }
    if (token.length > 5 && token.endsWith('ing')) {
      return token.substring(0, token.length - 3);
    }
    if (token.length > 4 && token.endsWith('ed')) {
      return token.substring(0, token.length - 2);
    }
    if (token.length > 4 && token.endsWith('s')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }
}

class AskAnswerActionPolicy {
  static final _libraryPresenceQuestion = RegExp(
    r'\b(did i save|have i saved|do i have (?:anything|something|any)|'
    r'any(?:thing)? saved (?:about|on)|any saves? (?:about|on)|'
    r'(?:is|are) there any(?:thing)? .+ in my (?:library|saves?))\b',
    caseSensitive: false,
  );

  static bool canSaveAnswer({
    required String question,
    required ChatAnswerType answerType,
    required ChatAnswerConfidence confidence,
    required int sourceCount,
  }) {
    if (sourceCount == 0 ||
        confidence == ChatAnswerConfidence.low ||
        confidence == ChatAnswerConfidence.insufficientEvidence ||
        answerType == ChatAnswerType.fallback ||
        answerType == ChatAnswerType.insufficientEvidence) {
      return false;
    }
    return !_libraryPresenceQuestion.hasMatch(question.trim());
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
          "I couldn't reach AI just now, but these are the closest saves I found.",
      isUser: false,
      sources: sections.map((section) => section.source).toList(),
      sections: sections,
      confidence: ChatAnswerConfidence.low,
      answerType: ChatAnswerType.fallback,
      canSaveAsNote: false,
    );
  }

  Future<void> ask(
    String question, {
    List<SavedUrl>? preloadedSources,
    String? originalQuestion,
    bool usePreloadedAsContext = false,
  }) async {
    if (question.trim().isEmpty) return;
    final previousMessages = state.messages;

    state = state.copyWith(
      messages: [
        ...previousMessages,
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
          usageService: usageService,
          gemini: gemini,
          previousMessages: previousMessages,
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

        _addBotMessage(
          text,
          sources: preloadedSources,
          confidence: ChatAnswerConfidence.medium,
          answerType: isPlan ? ChatAnswerType.plan : ChatAnswerType.synthesis,
          label: isPlan ? '📋 Plan' : null,
          originalQuestion: originalQuestion ?? question,
          canSaveAsNote: true,
        );
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
      final contextPlan = AskConversationPlanner.plan(
        question: question,
        allUrls: allUrls,
        semanticScored: semanticScored,
        limit: 6,
        previousMessages: previousMessages,
      );
      final contextUrls = contextPlan.contextUrls;

      if (contextUrls.isEmpty) {
        _addBotMessage(
          "I couldn't find any relevant saved links for that question. Try saving some links first!",
          confidence: ChatAnswerConfidence.insufficientEvidence,
          answerType: ChatAnswerType.insufficientEvidence,
        );
        return;
      }

      // Build conversation history from previous messages, cap at 6 exchanges.
      final recentHistory = _recentConversationHistory(previousMessages);

      final answer = await gemini.chat(
        question: question,
        contextUrls: contextUrls,
        conversationHistory: recentHistory,
        contextMode: ChatContextMode.retrieved,
      );
      final safeSuggestions = _guardSuggestions(
        answer: answer,
        evidence: contextUrls,
        previousMessages: previousMessages,
        currentQuestion: question,
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

      final action = _resolveAction(
        answer,
        question,
        hasProactiveTip: safeSuggestions.proactiveTip != null,
      );

      await usageService.incrementUsage(UsageFeature.ask);
      _ref.read(usageRevisionProvider.notifier).state++;

      _addBotMessage(
        answer.intro,
        sources: actionSources,
        sections: sections,
        proactiveTip: safeSuggestions.proactiveTip,
        followUpSuggestions: safeSuggestions.followUps,
        action: action,
        confidence: answer.confidence,
        answerType: answer.answerType,
        originalQuestion: question,
        canSaveAsNote: AskAnswerActionPolicy.canSaveAnswer(
          question: question,
          answerType: answer.answerType,
          confidence: answer.confidence,
          sourceCount: actionSources.length,
        ),
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

  ChatAction _resolveAction(
    ChatResponse response,
    String userQuestion, {
    required bool hasProactiveTip,
  }) {
    if (response.sections.isEmpty) return ChatAction.none;

    final q = userQuestion.toLowerCase();
    final asksForTravelPlan =
        q.contains('itinerary') ||
        q.contains('day trip') ||
        q.contains('travel plan') ||
        q.contains('trip plan') ||
        q.contains('route through') ||
        q.contains('places to visit') ||
        q.contains('day in ');
    if (asksForTravelPlan) return ChatAction.saveItinerary;

    if (q.contains('plan') ||
        q.contains('build') ||
        q.contains('project') ||
        q.contains('weekend')) {
      return ChatAction.buildPlan;
    }

    if (hasProactiveTip && response.sections.length >= 3) {
      return ChatAction.synthesize;
    }

    return ChatAction.saveToCollection;
  }

  List<Map<String, String>> _recentConversationHistory(
    List<ChatMessage> messages,
  ) {
    final history = messages
        .where((m) => m.text.trim().isNotEmpty)
        .map((m) => {'role': m.isUser ? 'User' : 'Glimpse', 'content': m.text})
        .toList();
    return history.length > 12 ? history.sublist(history.length - 12) : history;
  }

  ({String? proactiveTip, List<String> followUps}) _guardSuggestions({
    required ChatResponse answer,
    required List<SavedUrl> evidence,
    required List<ChatMessage> previousMessages,
    required String currentQuestion,
  }) {
    final citedEvidence = AskSuggestionGuard.citedEvidence(
      answer: answer,
      retrievedEvidence: evidence,
    );
    final topicText = [
      currentQuestion,
      answer.intro,
      ...answer.sections.expand(
        (section) => [section.heading, section.summary],
      ),
    ].join(' ');
    final followUps = AskSuggestionGuard.filter(
      candidates: answer.followUpSuggestions,
      evidence: citedEvidence,
      previousMessages: previousMessages,
      currentQuestion: currentQuestion,
      topicText: topicText,
    );
    final proactiveTip = answer.proactiveTip;
    final safeTip = proactiveTip == null
        ? const <String>[]
        : AskSuggestionGuard.filter(
            candidates: [proactiveTip],
            evidence: citedEvidence,
            previousMessages: previousMessages,
            currentQuestion: currentQuestion,
            topicText: topicText,
          );
    return (
      proactiveTip: safeTip.isEmpty ? null : safeTip.single,
      followUps: followUps,
    );
  }

  Future<void> _answerWithFixedContext({
    required String question,
    required List<SavedUrl> contextUrls,
    required UsageService usageService,
    required GeminiService gemini,
    required List<ChatMessage> previousMessages,
  }) async {
    final recentHistory = _recentConversationHistory(previousMessages);

    final answer = await gemini.chat(
      question: question,
      contextUrls: contextUrls,
      conversationHistory: recentHistory,
      contextMode: ChatContextMode.focusedSave,
    );
    final safeSuggestions = _guardSuggestions(
      answer: answer,
      evidence: contextUrls,
      previousMessages: previousMessages,
      currentQuestion: question,
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

    _addBotMessage(
      answer.intro,
      sources: sources.isEmpty ? contextUrls.take(1).toList() : sources,
      sections: sections,
      proactiveTip: safeSuggestions.proactiveTip,
      followUpSuggestions: safeSuggestions.followUps,
      confidence: answer.confidence,
      answerType: answer.answerType,
      originalQuestion: question,
      canSaveAsNote: AskAnswerActionPolicy.canSaveAnswer(
        question: question,
        answerType: answer.answerType,
        confidence: answer.confidence,
        sourceCount: sources.isEmpty ? contextUrls.length : sources.length,
      ),
    );
  }

  Future<bool> saveAnswerAsNote(String messageId) async {
    final index = state.messages.indexWhere(
      (message) => message.id == messageId,
    );
    if (index == -1) return false;

    final message = state.messages[index];
    if (message.isUser ||
        message.noteSaved ||
        !message.canSaveAsNote ||
        message.sources.isEmpty) {
      return false;
    }

    final question =
        _questionBefore(index) ?? message.originalQuestion ?? 'Ask Glimpse';
    final uniqueSources = <int, SavedUrl>{};
    for (final source in message.sources) {
      uniqueSources[source.id] = source;
    }

    var allSaved = true;
    final notesService = _ref.read(savedNotesServiceProvider);
    for (final source in uniqueSources.values) {
      final sectionsForSource = message.sections
          .where((section) => section.source.id == source.id)
          .toList();
      final details = sectionsForSource
          .map((section) => '${section.heading}\n${section.summary}')
          .where((line) => line.trim().isNotEmpty)
          .join('\n\n');
      final body = [
        message.text.trim(),
        if (details.isNotEmpty) details,
      ].join('\n\n');
      final saved = await notesService.saveAskNote(
        urlId: source.id,
        sourceMessageId: message.id,
        question: question,
        body: body,
      );
      allSaved = allSaved && saved;
    }

    if (!allSaved) return false;
    _ref.invalidate(urlStreamProvider);

    state = state.copyWith(
      messages: [
        ...state.messages.sublist(0, index),
        message.copyWith(noteSaved: true),
        ...state.messages.sublist(index + 1),
      ],
    );
    return true;
  }

  String? _questionBefore(int messageIndex) {
    for (var i = messageIndex - 1; i >= 0; i--) {
      final message = state.messages[i];
      if (message.isUser && message.text.trim().isNotEmpty) {
        return message.text.trim();
      }
    }
    return null;
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
    List<String> followUpSuggestions = const [],
    ChatAction action = ChatAction.none,
    String? label,
    String? originalQuestion,
    ChatAnswerConfidence confidence = ChatAnswerConfidence.medium,
    ChatAnswerType answerType = ChatAnswerType.direct,
    bool canSaveAsNote = false,
  }) {
    final citedSources = <int, SavedUrl>{};
    for (final source in sources) {
      citedSources[source.id] = source;
    }
    for (final section in sections) {
      citedSources[section.source.id] = section.source;
    }
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          text: text,
          isUser: false,
          sources: citedSources.values.toList(),
          citedSourceIds: citedSources.keys.toList(),
          sections: sections,
          proactiveTip: proactiveTip,
          followUpSuggestions: followUpSuggestions,
          action: action,
          label: label,
          originalQuestion: originalQuestion,
          confidence: confidence,
          answerType: answerType,
          canSaveAsNote: canSaveAsNote && citedSources.isNotEmpty,
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
