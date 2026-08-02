import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_assets.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_typography.dart';
import 'onboarding_flow_controller.dart';
import 'onboarding_story.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _storyKey = GlobalKey<OnboardingStorySceneState>();

  int _chapter = 0;
  bool _transitioning = false;
  bool _memoryOpened = false;
  bool _finishing = false;
  String? _completionError;
  bool _heroPrecached = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(onboardingFlowCoordinatorProvider).trackStarted());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_heroPrecached) return;
    _heroPrecached = true;
    unawaited(
      precacheImage(const AssetImage(AppAssets.onboardingKyoto), context),
    );
  }

  Future<void> _primaryAction() async {
    if (_transitioning || _finishing) return;
    switch (_chapter) {
      case 0:
        _setChapter(1);
        return;
      case 1:
        setState(() => _transitioning = true);
        await _storyKey.currentState?.selectGlimpse();
        if (!mounted) return;
        setState(() => _transitioning = false);
        _setChapter(2);
        return;
      case 2:
        _storyKey.currentState?.finishEnrichment();
        _setChapter(3);
        return;
      case 3:
        if (!_memoryOpened) {
          _storyKey.currentState?.openMemory();
        } else {
          await _complete();
        }
        return;
    }
  }

  void _setChapter(int chapter) {
    if (_finishing || chapter == _chapter || chapter < 0 || chapter > 3) {
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _chapter = chapter;
      _memoryOpened = false;
      _completionError = null;
    });
  }

  void _goBack() {
    if (_finishing || _transitioning) return;
    if (_chapter == 3 && _memoryOpened) {
      HapticFeedback.lightImpact();
      _storyKey.currentState?.closeMemory();
      setState(() => _memoryOpened = false);
      return;
    }
    _setChapter(_chapter - 1);
  }

  Future<void> _skip() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    HapticFeedback.lightImpact();
    try {
      await ref.read(onboardingFlowCoordinatorProvider).skip();
    } catch (_) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Couldn’t finish setup. Tap Skip to try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _complete() async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _completionError = null;
    });
    HapticFeedback.mediumImpact();
    try {
      await ref.read(onboardingFlowCoordinatorProvider).complete();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _completionError = 'We couldn’t save your progress. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: OnboardingPalette.sageDeep,
          brightness: Brightness.dark,
          surface: OnboardingPalette.ink,
        ).copyWith(
          primary: OnboardingPalette.sage,
          onPrimary: OnboardingPalette.ink,
          surface: OnboardingPalette.ink,
          surfaceContainerLow: OnboardingPalette.raised,
          surfaceContainer: OnboardingPalette.raised,
          onSurface: OnboardingPalette.paper,
        );

    return Theme(
      data: base.copyWith(colorScheme: colorScheme),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: OnboardingPalette.ink,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: OnboardingPalette.ink,
          body: SafeArea(
            child: PopScope(
              canPop: _chapter == 0 && !_finishing,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop && _chapter > 0 && !_finishing) {
                  _goBack();
                }
              },
              child: Column(
                children: [
                  _Navigation(
                    showBack: _chapter > 0,
                    backEnabled: !_finishing && !_transitioning,
                    skipEnabled: !_finishing,
                    onBack: _goBack,
                    onSkip: _skip,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: OnboardingStoryScene(
                            key: _storyKey,
                            chapter: _chapter,
                            onMemoryOpened: () {
                              if (mounted) setState(() => _memoryOpened = true);
                            },
                            onEnrichmentComplete: () => unawaited(
                              ref
                                  .read(onboardingFlowCoordinatorProvider)
                                  .trackTransformation(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _StoryCopy(chapter: _chapter, memoryOpened: _memoryOpened),
                  if (_completionError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _completionError!,
                          textAlign: TextAlign.center,
                          style: base.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  _StoryPositionIndicator(activeIndex: _storyPosition),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 472),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          key: const ValueKey('onboarding-primary-cta'),
                          onPressed: _primaryAction,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            layoutBuilder: (current, previous) =>
                                current ?? const SizedBox.shrink(),
                            child: _CtaLabel(
                              key: ValueKey(
                                'cta-$_chapter-$_transitioning-$_memoryOpened-$_finishing',
                              ),
                              label: _ctaLabel,
                              icon: _ctaIcon,
                            ),
                          ),
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

  int get _storyPosition {
    if (_chapter < 3) return _chapter;
    return _memoryOpened ? 4 : 3;
  }

  String get _ctaLabel {
    if (_finishing) return 'Opening Glimpse';
    if (_transitioning) return 'Saved to Glimpse';
    if (_completionError != null) return 'Try again';
    return switch (_chapter) {
      0 => 'Show me how to save',
      1 => 'Save to Glimpse',
      2 => 'See it return',
      _ => _memoryOpened ? 'Enter Glimpse' : 'Open the memory',
    };
  }

  IconData? get _ctaIcon {
    if (_finishing || _transitioning) return AppIcons.check;
    return switch (_chapter) {
      0 => AppIcons.arrowForward,
      1 => AppIcons.bookmarkAdd,
      2 => AppIcons.rediscover,
      _ => _memoryOpened ? AppIcons.arrowForward : AppIcons.tap,
    };
  }
}

class _Navigation extends StatelessWidget {
  const _Navigation({
    required this.showBack,
    required this.backEnabled,
    required this.skipEnabled,
    required this.onBack,
    required this.onSkip,
  });

  final bool showBack;
  final bool backEnabled;
  final bool skipEnabled;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: showBack
                  ? IconButton(
                      onPressed: backEnabled ? onBack : null,
                      tooltip: 'Previous step',
                      icon: const AppIcon(AppIcons.arrowBack),
                    )
                  : null,
            ),
            const Spacer(),
            TextButton(
              onPressed: skipEnabled ? onSkip : null,
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCopy extends StatelessWidget {
  const _StoryCopy({required this.chapter, required this.memoryOpened});

  final int chapter;
  final bool memoryOpened;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    final content = switch (chapter) {
      0 => (
        headline: 'Find something worth keeping.',
        body: 'A trip, recipe, or idea worth returning to.',
      ),
      1 => (
        headline: 'Save it from anywhere.',
        body: 'Share. Choose Glimpse. Done.',
      ),
      2 => (
        headline: 'Glimpse remembers the details.',
        body: 'Summary, tags, and intent—organized automatically.',
      ),
      3 when !memoryOpened => (
        headline: "Timed to when you'll actually need it.",
        body: 'Not a random ping—a well-timed one.',
      ),
      _ => (
        headline: 'It comes back when it matters.',
        body: 'Not another forgotten bookmark.',
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 472),
        child: SizedBox(
          width: double.infinity,
          height: 112 * scale,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            layoutBuilder: (current, previous) =>
                current ?? const SizedBox.shrink(),
            child: Column(
              key: ValueKey('copy-$chapter-$memoryOpened'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.editorial(
                    Theme.of(context).textTheme.headlineMedium,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 29,
                    fontWeight: FontWeight.w600,
                    height: 1.06,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  content.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
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

class _StoryPositionIndicator extends StatelessWidget {
  const _StoryPositionIndicator({required this.activeIndex});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('onboarding-position-indicator'),
      label: 'Step ${activeIndex + 1} of 5',
      child: SizedBox(
        height: 12,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < 5; index++) ...[
              AnimatedContainer(
                key: ValueKey('onboarding-position-$index'),
                duration: const Duration(milliseconds: 180),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == activeIndex
                      ? OnboardingPalette.sage
                      : Colors.white.withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                ),
              ),
              if (index < 4) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _CtaLabel extends StatelessWidget {
  const _CtaLabel({super.key, required this.label, required this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          AppIcon(icon!, size: 20),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );
  }
}
