import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/entitlement_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_typography.dart';
import 'onboarding_flow_controller.dart';
import 'onboarding_scenes.dart';
import 'onboarding_visual_scene.dart';
import 'onboarding_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _state = OnboardingChapterController();
  final _pages = PageController();
  bool _moving = false;
  String? _cachedAppearance;
  bool _finishing = false;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(onboardingFlowCoordinatorProvider).trackStarted());
    unawaited(ref.read(onboardingFlowCoordinatorProvider).trackChapter(0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appearance =
        '${Theme.of(context).brightness.name}/${Localizations.localeOf(context).languageCode}';
    if (_cachedAppearance == appearance) return;
    _cachedAppearance = appearance;
    unawaited(
      precacheImage(AssetImage(OnboardingArtwork.artwork('opening')), context),
    );
    for (var chapter = 1; chapter <= 5; chapter++) {
      for (final part in OnboardingScene.partsFor(chapter)) {
        unawaited(
          precacheImage(
            AssetImage(OnboardingScene.previewPath(context, chapter, part)),
            context,
          ),
        );
      }
    }
  }

  Future<void> _move(int delta) async {
    if (_moving || _finishing) return;
    final target = (_state.chapter + delta).clamp(
      0,
      OnboardingChapterController.count - 1,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target);
      return;
    }
    _moving = true;
    try {
      await _pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      _moving = false;
    }
  }

  void _onPageChanged(int chapter) {
    setState(() {
      _state.chapter = chapter;
      _failed = false;
    });
    unawaited(
      ref.read(onboardingFlowCoordinatorProvider).trackChapter(chapter),
    );
  }

  Future<void> _finish({bool skip = false, bool pro = false}) async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _failed = false;
    });
    try {
      final flow = ref.read(onboardingFlowCoordinatorProvider);
      if (skip) {
        await flow.skip();
      } else {
        await flow.complete(explorePro: pro);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Could not complete onboarding',
        name: 'Onboarding',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          _failed = true;
        });
      }
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
    final pro = ref.watch(isProUserProvider);
    final titles = [
      l.obTitle1,
      l.obTitle2,
      l.obTitle3,
      l.obCollected,
      l.obTitle4,
      l.obTitle5,
      l.obTitle6,
    ];
    final bodies = [
      l.obBody1,
      l.obBody2,
      l.obBody3,
      l.obLibraryBody,
      l.obBody4,
      l.obBody5,
      l.obBody6,
    ];
    final chapter = _state.chapter;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = OnboardingTheme.from(Theme.of(context));
    final scheme = theme.colorScheme;
    return Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: scheme.surface,
            ),
        child: PopScope(
          canPop: chapter == 0 && !_finishing,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && chapter > 0 && !_finishing) _move(-1);
          },
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  tooltip: l.obBack,
                                  onPressed: chapter > 0 && !_finishing
                                      ? () => _move(-1)
                                      : null,
                                  icon: const Icon(Icons.arrow_back),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Semantics(
                                liveRegion: true,
                                label: l.obPosition(
                                  chapter + 1,
                                  OnboardingChapterController.count,
                                ),
                                child: ExcludeSemantics(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      OnboardingChapterController.count,
                                      (i) => AnimatedContainer(
                                        duration:
                                            MediaQuery.disableAnimationsOf(
                                              context,
                                            )
                                            ? Duration.zero
                                            : const Duration(milliseconds: 280),
                                        curve: Curves.easeInOutCubic,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        width: i == chapter ? 20 : 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: i == chapter
                                              ? scheme.primary
                                              : scheme.outlineVariant,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _finishing
                                      ? null
                                      : () => _finish(skip: true),
                                  child: Text(l.obSkip),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _pages,
                          itemCount: OnboardingChapterController.count,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (context, index) => Column(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) =>
                                      SingleChildScrollView(
                                        key: PageStorageKey(
                                          'onboarding-chapter-$index',
                                        ),
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          10,
                                          20,
                                          12,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight:
                                                (constraints.maxHeight - 22)
                                                    .clamp(
                                                      0.0,
                                                      double.infinity,
                                                    ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Semantics(
                                                header: true,
                                                child: Text(
                                                  titles[index],
                                                  style:
                                                      AppTypography.editorial(
                                                        theme
                                                            .textTheme
                                                            .headlineLarge,
                                                        color: scheme.onSurface,
                                                        fontSize: 40,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        letterSpacing: -.8,
                                                        height: 1.06,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                bodies[index],
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                      height: 1.5,
                                                    ),
                                              ),
                                              const SizedBox(height: 20),
                                              OnboardingScene(
                                                chapter: index,
                                                active: index == chapter,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                              if (index ==
                                      OnboardingChapterController.count - 1 &&
                                  !pro) ...[
                                const SizedBox(height: 4),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: index == chapter ? 1 : 0,
                                  ),
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 280),
                                  curve: Curves.easeInOutCubic,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: TextButton(
                                      onPressed: _finishing
                                          ? null
                                          : () => _finish(),
                                      child: Text(l.obStartFree),
                                    ),
                                  ),
                                  builder: (context, value, child) => Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 6 * (1 - value)),
                                      child: child,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_failed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    l.obError,
                                    style: TextStyle(color: scheme.error),
                                  ),
                                ),
                              ),
                            FilledButton(
                              key: const ValueKey('onboarding-primary-cta'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 17,
                                ),
                              ),
                              onPressed: _finishing
                                  ? null
                                  : () {
                                      if (chapter <
                                          OnboardingChapterController.count -
                                              1) {
                                        _move(1);
                                      } else {
                                        unawaited(_finish(pro: !pro));
                                      }
                                    },
                              child: Text(
                                chapter == 0
                                    ? l.obBegin
                                    : chapter <
                                          OnboardingChapterController.count - 1
                                    ? l.obContinue
                                    : pro
                                    ? l.obContinuePro
                                    : l.obExplorePro,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
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
  }
}
