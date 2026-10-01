part of 'ask_screen.dart';

/// Placeholder cards while Ask suggestions load (M3 surface tones only).
class _SuggestionShimmerRow extends StatelessWidget {
  const _SuggestionShimmerRow();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainer,
      highlightColor: colorScheme.surfaceContainerHigh,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: _SuggestionCard.width,
                height: 84,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Glimpse's mascot on a new chat, floating gently as it does on Home.
class _AskMascot extends StatefulWidget {
  const _AskMascot();

  static const size = 112.0;

  @override
  State<_AskMascot> createState() => _AskMascotState();
}

class _AskMascotState extends State<_AskMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, Curves.easeInOut.transform(_float.value) * 6 - 3),
        child: child,
      ),
      child: Image.asset(
        AppAssets.emptySearch,
        width: _AskMascot.size,
        height: _AskMascot.size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// A prompt to ask next: quiet tonal pill with a leading glyph. Used for the
/// empty state's suggestions and the follow-ups under an answer.
class _PromptPill extends StatelessWidget {
  const _PromptPill({required this.text, required this.icon, this.onTap});

  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ExpressiveTapScale(
      enabled: onTap != null,
      pressedScale: 0.97,
      child: Material(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  AppHaptics.play(AppHaptics.tick);
                  onTap!();
                },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(icon, size: 16, color: cs.primary),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A starting point on a new chat: a short lead with its glyph, and the
/// save or question under it.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});

  static const width = 224.0;

  final AskSuggestionChipData suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final icon = switch (suggestion.kind) {
      AskSuggestionKind.explain => AppIcons.idea,
      AskSuggestionKind.topic => AppIcons.tag,
      AskSuggestionKind.recent => AppIcons.calendar,
      AskSuggestionKind.rediscover => AppIcons.chatHistory,
      AskSuggestionKind.connect => AppIcons.link,
      AskSuggestionKind.start => AppIcons.chat,
    };
    final headline = suggestion.headline;
    return SizedBox(
      width: width,
      child: ExpressiveTapScale(
        pressedScale: 0.97,
        child: Material(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              AppHaptics.play(AppHaptics.tick);
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: AppIcon(icon, size: 16, color: cs.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          headline ?? suggestion.display,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (headline != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      suggestion.display,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One user or assistant turn.
class _ChatTurn extends StatelessWidget {
  const _ChatTurn({
    super.key,
    required this.message,
    this.first = false,
    this.latest = false,
    this.streaming = false,
    this.onEdit,
    this.onAskAgain,
    this.editing = false,
    this.onRegenerate,
    this.onProactiveTipTap,
    this.onFollowUpTap,
    this.onActionConsumed,
    this.onSaveAnswerToNotesTap,
    this.onSynthesizeTap,
    this.onBuildPlanTap,
    this.onSaveItineraryTap,
    this.onSaveToCollectionTap,
  });

  final ChatMessage message;

  /// Top of the conversation: no gap above.
  final bool first;

  /// The newest turn: the only one whose extras animate in.
  final bool latest;
  final bool streaming;

  /// Holding one of your messages opens Edit, Copy and (on the latest)
  /// Ask again.
  final VoidCallback? onEdit;
  final VoidCallback? onAskAgain;

  /// This message is back in the composer being edited.
  final bool editing;
  final VoidCallback? onRegenerate;
  final VoidCallback? onProactiveTipTap;
  final ValueChanged<String>? onFollowUpTap;
  final VoidCallback? onActionConsumed;
  final Future<void> Function()? onSaveAnswerToNotesTap;
  final VoidCallback? onSynthesizeTap;
  final VoidCallback? onBuildPlanTap;
  final Future<bool> Function()? onSaveItineraryTap;
  final VoidCallback? onSaveToCollectionTap;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Padding(
        padding: EdgeInsets.only(top: first ? 4 : 20, bottom: 16),
        child: _UserBubble(
          text: message.text,
          onEdit: onEdit,
          onAskAgain: onAskAgain,
          editing: editing,
        ),
      );
    }
    return _AssistantBlock(
      message: message,
      latest: latest,
      streaming: streaming,
      onRegenerate: onRegenerate,
      onProactiveTipTap: onProactiveTipTap,
      onFollowUpTap: onFollowUpTap,
      onActionConsumed: onActionConsumed,
      onSaveAnswerToNotesTap: onSaveAnswerToNotesTap,
      onSynthesizeTap: onSynthesizeTap,
      onBuildPlanTap: onBuildPlanTap,
      onSaveItineraryTap: onSaveItineraryTap,
      onSaveToCollectionTap: onSaveToCollectionTap,
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.text,
    this.onEdit,
    this.onAskAgain,
    this.editing = false,
  });

  final String text;
  final VoidCallback? onEdit;
  final VoidCallback? onAskAgain;
  final bool editing;

  /// Edit, Copy and Ask again, opened by holding the bubble and anchored to
  /// it.
  Future<void> _showMenu(BuildContext bubbleContext) async {
    AppHaptics.play(AppHaptics.tick);
    final strings = bubbleContext.l10n;
    final box = bubbleContext.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(bubbleContext).context.findRenderObject()! as RenderBox;
    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final action = await showMenu<String>(
      context: bubbleContext,
      position: RelativeRect.fromRect(
        // Opens just under the bubble, right-aligned with it.
        Rect.fromLTWH(rect.right, rect.bottom + 4, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        if (onEdit != null)
          appMenuItem(
            value: 'edit',
            icon: AppIcons.edit,
            label: strings.askEditMessage,
          ),
        appMenuItem(value: 'copy', icon: AppIcons.copy, label: strings.copy),
        if (onAskAgain != null)
          appMenuItem(
            value: 'again',
            icon: AppIcons.refresh,
            label: strings.askAskAgain,
          ),
      ],
    );
    switch (action) {
      case 'edit':
        onEdit?.call();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: text));
      case 'again':
        AppHaptics.play(AppHaptics.tap);
        onAskAgain?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textStyle =
        theme.textTheme.bodyLarge?.copyWith(
          color: colorScheme.onPrimaryContainer,
          height: 1.45,
        ) ??
        TextStyle(color: colorScheme.onPrimaryContainer, height: 1.45);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = math.min(520.0, constraints.maxWidth * 0.84);
        final bubbleWidth = _balancedBubbleWidth(
          context: context,
          text: text,
          style: textStyle,
          maxWidth: maxW,
        );
        return Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SizedBox(
            width: bubbleWidth,
            child: AnimatedOpacity(
              // While it's back in the composer, the original steps back.
              opacity: editing ? 0.45 : 1,
              duration: AppMotion.short,
              child: Builder(
                builder: (bubbleContext) => Semantics(
                  onLongPressHint: context.l10n.more,
                  child: ExpressiveTapScale(
                    pressedScale: 0.96,
                    child: GestureDetector(
                      onLongPress: () => _showMenu(bubbleContext),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(22),
                            topRight: Radius.circular(22),
                            bottomLeft: Radius.circular(22),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Text(text, style: textStyle),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _balancedBubbleWidth({
    required BuildContext context,
    required String text,
    required TextStyle style,
    required double maxWidth,
  }) {
    const horizontalPadding = 36.0;
    final maxTextWidth = math.max(1.0, maxWidth - horizontalPadding);
    TextPainter painter(double width) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);

    final widestLayout = painter(maxTextWidth);
    final targetLines = widestLayout.computeLineMetrics().length;
    if (targetLines <= 1) {
      return math.min(maxWidth, widestLayout.width + horizontalPadding + 1);
    }

    var low = math.min(96.0, maxTextWidth);
    var high = maxTextWidth;
    for (var i = 0; i < 10; i++) {
      final midpoint = (low + high) / 2;
      final lines = painter(midpoint).computeLineMetrics().length;
      if (lines <= targetLines) {
        high = midpoint;
      } else {
        low = midpoint;
      }
    }
    return math.min(maxWidth, high + horizontalPadding + 4);
  }
}

class _AssistantBlock extends StatefulWidget {
  const _AssistantBlock({
    required this.message,
    this.latest = false,
    this.streaming = false,
    this.onRegenerate,
    this.onProactiveTipTap,
    this.onFollowUpTap,
    this.onActionConsumed,
    this.onSaveAnswerToNotesTap,
    this.onSynthesizeTap,
    this.onBuildPlanTap,
    this.onSaveItineraryTap,
    this.onSaveToCollectionTap,
  });

  final ChatMessage message;
  final bool latest;
  final bool streaming;
  final VoidCallback? onRegenerate;
  final VoidCallback? onProactiveTipTap;
  final ValueChanged<String>? onFollowUpTap;
  final VoidCallback? onActionConsumed;
  final Future<void> Function()? onSaveAnswerToNotesTap;
  final VoidCallback? onSynthesizeTap;
  final VoidCallback? onBuildPlanTap;
  final Future<bool> Function()? onSaveItineraryTap;
  final VoidCallback? onSaveToCollectionTap;

  @override
  State<_AssistantBlock> createState() => _AssistantBlockState();
}

class _AssistantBlockState extends State<_AssistantBlock> {
  bool _actionConsumed = false;
  bool _sourcesOpen = false;
  bool _copied = false;
  Timer? _copiedTimer;
  int _resultPageSize = 12;

  ChatMessage get _message => widget.message;
  bool get _hasBody => _message.text.trim().isNotEmpty;
  bool get _complete => !_message.incomplete;
  int get _cardTotal => _message.sections.isNotEmpty
      ? _message.sections.length
      : _message.sources.length;
  int get _visibleCardCount => _message.isResultList
      ? math.min(_resultPageSize, _cardTotal)
      : _cardTotal;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    AppHaptics.play(AppHaptics.tick);
    Clipboard.setData(ClipboardData(text: _message.text));
    _copiedTimer?.cancel();
    setState(() => _copied = true);
    _copiedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _runAction() async {
    AppHaptics.play(AppHaptics.tap);
    if (_message.action == ChatAction.saveItinerary) {
      final saved = await widget.onSaveItineraryTap?.call() ?? false;
      if (!saved || !mounted) return;
    }
    setState(() => _actionConsumed = true);
    widget.onActionConsumed?.call();
    switch (_message.action) {
      case ChatAction.saveToCollection:
        widget.onSaveToCollectionTap?.call();
      case ChatAction.synthesize:
        widget.onSynthesizeTap?.call();
      case ChatAction.buildPlan:
        widget.onBuildPlanTap?.call();
      case ChatAction.saveItinerary:
      case ChatAction.none:
        break;
    }
  }

  /// The saves behind the answer, as rows.
  List<Widget> _sourceRows() {
    final sections = _message.sections;
    if (sections.isNotEmpty) {
      return [
        for (var i = 0; i < sections.length && i < _visibleCardCount; i++)
          _SourceRow(
            source: sections[i].source,
            title: sections[i].heading,
            summary: sections[i].summary,
            order: sections[i].citationIndex > 0
                ? sections[i].citationIndex
                : i + 1,
            showIndex: sections.length > 1 || sections[i].citationIndex > 0,
          ),
      ];
    }
    final sources = _message.sources;
    return [
      for (var i = 0; i < sources.length && i < _visibleCardCount; i++)
        _SourceRow(
          source: sources[i],
          title: sources[i].title.isNotEmpty
              ? sources[i].title
              : sources[i].domain,
          summary: sources[i].summary ?? sources[i].description,
          order: i + 1,
          showIndex: sources.length > 1,
        ),
    ];
  }

  Widget _enter(Widget child, {int order = 0}) => EntranceMotion(
    animate: widget.latest,
    spring: true,
    offset: 10,
    delay: EntranceMotion.stagger(order),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final strings = context.l10n;
    final hasCards = _cardTotal > 0;
    final collapsesSources =
        !_message.isResultList &&
        _message.answerType != ChatAnswerType.fallback;
    final tip = _message.proactiveTip;
    final label = _message.label;
    final interrupted = _message.incomplete && !widget.streaming;
    final showAction =
        _message.action != ChatAction.none && !_actionConsumed && _complete;
    final followUps = _complete && widget.onFollowUpTap != null
        ? _message.followUpSuggestions.take(3).toList()
        : const <String>[];
    final sourcesPill = collapsesSources && hasCards
        ? _SourcesPill(
            sources: [
              if (_message.sections.isNotEmpty)
                for (final section in _message.sections) section.source
              else
                ..._message.sources,
            ],
            open: _sourcesOpen,
            onTap: () {
              AppHaptics.play(AppHaptics.tick);
              setState(() => _sourcesOpen = !_sourcesOpen);
            },
          )
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null && _complete)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_hasBody)
            AskAnswerText(
              text: _message.text,
              onCitation: !_complete
                  ? null
                  : (index) {
                      final source = _message.sections
                          .where((s) => s.citationIndex == index)
                          .firstOrNull
                          ?.source;
                      if (source != null) context.push('/url/${source.id}');
                    },
              style:
                  textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.55,
                  ) ??
                  const TextStyle(),
              selectable: _complete,
            ),
          if (interrupted)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Text(
                    strings.askInterrupted,
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (widget.onRegenerate != null) ...[
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: widget.onRegenerate,
                      child: Text(strings.retry),
                    ),
                  ],
                ],
              ),
            ),
          if (_complete && (_hasBody || sourcesPill != null))
            _enter(
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    if (_hasBody)
                      _AnswerIconButton(
                        tooltip: strings.askCopyAnswer,
                        onPressed: _copy,
                        child: AnimatedSwitcher(
                          duration: AppMotion.short,
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: AppIcon(
                            _copied ? AppIcons.check : AppIcons.copy,
                            key: ValueKey(_copied),
                            size: 18,
                            color: _copied ? colorScheme.primary : null,
                          ),
                        ),
                      ),
                    if (widget.onRegenerate != null)
                      _AnswerIconButton(
                        tooltip: strings.askRegenerate,
                        onPressed: () {
                          AppHaptics.play(AppHaptics.tap);
                          widget.onRegenerate!();
                        },
                        child: const AppIcon(AppIcons.refresh, size: 18),
                      ),
                    if (_message.noteSaved)
                      _AnswerIconButton(
                        tooltip: strings.askNoteSaved,
                        child: AppIcon(
                          AppIcons.check,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      )
                    else if (widget.onSaveAnswerToNotesTap != null)
                      _AnswerIconButton(
                        tooltip: strings.askAddNote,
                        onPressed: widget.onSaveAnswerToNotesTap,
                        child: const AppIcon(AppIcons.addNote, size: 18),
                      ),
                    // The pill takes what's left and sits at the end.
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: sourcesPill,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (sourcesPill != null)
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.emphasizedDecelerate,
              alignment: Alignment.topCenter,
              child: _sourcesOpen
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _SourceGroup(children: _sourceRows()),
                    )
                  : const SizedBox(width: double.infinity),
            )
          else if (!collapsesSources && hasCards) ...[
            const SizedBox(height: 12),
            _enter(_SourceGroup(children: _sourceRows())),
            if (_message.isResultList && _visibleCardCount < _cardTotal)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton(
                  onPressed: () => setState(() => _resultPageSize += 12),
                  child: Text(strings.showMore),
                ),
              ),
          ],
          if (showAction) ...[
            const SizedBox(height: 10),
            _enter(
              _ChatActionChip(action: _message.action, onTap: _runAction),
              order: 1,
            ),
          ],
          if (tip != null && _complete) ...[
            const SizedBox(height: 12),
            _enter(
              _ProactiveTipNudge(tip: tip, onTap: widget.onProactiveTipTap),
              order: 2,
            ),
          ],
          if (followUps.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (var i = 0; i < followUps.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: _enter(
                  _PromptPill(
                    text: followUps[i],
                    icon: AppIcons.followUp,
                    onTap: () => widget.onFollowUpTap!(followUps[i]),
                  ),
                  order: 2 + i,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A quiet 40dp icon under an answer.
class _AnswerIconButton extends StatelessWidget {
  const _AnswerIconButton({
    required this.tooltip,
    required this.child,
    this.onPressed,
  });

  final String tooltip;
  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      color: cs.onSurfaceVariant,
      disabledColor: cs.onSurfaceVariant,
      icon: child,
    );
  }
}

/// "3 sources", with the first few sites as overlapping initials; opens the
/// list of saves behind the answer.
class _SourcesPill extends StatelessWidget {
  const _SourcesPill({
    required this.sources,
    required this.open,
    required this.onTap,
  });

  final List<SavedUrl> sources;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final faces = <String>[];
    for (final source in sources) {
      final name = CategoryResolver.displaySourceName(
        rawUrl: source.rawUrl,
        fallbackDomain: source.domain,
      );
      final initial = name.trim().isEmpty ? '·' : name.trim()[0].toUpperCase();
      if (!faces.contains(initial)) faces.add(initial);
      if (faces.length == 3) break;
    }
    final tones = [
      (cs.primaryContainer, cs.onPrimaryContainer),
      (cs.tertiaryContainer, cs.onTertiaryContainer),
      (cs.secondaryContainer, cs.onSecondaryContainer),
    ];
    const face = 22.0;
    const overlap = 7.0;

    return Semantics(
      button: true,
      expanded: open,
      child: Material(
        color: open ? cs.secondaryContainer : cs.surfaceContainer,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 9, 12, 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: face + (faces.length - 1) * (face - overlap),
                  height: face,
                  child: Stack(
                    children: [
                      for (var i = faces.length - 1; i >= 0; i--)
                        Positioned(
                          left: i * (face - overlap),
                          child: Container(
                            width: face,
                            height: face,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: tones[i].$1,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: open
                                    ? cs.secondaryContainer
                                    : cs.surfaceContainer,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              faces[i],
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: tones[i].$2,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.l10n.askSourcesCount(sources.length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: open ? cs.onSecondaryContainer : cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: AppMotion.medium,
                  curve: AppMotion.emphasized,
                  child: AppIcon(
                    AppIcons.chevronDown,
                    size: 14,
                    color: open ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Saves behind an answer, as one rounded group of rows.
class _SourceGroup extends StatelessWidget {
  const _SourceGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One save behind an answer: opens its details; the arrow opens the page.
class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.title,
    required this.summary,
    required this.order,
    required this.showIndex,
  });

  final SavedUrl source;
  final String title;
  final String summary;
  final int order;
  final bool showIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final domain = CategoryResolver.displaySourceName(
      rawUrl: source.rawUrl,
      fallbackDomain: source.domain,
    );
    return InkWell(
      onTap: () => context.push('/url/${source.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showIndex) ...[
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$order',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (summary.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    domain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.l10n.open,
              visualDensity: VisualDensity.compact,
              color: cs.onSurfaceVariant,
              icon: const AppIcon(AppIcons.externalLink, size: 18),
              onPressed: () => _openExternalUrl(source.rawUrl),
            ),
          ],
        ),
      ),
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
    final cs = theme.colorScheme;
    return Material(
      color: cs.tertiaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(AppIcons.idea, size: 18, color: cs.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tip,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onTertiaryContainer,
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

Future<void> _openExternalUrl(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// While Glimpse works: a shimmering line where the answer will be.
class GlimpseTypingIndicator extends StatelessWidget {
  const GlimpseTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = Text(
      context.l10n.askThinking,
      style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 16),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: MediaQuery.disableAnimationsOf(context)
            ? DefaultTextStyle.merge(
                style: TextStyle(color: cs.onSurfaceVariant),
                child: text,
              )
            : Shimmer.fromColors(
                baseColor: cs.onSurfaceVariant.withValues(alpha: 0.7),
                highlightColor: cs.onSurface,
                period: const Duration(milliseconds: 1500),
                child: text,
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
    this.editing,
    this.editingReplacesLater = false,
    this.onCancelEdit,
    required this.onSubmit,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;

  /// The question being edited in place, if any.
  final ChatMessage? editing;
  final bool editingReplacesLater;
  final VoidCallback? onCancelEdit;
  final SavedUrl? attachedSource;
  final VoidCallback? onClearAttachedSource;
  final ValueChanged<String> onSubmit;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kChatMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Material(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: AppMotion.medium,
                    curve: AppMotion.emphasizedDecelerate,
                    alignment: Alignment.bottomCenter,
                    child: editing != null
                        ? _ComposerStrip(
                            icon: AppIcons.edit,
                            overline: editingReplacesLater
                                ? context.l10n.askEditingReplaces
                                : context.l10n.askEditingQuestion,
                            title: editing!.text,
                            actionLabel: context.l10n.cancel,
                            onAction: onCancelEdit,
                          )
                        : attachedSource == null
                        ? const SizedBox(width: double.infinity)
                        : _AttachedSourceBar(
                            source: attachedSource!,
                            onClear: onClearAttachedSource,
                          ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onSubmitted: (_) {
                            if (controller.text.trim().isNotEmpty) {
                              onSubmit(controller.text);
                            }
                          },
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          textCapitalization: TextCapitalization.sentences,
                          textAlignVertical: TextAlignVertical.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: attachedSource == null
                                ? context.l10n.messageGlimpse
                                : context.l10n.askAboutThisSave,
                            hintStyle: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isDense: true,
                            constraints: const BoxConstraints(minHeight: 56),
                            contentPadding: const EdgeInsets.fromLTRB(
                              20,
                              16,
                              8,
                              16,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: _SendButton(
                          controller: controller,
                          isLoading: isLoading,
                          onSubmit: onSubmit,
                          onStop: onStop,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Send when there's a question, Stop while an answer is coming, quiet
/// otherwise.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onSubmit;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final active = isLoading || hasText;
        return AnimatedContainer(
          duration: AppMotion.short,
          curve: AppMotion.emphasizedDecelerate,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? cs.primary : cs.primary.withValues(alpha: 0),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            tooltip: isLoading ? context.l10n.askStop : context.l10n.send,
            padding: EdgeInsets.zero,
            color: cs.onPrimary,
            disabledColor: cs.onSurfaceVariant.withValues(alpha: 0.6),
            onPressed: isLoading
                ? () {
                    AppHaptics.play(AppHaptics.tap);
                    onStop();
                  }
                : hasText
                ? () {
                    AppHaptics.play(AppHaptics.tap);
                    onSubmit(controller.text);
                  }
                : null,
            icon: AnimatedSwitcher(
              duration: AppMotion.short,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: AppIcon(
                isLoading ? AppIcons.stop : AppIcons.arrowUp,
                key: ValueKey(isLoading),
                size: isLoading ? 16 : 20,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The save a question is about, at the top of the composer.
class _AttachedSourceBar extends ConsumerWidget {
  const _AttachedSourceBar({required this.source, this.onClear});

  final SavedUrl source;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagFreq = ref.watch(tagOccurrenceMapProvider);
    final title = TitleResolver.resolveDetailTitle(
      source,
      tagFrequency: tagFreq,
    );
    final platform = CategoryResolver.displaySourceName(
      rawUrl: source.rawUrl,
      fallbackDomain: source.domain,
    );

    return _ComposerStrip(
      icon: AppIcons.link,
      overline: '${context.l10n.askAskingAbout} · $platform',
      title: title,
      actionLabel: onClear == null ? null : context.l10n.askAllSaves,
      onAction: onClear,
    );
  }
}

/// The line at the top of the composer saying what the next send does:
/// asks about one save, or replaces an edited question.
class _ComposerStrip extends StatelessWidget {
  const _ComposerStrip({
    required this.icon,
    required this.overline,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String overline;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: AppIcon(icon, size: 16, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    overline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

/// The one next step an answer suggests, as a tonal pill.
class _ChatActionChip extends StatelessWidget {
  final ChatAction action;
  final VoidCallback onTap;

  const _ChatActionChip({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final (icon, label) = switch (action) {
      ChatAction.saveToCollection => (
        AppIcons.bookmarkAdd,
        strings.askActionSaveToCollection,
      ),
      ChatAction.synthesize => (AppIcons.sparkle, strings.askActionSynthesize),
      ChatAction.buildPlan => (AppIcons.calendar, strings.askActionBuildPlan),
      ChatAction.saveItinerary => (
        AppIcons.route,
        strings.askActionSaveItinerary,
      ),
      ChatAction.none => (null, ''),
    };
    if (icon == null) return const SizedBox.shrink();

    return ExpressiveTapScale(
      pressedScale: 0.97,
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        icon: AppIcon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

/// A rounded group of rows, as in Settings: the sheets' one container.
class _SheetGroup extends StatelessWidget {
  const _SheetGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 66,
                endIndent: 16,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A filled search field for long lists in a sheet.
class _SheetSearchField extends StatelessWidget {
  const _SheetSearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: AppIcon(AppIcons.search, size: 18, color: cs.onSurfaceVariant),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Recent chats, grouped by when they last moved. Rename and delete stay in
/// the sheet; a deleted chat leaves an Undo in its place.
class _ChatHistorySheet extends StatefulWidget {
  const _ChatHistorySheet({
    required this.chats,
    required this.currentKey,
    required this.onOpen,
    required this.onNewChat,
    required this.onRename,
    required this.onDelete,
    required this.onRestore,
  });

  final List<AskConversation> chats;
  final String? currentKey;
  final ValueChanged<AskConversation> onOpen;
  final VoidCallback onNewChat;
  final Future<String?> Function(AskConversation chat) onRename;
  final Future<void> Function(AskConversation chat) onDelete;
  final Future<void> Function(AskConversation chat) onRestore;

  @override
  State<_ChatHistorySheet> createState() => _ChatHistorySheetState();
}

enum _ChatAge { today, yesterday, thisWeek, earlier }

class _ChatHistorySheetState extends State<_ChatHistorySheet> {
  /// Below this many chats the whole list fits and search is noise.
  static const _searchThreshold = 8;

  late final List<AskConversation> _chats = [...widget.chats]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final Set<String> _deleted = {};
  String _query = '';

  static _ChatAge _age(DateTime at, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return _ChatAge.today;
    if (days == 1) return _ChatAge.yesterday;
    if (days < 7) return _ChatAge.thisWeek;
    return _ChatAge.earlier;
  }

  String _ageLabel(AppLocalizations strings, _ChatAge age) => switch (age) {
    _ChatAge.today => strings.today,
    _ChatAge.yesterday => strings.yesterday,
    _ChatAge.thisWeek => strings.thisWeek,
    _ChatAge.earlier => strings.askEarlier,
  };

  String _when(BuildContext context, DateTime at, _ChatAge age) {
    final material = MaterialLocalizations.of(context);
    final local = at.toLocal();
    return switch (age) {
      _ChatAge.today || _ChatAge.yesterday => material.formatTimeOfDay(
        TimeOfDay.fromDateTime(local),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      ),
      _ChatAge.thisWeek => material.formatMediumDate(local),
      _ChatAge.earlier => material.formatShortMonthDay(local),
    };
  }

  Future<void> _rename(AskConversation chat) async {
    final title = await widget.onRename(chat);
    if (title != null && mounted) setState(() => chat.title = title);
  }

  Future<void> _delete(AskConversation chat) async {
    AppHaptics.play(AppHaptics.tap);
    setState(() => _deleted.add(chat.key));
    await widget.onDelete(chat);
  }

  Future<void> _restore(AskConversation chat) async {
    AppHaptics.play(AppHaptics.tick);
    setState(() => _deleted.remove(chat.key));
    await widget.onRestore(chat);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = context.l10n;
    final now = DateTime.now();
    final query = _query.trim().toLowerCase();
    final groups = <_ChatAge, List<AskConversation>>{};
    for (final chat in _chats) {
      if (query.isNotEmpty && !chat.title.toLowerCase().contains(query)) {
        continue;
      }
      groups.putIfAbsent(_age(chat.updatedAt, now), () => []).add(chat);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.askRecentChats,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      AppHaptics.play(AppHaptics.tap);
                      widget.onNewChat();
                    },
                    icon: const AppIcon(AppIcons.newChat, size: 18),
                    label: Text(strings.newChat),
                  ),
                ],
              ),
            ),
            if (_chats.length >= _searchThreshold)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SheetSearchField(
                  hint: strings.askSearchChats,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            if (_chats.isEmpty || groups.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: AppIcon(
                        _chats.isEmpty ? AppIcons.chat : AppIcons.search,
                        size: 24,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _chats.isEmpty
                          ? strings.askNoChats
                          : strings.askNoChatsMatch,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (_chats.isEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        strings.askNoChatsHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final age in _ChatAge.values)
                      if (groups[age] case final chats?) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          child: Text(
                            _ageLabel(strings, age),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _SheetGroup(
                          children: [
                            for (final chat in chats)
                              _deleted.contains(chat.key)
                                  ? _DeletedChatRow(
                                      onUndo: () => _restore(chat),
                                    )
                                  : _ChatRow(
                                      title: chat.title,
                                      when: _when(context, chat.updatedAt, age),
                                      current: chat.key == widget.currentKey,
                                      onTap: () => widget.onOpen(chat),
                                      onRename: () => _rename(chat),
                                      onDelete: () => _delete(chat),
                                    ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.title,
    required this.when,
    required this.current,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final String title;
  final String when;
  final bool current;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = context.l10n;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: current
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: AppIcon(
                AppIcons.chat,
                filled: current,
                size: 18,
                color: current ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    current ? strings.askOpenNow : when,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: current ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: strings.more,
              icon: AppIcon(
                AppIcons.more,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              onSelected: (action) =>
                  action == 'delete' ? onDelete() : onRename(),
              itemBuilder: (_) => [
                appMenuItem(
                  value: 'rename',
                  icon: AppIcons.edit,
                  label: strings.askRenameChat,
                ),
                appMenuItem(
                  value: 'delete',
                  icon: AppIcons.clearData,
                  label: strings.delete,
                  destructive: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeletedChatRow extends StatelessWidget {
  const _DeletedChatRow({required this.onUndo});

  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(66, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.askChatDeleted,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(onPressed: onUndo, child: Text(context.l10n.undo)),
        ],
      ),
    );
  }
}

/// One choice in the save-to-collection sheet: a new collection, or one of
/// yours with how many of these saves it already holds.
class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.leading,
    required this.name,
    required this.subtitle,
    this.isCreate = false,
    this.added = false,
    this.onTap,
  });

  final Widget leading;
  final String name;
  final String subtitle;
  final bool isCreate;

  /// Every save is already in it: shown, but nothing to do.
  final bool added;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        child: Row(
          children: [
            SizedBox.square(dimension: 44, child: Center(child: leading)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isCreate ? cs.primary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: added ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (added) AppIcon(AppIcons.check, size: 20, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class _SaveToCollectionSheet extends ConsumerStatefulWidget {
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
  ConsumerState<_SaveToCollectionSheet> createState() =>
      _SaveToCollectionSheetState();
}

class _SaveToCollectionSheetState
    extends ConsumerState<_SaveToCollectionSheet> {
  /// Below this many collections the whole list fits and search is noise.
  static const _searchThreshold = 7;

  String _query = '';

  late final Set<int> _ids = {for (final s in widget.sources) s.id};

  int _alreadyIn(UserCollection collection) =>
      collection.urlIds.where(_ids.contains).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = context.l10n;
    final collections = ref.watch(collectionsListProvider);
    final all = collections.valueOrNull ?? const <UserCollection>[];
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final c in all)
        if (query.isEmpty || c.name.toLowerCase().contains(query)) c,
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 2),
              child: Text(
                strings.askActionSaveToCollection,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                strings.linkCount(widget.sources.length),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            if (all.length >= _searchThreshold)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SheetSearchField(
                  hint: strings.searchCollections,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (query.isEmpty) ...[
                    _SheetGroup(
                      children: [
                        _CollectionTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: AppIcon(
                              AppIcons.add,
                              size: 20,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          name: strings.newCollection,
                          subtitle: strings.askNewCollectionHint,
                          isCreate: true,
                          onTap: () => _createAndSave(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (collections.isLoading && all.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: ExpressiveLoadingIndicator(
                          size: 32,
                          color: cs.primary,
                        ),
                      ),
                    )
                  else if (shown.isNotEmpty)
                    _SheetGroup(
                      children: [
                        for (final col in shown) _collectionRow(strings, col),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collectionRow(AppLocalizations strings, UserCollection col) {
    final inIt = _alreadyIn(col);
    final added = inIt == _ids.length;
    return _CollectionTile(
      leading: CollectionVisual(
        style: resolveCollectionVisual(col),
        size: 40,
        iconSize: 18,
      ),
      name: col.name,
      subtitle: added
          ? strings.askAlreadyInCollection
          : inIt > 0
          ? strings.askSomeInCollection(inIt)
          : strings.linkCount(col.urlIds.length),
      added: added,
      onTap: added ? null : () => _addToExisting(context, col, inIt),
    );
  }

  void _announce(UserCollection collection, int count, {bool open = true}) {
    final host = widget.hostContext;
    if (!host.mounted) return;
    final strings = host.l10n;
    ScaffoldMessenger.of(host)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(strings.askAddedToCollection(count, collection.name)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: open
              ? SnackBarAction(
                  label: strings.open,
                  onPressed: () => host.push('/collections/${collection.id}'),
                )
              : null,
        ),
      );
  }

  Future<void> _createAndSave(BuildContext context) async {
    AppHaptics.play(AppHaptics.tap);
    Navigator.pop(context);

    final defaultName = widget.sources.length == 1
        ? widget.sources.first.title
        : '';
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
    AppHaptics.play(AppHaptics.success);
    _announce(collection, widget.sources.length, open: false);
    if (widget.hostContext.mounted) {
      widget.hostContext.push('/collections/${collection.id}');
    }
  }

  Future<void> _addToExisting(
    BuildContext context,
    UserCollection col,
    int alreadyIn,
  ) async {
    AppHaptics.play(AppHaptics.success);
    Navigator.pop(context);
    await widget.isarService.addUrlsToCollection(
      collectionId: col.id,
      urlIds: widget.sources.map((u) => u.id).toList(),
    );
    widget.onCollectionChanged(col.id);
    _announce(col, _ids.length - alreadyIn);
  }
}

/// A side-effect-free composition of the real chat turns for bundled previews.
class AskConversationPreview extends StatelessWidget {
  const AskConversationPreview({super.key, required this.messages});
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final message in messages) _ChatTurn(message: message)],
    ),
  );
}
