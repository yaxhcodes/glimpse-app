import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_assets.dart';
import '../../core/models/saved_url.dart';
import '../../core/models/user_collection.dart';
import '../../core/providers/user_display_name_provider.dart';
import '../../core/services/usage_service.dart';
import '../../shared/widgets/upgrade_gate.dart';
import '../../shared/widgets/usage_badge.dart';
import '../../core/database/isar_service.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/title_resolver.dart';
import '../home/home_provider.dart';
import '../collections/collection_visual.dart';
import '../collections/collections_provider.dart';
import '../collections/create_collection_sheet.dart';
import 'ask_empty_suggestions_provider.dart';
import 'ask_greeting_service.dart';
import 'ask_provider.dart';

/// Max width for chat column on large phones / tablets (readable line length).
const double _kChatMaxWidth = 680;
const Duration _kAssistantHapticInterval = Duration(milliseconds: 160);
const int _kAssistantHapticCharacterStep = 32;

final Set<String> _completedAssistantAnimationIds = <String>{};

class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, this.embedded = false, this.initialSource});

  final bool embedded;
  final SavedUrl? initialSource;

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
    if (widget.initialSource != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _clearedForInitialSource) return;
        _clearedForInitialSource = true;
        ref.read(askProvider.notifier).clearHistory();
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
          saveAnswerToUrlId: preloadedSources == null
              ? contextualSource?.id
              : null,
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => context.pop(),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(
          'Ask Glimpse',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        actions: [
          const UsageBadge(feature: UsageFeature.ask),
          if (askState.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'New chat',
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
                  linkCount == 1 ? '1 link' : '$linkCount links',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: DecoratedBox(
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
                                      if (!context.mounted || !saved) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Saved to notes'),
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
                  final line =
                      greeting?.line ??
                      (userName != null && userName.isNotEmpty
                          ? 'Hey, $userName.'
                          : 'Hey.');
                  final hint = greeting?.hint;

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
}

/// Placeholder chips while Ask suggestions load (M3 surface tones only).
class _SuggestionShimmerRow extends StatelessWidget {
  const _SuggestionShimmerRow();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(3, (i) {
        final w = 88.0 + (i * 24.0);
        return Shimmer.fromColors(
          baseColor: colorScheme.surfaceContainerHigh,
          highlightColor: colorScheme.surfaceContainerHighest,
          child: Container(
            width: w,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      }),
    );
  }
}

/// Clean Glimpse mark for the empty state.
class _GlimpseMark extends StatelessWidget {
  const _GlimpseMark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.logo,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
    );
  }
}

/// One user or assistant message block (modern chat layout).
class _ChatTurn extends StatelessWidget {
  const _ChatTurn({
    super.key,
    required this.message,
    required this.animateAssistant,
    required this.onAssistantAnimationComplete,
    this.onAssistantContentGrowth,
    this.onProactiveTipTap,
    this.onFollowUpTap,
    this.onActionConsumed,
    this.onSaveAnswerToNotesTap,
    this.onSynthesizeTap,
    this.onBuildPlanTap,
    this.onSaveToCollectionTap,
  });

  final ChatMessage message;
  final bool animateAssistant;
  final ValueChanged<String> onAssistantAnimationComplete;
  final VoidCallback? onAssistantContentGrowth;
  final VoidCallback? onProactiveTipTap;
  final ValueChanged<String>? onFollowUpTap;
  final VoidCallback? onActionConsumed;
  final Future<void> Function()? onSaveAnswerToNotesTap;
  final VoidCallback? onSynthesizeTap;
  final VoidCallback? onBuildPlanTap;
  final VoidCallback? onSaveToCollectionTap;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _UserBubble(text: message.text);
    }
    return _AssistantBlock(
      message: message,
      animate: animateAssistant,
      onAnimationComplete: onAssistantAnimationComplete,
      onContentGrowth: onAssistantContentGrowth,
      onProactiveTipTap: onProactiveTipTap,
      onFollowUpTap: onFollowUpTap,
      onActionConsumed: onActionConsumed,
      onSaveAnswerToNotesTap: onSaveAnswerToNotesTap,
      onSynthesizeTap: onSynthesizeTap,
      onBuildPlanTap: onBuildPlanTap,
      onSaveToCollectionTap: onSaveToCollectionTap,
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final maxW = math.min(520.0, MediaQuery.sizeOf(context).width * 0.86);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Text(
              text,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimary,
                height: 1.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantBlock extends StatefulWidget {
  const _AssistantBlock({
    required this.message,
    required this.animate,
    required this.onAnimationComplete,
    this.onContentGrowth,
    this.onProactiveTipTap,
    this.onFollowUpTap,
    this.onActionConsumed,
    this.onSaveAnswerToNotesTap,
    this.onSynthesizeTap,
    this.onBuildPlanTap,
    this.onSaveToCollectionTap,
  });

  final ChatMessage message;
  final bool animate;
  final ValueChanged<String> onAnimationComplete;
  final VoidCallback? onContentGrowth;
  final VoidCallback? onProactiveTipTap;
  final ValueChanged<String>? onFollowUpTap;
  final VoidCallback? onActionConsumed;
  final Future<void> Function()? onSaveAnswerToNotesTap;
  final VoidCallback? onSynthesizeTap;
  final VoidCallback? onBuildPlanTap;
  final VoidCallback? onSaveToCollectionTap;

  @override
  State<_AssistantBlock> createState() => _AssistantBlockState();
}

class _AssistantBlockState extends State<_AssistantBlock> {
  String _displayedIntro = '';
  bool _introComplete = false;
  int _visibleCardCount = 0;
  bool _sectionRevealScheduled = false;
  DateTime? _lastScrollNudge;
  bool _tipVisible = false;
  bool _chipVisible = false;
  bool _followUpsVisible = false;
  bool _saveActionVisible = false;
  bool _actionConsumed = false;
  bool _streamingCancelled = false;
  DateTime? _lastHapticFeedback;

  String get _intro => widget.message.text;
  bool get _hasBody => _intro.trim().isNotEmpty;

  int get _cardTotal {
    if (widget.message.sections.isNotEmpty) {
      return widget.message.sections.length;
    }
    if (widget.message.sources.isNotEmpty) {
      return widget.message.sources.length;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _actionConsumed = widget.message.actionConsumed;
    if (!widget.animate) {
      _displayedIntro = _intro;
      _introComplete = true;
      _visibleCardCount = _cardTotal;
      _tipVisible = widget.message.proactiveTip != null;
      _chipVisible = widget.message.action != ChatAction.none;
      _followUpsVisible = widget.message.followUpSuggestions.isNotEmpty;
      _saveActionVisible = widget.onSaveAnswerToNotesTap != null;
      return;
    }
    if (!_hasBody) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startSectionReveal(),
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _streamIntro(_intro);
    });
  }

  Future<void> _streamIntro(String fullText) async {
    _streamingCancelled = false;
    for (int i = 1; i <= fullText.length; i++) {
      if (!mounted || _streamingCancelled) return;
      setState(() => _displayedIntro = fullText.substring(0, i));
      _maybePlayTextHaptic(i);
      final delay = fullText.length > 200 ? 6 : 15;
      await Future.delayed(Duration(milliseconds: delay));
    }
    if (!mounted || _streamingCancelled) return;
    setState(() => _introComplete = true);
    widget.onAnimationComplete(widget.message.id);
    _throttledScroll();
    _showCards();
  }

  void _maybePlayTextHaptic(int visibleCharacterCount) {
    if (visibleCharacterCount == 1 ||
        visibleCharacterCount % _kAssistantHapticCharacterStep != 0) {
      return;
    }
    final now = DateTime.now();
    if (_lastHapticFeedback != null &&
        now.difference(_lastHapticFeedback!) < _kAssistantHapticInterval) {
      return;
    }
    _lastHapticFeedback = now;
    HapticFeedback.selectionClick();
  }

  void _showCards() {
    if (_sectionRevealScheduled) return;
    _sectionRevealScheduled = true;
    _startSectionReveal();
  }

  Future<void> _startSectionReveal() async {
    final n = _cardTotal;
    if (n == 0) {
      widget.onAnimationComplete(widget.message.id);
      _showTipIfPresent();
      _showChipIfPresent();
      _showFollowUpsIfPresent();
      _showSaveActionIfPresent();
      _throttledScroll();
      return;
    }
    for (var i = 0; i < n; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _visibleCardCount = i + 1);
      _throttledScroll();
    }
    widget.onAnimationComplete(widget.message.id);
    _showTipIfPresent();
    _showChipIfPresent();
    _showFollowUpsIfPresent();
    _showSaveActionIfPresent();
  }

  void _showTipIfPresent() {
    if (widget.message.proactiveTip != null) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() => _tipVisible = true);
          _throttledScroll();
        }
      });
    }
  }

  void _showChipIfPresent() {
    if (widget.message.action != ChatAction.none) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() => _chipVisible = true);
          _throttledScroll();
        }
      });
    }
  }

  void _showFollowUpsIfPresent() {
    if (widget.message.followUpSuggestions.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() => _followUpsVisible = true);
          _throttledScroll();
        }
      });
    }
  }

  void _showSaveActionIfPresent() {
    if (widget.onSaveAnswerToNotesTap != null) {
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) {
          setState(() => _saveActionVisible = true);
          _throttledScroll();
        }
      });
    }
  }

  void _throttledScroll() {
    final now = DateTime.now();
    if (_lastScrollNudge == null ||
        now.difference(_lastScrollNudge!) > const Duration(milliseconds: 140)) {
      _lastScrollNudge = now;
      widget.onContentGrowth?.call();
    }
  }

  @override
  void dispose() {
    if (widget.animate) {
      widget.onAnimationComplete(widget.message.id);
    }
    _streamingCancelled = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final hasSections = widget.message.sections.isNotEmpty;
    final hasSources = widget.message.sources.isNotEmpty;
    final tip = widget.message.proactiveTip;
    final label = widget.message.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null && _introComplete) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (_hasBody)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: _introComplete
                  ? SelectableText(
                      _intro,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.5,
                      ),
                    )
                  : Text(
                      _displayedIntro,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.5,
                      ),
                    ),
            ),
          if (hasSections) ...[
            for (var index = 0; index < widget.message.sections.length; index++)
              if (index < _visibleCardCount)
                _StaggerAppear(
                  child: _AnswerSectionCard(
                    order: index + 1,
                    showIndex: widget.message.sections.length > 1,
                    section: widget.message.sections[index],
                  ),
                ),
          ] else if (hasSources) ...[
            for (var index = 0; index < widget.message.sources.length; index++)
              if (index < _visibleCardCount)
                _StaggerAppear(
                  child: _SourceCard(
                    source: widget.message.sources[index],
                    order: index + 1,
                    showIndex: widget.message.sources.length > 1,
                  ),
                ),
          ],
          if (widget.message.action != ChatAction.none &&
              !_actionConsumed &&
              _chipVisible) ...[
            const SizedBox(height: 10),
            AnimatedOpacity(
              opacity: _chipVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              child: _ChatActionChip(
                action: widget.message.action,
                onTap: () {
                  setState(() => _actionConsumed = true);
                  widget.onActionConsumed?.call();
                  switch (widget.message.action) {
                    case ChatAction.saveToCollection:
                      widget.onSaveToCollectionTap?.call();
                    case ChatAction.synthesize:
                      widget.onSynthesizeTap?.call();
                    case ChatAction.buildPlan:
                      widget.onBuildPlanTap?.call();
                    case ChatAction.none:
                      break;
                  }
                },
              ),
            ),
          ],
          if (widget.onSaveAnswerToNotesTap != null && _saveActionVisible) ...[
            const SizedBox(height: 10),
            AnimatedOpacity(
              opacity: _saveActionVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: _AssistantUtilityAction(
                icon: Icons.note_add_outlined,
                label: 'Save answer',
                onTap: widget.onSaveAnswerToNotesTap!,
              ),
            ),
          ],
          if (tip != null) ...[
            const SizedBox(height: 10),
            AnimatedOpacity(
              opacity: _tipVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              child: _ProactiveTipNudge(
                tip: tip,
                onTap: widget.onProactiveTipTap,
              ),
            ),
          ],
          if (widget.message.followUpSuggestions.isNotEmpty &&
              _followUpsVisible) ...[
            const SizedBox(height: 10),
            AnimatedOpacity(
              opacity: _followUpsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: _FollowUpChips(
                prompts: widget.message.followUpSuggestions,
                onTap: widget.onFollowUpTap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssistantUtilityAction extends StatelessWidget {
  const _AssistantUtilityAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _FollowUpChips extends StatelessWidget {
  const _FollowUpChips({required this.prompts, this.onTap});

  final List<String> prompts;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: prompts.take(3).map((prompt) {
        return ActionChip(
          label: Text(prompt),
          onPressed: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!(prompt);
                },
        );
      }).toList(),
    );
  }
}

/// Fade + slight slide when a card first appears (ChatGPT-style stagger).
class _StaggerAppear extends StatelessWidget {
  const _StaggerAppear({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) {
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: c),
        );
      },
      child: child,
    );
  }
}

class _ProactiveTipNudge extends StatelessWidget {
  const _ProactiveTipNudge({required this.tip, this.onTap});

  final String tip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tip,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerSectionCard extends StatelessWidget {
  const _AnswerSectionCard({
    required this.order,
    required this.showIndex,
    required this.section,
  });

  final int order;
  final bool showIndex;
  final ChatMessageSection section;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final source = section.source;
    final title = section.heading;
    final summary = section.summary;
    final domain = CategoryResolver.displaySourceName(
      rawUrl: source.rawUrl,
      fallbackDomain: source.domain,
    );

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showIndex) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Text(
                      '$order',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Icon(
                    Icons.grid_view_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Summary — indented only when numbered
            Padding(
              padding: EdgeInsets.only(left: showIndex ? 18.0 : 0),
              child: Text(
                summary,
                style: TextStyle(
                  fontSize: 12.5,
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            // Footer
            Padding(
              padding: EdgeInsets.only(left: showIndex ? 18.0 : 0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: cs.outlineVariant, width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      domain,
                      style: TextStyle(fontSize: 11, color: cs.outline),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/url/${source.id}'),
                      child: Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 0.5,
                      height: 12,
                      color: cs.outlineVariant,
                    ),
                    GestureDetector(
                      onTap: () => _openUrl(source.rawUrl),
                      child: Row(
                        children: [
                          Text(
                            'Open',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 11,
                            color: cs.outline,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.order,
    required this.showIndex,
  });

  final SavedUrl source;
  final int order;
  final bool showIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = source.title.isNotEmpty ? source.title : source.domain;
    final summary = source.summary ?? source.description;
    final domain = CategoryResolver.displaySourceName(
      rawUrl: source.rawUrl,
      fallbackDomain: source.domain,
    );

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showIndex) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Text(
                      '$order',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Icon(
                    Icons.grid_view_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Summary — indented only when numbered
            Padding(
              padding: EdgeInsets.only(left: showIndex ? 18.0 : 0),
              child: Text(
                summary,
                style: TextStyle(
                  fontSize: 12.5,
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            // Footer
            Padding(
              padding: EdgeInsets.only(left: showIndex ? 18.0 : 0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: cs.outlineVariant, width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      domain,
                      style: TextStyle(fontSize: 11, color: cs.outline),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/url/${source.id}'),
                      child: Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 0.5,
                      height: 12,
                      color: cs.outlineVariant,
                    ),
                    GestureDetector(
                      onTap: () => _openUrl(source.rawUrl),
                      child: Row(
                        children: [
                          Text(
                            'Open',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 11,
                            color: cs.outline,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class GlimpseTypingIndicator extends StatefulWidget {
  const GlimpseTypingIndicator({super.key});

  @override
  State<GlimpseTypingIndicator> createState() => _GlimpseTypingIndicatorState();
}

class _GlimpseTypingIndicatorState extends State<GlimpseTypingIndicator>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _animations = _controllers
        .map(
          (c) => Tween<double>(
            begin: 0,
            end: -6,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.stop();
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => AnimatedBuilder(
              animation: _animations[i],
              builder: (_, _) => Transform.translate(
                offset: Offset(0, _animations[i].value),
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    this.attachedSource,
    this.onClearAttachedSource,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final SavedUrl? attachedSource;
  final VoidCallback? onClearAttachedSource;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final transparent = colorScheme.surface.withValues(alpha: 0);

    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kChatMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (attachedSource != null) ...[
                  _AttachedSourceBar(
                    source: attachedSource!,
                    onClear: onClearAttachedSource,
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Pill only wraps the text field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                            width: 0.5,
                          ),
                        ),
                        child: Theme(
                          data: theme.copyWith(
                            splashFactory: NoSplash.splashFactory,
                            highlightColor: transparent,
                            focusColor: transparent,
                            hoverColor: transparent,
                            inputDecorationTheme: const InputDecorationTheme(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onTap: () => focusNode.requestFocus(),
                            onSubmitted: (_) {
                              if (controller.text.trim().isNotEmpty) {
                                onSubmit(controller.text);
                              }
                            },
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: attachedSource == null
                                  ? 'Message Glimpse...'
                                  : 'Ask about this save...',
                              hintStyle: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.outline,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send button sits outside the pill
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        if (isLoading) {
                          return Tooltip(
                            message: 'Sending...',
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.primary,
                              ),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          );
                        }
                        final hasText = value.text.trim().isNotEmpty;
                        return Tooltip(
                          message: 'Send',
                          child: GestureDetector(
                            onTap: hasText
                                ? () {
                                    HapticFeedback.lightImpact();
                                    onSubmit(controller.text);
                                  }
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasText
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHigh,
                                border: hasText
                                    ? null
                                    : Border.all(
                                        color: colorScheme.outlineVariant,
                                      ),
                              ),
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                size: 20,
                                color: hasText
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachedSourceBar extends ConsumerWidget {
  const _AttachedSourceBar({required this.source, this.onClear});

  final SavedUrl source;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tagFreq = ref.watch(tagOccurrenceMapProvider);
    final title = TitleResolver.resolveDetailTitle(
      source,
      tagFrequency: tagFreq,
    );
    final platform = CategoryResolver.displaySourceName(
      rawUrl: source.rawUrl,
      fallbackDomain: source.domain,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  platform,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.74),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('All saves'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatActionChip extends StatelessWidget {
  final ChatAction action;
  final VoidCallback onTap;

  const _ChatActionChip({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (icon, label) = switch (action) {
      ChatAction.saveToCollection => (
        Icons.bookmark_add_outlined,
        'Save these to a collection',
      ),
      ChatAction.synthesize => (
        Icons.auto_awesome_outlined,
        'Synthesize these',
      ),
      ChatAction.buildPlan => (
        Icons.calendar_today_outlined,
        'Build a plan from these',
      ),
      ChatAction.none => (null, ''),
    };

    if (action == ChatAction.none) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.35),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final CollectionVisualStyle visualStyle;
  final String name;
  final String subtitle;
  final bool isCreate;
  final VoidCallback onTap;

  const _CollectionTile({
    required this.visualStyle,
    required this.name,
    required this.subtitle,
    this.isCreate = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: CollectionVisual(
          style: visualStyle,
          seed: name,
          selected: isCreate,
          size: 40,
          iconSize: isCreate ? 19 : 18,
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isCreate ? cs.primary : cs.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurface.withValues(alpha: 0.4),
        ),
      ),
      trailing: Icon(
        isCreate ? Icons.add_rounded : Icons.chevron_right_rounded,
        size: 18,
        color: isCreate ? cs.primary : cs.onSurface.withValues(alpha: 0.3),
      ),
      onTap: onTap,
    );
  }
}

class _SaveToCollectionSheet extends StatefulWidget {
  final BuildContext hostContext;
  final List<SavedUrl> sources;
  final IsarService isarService;
  final ValueChanged<int> onCollectionChanged;

  const _SaveToCollectionSheet({
    required this.hostContext,
    required this.sources,
    required this.isarService,
    required this.onCollectionChanged,
  });

  @override
  State<_SaveToCollectionSheet> createState() => _SaveToCollectionSheetState();
}

class _SaveToCollectionSheetState extends State<_SaveToCollectionSheet> {
  List<UserCollection> _existing = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cols = await widget.isarService.getAllCollections();
    setState(() {
      _existing = cols;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save to collection',
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.sources.length} links will be added',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Create new — always first
          _CollectionTile(
            visualStyle: CollectionVisualStyle.knowledge,
            name: 'New collection',
            subtitle: 'Create a focused space',
            isCreate: true,
            onTap: () => _createAndSave(context),
          ),

          if (_loading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cs.primary,
                ),
              ),
            )
          else
            ..._existing.map(
              (col) => _CollectionTile(
                visualStyle: resolveCollectionVisual(col),
                name: col.name,
                subtitle: '${col.urlIds.length} links',
                onTap: () => _addToExisting(context, col),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _createAndSave(BuildContext context) async {
    Navigator.pop(context);

    final defaultName = widget.sources.length == 1
        ? widget.sources.first.title
        : '${widget.sources.length} links';
    final collection = await showCreateCollectionSheet(
      widget.hostContext,
      initialName: defaultName.isNotEmpty ? defaultName : null,
      initialVisual: resolveCollectionVisualStyle(
        null,
        name: defaultName,
        description: widget.sources.map((source) => source.category).join(' '),
      ),
    );
    if (collection == null) return;

    await widget.isarService.addUrlsToCollection(
      collectionId: collection.id,
      urlIds: widget.sources.map((u) => u.id).toList(),
    );
    widget.onCollectionChanged(collection.id);
    if (widget.hostContext.mounted) {
      widget.hostContext.push('/collections/${collection.id}');
    }
  }

  Future<void> _addToExisting(BuildContext context, UserCollection col) async {
    Navigator.pop(context);
    await widget.isarService.addUrlsToCollection(
      collectionId: col.id,
      urlIds: widget.sources.map((u) => u.id).toList(),
    );
    widget.onCollectionChanged(col.id);
    if (widget.hostContext.mounted) {
      final cs = Theme.of(widget.hostContext).colorScheme;
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(child: Text('Added to "${col.name}"')),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(
                    widget.hostContext,
                  ).hideCurrentSnackBar();
                  widget.hostContext.push('/collections/${col.id}');
                },
                child: Text(
                  'View',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: cs.surfaceContainerHigh,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
