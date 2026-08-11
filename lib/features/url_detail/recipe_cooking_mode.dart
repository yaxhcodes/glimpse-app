part of 'url_detail_screen.dart';

class _RecipeCookingModeScreen extends StatefulWidget {
  const _RecipeCookingModeScreen({required this.recipe});

  final EnrichedRecipe recipe;

  @override
  State<_RecipeCookingModeScreen> createState() =>
      _RecipeCookingModeScreenState();
}

class _RecipeCookingModeScreenState extends State<_RecipeCookingModeScreen> {
  int _index = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.recipe.steps.length) return;
    setState(() => _index = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final steps = widget.recipe.steps;
    final hasSteps = steps.isNotEmpty;
    final isFirst = !hasSteps || _index == 0;
    final isLast = !hasSteps || _index == steps.length - 1;
    final progress = steps.isEmpty ? 0.0 : (_index + 1) / steps.length;
    final cookAccent = _cookAccent(colorScheme);
    final recipeTitle = widget.recipe.title.trim().isEmpty
        ? 'Cooking Mode'
        : widget.recipe.title.trim();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Close',
        ),
        title: const Text('Cook Mode'),
        actions: [
          if (hasSteps)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Center(
                child: _CookModePill(
                  label: '${_index + 1}/${steps.length}',
                  icon: Icons.format_list_numbered_rounded,
                  color: cookAccent,
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CookModeHeader(
                title: recipeTitle,
                recipe: widget.recipe,
                progress: progress,
                accent: cookAccent,
                theme: theme,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: hasSteps
                    ? PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (i) => setState(() => _index = i),
                        itemCount: steps.length,
                        itemBuilder: (context, i) {
                          return _CookStepCard(
                            step: steps[i],
                            stepNumber: i + 1,
                            totalSteps: steps.length,
                            accent: cookAccent,
                            theme: theme,
                            colorScheme: colorScheme,
                          );
                        },
                      )
                    : _CookEmptyState(theme: theme, colorScheme: colorScheme),
              ),
              const SizedBox(height: 14),
              if (hasSteps)
                _CookStepDots(
                  count: steps.length,
                  activeIndex: _index,
                  accent: cookAccent,
                  colorScheme: colorScheme,
                  onTap: _goTo,
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _CookNavButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: isFirst ? null : () => _goTo(_index - 1),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isLast
                          ? () => Navigator.pop(context)
                          : () => _goTo(_index + 1),
                      icon: Icon(
                        isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(isLast ? 'Done' : 'Next Step'),
                      style: FilledButton.styleFrom(
                        backgroundColor: cookAccent,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _cookAccent(ColorScheme colorScheme) {
    return Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.46),
      colorScheme.onSurfaceVariant,
    );
  }
}

class _CookModeHeader extends StatelessWidget {
  const _CookModeHeader({
    required this.title,
    required this.recipe,
    required this.progress,
    required this.accent,
    required this.theme,
    required this.colorScheme,
  });

  final String title;
  final EnrichedRecipe recipe;
  final double progress;
  final Color accent;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final meta = <Widget>[
      if ((recipe.totalTime ?? '').trim().isNotEmpty)
        _CookModePill(
          label: recipe.totalTime!.trim(),
          icon: Icons.timer_outlined,
          color: accent,
          colorScheme: colorScheme,
          theme: theme,
        ),
      if ((recipe.difficulty ?? '').trim().isNotEmpty)
        _CookModePill(
          label: recipe.difficulty!.trim(),
          icon: Icons.local_fire_department_outlined,
          color: accent,
          colorScheme: colorScheme,
          theme: theme,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.editorial(
            theme.textTheme.titleLarge,
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            height: 1.12,
            letterSpacing: 0,
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: meta),
        ],
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.6,
            ),
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _CookStepCard extends StatelessWidget {
  const _CookStepCard({
    required this.step,
    required this.stepNumber,
    required this.totalSteps,
    required this.accent,
    required this.theme,
    required this.colorScheme,
  });

  final String step;
  final int stepNumber;
  final int totalSteps;
  final Color accent;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.012),
          colorScheme.surfaceContainerLow,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$stepNumber',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Step $stepNumber of $totalSteps',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                step,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.42,
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CookStepDots extends StatelessWidget {
  const _CookStepDots({
    required this.count,
    required this.activeIndex,
    required this.accent,
    required this.colorScheme,
    required this.onTap,
  });

  final int count;
  final int activeIndex;
  final Color accent;
  final ColorScheme colorScheme;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (count > 18) {
      return Text(
        '${activeIndex + 1} / $count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == activeIndex;
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active
                  ? accent
                  : colorScheme.outlineVariant.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _CookNavButton extends StatelessWidget {
  const _CookNavButton({
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _CookModePill extends StatelessWidget {
  const _CookModePill({
    required this.label,
    required this.icon,
    required this.color,
    required this.colorScheme,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final Color color;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CookEmptyState extends StatelessWidget {
  const _CookEmptyState({required this.theme, required this.colorScheme});

  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No cooking steps yet.',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
