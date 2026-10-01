import 'ask_answer_text.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:glimpse/shared/widgets/app_menu.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_assets.dart';
import '../../core/models/saved_url.dart';
import '../../core/models/place_itinerary.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/models/ask_conversation.dart';
import '../../core/models/user_collection.dart';
import '../../core/providers/user_display_name_provider.dart';
import '../../core/services/usage_service.dart';
import '../../shared/widgets/upgrade_gate.dart';
import '../../shared/widgets/usage_badge.dart';
import '../../core/database/isar_service.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/gemini_service.dart' show ChatAnswerType;
import '../../core/services/analytics_service.dart';
import '../../core/services/title_resolver.dart';
import '../home/home_provider.dart';
import '../collections/collection_visual.dart';
import '../collections/collections_provider.dart';
import '../collections/create_collection_sheet.dart';
import '../library/library_entity.dart';
import '../library/library_provider.dart';
import '../library/place_itinerary_provider.dart';
import '../../shared/widgets/entrance_motion.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/expressive_tap_scale.dart';
import '../../shared/theme/app_motion.dart';
import '../../shared/theme/app_icons.dart';
import 'ask_itinerary_builder.dart';
import 'ask_empty_suggestions_provider.dart';
import 'ask_greeting_service.dart';
import 'ask_provider.dart';
import '../../l10n/l10n.dart';
import '../../core/services/app_haptics.dart';

part 'ask_conversation_widgets.dart';

/// Max width for chat column on large phones / tablets (readable line length).
const double _kChatMaxWidth = 680;

class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({
    super.key,
    this.embedded = false,
    this.initialSource,
    this.initialPrompt,
    this.autofocus = false,
  });

  final bool embedded;
  final SavedUrl? initialSource;
  final String? initialPrompt;
  final bool autofocus;

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  /// Cached greeting future so [FutureBuilder] does not flash on rebuilds.
  Future<AskGreeting>? _greetingFuture;
  String? _lastGreetingName;
  int? _lastGreetingCount;
  bool _clearedForInitialSource = false;
  SavedUrl? _attachedSource;
  bool _nearBottom = true;

  /// The question being edited in the composer; sending replaces it.
  ChatMessage? _editing;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final near = _scrollController.position.extentAfter < 160;
      if (near != _nearBottom && mounted) setState(() => _nearBottom = near);
    });
    _attachedSource = widget.initialSource;
    if (widget.initialSource == null && !widget.autofocus) {
      Future<void>(() async {
        final notifier = ref.read(askProvider.notifier);
        await notifier.ready;
        final saves = await ref.read(isarServiceProvider).getAllUrls();
        if (mounted) {
          setState(
            () => _attachedSource = saves
                .where((s) => s.rawUrl == notifier.focusedUrl)
                .firstOrNull,
          );
        }
      });
    }

    if (widget.autofocus ||
        widget.initialSource != null ||
        widget.initialPrompt?.trim().isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _clearedForInitialSource) return;
        _clearedForInitialSource = true;
        ref.read(askProvider.notifier).clearHistory();
        ref.read(askProvider.notifier).setFocusedSource(widget.initialSource);
        final prompt = widget.initialPrompt?.trim() ?? '';
        if (prompt.isNotEmpty) {
          _controller.value = TextEditingValue(
            text: prompt,
            selection: TextSelection.collapsed(offset: prompt.length),
          );
        }
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSource?.id != widget.initialSource?.id) {
      _attachedSource = widget.initialSource;
      _clearedForInitialSource = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSendMessage(
    String text, {
    List<SavedUrl>? preloadedSources,
    String? originalQuestion,
  }) {
    FocusScope.of(context).unfocus();
    final question = text.trim();
    if (question.isEmpty) return;
    _controller.clear();
    final editing = _editing;
    if (editing != null) {
      setState(() => _editing = null);
      ref.read(askProvider.notifier).editAndResend(editing.id, question);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToBottom(force: true),
      );
      return;
    }
    if (RegExp(
      r'\b(whole library|all my saves|entire library|across my library)\b',
      caseSensitive: false,
    ).hasMatch(question)) {
      setState(() => _attachedSource = null);
      ref.read(askProvider.notifier).setFocusedSource(null);
    }
    final contextualSource = _attachedSource;
    ref
        .read(askProvider.notifier)
        .ask(
          question,
          preloadedSources:
              preloadedSources ??
              (contextualSource != null ? [contextualSource] : null),
          originalQuestion: originalQuestion,
          usePreloadedAsContext:
              preloadedSources == null && contextualSource != null,
        );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(force: true),
    );
  }

  void _onSynthesizeTapped(List<SavedUrl> sources) {
    _onSendMessage(
      'Synthesize these ${sources.length} saves into one cohesive summary',
      preloadedSources: sources,
    );
  }

  void _usePromptChip(String prompt) {
    _controller.value = TextEditingValue(
      text: prompt,
      selection: TextSelection.collapsed(offset: prompt.length),
    );
    _focusNode.requestFocus();
  }

  void _onBuildPlanTapped(List<SavedUrl> sources, String originalQuestion) {
    _onSendMessage(
      'Build me a practical weekend plan from these saves',
      preloadedSources: sources,
      originalQuestion: originalQuestion,
    );
  }

  Future<bool> _saveItineraryFromAnswer(ChatMessage message) async {
    try {
      final snapshot = await loadLibrarySnapshot(ref);
      final draft = AskItineraryBuilder.fromMessage(message, snapshot);
      if (draft == null) {
        _showItineraryMessage(
          'This answer does not cite any saved places to add to a plan.',
        );
        return false;
      }

      final now = DateTime.now();
      final itinerary = PlaceItinerary()
        ..name = draft.name
        ..areaKey = draft.areaKey
        ..areaTitle = draft.areaTitle
        ..country = draft.country
        ..createdAt = now
        ..updatedAt = now
        ..stops = draft.entities
            .map(itineraryStopFromEntity)
            .toList(growable: false);
      // The answer's order stands; more than a day's worth splits by time.
      if (estimateStops(itinerary.stops).exceedsADay) {
        assignDays(itinerary.stops);
      }
      final id = await ref.read(placeItineraryActionsProvider).save(itinerary);

      var statusFailures = 0;
      for (final entity in draft.entities) {
        if (entity.status != LibraryItemStatus.unlisted) continue;
        try {
          await ref
              .read(libraryEntityActionsProvider)
              .setStatus(entity, LibraryItemStatus.planning);
        } catch (_) {
          statusFailures++;
        }
      }
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .trackEvent(AnalyticsEvent.placeItineraryCreated),
      );
      if (!mounted) return true;
      if (statusFailures > 0) {
        _showItineraryMessage(
          'Itinerary saved. $statusFailures ${statusFailures == 1 ? 'place was' : 'places were'} not marked Want to visit.',
        );
      }
      context.push('/library/places/itinerary/$id');
      return true;
    } catch (_) {
      _showItineraryMessage('Could not save this itinerary. Try again.');
      return false;
    }
  }

  void _showItineraryMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSaveToCollectionSheet(
    BuildContext context,
    List<SavedUrl> sources,
  ) {
    final isar = ref.read(isarServiceProvider);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SaveToCollectionSheet(
        hostContext: context,
        sources: sources,
        isarService: isar,
        onCollectionChanged: (collectionId) {
          ref.invalidate(collectionsListProvider);
          ref.invalidate(collectionsSummaryProvider);
          ref.invalidate(collectionUrlsProvider(collectionId));
        },
      ),
    );
  }

  Future<String?> _editText(
    String title,
    String initial, {
    String? warning,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (warning != null) Text(warning),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    // Dialog route disposal can run after showDialog resolves.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  /// Puts [message] back in the composer to edit; sending replaces it.
  void _editMessage(ChatMessage message) {
    setState(() => _editing = message);
    _controller.value = TextEditingValue(
      text: message.text,
      selection: TextSelection.collapsed(offset: message.text.length),
    );
    _focusNode.requestFocus();
  }

  void _cancelEdit() {
    AppHaptics.play(AppHaptics.tick);
    setState(() => _editing = null);
    _controller.clear();
  }

  Future<void> _showHistory() async {
    final notifier = ref.read(askProvider.notifier);
    final chats = await notifier.conversations();
    if (!mounted) return;
    final picked = await showModalBottomSheet<AskConversation>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _ChatHistorySheet(
        chats: chats,
        currentKey: notifier.conversationKey,
        onOpen: (chat) => Navigator.pop(sheetContext, chat),
        onNewChat: () {
          Navigator.pop(sheetContext);
          notifier.clearHistory();
          setState(() => _attachedSource = null);
        },
        onRename: (chat) async {
          final title = await _editText(context.l10n.askRenameChat, chat.title);
          if (title == null || title.trim().isEmpty) return null;
          await notifier.renameConversation(chat, title);
          return title.trim();
        },
        onDelete: (chat) async {
          final wasOpen = chat.key == notifier.conversationKey;
          await notifier.deleteConversation(chat);
          if (wasOpen && mounted) setState(() => _attachedSource = null);
        },
        onRestore: notifier.restoreConversation,
      ),
    );
    if (picked == null || !mounted) return;
    await notifier.openConversation(picked);
    final saves = await ref.read(isarServiceProvider).getAllUrls();
    if (!mounted) return;
    setState(
      () => _attachedSource = saves
          .where((s) => s.rawUrl == notifier.focusedUrl)
          .firstOrNull,
    );
  }

  void _scrollToBottom({bool force = false}) {
    if (_scrollController.hasClients && (force || _nearBottom)) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final askState = ref.watch(askProvider);
    final showTyping =
        askState.isLoading && (askState.messages.lastOrNull?.isUser ?? true);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final urlsAsync = ref.watch(urlStreamProvider);
    final hasBack = !widget.embedded && context.canPop();
    final lastUserIndex = askState.messages.lastIndexWhere((m) => m.isUser);
    final savedUrlCount = urlsAsync.valueOrNull?.length ?? 0;
    final userName = ref.watch(userDisplayNameProvider).valueOrNull;
    final suggestionsAsync = ref.watch(askEmptySuggestionsProvider);

    ref.listen(askProvider, (_, next) {
      // Scroll on every state change so the indicator and new messages
      // are always visible.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      if (next.limitReached != null) {
        // Clear the flag immediately so it doesn't re-trigger on rebuilds.
        ref.read(askProvider.notifier).clearLimitReached();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final upgraded = await showUpgradeGate(context, UpgradeFeature.ask);
          if (!mounted) return;
          if (upgraded == true) {
            ref.read(askProvider.notifier).clearHistory();
          }
        });
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleSpacing: hasBack ? 0 : 20,
        leading: hasBack
            ? IconButton(
                icon: const AppIcon(AppIcons.arrowBack),
                onPressed: () => context.pop(),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(
          context.l10n.askGlimpse,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        actions: [
          const UsageBadge(feature: UsageFeature.ask),
          IconButton(
            icon: const AppIcon(AppIcons.chatHistory),
            tooltip: context.l10n.askRecentChats,
            onPressed: _showHistory,
          ),
          if (askState.messages.isNotEmpty)
            IconButton(
              icon: const AppIcon(AppIcons.newChat),
              tooltip: context.l10n.newChat,
              onPressed: () {
                AppHaptics.play(AppHaptics.tap);
                ref.read(askProvider.notifier).clearHistory();
                setState(() {
                  _attachedSource = null;
                  _editing = null;
                });
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: askState.messages.isEmpty
                ? _buildEmptyState(
                    textTheme,
                    colorScheme,
                    suggestionsAsync,
                    savedUrlCount,
                    userName,
                  )
                : Stack(
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _kChatMaxWidth,
                          ),
                          child: ListView.builder(
                            controller: _scrollController,
                            physics: const ClampingScrollPhysics(),
                            cacheExtent: 600,
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            itemCount:
                                askState.messages.length + (showTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (showTyping &&
                                  index == askState.messages.length) {
                                return const GlimpseTypingIndicator(
                                  key: PageStorageKey('typing-indicator'),
                                );
                              }
                              return _turn(askState, index, lastUserIndex);
                            },
                          ),
                        ),
                      ),
                      // Back to the newest answer after reading up.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: Center(
                          child: IgnorePointer(
                            ignoring: _nearBottom,
                            child: AnimatedScale(
                              scale: _nearBottom ? 0.6 : 1,
                              duration: AppMotion.medium,
                              curve: AppMotion.emphasized,
                              child: AnimatedOpacity(
                                opacity: _nearBottom ? 0 : 1,
                                duration: AppMotion.short,
                                child: IconButton.filledTonal(
                                  tooltip: context.l10n.askJumpLatest,
                                  icon: const AppIcon(
                                    AppIcons.arrowDown,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    AppHaptics.play(AppHaptics.tick);
                                    _scrollToBottom(force: true);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          _ComposerBar(
            controller: _controller,
            focusNode: _focusNode,
            isLoading: askState.isLoading,
            attachedSource: _attachedSource,
            onClearAttachedSource: _attachedSource == null
                ? null
                : () {
                    AppHaptics.play(AppHaptics.tick);
                    setState(() => _attachedSource = null);
                    ref.read(askProvider.notifier).setFocusedSource(null);
                  },
            editing: _editing,
            editingReplacesLater:
                _editing != null &&
                askState.messages.lastIndexWhere((m) => m.isUser) !=
                    askState.messages.indexWhere((m) => m.id == _editing!.id),
            onCancelEdit: _cancelEdit,
            onSubmit: (text) => _onSendMessage(text),
            onStop: () => ref.read(askProvider.notifier).stop(),
          ),
        ],
      ),
    );
  }

  Widget _turn(AskState askState, int index, int lastUserIndex) {
    final msg = askState.messages[index];
    final last = index == askState.messages.length - 1;
    final idle = !askState.isLoading;
    final notifier = ref.read(askProvider.notifier);
    return _ChatTurn(
      key: ValueKey(msg.id),
      message: msg,
      first: index == 0,
      latest: last,
      streaming: askState.isLoading && last,
      onEdit: msg.isUser && idle ? () => _editMessage(msg) : null,
      onAskAgain: msg.isUser && idle && index == lastUserIndex
          ? notifier.retryLast
          : null,
      editing: msg.id == _editing?.id,
      onRegenerate: !msg.isUser && last && idle ? notifier.retryLast : null,
      onProactiveTipTap: msg.proactiveTip != null
          ? () => _usePromptChip(msg.proactiveTip!)
          : null,
      onFollowUpTap: last && idle ? _usePromptChip : null,
      onActionConsumed: () => notifier.consumeAction(msg.id),
      onSaveAnswerToNotesTap: msg.canSaveAsNote && !msg.noteSaved
          ? () async {
              AppHaptics.play(AppHaptics.success);
              final saved = await notifier.saveAnswerAsNote(msg.id);
              if (!mounted) return;
              final strings = context.l10n;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    saved ? strings.askNoteSaved : strings.askNoteSaveFailed,
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          : null,
      onSynthesizeTap: msg.action == ChatAction.synthesize
          ? () => _onSynthesizeTapped(msg.sources)
          : null,
      onBuildPlanTap: msg.action == ChatAction.buildPlan
          ? () => _onBuildPlanTapped(
              msg.sources,
              msg.originalQuestion ?? msg.text,
            )
          : null,
      onSaveItineraryTap: msg.action == ChatAction.saveItinerary
          ? () => _saveItineraryFromAnswer(msg)
          : null,
      onSaveToCollectionTap: msg.action == ChatAction.saveToCollection
          ? () => _showSaveToCollectionSheet(context, msg.sources)
          : null,
    );
  }

  Widget _buildEmptyState(
    TextTheme textTheme,
    ColorScheme colorScheme,
    AsyncValue<List<AskSuggestionChipData>> suggestionsAsync,
    int savedUrlCount,
    String? userName,
  ) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Build or reuse the cached greeting future so the empty state does not
    // flicker on every rebuild.
    if (_greetingFuture == null ||
        _lastGreetingName != userName ||
        _lastGreetingCount != savedUrlCount) {
      _lastGreetingName = userName;
      _lastGreetingCount = savedUrlCount;
      _greetingFuture = AskGreetingService().build(
        savedUrlCount: savedUrlCount,
        userName: userName,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kChatMaxWidth),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 16),
                          const _AskMascot(),
                          const SizedBox(height: 20),
                          FutureBuilder<AskGreeting>(
                            future: _greetingFuture,
                            builder: (context, snapshot) {
                              final greeting = snapshot.data;
                              final subline = greeting?.hint != null
                                  ? context.l10n.saveYourFirstLink
                                  : savedUrlCount > 0
                                  ? context.l10n.askAcrossSaves(savedUrlCount)
                                  : null;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _localizedGreeting(greeting),
                                    textAlign: TextAlign.center,
                                    style: textTheme.headlineSmall?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (subline != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      subline,
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Starting points sit by the message box, where the thumb is;
            // typing tucks them away.
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.emphasizedDecelerate,
              alignment: Alignment.bottomCenter,
              child: keyboardOpen
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: suggestionsAsync.when(
                        data: _suggestionRow,
                        loading: () => const _SuggestionShimmerRow(),
                        error: (_, _) =>
                            _suggestionRow(kAskOnboardingSuggestionChips),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionRow(List<AskSuggestionChipData> chips) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, chip) in chips.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: EntranceMotion(
                    spring: true,
                    offset: 12,
                    delay: EntranceMotion.stagger(i + 1),
                    child: _SuggestionCard(
                      suggestion: chip,
                      onTap: () => _usePromptChip(chip.promptText),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  String _localizedGreeting(AskGreeting? greeting) {
    if (greeting == null) return context.l10n.askGreetingAfternoon;
    return switch (greeting.phase) {
      TimeBucket.earlyMorning => context.l10n.askGreetingEarlyMorning,
      TimeBucket.morning => context.l10n.askGreetingMorning,
      TimeBucket.afternoon => context.l10n.askGreetingAfternoon,
      TimeBucket.evening => context.l10n.askGreetingEvening,
      TimeBucket.night => context.l10n.askGreetingNight,
      TimeBucket.lateNight => context.l10n.askGreetingLateNight,
    };
  }
}
