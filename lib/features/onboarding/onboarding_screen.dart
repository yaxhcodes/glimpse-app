import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/usage_limits.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_typography.dart';
import 'onboarding_flow_controller.dart';
import 'onboarding_stages.dart';

/// First run: one example reel followed from the share sheet, to the page
/// Glimpse makes of it, to finding it again — then what grows with more
/// saves. Drawn in the app's own theme, so the story and the product match.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static final _count = OnboardingFlowCoordinator.chapters.length;
  final _pages = PageController();
  int _page = 0;
  bool _moving = false;
  bool _finishing = false;
  bool _failed = false;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    final flow = ref.read(onboardingFlowCoordinatorProvider);
    unawaited(flow.trackStarted());
    unawaited(flow.trackChapter(0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (final art in OnboardingArt.all) {
      unawaited(precacheImage(AssetImage(OnboardingArt.path(art)), context));
    }
  }

  Future<void> _move(int delta) async {
    if (_moving || _finishing) return;
    final target = (_page + delta).clamp(0, _count - 1);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target);
      return;
    }
    _moving = true;
    try {
      await _pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      _moving = false;
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _page = page;
      _failed = false;
    });
    unawaited(ref.read(onboardingFlowCoordinatorProvider).trackChapter(page));
  }

  Future<void> _finish({bool skip = false}) async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _failed = false;
    });
    try {
      final flow = ref.read(onboardingFlowCoordinatorProvider);
      await (skip ? flow.skip() : flow.complete());
    } catch (error, stackTrace) {
      developer.log(
        'Could not complete onboarding',
        name: 'Onboarding',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final dark = theme.brightness == Brightness.dark;
    final last = _page == _count - 1;
    // The welcome painting sits under the status bar: light icons there.
    final overArt = _page == 0;
    final chapters = [
      (l.obWelcomeTitle, l.obWelcomeBody),
      (l.obShareTitle, l.obShareBody),
      (l.obReadTitle, l.obReadBody),
      (l.obFindTitle, l.obFindBody),
      (l.obGrowTitle, l.obGrowBody),
    ];
    assert(chapters.length == _count);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (overArt || dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: cs.surface,
              ),
      child: PopScope(
        canPop: _page == 0 && !_finishing,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _page > 0 && !_finishing) _move(-1);
        },
        child: Scaffold(
          backgroundColor: cs.surface,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pages,
                    itemCount: _count,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) => _Chapter(
                      index: index,
                      active: index == _page,
                      title: chapters[index].$1,
                      body: chapters[index].$2,
                    ),
                  ),
                  // Chrome sits above the pages so it never slides with them.
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              label: l.obPosition(_page + 1, _count),
                              child: ExcludeSemantics(
                                child: _Segments(
                                  count: _count,
                                  index: _page,
                                  onArt: overArt,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // No skipping the page that finishes anyway.
                          Flexible(
                            child: Visibility(
                              visible: !last,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: TextButton(
                                onPressed: _finishing
                                    ? null
                                    : () => _finish(skip: true),
                                style: TextButton.styleFrom(
                                  foregroundColor: overArt
                                      ? Colors.white
                                      : cs.onSurfaceVariant,
                                ),
                                child: Text(
                                  l.obSkip,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_failed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    l.obError,
                                    textAlign: TextAlign.center,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.error,
                                    ),
                                  ),
                                ),
                              ),
                            FilledButton(
                              key: const ValueKey('onboarding-primary-cta'),
                              onPressed: _finishing
                                  ? null
                                  : () => last ? _finish() : _move(1),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                              ),
                              child: Text(
                                _page == 0
                                    ? l.obGetStarted
                                    : last
                                    ? l.obStartSaving
                                    : l.obNext,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Reserved on every page so the button never
                            // shifts when the note appears.
                            AnimatedOpacity(
                              opacity: last ? 1 : 0,
                              duration: const Duration(milliseconds: 240),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  l.obFreeNote(
                                    UsageLimits.planAllowance(
                                      UsageFeature.aiSave,
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

class _Segments extends StatelessWidget {
  const _Segments({
    required this.count,
    required this.index,
    required this.onArt,
  });
  final int count;
  final int index;
  final bool onArt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 320);
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: duration,
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i <= index
                    ? (onArt ? Colors.white : cs.primary)
                    : (onArt
                          ? Colors.white.withValues(alpha: .35)
                          : cs.outlineVariant),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Every chapter shares one skeleton: a stage on top, then the headline at
/// the same height on every page, so swiping never makes the text jump.
class _Chapter extends StatelessWidget {
  const _Chapter({
    required this.index,
    required this.active,
    required this.title,
    required this.body,
  });
  final int index;
  final bool active;
  final String title;
  final String body;

  /// How far the welcome painting runs on under the headline before it has
  /// fully faded, so there is no edge between picture and page.
  static const _artOverlap = 96.0;

  /// Room under the text for the CTA and the free-plan note, which grows
  /// with the text size.
  static double _ctaSpace(BuildContext context) =>
      72 + MediaQuery.textScalerOf(context).scale(46);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final padding = MediaQuery.paddingOf(context);
    final bodyStyle = tt.bodyLarge?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.45,
    );
    final text = Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTypography.editorial(
                tt.headlineLarge,
                color: cs.onSurface,
                fontSize: 34,
                fontWeight: FontWeight.w400,
                letterSpacing: -.6,
                height: 1.08,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            // Two lines are always reserved so the CTA gap is identical;
            // larger text simply takes more room from the stage.
            constraints: BoxConstraints(
              minHeight: MediaQuery.textScalerOf(
                context,
              ).scale((bodyStyle?.fontSize ?? 16) * 1.45 * 2 + 2),
            ),
            child: Text(body, style: bodyStyle),
          ),
        ],
      ),
    );
    final Widget stage = switch (index) {
      0 => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: -_artOverlap,
            child: OnboardingWelcomeArt(active: active),
          ),
        ],
      ),
      1 => _StageFrame(
        minHeight: 380,
        child: OnboardingShareStage(active: active),
      ),
      2 => _StageFrame(
        minHeight: 300,
        child: OnboardingReadStage(active: active),
      ),
      3 => _StageFrame(
        minHeight: 440,
        child: OnboardingFindStage(active: active),
      ),
      _ => _StageFrame(
        fitContent: true,
        child: OnboardingGrowStage(active: active),
      ),
    };
    return LayoutBuilder(
      builder: (context, c) => Column(
        children: [
          Expanded(
            child: index == 0
                ? stage
                : Padding(
                    padding: EdgeInsets.fromLTRB(20, padding.top + 52, 20, 0),
                    child: stage,
                  ),
          ),
          // Long translations at large text sizes scroll rather than push
          // the stage off screen.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: c.maxHeight * .45),
            child: SingleChildScrollView(child: text),
          ),
          SizedBox(height: _ctaSpace(context) + padding.bottom),
        ],
      ),
    );
  }
}

/// The rounded card each product stage plays in. Below [minHeight] the stage
/// is laid out at that height and scaled down to fit, so small phones and
/// large text get a smaller picture instead of an overflow. A [fitContent]
/// stage takes its natural height instead, centred and scaled down to fit.
class _StageFrame extends StatelessWidget {
  const _StageFrame({
    required this.child,
    this.minHeight = 0,
    this.fitContent = false,
  });
  final Widget child;
  final double minHeight;
  final bool fitContent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        if (fitContent) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ColoredBox(
              color: cs.surfaceContainerLow,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(width: c.maxWidth, child: child),
                ),
              ),
            ),
          );
        }
        // Larger text needs a taller stage before it is scaled to fit.
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final height = math.max(
          c.maxHeight,
          minHeight * textScale.clamp(1.0, 2.0),
        );
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: c.maxWidth,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: ColoredBox(color: cs.surfaceContainerLow, child: child),
            ),
          ),
        );
      },
    );
  }
}
