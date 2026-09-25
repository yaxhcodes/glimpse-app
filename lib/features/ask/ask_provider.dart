import '../library/library_entity.dart';
import '../../core/services/ask_query_plan.dart';
import 'dart:async';
import 'dart:convert';
import '../../core/models/ask_conversation.dart';
import '../../core/services/ask_conversation_store.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/ask_library_context.dart';
import 'dart:developer' as developer;
import '../../core/services/demo_seed_service.dart';
import '../../l10n/l10n.dart';
import 'dart:math' show Random, min;

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final bool incomplete;
  final bool isResultList;

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
    this.incomplete = false,
    this.isResultList = false,
  }) : citedSourceIds =
           citedSourceIds ?? sources.map((source) => source.id).toList(),
       id = id ?? _generateId();

  ChatMessage copyWith({
    bool? actionConsumed,
    bool? noteSaved,
    String? text,
    bool? incomplete,
  }) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
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
      incomplete: incomplete ?? this.incomplete,
      isResultList: isResultList,
    );
  }
}

class ChatMessageSection {
  final String heading;
  final String summary;
  final SavedUrl source;
  final int citationIndex;

  const ChatMessageSection({
    required this.heading,
    required this.summary,
    required this.source,
    this.citationIndex = 0,
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
    final referencesContext =
        referencesActiveContext(question) ||
        RegExp(
          r'^(why[?!]?|how so[?!]?|make it (shorter|longer)|explain more|tell me more about that|the (first|second|third|fourth) one)[?.!]*$',
          caseSensitive: false,
        ).hasMatch(question.trim());
    final isFollowUp = looksLikeFollowUp(question) || referencesContext;
    final allowRepeats = referencesContext || asksForPreviousSources(question);
    final citedIds = citedSourceIds(previousMessages);
    final wantsMore = RegExp(
      r'\b(what else|anything else|show more|another|other saves|more links)\b',
      caseSensitive: false,
    ).hasMatch(question);
    final suppressedIds = wantsMore && !allowRepeats ? citedIds : <int>{};

    final candidateUrls = suppressedIds.isEmpty
        ? allUrls
        : allUrls.where((url) => !suppressedIds.contains(url.id)).toList();
    final allowedIds = candidateUrls.map((s) => s.id).toSet();
    final eligibleSemantic = semanticScored
        .where((entry) => allowedIds.contains(entry.key.id))
        .toList();
    final candidateSemantic = suppressedIds.isEmpty
        ? eligibleSemantic
        : eligibleSemantic
              .where((entry) => !suppressedIds.contains(entry.key.id))
              .toList();

    var contextUrls = referencesContext
        ? latestContext(previousMessages, limit: limit)
        : const <SavedUrl>[];

    final liveById = {for (final save in allUrls) save.id: save};
    contextUrls = contextUrls
        .map((s) => liveById[s.id])
        .whereType<SavedUrl>()
        .toList();
    final ordinal = RegExp(
      r'\b(first|second|third|fourth)\b',
      caseSensitive: false,
    ).firstMatch(question);
    if (referencesContext && ordinal != null) {
      final index = [
        'first',
        'second',
        'third',
        'fourth',
      ].indexOf(ordinal.group(1)!.toLowerCase());
      contextUrls = index < contextUrls.length ? [contextUrls[index]] : [];
    }
    if (contextUrls.isEmpty) {
      contextUrls = AskRetrievalService.retrieve(
        query: wantsMore
            ? '${previousMessages.where((m) => m.isUser).lastOrNull?.text ?? ''} $question'
            : question,
        allUrls: candidateUrls,
        semanticScored: candidateSemantic,
        limit: limit,
      );
    }

    if (contextUrls.isEmpty && isFollowUp && !wantsMore) {
      contextUrls = activeContext(
        previousMessages,
        limit: limit,
      ).map((s) => liveById[s.id]).whereType<SavedUrl>().toList();
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
      r'^(why[?!]?|how so[?!]?|make it (shorter|longer)|explain more|tell me more about that|the (first|second|third|fourth) one)[?.!]*$',
    ).hasMatch(q)) {
      return true;
    }
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
    bool referencesValidated = false,
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
      if (clean.isEmpty || !(clean.endsWith('?') || clean.endsWith('？'))) {
        continue;
      }
      if (!referencesValidated && !_isGrounded(clean, evidenceTokens)) continue;
      if (!referencesValidated &&
          topicTokens.isNotEmpty &&
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

  static Set<String> _tokens(String value) => RegExp(r'[\p{L}\p{N}]+', unicode: true)
      .allMatches(value.toLowerCase())
      .map((match) => match.group(0)!)
      .where((token) => !_stopWords.contains(token))
      .map(_stem)
      .where((token) => token.length > 2 && !_stopWords.contains(token))
      .toSet();

  static String _normalize(String value) => RegExp(
    r'[\p{L}\p{N}]+', unicode: true,
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

class AskLocalAnswerCopy {
  static final _topicQuestion = RegExp(
    r'^(?:what did i save|did i save (?:anything|something)|what do i have|show me (?:my )?saves?)\s+(?:about|on)\s+(.+?)[?.!]*$',
    caseSensitive: false,
  );

  static String intro(String question, int sourceCount) {
    final normalizedQuestion = question.trim();
    final match = _topicQuestion.firstMatch(normalizedQuestion);
    final topic = match?.group(1)?.trim();
    final count = sourceCount == 1
        ? 'one relevant save'
        : '$sourceCount relevant saves';

    if (topic != null && topic.isNotEmpty) {
      return 'You have $count about $topic. This answer uses summaries already saved on this device.';
    }
    return 'I found $count on this device. Here is what the saved summaries say about your question.';
  }
}

class AskNotifier extends StateNotifier<AskState> {
  final _passageIndex = AskPassageIndex();
  final _entityIndex = LibraryIndexCache();
  AskQueryPlan? _activeQueryPlan;
  int _generation = 0;
  CancelToken? _cancelToken;
  String? _partialId;

  void stop() {
    _generation++;
    _cancelToken?.cancel();
    _partialId = null;
    state = state.copyWith(isLoading: false);
  }

  void retryLast() {
    if (state.isLoading) return;
    final index = state.messages.lastIndexWhere((m) => m.isUser);
    if (index < 0) return;
    final question = state.messages[index].text;
    final failed = state.messages
        .skip(index + 1)
        .every((m) => m.incomplete || m.answerType == ChatAnswerType.fallback);
    final retryId = failed ? state.messages[index].id : null;
    state = state.copyWith(messages: state.messages.take(index).toList());
    ask(question, retryTurnId: retryId);
  }

  void editAndResend(String id, String question) {
    stop();
    final index = state.messages.indexWhere((m) => m.id == id && m.isUser);
    if (index < 0) return;
    state = state.copyWith(messages: state.messages.take(index).toList());
    ask(question);
  }

  void _partial(String text, int generation) {
    if (!mounted || generation != _generation) return;
    _partialId ??= const Uuid().v4();
    final message = ChatMessage(
      id: _partialId,
      text: text,
      isUser: false,
      incomplete: true,
    );
    state = state.copyWith(
      messages: [...state.messages.where((m) => m.id != _partialId), message],
    );
  }

  final Ref _ref;

  late final AskConversationStore _store;
  AskConversation? _conversation;
  Timer? _persistTimer;
  Future<void> _writes = Future.value();
  late final Future<void> ready;

  AskNotifier(this._ref) : super(const AskState()) {
    _store = AskConversationStore(_ref.read(isarServiceProvider));
    ready = _restoreLatest();
    addListener((next) {
      if (next.messages.isEmpty) return;
      if (!next.isLoading) {
        _persistTimer?.cancel();
        _persistTimer = null;
        _persist();
      } else {
        _persistTimer ??= Timer(const Duration(milliseconds: 700), () {
          _persistTimer = null;
          if (mounted) _persist();
        });
      }
    }, fireImmediately: false);
  }

  Future<void> _restoreLatest() async {
    final generation = _generation;
    try {
      final chats = await _store.list();
      if (mounted &&
          generation == _generation &&
          state.messages.isEmpty &&
          chats.isNotEmpty) {
        await openConversation(chats.first);
      }
    } catch (e, stack) {
      developer.log(
        'Could not restore Ask history',
        name: 'Ask',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<List<AskConversation>> conversations() async {
    await _writes;
    return _store.list();
  }

  String? _focusedUrl;
  String? get focusedUrl => _focusedUrl;
  void setFocusedSource(SavedUrl? source) {
    _focusedUrl = source?.rawUrl;
  }

  void _persist() {
    if (state.messages.isEmpty) return;
    final now = DateTime.now();
    final first = state.messages.first.text;
    _conversation ??= AskConversation()
      ..key = const Uuid().v4()
      ..title = first.length > 70 ? first.substring(0, 70) : first
      ..createdAt = now;
    final record = AskConversation()
      ..id = _conversation!.id
      ..key = _conversation!.key
      ..title = _conversation!.title
      ..createdAt = _conversation!.createdAt
      ..updatedAt = now
      ..focusedUrl = _focusedUrl
      ..messagesJson = jsonEncode(
        state.messages
            .map(
              (m) => {
                'id': m.id,
                'text': m.text,
                'isUser': m.isUser,
                'incomplete': m.incomplete,
                'isResultList': m.isResultList,
                'queryPlan': _activeQueryPlan?.toJson(),
                'sources': m.sources.map((source) => source.rawUrl).toList(),
                'sections': m.sections
                    .map(
                      (section) => {
                        'heading': section.heading,
                        'citationIndex': section.citationIndex,
                        'summary': section.summary,
                        'url': section.source.rawUrl,
                      },
                    )
                    .toList(),
                'followUps': m.followUpSuggestions,
                'answerType': m.answerType.name,
                'confidence': m.confidence.name,
                'action': m.action.name,
                'originalQuestion': m.originalQuestion,
                'noteSaved': m.noteSaved,
                'canSaveAsNote': m.canSaveAsNote,
                'actionConsumed': m.actionConsumed,
              },
            )
            .toList(),
      );
    _writes = _writes.then((_) => _store.save(record)).catchError((
      Object e,
      StackTrace stack,
    ) {
      developer.log(
        'Could not persist Ask history',
        name: 'Ask',
        error: e,
        stackTrace: stack,
      );
    });
  }

  Future<void> openConversation(AskConversation chat) async {
    stop();
    final generation = _generation;
    final saves = await _ref.read(isarServiceProvider).getAllUrls();
    if (!mounted || generation != _generation) return;
    final byUrl = {for (final source in saves) source.rawUrl: source};
    final raw = jsonDecode(chat.messagesJson) as List;
    final messages = <ChatMessage>[];
    for (final item in raw.whereType<Map>()) {
      final sources = (item['sources'] as List? ?? [])
          .map((url) => byUrl[url])
          .whereType<SavedUrl>()
          .toList();
      final sections = <ChatMessageSection>[];
      for (final section
          in (item['sections'] as List? ?? []).whereType<Map>()) {
        final source = byUrl[section['url']];
        if (source != null) {
          sections.add(
            ChatMessageSection(
              heading: section['heading'] as String? ?? '',
              citationIndex: section['citationIndex'] as int? ?? 0,
              summary: section['summary'] as String? ?? '',
              source: source,
            ),
          );
        }
      }
      messages.add(
        ChatMessage(
          id: item['id'] as String?,
          text: item['text'] as String? ?? '',
          isUser: item['isUser'] == true,
          incomplete: item['incomplete'] == true,
          isResultList: item['isResultList'] == true,
          sources: sources,
          sections: sections,
          followUpSuggestions: (item['followUps'] as List? ?? [])
              .whereType<String>()
              .toList(),
          answerType:
              ChatAnswerType.values
                  .where((v) => v.name == item['answerType'])
                  .firstOrNull ??
              ChatAnswerType.direct,
          confidence:
              ChatAnswerConfidence.values
                  .where((v) => v.name == item['confidence'])
                  .firstOrNull ??
              ChatAnswerConfidence.medium,
          action:
              ChatAction.values
                  .where((v) => v.name == item['action'])
                  .firstOrNull ??
              ChatAction.none,
          originalQuestion: item['originalQuestion'] as String?,
          noteSaved: item['noteSaved'] == true,
          canSaveAsNote: item['canSaveAsNote'] == true && sources.isNotEmpty,
          actionConsumed: item['actionConsumed'] == true,
        ),
      );
    }
    final lastPlan = raw.whereType<Map>().lastOrNull?['queryPlan'];
    _activeQueryPlan = lastPlan is Map<String, dynamic>
        ? AskQueryPlan.fromJson(lastPlan, '')
        : null;
    _conversation = chat;
    _focusedUrl = chat.focusedUrl;
    state = AskState(messages: messages);
  }

  Future<void> deleteConversation(AskConversation chat) async {
    if (_conversation?.key == chat.key) {
      clearHistory();
    }
    await _writes;
    await _store.delete(chat.id);
  }

  Future<void> renameConversation(AskConversation chat, String title) async {
    if (title.trim().isEmpty) return;
    chat.title = title.trim();
    if (_conversation?.key == chat.key) _conversation!.title = chat.title;
    await _writes;
    await _store.save(chat);
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    _persist();
    _cancelToken?.cancel();
    super.dispose();
  }

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
      final indexed = _passageIndex.passages(question, url.id, maxChars: 900);
      final sourceSummary = indexed.isEmpty
          ? (url.summary ?? url.description).trim()
          : indexed.map((p) => p.text).join('\n');
      return ChatMessageSection(
        heading: url.title.isNotEmpty ? url.title : url.domain,
        summary: sourceSummary.isNotEmpty
            ? sourceSummary
            : 'This saved link appears relevant to "$question", but there is not enough extracted text yet to summarize it better.',
        source: url,
      );
    }).toList();

    return ChatMessage(
      text: AskLocalAnswerCopy.intro(question, sections.length),
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
    String? retryTurnId,
  }) async {
    await ready;
    if (!mounted || question.trim().isEmpty || state.isLoading) return;
    final generation = ++_generation;
    final turnId = const Uuid().v4();
    final logicalTurnId = retryTurnId ?? turnId;
    final timer = Stopwatch()..start();
    var firstToken = false;
    _cancelToken = CancelToken();
    final previousMessages = state.messages;

    state = state.copyWith(
      messages: [
        ...previousMessages,
        ChatMessage(id: logicalTurnId, text: question, isUser: true),
      ],
      isLoading: true,
      error: null,
    );

    // Instant local response for greetings — no API call, no loading flash.
    if (_isGreeting(question)) {
      final reply = _greetingReplies[Random().nextInt(_greetingReplies.length)];
      _addBotMessage(generation, reply);
      return;
    }

    final isarService = _ref.read(isarServiceProvider);

    try {
      final hasSampleContext =
          preloadedSources?.any(
                (url) => DemoSeedService.isDemoUrl(url.rawUrl),
              ) ==
              true ||
          await DemoSeedService.demoId() != null;
      if (hasSampleContext) {
        final sources = preloadedSources?.isNotEmpty == true
            ? preloadedSources!
            : await isarService.getAllUrls();
        if (sources.isNotEmpty &&
            sources.every((url) => DemoSeedService.isDemoUrl(url.rawUrl))) {
          final l = await loadBackgroundLocalizations();
          _addBotMessage(
            generation,
            '${l.obExample}\n\n${l.obSummary}',
            sources: sources,
            answerType: ChatAnswerType.fallback,
            canSaveAsNote: false,
          );
          return;
        }
        preloadedSources = preloadedSources
            ?.where((url) => !DemoSeedService.isDemoUrl(url.rawUrl))
            .toList();
      }
      final library = AskLibrarySnapshot(
        await isarService.getAllUrls(),
        await isarService.getAllCollections(),
      );
      if (!mounted || generation != _generation) return;
      if (preloadedSources == null && _focusedUrl != null) {
        preloadedSources = library.saves
            .where((s) => s.rawUrl == _focusedUrl)
            .toList();
        if (preloadedSources.isEmpty) {
          _addBotMessage(
            generation,
            (await loadBackgroundLocalizations()).askNoMatch,
            confidence: ChatAnswerConfidence.insufficientEvidence,
          );
          return;
        }
        usePreloadedAsContext = true;
      }
      final browse = RegExp(
        r'^(show|list|browse)( me)? (all( of)? )?(my |our |the )?(saved )?(links|saves|bookmarks)( in (my |the )?library)?[.!?]*$',
        caseSensitive: false,
      ).hasMatch(question.trim());
      if (browse) {
        final l = await loadBackgroundLocalizations();
        _addBotMessage(
          generation,
          l.askExactLinkCount(library.saves.length),
          sources: library.saves,
          isResultList: true,
          confidence: ChatAnswerConfidence.high,
        );
        return;
      }
      final entityCount = RegExp(
        r'^(?:how many|count)(?: saved| my)? (books|movies|films|shows|places|songs)(?: do (?:i|we) have| have i saved| are (?:there|in my library))?[?.!]*$',
        caseSensitive: false,
      ).firstMatch(question.trim());
      if (entityCount != null) {
        final l = await loadBackgroundLocalizations();
        final kind = switch (entityCount.group(1)!.toLowerCase()) {
          'books' => LibraryEntityKind.book,
          'places' => LibraryEntityKind.place,
          'songs' => LibraryEntityKind.music,
          _ => LibraryEntityKind.movie,
        };
        final label = switch (kind) {
          LibraryEntityKind.book => l.libraryBooks,
          LibraryEntityKind.movie => l.libraryMoviesShows,
          LibraryEntityKind.place => l.libraryPlaces,
          LibraryEntityKind.music => l.libraryMusic,
        };
        final count = _entityIndex.build(library.saves).ofKind(kind).length;
        _addBotMessage(
          generation,
          l.askEntityCount(count, label),
          confidence: ChatAnswerConfidence.high,
        );
        return;
      }
      final exactMatches = library.exactCountMatches(question);
      if (exactMatches != null) {
        final l = await loadBackgroundLocalizations();
        _addBotMessage(
          generation,
          l.askExactLinkCount(exactMatches.length),
          confidence: ChatAnswerConfidence.high,
        );
        return;
      }
      _passageIndex.refresh(library.saves, library.collections);
      if (await _ref.read(networkStatusServiceProvider).isDefinitelyOffline()) {
        final localContext = preloadedSources?.isNotEmpty == true
            ? preloadedSources!.take(3).toList()
            : _passageIndex.search(question, library.saves).take(3).toList();
        if (!mounted || generation != _generation) return;
        if (localContext.isEmpty) {
          _addBotMessage(
            generation,
            "I couldn't find a relevant save for that question on this device.",
            confidence: ChatAnswerConfidence.insufficientEvidence,
            answerType: ChatAnswerType.insufficientEvidence,
          );
        } else {
          state = state.copyWith(
            messages: [
              ...state.messages,
              _buildLocalFallbackAnswer(question, localContext),
            ],
            isLoading: false,
          );
        }
        return;
      }

      // Usage-based gating: free users have a monthly Ask allowance. Pro
      // conversations use the gateway's separate fair-use rate limits.
      final isPro = _ref.read(isProUserProvider);
      final usageService = _ref.read(usageServiceProvider);
      final hasReached = await usageService.hasReachedLimit(
        UsageFeature.ask,
        isPro,
      );
      if (!mounted || generation != _generation) return;
      if (hasReached) {
        developer.log('Ask limit reached (isPro=$isPro)', name: 'AskNotifier');
        state = state.copyWith(
          isLoading: false,
          limitReached: UsageLimitHit.ask,
        );
        return;
      }

      if (!mounted || generation != _generation) return;
      final gemini = _ref.read(geminiServiceProvider);
      if (gemini == null) {
        final matches = _passageIndex
            .search(question, library.saves)
            .take(3)
            .toList();
        if (matches.isNotEmpty) {
          state = state.copyWith(
            messages: [
              ...state.messages,
              _buildLocalFallbackAnswer(question, matches),
            ],
            isLoading: false,
          );
        } else {
          _addBotMessage(
            generation,
            (await loadBackgroundLocalizations()).askNoMatch,
            confidence: ChatAnswerConfidence.insufficientEvidence,
          );
        }
        return;
      }

      // Retrieve relevant context with lexical matches first and semantic
      // matches as a recall boost. Ask should never force unrelated nearest
      // neighbors into the model just because embeddings exist.
      final embeddings = _ref.read(embeddingServiceProvider);
      var allUrls = library.saves;
      var searchQuestion = question;
      if (RegExp(
        r'\b(what else|anything else|show more|another)\b',
        caseSensitive: false,
      ).hasMatch(question)) {
        searchQuestion =
            '${previousMessages.where((m) => m.isUser).lastOrNull?.text ?? ''} $question';
      }
      final continuesContext =
          AskConversationPlanner.looksLikeFollowUp(question) ||
          AskConversationPlanner.referencesActiveContext(question);
      if (!continuesContext) _activeQueryPlan = null;
      if (_activeQueryPlan != null) {
        final active = _activeQueryPlan!;
        if (active.domain != null) {
          allUrls = allUrls.where((s) => s.domain == active.domain).toList();
        }
        final collection = library.collections
            .where((c) => c.name == active.collection)
            .firstOrNull;
        if (collection != null) {
          allUrls = allUrls
              .where((s) => collection.urlIds.contains(s.id))
              .toList();
        }
        if (active.after != null) {
          allUrls = allUrls
              .where((s) => !s.savedAt.isBefore(active.after!))
              .toList();
        }
        if (active.before != null) {
          allUrls = allUrls
              .where((s) => s.savedAt.isBefore(active.before!))
              .toList();
        }
        searchQuestion = '${active.query} $question';
      }

      if (AskQueryPlan.needsPlanning(
            question,
            hasHistory: previousMessages.isNotEmpty,
          ) &&
          !AskConversationPlanner.referencesActiveContext(question)) {
        try {
          final queryPlan = await gemini.planAskQuery(
            question: question,
            turnId: turnId,
            libraryFacts: library.promptFacts(),
            history: _recentConversationHistory(previousMessages).reversed
                .take(4)
                .toList()
                .reversed
                .map((m) => m['content'])
                .join('\n'),
          );
          if (!mounted || generation != _generation) return;
          searchQuestion = queryPlan.query;
          _activeQueryPlan = queryPlan;
          if (queryPlan.domain != null &&
              library.saves.any((s) => s.domain == queryPlan.domain)) {
            allUrls = allUrls
                .where((s) => s.domain == queryPlan.domain)
                .toList();
          }
          final collection = library.collections
              .where((c) => c.name == queryPlan.collection)
              .firstOrNull;
          if (collection != null) {
            allUrls = allUrls
                .where((s) => collection.urlIds.contains(s.id))
                .toList();
          }
          if (queryPlan.after != null) {
            allUrls = allUrls
                .where((s) => !s.savedAt.isBefore(queryPlan.after!))
                .toList();
          }
          if (queryPlan.before != null) {
            allUrls = allUrls
                .where((s) => s.savedAt.isBefore(queryPlan.before!))
                .toList();
          }
        } catch (e) {
          developer.log(
            'Ask planning unavailable; using local retrieval',
            name: 'Ask',
            error: e.runtimeType,
          );
        }
      }

      var semanticScored = <MapEntry<SavedUrl, double>>[];
      if (embeddings != null &&
          preloadedSources?.isNotEmpty != true &&
          !AskConversationPlanner.referencesActiveContext(question)) {
        try {
          final queryEmbedding = await embeddings.generateEmbedding(
            searchQuestion,
          );
          if (queryEmbedding.isNotEmpty) {
            semanticScored = await isarService.semanticSearchScored(
              queryEmbedding,
              limit: 40,
              minScore: AskRetrievalService.semanticMinScore,
            );
          }
        } on EmbeddingException {
          semanticScored = const [];
        }
      }
      if (!mounted || generation != _generation) return;
      final contextPlan = AskConversationPlanner.plan(
        question: question,
        allUrls: allUrls,
        semanticScored: semanticScored,
        limit: 40,
        previousMessages: previousMessages,
      );
      final passageHits =
          AskConversationPlanner.referencesActiveContext(question)
          ? const <SavedUrl>[]
          : _passageIndex
                .search(searchQuestion, allUrls)
                .where((s) => !contextPlan.suppressedSourceIds.contains(s.id))
                .toList();
      final candidates = <int, SavedUrl>{};
      final ranks = <int, double>{};
      for (final ranking in [contextPlan.contextUrls, passageHits]) {
        for (var i = 0; i < ranking.length; i++) {
          final source = ranking[i];
          candidates[source.id] = source;
          ranks.update(
            source.id,
            (score) => score + 1 / (60 + i),
            ifAbsent: () => 1 / (60 + i),
          );
        }
      }
      final ranked = candidates.values.toList()
        ..sort((a, b) => ranks[b.id]!.compareTo(ranks[a.id]!));
      final retrievedUrls = ranked.take(12).toList();

      final preloadedIds =
          preloadedSources?.map((s) => s.id).toSet() ?? <int>{};
      final contextUrls = preloadedIds.isEmpty
          ? retrievedUrls
          : library.saves
                .where((s) => preloadedIds.contains(s.id))
                .take(12)
                .toList();
      final metadataQuestion =
          RegExp(
            r'\b(count|total|top|most|overview|themes|patterns)\b',
            caseSensitive: false,
          ).hasMatch(question) &&
          RegExp(
            r'\b(library|saves|saved|links|bookmarks|collections|categories|domains)\b',
            caseSensitive: false,
          ).hasMatch(question);
      if (contextUrls.isEmpty && !metadataQuestion) {
        _addBotMessage(
          generation,
          (await loadBackgroundLocalizations()).askNoMatch,
          confidence: ChatAnswerConfidence.insufficientEvidence,
          answerType: ChatAnswerType.insufficientEvidence,
        );
        return;
      }

      developer.log(
        'Ask retrievalMs=${timer.elapsedMilliseconds}, evidenceSources=${contextUrls.length}, totalSaves=${library.saves.length}',
        name: 'Ask',
      );
      // Keep recent complete turns and a compact record of earlier questions.
      final recentHistory = _recentConversationHistory(previousMessages);

      final answer = await gemini.chat(
        question: question,
        contextUrls: contextUrls,
        conversationHistory: recentHistory,
        contextMode: usePreloadedAsContext
            ? ChatContextMode.focusedSave
            : ChatContextMode.retrieved,
        turnId: turnId,
        cancelToken: _cancelToken,
        onPartial: (text) {
          if (!firstToken) {
            firstToken = true;
            developer.log(
              'Ask firstTextMs=${timer.elapsedMilliseconds}',
              name: 'Ask',
            );
          }
          _partial(text, generation);
        },
        libraryFacts: library.promptFacts(),
        evidencePassages: {
          for (final source in contextUrls)
            source.id: _passageIndex
                .passages(question, source.id)
                .map((p) => p.text)
                .join("\n"),
        },
      );
      if (!mounted || generation != _generation) return;
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
              citationIndex: section.sourceIndex,
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

      if (answer.answerType != ChatAnswerType.fallback) {
        await usageService.incrementUsage(
          UsageFeature.ask,
          isPro: isPro,
          requestId: '$logicalTurnId-quota',
        );
        _ref.read(usageRevisionProvider.notifier).state++;
      }

      _addBotMessage(
        generation,
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
      if (!mounted || generation != _generation) return;
      if (_partialId != null) {
        stop();
        return;
      }
      developer.log('Ask AI error: $e', name: 'AskNotifier');
      // Try local fallback for any AI failure.
      try {
        final fallbackUrls = await _fallbackContext(question);
        if (!mounted || generation != _generation) return;
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
      } catch (fallbackError, stack) {
        developer.log(
          'Ask local fallback failed',
          name: 'Ask',
          error: fallbackError,
          stackTrace: stack,
        );
      }
      _addBotMessage(
        generation,
        _friendlyErrorMessage(e),
        answerType: ChatAnswerType.fallback,
      );
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
        .map(
          (m) => {
            'role': m.isUser ? 'User' : 'Glimpse',
            'content': [
              m.text,
              ...m.sections.map((s) => '${s.heading}: ${s.summary}'),
              if (m.sources.isNotEmpty)
                'Sources: ${m.sources.map((s) => '${s.id}: ${s.title}').join('; ')}',
            ].join('\n'),
          },
        )
        .toList();
    if (history.length <= 12) return history;
    final earlier = messages
        .take(messages.length - 12)
        .where((m) => m.isUser)
        .map((m) => m.text)
        .join('; ');
    return [
      {
        'role': 'Context',
        'content':
            'Earlier questions: ${earlier.length > 2000 ? earlier.substring(earlier.length - 2000) : earlier}',
      },
      ...history.sublist(history.length - 12),
    ];
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
      referencesValidated: answer.followUpsHaveReferences,
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
    return urls;
  }

  void _addBotMessage(
    int generation,
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
    bool isResultList = false,
  }) {
    if (!mounted || generation != _generation) return;
    final citedSources = <int, SavedUrl>{};
    for (final source in sources) {
      citedSources[source.id] = source;
    }
    for (final section in sections) {
      citedSources[section.source.id] = section.source;
    }
    state = state.copyWith(
      messages: [
        ...state.messages.where((m) => m.id != _partialId),
        ChatMessage(
          text: text,
          isResultList: isResultList,
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
    _partialId = null;
  }

  Future<void> resetForDataClear() async {
    clearHistory();
    await _writes;
  }

  void clearHistory() {
    _persistTimer?.cancel();
    _persistTimer = null;
    _persist();
    stop();
    _conversation = null;
    _focusedUrl = null;
    _activeQueryPlan = null;
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
