import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/constants/app_assets.dart';
import '../../core/models/url_processing_status.dart';
import '../../core/services/demo_seed_service.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/url_card.dart';

abstract final class OnboardingPalette {
  static const ink = Color(0xFF090D0C);
  static const raised = Color(0xFF141A18);
  static const raisedHigh = Color(0xFF202724);
  static const sage = Color(0xFFB8C99A);
  static const sageDeep = Color(0xFF78906A);
  static const paper = Color(0xFFF3ECDD);
}

const _calendarCompleteAt = 0.58;
const _notificationRevealAt = 0.68;

class OnboardingStoryScene extends StatefulWidget {
  const OnboardingStoryScene({
    super.key,
    required this.chapter,
    required this.onMemoryOpened,
    required this.onEnrichmentComplete,
  });

  final int chapter;
  final VoidCallback onMemoryOpened;
  final VoidCallback onEnrichmentComplete;

  @override
  State<OnboardingStoryScene> createState() => OnboardingStorySceneState();
}

class OnboardingStorySceneState extends State<OnboardingStoryScene>
    with TickerProviderStateMixin {
  late final AnimationController _shareConfirmation;
  late final AnimationController _enrichment;
  late final AnimationController _timePassage;
  bool _memoryOpened = false;
  bool _enrichmentReported = false;

  @override
  void initState() {
    super.initState();
    _shareConfirmation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _enrichment =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2200),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _reportEnrichment();
        });
    _timePassage = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1550),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      if (widget.chapter >= 2) _enrichment.value = 1;
      if (widget.chapter >= 3) _timePassage.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant OnboardingStoryScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter == widget.chapter) return;

    if (widget.chapter == 1) {
      _shareConfirmation.value = 0;
    }
    if (widget.chapter == 2) {
      _memoryOpened = false;
      if (_reduceMotion(context)) {
        _enrichment.value = 1;
        _reportEnrichment();
      } else {
        unawaited(_enrichment.forward(from: 0));
      }
    }
    if (widget.chapter == 3) {
      finishEnrichment();
      _memoryOpened = false;
      if (_reduceMotion(context)) {
        _timePassage.value = 1;
      } else {
        unawaited(_timePassage.forward(from: 0));
      }
    }
    if (widget.chapter < 3) {
      _timePassage.value = 0;
      _memoryOpened = false;
    }
  }

  Future<void> selectGlimpse() async {
    if (_shareConfirmation.isCompleted) return;
    HapticFeedback.selectionClick();
    if (_reduceMotion(context)) {
      _shareConfirmation.value = 1;
      return;
    }
    await _shareConfirmation.forward();
  }

  void finishEnrichment() {
    if (!_enrichment.isCompleted) _enrichment.value = 1;
    _reportEnrichment();
  }

  void openMemory() {
    if (_memoryOpened) return;
    if (!_timePassage.isCompleted) _timePassage.value = 1;
    HapticFeedback.selectionClick();
    setState(() => _memoryOpened = true);
    widget.onMemoryOpened();
  }

  void closeMemory() {
    if (!_memoryOpened) return;
    setState(() => _memoryOpened = false);
  }

  @visibleForTesting
  void setTimePassage(double value) {
    _timePassage
      ..stop()
      ..value = value.clamp(0, 1).toDouble();
  }

  void _reportEnrichment() {
    if (_enrichmentReported) return;
    _enrichmentReported = true;
    widget.onEnrichmentComplete();
  }

  @override
  void dispose() {
    _shareConfirmation.dispose();
    _enrichment.dispose();
    _timePassage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;
    final motion = _motionDuration(context, 420);
    return Semantics(
      label: _sceneLabel(chapter),
      child: RepaintBoundary(
        key: const ValueKey('onboarding-story-stage'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AnimatedContainer(
            duration: motion,
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              color: chapter == 3
                  ? Colors.transparent
                  : OnboardingPalette.raised,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: chapter == 3
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedOpacity(
                  opacity: chapter <= 1 ? 1 : 0,
                  duration: motion,
                  child: const _BrowserEnvironment(),
                ),
                _PersistentArticle(chapter: chapter),
                AnimatedOpacity(
                  opacity: chapter == 1 ? 1 : 0,
                  duration: motion,
                  child: _ShareEnvironment(
                    confirmation: _shareConfirmation,
                    onSelect: selectGlimpse,
                  ),
                ),
                AnimatedOpacity(
                  opacity: chapter == 2 ? 1 : 0,
                  duration: motion,
                  child: TickerMode(
                    enabled: chapter == 2,
                    child: IgnorePointer(
                      ignoring: chapter != 2,
                      child: _EnrichmentEnvironment(progress: _enrichment),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: chapter == 3 ? 1 : 0,
                  duration: motion,
                  child: IgnorePointer(
                    ignoring: chapter != 3,
                    child: _RediscoverEnvironment(
                      progress: _timePassage,
                      opened: _memoryOpened,
                      onOpen: openMemory,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sceneLabel(int chapter) => switch (chapter) {
    0 => 'A Kyoto article discovered in a browser',
    1 => 'The same Kyoto article entering the Android share sheet',
    2 => 'Glimpse understanding and organizing the Kyoto article',
    _ => 'The same Kyoto memory returning two weeks later',
  };
}

class _PersistentArticle extends StatelessWidget {
  const _PersistentArticle({required this.chapter});

  final int chapter;

  @override
  Widget build(BuildContext context) {
    final visible = chapter <= 1;
    return AnimatedPositioned(
      duration: _motionDuration(context, 520),
      curve: Curves.easeInOutCubic,
      left: 12,
      right: 12,
      top: 54,
      bottom: 12,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: _motionDuration(context, 260),
        child: IgnorePointer(
          ignoring: !visible,
          child: _KyotoArticle(showShare: chapter == 0),
        ),
      ),
    );
  }
}

class _BrowserEnvironment extends StatelessWidget {
  const _BrowserEnvironment();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: OnboardingPalette.sage,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'kyoto.travel',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const AppIcon(Symbols.more_vert_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ShareEnvironment extends StatelessWidget {
  const _ShareEnvironment({required this.confirmation, required this.onSelect});

  final Animation<double> confirmation;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: confirmation,
      builder: (context, _) {
        final selected = confirmation.value > 0.45;
        final compact = MediaQuery.sizeOf(context).width < 360;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, 12 * confirmation.value),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 16),
              decoration: const BoxDecoration(
                color: OnboardingPalette.raisedHigh,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    'Share with',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ShareTarget(
                        key: const ValueKey('onboarding-share-target'),
                        label: 'Glimpse',
                        onTap: onSelect,
                        selected: selected,
                        emphasized: true,
                        compact: compact,
                        mark: _GlimpseMark(size: compact ? 46 : 52),
                      ),
                      _ShareTarget(
                        label: 'WhatsApp',
                        compact: compact,
                        mark: _ShareBrandMark(
                          asset: AppAssets.whatsapp,
                          size: compact ? 46 : 52,
                          background: const Color(0xFFEDF8F0),
                        ),
                      ),
                      _ShareTarget(
                        label: 'Gmail',
                        compact: compact,
                        mark: _ShareBrandMark(
                          asset: AppAssets.gmail,
                          size: compact ? 46 : 52,
                          background: const Color(0xFFF8F3EF),
                        ),
                      ),
                      _ShareTarget(
                        label: 'Messages',
                        compact: compact,
                        mark: _ShareBrandMark(
                          asset: AppAssets.googleMessages,
                          size: compact ? 46 : 52,
                          background: const Color(0xFFF3F6FC),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Container(
                    key: const ValueKey('onboarding-copy-link-action'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.045),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        const AppIcon(
                          Symbols.link_rounded,
                          size: 18,
                          color: OnboardingPalette.sage,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Copy link',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          'kyoto.travel',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShareTarget extends StatelessWidget {
  const _ShareTarget({
    super.key,
    required this.label,
    required this.mark,
    required this.compact,
    this.onTap,
    this.selected = false,
    this.emphasized = false,
  });

  final String label;
  final Widget mark;
  final bool compact;
  final VoidCallback? onTap;
  final bool selected;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 38,
        child: SizedBox(
          width: compact ? 52 : 66,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: _motionDuration(context, 180),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      border: emphasized
                          ? Border.all(
                              color: OnboardingPalette.sage.withValues(
                                alpha: selected ? 1 : 0.58,
                              ),
                              width: selected ? 2 : 1,
                            )
                          : null,
                    ),
                    child: mark,
                  ),
                  if (selected)
                    const Positioned(
                      right: -3,
                      bottom: -3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: OnboardingPalette.sage,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(3),
                          child: AppIcon(
                            Symbols.check_rounded,
                            size: 12,
                            color: OnboardingPalette.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontSize: compact ? 9 : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareBrandMark extends StatelessWidget {
  const _ShareBrandMark({
    required this.asset,
    required this.size,
    required this.background,
  });

  final String asset;
  final double size;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.23),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: SvgPicture.asset(asset),
    );
  }
}

class _EnrichmentEnvironment extends StatelessWidget {
  const _EnrichmentEnvironment({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 440;
        return AnimatedBuilder(
          animation: progress,
          builder: (context, _) {
            final completedSteps = _completedEnrichmentSteps(progress.value);
            final ready = completedSteps == _understandingSteps.length;
            if (compact) {
              return _CompactEnrichmentLedger(
                completedSteps: completedSteps,
                ready: ready,
              );
            }
            final content = Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EnrichmentHeader(
                    completedSteps: completedSteps,
                    ready: ready,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < _understandingSteps.length;
                          index++
                        )
                          Expanded(
                            child: _EnrichmentStepRow(
                              index: index,
                              completed: index < completedSteps,
                              active: index == completedSteps && !ready,
                              compact: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SavedMemoryResult(ready: ready),
                ],
              ),
            );
            return content;
          },
        );
      },
    );
  }
}

class _CompactEnrichmentLedger extends StatelessWidget {
  const _CompactEnrichmentLedger({
    required this.completedSteps,
    required this.ready,
  });

  final int completedSteps;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(
        children: [
          _EnrichmentHeader(completedSteps: completedSteps, ready: ready),
          const SizedBox(height: 5),
          Expanded(
            child: Column(
              children: [
                for (var index = 0; index < _understandingSteps.length; index++)
                  Expanded(
                    child: _CompactEnrichmentStep(
                      index: index,
                      completed: index < completedSteps,
                      active: index == completedSteps && !ready,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          _CompactSavedMemoryResult(ready: ready),
        ],
      ),
    );
  }
}

class _CompactEnrichmentStep extends StatelessWidget {
  const _CompactEnrichmentStep({
    required this.index,
    required this.completed,
    required this.active,
  });

  final int index;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final step = _understandingSteps[index];
    final visible = completed || active;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0.32,
      duration: _motionDuration(context, 180),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: completed
                  ? OnboardingPalette.sage
                  : OnboardingPalette.sage.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              completed ? Symbols.check_rounded : step.icon,
              size: 12,
              color: completed ? OnboardingPalette.ink : OnboardingPalette.sage,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: visible ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              visible ? step.value : 'Waiting',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active
                    ? OnboardingPalette.sage
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSavedMemoryResult extends StatelessWidget {
  const _CompactSavedMemoryResult({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(ready ? 'ready-memory-card' : 'processing-memory-card'),
      height: 58,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ready
              ? OnboardingPalette.sage.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset(
              AppAssets.onboardingKyoto,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? 'Three quiet days in Kyoto' : 'Kyoto Travel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ready ? 'Ready to search' : 'Building your memory',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          AppIcon(
            ready ? Symbols.check_circle_rounded : Symbols.auto_awesome_rounded,
            size: 18,
            color: OnboardingPalette.sage,
          ),
        ],
      ),
    );
  }
}

const _understandingSteps = <({IconData icon, String label, String value})>[
  (icon: Symbols.link_rounded, label: 'Link received', value: 'kyoto.travel'),
  (
    icon: Symbols.image_rounded,
    label: 'Thumbnail found',
    value: 'Kyoto at dusk',
  ),
  (
    icon: Symbols.subject_rounded,
    label: 'Summary written',
    value: 'Quiet 3-day plan',
  ),
  (icon: Symbols.sell_rounded, label: 'Tags created', value: 'Kyoto · autumn'),
  (
    icon: Symbols.account_tree_rounded,
    label: 'Intent understood',
    value: 'Visit later',
  ),
];

int _completedEnrichmentSteps(double progress) {
  if (progress >= 0.88) return _understandingSteps.length;
  return (progress / 0.17)
      .floor()
      .clamp(0, _understandingSteps.length - 1)
      .toInt();
}

class _EnrichmentHeader extends StatelessWidget {
  const _EnrichmentHeader({required this.completedSteps, required this.ready});

  final int completedSteps;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(
          ready ? Symbols.check_circle_rounded : Symbols.auto_awesome_rounded,
          size: 18,
          color: OnboardingPalette.sage,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ready ? 'SEARCHABLE MEMORY' : 'UNDERSTANDING YOUR SAVE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: OnboardingPalette.sage,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
        ),
        Text(
          '$completedSteps/${_understandingSteps.length}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: OnboardingPalette.sage,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EnrichmentStepRow extends StatelessWidget {
  const _EnrichmentStepRow({
    required this.index,
    required this.completed,
    required this.active,
    required this.compact,
  });

  final int index;
  final bool completed;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final step = _understandingSteps[index];
    final visible = completed || active;
    final cs = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      key: ValueKey('enrichment-step-$index'),
      opacity: visible ? 1 : 0.32,
      duration: _motionDuration(context, 220),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 1,
                    color: index == 0
                        ? Colors.transparent
                        : completed
                        ? OnboardingPalette.sage.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                AnimatedContainer(
                  duration: _motionDuration(context, 220),
                  width: compact ? 24 : 28,
                  height: compact ? 24 : 28,
                  decoration: BoxDecoration(
                    color: completed
                        ? OnboardingPalette.sage
                        : active
                        ? OnboardingPalette.sage.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: active
                        ? Border.all(color: OnboardingPalette.sage)
                        : null,
                  ),
                  child: AppIcon(
                    completed ? Symbols.check_rounded : step.icon,
                    size: compact ? 14 : 16,
                    color: completed
                        ? OnboardingPalette.ink
                        : active
                        ? OnboardingPalette.sage
                        : cs.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 1,
                    color: index == _understandingSteps.length - 1
                        ? Colors.transparent
                        : completed
                        ? OnboardingPalette.sage.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedContainer(
              duration: _motionDuration(context, 220),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: active
                    ? OnboardingPalette.sage.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      step.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: visible ? cs.onSurface : cs.onSurfaceVariant,
                        fontWeight: active || completed
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      visible ? step.value : 'Waiting',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: active
                            ? OnboardingPalette.sage
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedMemoryResult extends StatelessWidget {
  const _SavedMemoryResult({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _motionDuration(context, 280),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: ready
            ? OnboardingPalette.sage.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ready
              ? OnboardingPalette.sage.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: AnimatedSwitcher(
        duration: _motionDuration(context, 280),
        layoutBuilder: (current, previous) => current ?? const SizedBox(),
        child: ready
            ? const _RealKyotoCard(key: ValueKey('ready-memory-card'))
            : const _RealKyotoCard(
                key: ValueKey('processing-memory-card'),
                processing: true,
              ),
      ),
    );
  }
}

class _RediscoverEnvironment extends StatelessWidget {
  const _RediscoverEnvironment({
    required this.progress,
    required this.opened,
    required this.onOpen,
  });

  final Animation<double> progress;
  final bool opened;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
          child: AnimatedSwitcher(
            duration: _motionDuration(context, 380),
            layoutBuilder: (current, previous) => current ?? const SizedBox(),
            child: opened
                ? const _OpenedMemory(key: ValueKey('opened-memory'))
                : progress.value >= _notificationRevealAt
                ? _RediscoverNotification(
                    key: const ValueKey('rediscover-notification'),
                    onTap: onOpen,
                  )
                : _CalendarPassage(
                    key: const ValueKey('passing-memory'),
                    progress: progress.value,
                  ),
          ),
        );
      },
    );
  }
}

class _CalendarPassage extends StatelessWidget {
  const _CalendarPassage({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final calendarProgress = (progress / _calendarCompleteAt)
        .clamp(0.0, 1.0)
        .toDouble();
    final elapsedDay = (calendarProgress * 14).ceil().clamp(1, 14).toInt();
    final elapsedLabel = elapsedDay < 7
        ? 'This week'
        : elapsedDay < 14
        ? 'Next week'
        : 'Two weeks later';
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 1 - (calendarProgress * 0.62),
              child: Transform.scale(
                scale: 1 - (calendarProgress * 0.045),
                child: _RealKyotoCard(
                  savedAt: DateTime.now().subtract(Duration(days: elapsedDay)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
              decoration: BoxDecoration(
                color: OnboardingPalette.raisedHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const AppIcon(
                        Symbols.calendar_month_rounded,
                        size: 18,
                        color: OnboardingPalette.sage,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'OCTOBER',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: OnboardingPalette.sage,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        elapsedLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _CalendarWeekdays(),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 64,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            mainAxisExtent: 30,
                          ),
                      itemCount: 14,
                      itemBuilder: (context, index) {
                        final day = index + 1;
                        return _CalendarDay(
                          day: day,
                          elapsed: day <= elapsedDay,
                          current: day == elapsedDay,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        if (constraints.maxHeight >= 430) return content;
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: constraints.maxWidth,
            height: 390,
            child: content,
          ),
        );
      },
    );
  }
}

class _CalendarWeekdays extends StatelessWidget {
  const _CalendarWeekdays();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final day in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
          Expanded(
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.elapsed,
    required this.current,
  });

  final int day;
  final bool elapsed;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: ValueKey('onboarding-calendar-day-$day'),
      duration: _motionDuration(context, 160),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: current
            ? OnboardingPalette.sage
            : elapsed
            ? OnboardingPalette.sage.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$day',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: current
              ? OnboardingPalette.ink
              : elapsed
              ? OnboardingPalette.paper
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
          fontFeatures: const [FontFeature.tabularFigures()],
          fontWeight: current ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _RediscoverNotification extends StatelessWidget {
  const _RediscoverNotification({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 344,
              child: Semantics(
                button: true,
                label: 'Glimpse notification. Three quiet days in Kyoto.',
                child: Material(
                  color: OnboardingPalette.paper,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const _GlimpseMark(size: 32),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'GLIMPSE',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: OnboardingPalette.sageDeep,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                ),
                              ),
                              Text(
                                'now',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: const Color(0xFF686F68)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Three quiet days in Kyoto',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: OnboardingPalette.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Your autumn trip is back—with the plan and places intact.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF4F554E),
                                  height: 1.35,
                                ),
                          ),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              const AppIcon(
                                Symbols.history_rounded,
                                size: 18,
                                color: OnboardingPalette.sageDeep,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'Open memory',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: OnboardingPalette.sageDeep,
                                      fontWeight: FontWeight.w700,
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
            ),
          ),
        );
      },
    );
  }
}

class _OpenedMemory extends StatelessWidget {
  const _OpenedMemory({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 420) {
          return const _CompactOpenedMemory();
        }
        final content = Center(
          child: Container(
            decoration: BoxDecoration(
              color: OnboardingPalette.raisedHigh,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 178,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(AppAssets.onboardingKyoto, fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xD9141A18)],
                            stops: [0.38, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 14,
                        child: Row(
                          children: [
                            const AppIcon(
                              Symbols.history_rounded,
                              size: 17,
                              color: OnboardingPalette.sage,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'REDISCOVERED · 2 WEEKS LATER',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: OnboardingPalette.sage,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.85,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'For your autumn in Kyoto',
                        style: AppTypography.editorial(
                          Theme.of(context).textTheme.titleLarge,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Three quiet days in Kyoto',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: OnboardingPalette.paper,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Early temple walks, quiet lanes, and the places you '
                        'wanted to remember—all still together.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _MemoryContextPill(
                            label: 'Slow travel',
                          ),
                          _MemoryContextPill(
                            label: 'Temple walks',
                          ),
                          _MemoryContextPill(
                            label: 'Gion evenings',
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          const AppIcon(
                            Symbols.check_circle_rounded,
                            size: 18,
                            color: OnboardingPalette.sage,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Saved with its context intact',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: OnboardingPalette.sage,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        if (constraints.maxHeight >= 500) return content;
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: constraints.maxWidth,
            height: 490,
            child: content,
          ),
        );
      },
    );
  }
}

class _CompactOpenedMemory extends StatelessWidget {
  const _CompactOpenedMemory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: OnboardingPalette.raisedHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 60,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(AppAssets.onboardingKyoto, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xD9141A18)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 8,
                    child: Text(
                      'REDISCOVERED · 2 WEEKS LATER',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: OnboardingPalette.sage,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.65,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'For your autumn in Kyoto',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: OnboardingPalette.paper,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The plan, places, and intent are still together.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Wrap(
                    spacing: 5,
                    children: [
                      _MemoryContextPill(
                        label: 'Temples',
                        compact: true,
                      ),
                      _MemoryContextPill(
                        label: 'Gion nights',
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const AppIcon(
                        Symbols.check_circle_rounded,
                        size: 15,
                        color: OnboardingPalette.sage,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Context intact',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: OnboardingPalette.sage,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
}

class _MemoryContextPill extends StatelessWidget {
  const _MemoryContextPill({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: OnboardingPalette.sage.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: OnboardingPalette.sage,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _KyotoArticle extends StatelessWidget {
  const _KyotoArticle({required this.showShare});

  final bool showShare;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.onboardingKyoto, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xE80A0D0C)],
                stops: [0.42, 1],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KYOTO TRAVEL',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: OnboardingPalette.sage,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Three quiet days in Kyoto',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: OnboardingPalette.paper,
                          fontWeight: FontWeight.w700,
                          height: 1.08,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showShare) ...[
                  const SizedBox(width: 12),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: OnboardingPalette.paper,
                      shape: BoxShape.circle,
                    ),
                    child: const AppIcon(
                      Symbols.ios_share_rounded,
                      size: 22,
                      color: OnboardingPalette.ink,
                      semanticLabel: 'Share this article',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RealKyotoCard extends StatelessWidget {
  const _RealKyotoCard({super.key, this.savedAt, this.processing = false});

  final DateTime? savedAt;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    final memory = DemoSeedService.buildPreview(savedAt: savedAt);
    if (processing) {
      memory
        ..summary = null
        ..enrichmentJson = null
        ..processingStatus = UrlProcessingStatus.enriching
        ..title = 'Kyoto Travel'
        ..tags = [];
    }
    return IgnorePointer(
      child: UrlCard(
        savedUrl: memory,
        tagFrequency: const {
          'kyoto': 1,
          'japan': 1,
          'slow travel': 1,
          'autumn': 1,
        },
      ),
    );
  }
}

class _GlimpseMark extends StatelessWidget {
  const _GlimpseMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.27),
      child: Image.asset(
        AppAssets.launcherIcon,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

bool _reduceMotion(BuildContext context) {
  final media = MediaQuery.of(context);
  return media.disableAnimations || media.accessibleNavigation;
}

Duration _motionDuration(BuildContext context, int milliseconds) {
  return _reduceMotion(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}
