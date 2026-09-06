import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_assets.dart';
import '../../core/models/saved_url.dart';
import '../../core/models/place_itinerary.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/models/user_collection.dart';
import '../../core/providers/user_display_name_provider.dart';
import '../../core/services/usage_service.dart';
import '../../shared/widgets/upgrade_gate.dart';
import '../../shared/widgets/usage_badge.dart';
import '../../shared/widgets/lightweight_markdown_text.dart';
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
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/theme/app_icons.dart';
import 'ask_itinerary_builder.dart';
import 'ask_empty_suggestions_provider.dart';
import 'ask_greeting_service.dart';
import 'ask_provider.dart';
import '../../l10n/l10n.dart';

part 'ask_conversation_widgets.dart';

/// Max width for chat column on large phones / tablets (readable line length).
const double _kChatMaxWidth = 680;
const Duration _kAssistantHapticInterval = Duration(milliseconds: 160);
const int _kAssistantHapticCharacterStep = 32;

final Set<String> _completedAssistantAnimationIds = <String>{};

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

  @override
  void initState() {
    super.initState();
    _attachedSource = widget.initialSource;
    if (widget.autofocus ||
        widget.initialSource != null ||
        widget.initialPrompt?.trim().isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _clearedForInitialSource) return;
        _clearedForInitialSource = true;
        ref.read(askProvider.notifier).clearHistory();
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onSynthesizeTapped(List<SavedUrl> sources) {
    _onSendMessage(
      'Synthesize these ${sources.length} saves into one cohesive summary',
      preloadedSources: sources,
    );
  }

  void _syncCompletedAssistantAnimations(List<ChatMessage> messages) {
    final assistantIds = messages
        .where((message) => !message.isUser)
        .map((message) => message.id)
        .toSet();
    _completedAssistantAnimationIds.removeWhere(
      (messageId) => !assistantIds.contains(messageId),
    );
  }

  void _markAssistantAnimationComplete(String messageId) {
    _completedAssistantAnimationIds.add(messageId);
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
      showDragHandle: false,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final urlsAsync = ref.watch(displayedUrlsProvider);
    final linkCount = urlsAsync.valueOrNull?.length;
    final savedUrlCount = urlsAsync.valueOrNull?.length ?? 0;
    final userName = ref.watch(userDisplayNameProvider).valueOrNull;
    final suggestionsAsync = ref.watch(askEmptySuggestionsProvider);

    _syncCompletedAssistantAnimations(askState.messages);

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
        surfaceTintColor: colorScheme.surfaceTint,
        titleSpacing: 0,
        leading: !widget.embedded && context.canPop()
            ? IconButton(
                icon: const AppIcon(AppIcons.arrowBack),
                onPressed: () => context.pop(),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(
          context.l10n.askGlimpse,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        actions: [
          const UsageBadge(feature: UsageFeature.ask),
          if (askState.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: context.l10n.newChat,
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(askProvider.notifier).clearHistory();
                setState(() => _attachedSource = null);
              },
            ),
          if (linkCount != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  context.l10n.linkCount(linkCount),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerLow.withValues(alpha: 0.65),
            ],
          ),
        ),
        child: Column(
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
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _kChatMaxWidth,
                        ),
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const ClampingScrollPhysics(),
                          cacheExtent: 9999,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          itemCount:
                              askState.messages.length +
                              (askState.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (askState.isLoading &&
                                index == askState.messages.length) {
                              return const GlimpseTypingIndicator(
                                key: PageStorageKey('typing-indicator'),
                              );
                            }
                            final msg = askState.messages[index];
                            final animateAssistant =
                                !msg.isUser &&
                                !_completedAssistantAnimationIds.contains(
                                  msg.id,
                                );
                            return _ChatTurn(
                              key: ValueKey(msg.id),
                              message: msg,
                              animateAssistant: animateAssistant,
                              onAssistantAnimationComplete:
                                  _markAssistantAnimationComplete,
                              onAssistantContentGrowth: _scrollToBottom,
                              onProactiveTipTap: msg.proactiveTip != null
                                  ? () => _usePromptChip(msg.proactiveTip!)
                                  : null,
                              onFollowUpTap: _usePromptChip,
                              onActionConsumed: () => ref
                                  .read(askProvider.notifier)
                                  .consumeAction(msg.id),
                              onSaveAnswerToNotesTap:
                                  msg.canSaveAsNote && !msg.noteSaved
                                  ? () async {
                                      HapticFeedback.lightImpact();
                                      final saved = await ref
                                          .read(askProvider.notifier)
                                          .saveAnswerAsNote(msg.id);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            saved
                                                ? 'Saved to notes'
                                                : 'Could not save. Try again.',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  : null,
                              onSynthesizeTap:
                                  msg.action == ChatAction.synthesize
                                  ? () => _onSynthesizeTapped(msg.sources)
                                  : null,
                              onBuildPlanTap: msg.action == ChatAction.buildPlan
                                  ? () => _onBuildPlanTapped(
                                      msg.sources,
                                      msg.originalQuestion ?? msg.text,
                                    )
                                  : null,
                              onSaveItineraryTap:
                                  msg.action == ChatAction.saveItinerary
                                  ? () => _saveItineraryFromAnswer(msg)
                                  : null,
                              onSaveToCollectionTap:
                                  msg.action == ChatAction.saveToCollection
                                  ? () => _showSaveToCollectionSheet(
                                      context,
                                      msg.sources,
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
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
                      HapticFeedback.selectionClick();
                      setState(() => _attachedSource = null);
                    },
              onSubmit: (text) => _onSendMessage(text),
            ),
          ],
        ),
      ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              const _GlimpseMark(),
              const SizedBox(height: 12),
              FutureBuilder<AskGreeting>(
                future: _greetingFuture,
                builder: (context, snapshot) {
                  final greeting = snapshot.data;
                  final line = _localizedGreeting(greeting);
                  final hint = greeting?.hint == null
                      ? null
                      : context.l10n.saveYourFirstLink;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        line,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      if (hint != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          hint,
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
              AnimatedOpacity(
                opacity: keyboardOpen ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: keyboardOpen
                      ? const SizedBox(width: double.infinity, height: 0)
                      : Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: suggestionsAsync.when(
                            data: (chips) => Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: chips.take(3).map((chip) {
                                return ActionChip(
                                  label: Text(chip.display),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    final t = chip.promptText;
                                    _controller.value = TextEditingValue(
                                      text: t,
                                      selection: TextSelection.collapsed(
                                        offset: t.length,
                                      ),
                                    );
                                    _focusNode.requestFocus();
                                  },
                                );
                              }).toList(),
                            ),
                            loading: () => const _SuggestionShimmerRow(),
                            error: (_, _) => Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: kAskOnboardingSuggestionChips
                                  .take(3)
                                  .map((chip) {
                                    return ActionChip(
                                      label: Text(chip.display),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        final t = chip.promptText;
                                        _controller.value = TextEditingValue(
                                          text: t,
                                          selection: TextSelection.collapsed(
                                            offset: t.length,
                                          ),
                                        );
                                        _focusNode.requestFocus();
                                      },
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

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
