import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/user_display_name_provider.dart';
import '../../core/services/category_resolver.dart';
import '../home/home_provider.dart';
import 'ask_empty_suggestions_provider.dart';
import 'ask_provider.dart';

/// Max width for chat column on large phones / tablets (readable line length).
const double _kChatMaxWidth = 680;

String _askTimeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String _askGreetingLine(String? userName) {
  final time = _askTimeGreeting();
  final name = userName?.trim();
  if (name != null && name.isNotEmpty) {
    return '$time, $name.';
  }
  return '$time.';
}

class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    _controller.clear();
    ref.read(askProvider.notifier).ask(question);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
    final urlsAsync = ref.watch(urlStreamProvider);
    final linkCount = urlsAsync.valueOrNull?.length;
    final savedUrlCount = urlsAsync.valueOrNull?.length ?? 0;
    final userName = ref.watch(userDisplayNameProvider).valueOrNull;
    final suggestionsAsync = ref.watch(askEmptySuggestionsProvider);

    ref.listen(askProvider, (_, next) {
      if (!next.isLoading) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return KeyboardVisibilityBuilder(
      builder: (context, keyboardVisible) {
        return Scaffold(
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
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.secondaryContainer,
              child: ClipOval(
                child: Image.asset(
                  'assets/unown_bookmark_transparent.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Ask Glimpse',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (askState.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'New chat',
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(askProvider.notifier).clearHistory();
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
                      keyboardVisible,
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
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            8,
                          ),
                          itemCount: askState.messages.length +
                              (askState.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == askState.messages.length) {
                              return const _TypingRow();
                            }
                            final msg = askState.messages[index];
                            return _ChatTurn(
                              message: msg,
                              onAssistantContentGrowth: _scrollToBottom,
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
            onSubmit: _submit,
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildEmptyState(
    TextTheme textTheme,
    ColorScheme colorScheme,
    bool keyboardOpen,
    AsyncValue<List<AskSuggestionChipData>> suggestionsAsync,
    int savedUrlCount,
    String? userName,
  ) {
    final subtitle = savedUrlCount == 0
        ? 'Save your first link to get started.'
        : 'Ask me anything — find a link, summarize what you saved, or explore a topic.';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kChatMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const _GlimpsePulseOrb(),
              const SizedBox(height: 24),
              Text(
                _askGreetingLine(userName),
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
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
                          padding: const EdgeInsets.only(top: 24),
                          child: suggestionsAsync.when(
                            data: (chips) => Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: chips.map((chip) {
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
                              children: kAskOnboardingSuggestionChips.map((chip) {
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

/// Pulsing orb with Glimpse mark — uses [ColorScheme] only.
class _GlimpsePulseOrb extends StatefulWidget {
  const _GlimpsePulseOrb();

  @override
  State<_GlimpsePulseOrb> createState() => _GlimpsePulseOrbState();
}

class _GlimpsePulseOrbState extends State<_GlimpsePulseOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Center(
          child: ClipOval(
            child: Image.asset(
              'assets/unown_bookmark_transparent.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

/// One user or assistant message block (modern chat layout).
class _ChatTurn extends StatelessWidget {
  const _ChatTurn({
    required this.message,
    this.onAssistantContentGrowth,
  });

  final ChatMessage message;
  final VoidCallback? onAssistantContentGrowth;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _UserBubble(text: message.text);
    }
    return _AssistantBlock(
      message: message,
      onContentGrowth: onAssistantContentGrowth,
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
    final maxW = math.min(
      520.0,
      MediaQuery.sizeOf(context).width * 0.86,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
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
                color: colorScheme.onPrimaryContainer,
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
    this.onContentGrowth,
  });

  final ChatMessage message;
  final VoidCallback? onContentGrowth;

  @override
  State<_AssistantBlock> createState() => _AssistantBlockState();
}

class _AssistantBlockState extends State<_AssistantBlock>
    with SingleTickerProviderStateMixin {
  AnimationController? _introAnim;
  int _introVisibleChars = 0;
  int _visibleCardCount = 0;
  bool _sectionRevealScheduled = false;
  DateTime? _lastScrollNudge;

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
    if (!_hasBody) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _startSectionReveal());
      return;
    }
    final charCount = _intro.characters.length;
    final ms = (charCount * 16).clamp(450, 2800).round();
    _introAnim = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    )
      ..addListener(_onIntroTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _introVisibleChars = charCount);
          _throttledScroll();
          _startSectionReveal();
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _introAnim?.forward();
    });
  }

  void _onIntroTick() {
    final c = _introAnim;
    if (c == null) return;
    final total = _intro.characters.length;
    final next = (total * c.value).round();
    if (next != _introVisibleChars) {
      setState(() => _introVisibleChars = next);
      _throttledScroll();
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

  Future<void> _startSectionReveal() async {
    if (_sectionRevealScheduled) return;
    _sectionRevealScheduled = true;
    final n = _cardTotal;
    if (n == 0) {
      _throttledScroll();
      return;
    }
    for (var i = 0; i < n; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 95));
      if (!mounted) return;
      setState(() => _visibleCardCount = i + 1);
      _throttledScroll();
    }
  }

  @override
  void dispose() {
    _introAnim?.removeListener(_onIntroTick);
    _introAnim?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final hasSections = widget.message.sections.isNotEmpty;
    final hasSources = widget.message.sources.isNotEmpty;
    final introComplete =
        !_hasBody || (_introAnim?.isCompleted ?? false);
    final introShown = _hasBody
        ? _intro.characters.take(_introVisibleChars).toString()
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasBody)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: introComplete
                  ? SelectableText(
                      _intro,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.5,
                      ),
                    )
                  : Text(
                      introShown,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.5,
                      ),
                    ),
            ),
          if (_hasBody && (hasSections || hasSources))
            const SizedBox(height: 12),
          if (hasSections) ...[
            for (var index = 0; index < widget.message.sections.length; index++)
              if (index < _visibleCardCount) ...[
                _StaggerAppear(
                  child: _AnswerSectionCard(
                    order: index + 1,
                    section: widget.message.sections[index],
                  ),
                ),
                if (index != widget.message.sections.length - 1)
                  const SizedBox(height: 12),
              ],
          ] else if (hasSources) ...[
            for (var index = 0; index < widget.message.sources.length; index++)
              if (index < _visibleCardCount) ...[
                _StaggerAppear(
                  child: _SourceCard(
                    source: widget.message.sources[index],
                    order: index + 1,
                  ),
                ),
                if (index != widget.message.sources.length - 1)
                  const SizedBox(height: 12),
              ],
          ],
        ],
      ),
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
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

class _AnswerSectionCard extends StatelessWidget {
  const _AnswerSectionCard({
    required this.order,
    required this.section,
  });

  final int order;
  final ChatMessageSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$order',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.heading,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              section.summary,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            _SourceCard(source: section.source, order: order),
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.order});

  final SavedUrl source;
  final int order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displaySourceName = CategoryResolver.displaySourceName(
      rawUrl: source.rawUrl,
      fallbackDomain: source.domain,
    );
    final metaLabel = source.category == displaySourceName
        ? '${source.categoryEmoji} ${source.category}'
        : '${source.categoryEmoji} ${source.category} • $displaySourceName';

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push('/url/${source.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Source $order',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                source.title.isNotEmpty ? source.title : source.domain,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                metaLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => _openUrl(source.rawUrl),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => context.push('/url/${source.id}'),
                    icon: const Icon(Icons.article_outlined, size: 18),
                    label: const Text('Details'),
                  ),
                ],
              ),
            ],
          ),
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

class _TypingRow extends StatelessWidget {
  const _TypingRow();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: const SizedBox(
          width: 40,
          height: 8,
          child: _StaggerTypingDots(),
        ),
      ),
    );
  }
}

/// Three staggered dots using [ColorScheme.primary].
class _StaggerTypingDots extends StatefulWidget {
  const _StaggerTypingDots();

  @override
  State<_StaggerTypingDots> createState() => _StaggerTypingDotsState();
}

class _StaggerTypingDotsState extends State<_StaggerTypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (i) {
            final phase =
                (_controller.value * 2 * math.pi) + (i * 2 * math.pi / 3);
            final op = 0.3 + 0.7 * ((math.sin(phase) + 1) / 2);
            return Container(
              width: 8,
              height: 8,
              margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: op.clamp(0.3, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSubmit;

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
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
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
                      onSubmitted: (_) {
                        if (controller.text.trim().isNotEmpty) onSubmit();
                      },
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message Glimpse...',
                        hintStyle: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    if (isLoading) {
                      return Tooltip(
                        message: 'Sending…',
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                          ),
                          child: SizedBox(
                            width: 20,
                            height: 20,
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
                                onSubmit();
                              }
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasText
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            border: hasText
                                ? null
                                : Border.all(
                                    color: colorScheme.outlineVariant,
                                  ),
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
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
          ),
        ),
      ),
    );
  }
}
