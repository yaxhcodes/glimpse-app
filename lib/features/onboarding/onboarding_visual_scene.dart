import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'onboarding_scenes.dart';

/// Bundled product captures. No live providers, networking, or AI work runs here.
class OnboardingScene extends StatefulWidget {
  const OnboardingScene({
    super.key,
    required this.chapter,
    required this.active,
  });
  final int chapter;
  final bool active;

  static String previewPath(BuildContext context, int chapter, [int part = 0]) {
    if (chapter >= 1 && chapter <= 3) {
      return OnboardingArtwork.artwork(
        const ['enrichment', 'interests', 'discovered'][chapter - 1],
      );
    }
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context).brightness.name;
    return 'assets/onboarding/previews/${locale}_${theme}_${chapter}_$part.webp';
  }

  static List<int> partsFor(int chapter) => switch (chapter) {
    5 => const [1, 2],
    _ => const [0],
  };

  @override
  State<OnboardingScene> createState() => _OnboardingSceneState();
}

class _OnboardingSceneState extends State<OnboardingScene>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _played = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  @override
  void didUpdateWidget(OnboardingScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _start();
  }

  void _start() {
    if (widget.chapter == 0 ||
        widget.chapter == 6 ||
        MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
      _played = true;
    } else if (widget.active && !_played) {
      _played = true;
      _motion.forward();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = context.l10n;
    if (widget.chapter == 0 || widget.chapter == 6) {
      return OnboardingProductPreview(chapter: widget.chapter);
    }
    final descriptions = [
      '',
      l.obBody2,
      '${l.obBody3} ${l.obInterestNote}',
      '${l.obBooks}, ${l.obMovies}, ${l.obMusic}, ${l.obPlaces}. ${l.obCollection}',
      '${l.obQuestion}\n${l.obAnswer.replaceAll('**', '')}\n${l.obSaveTitle}. ${l.obSemantic}',
      '${l.obAutomatic}: ${l.obAutomaticNote}\n${l.obChosen}: ${l.obRevisit}. ${l.obChosenNote}',
    ];
    final parts = OnboardingScene.partsFor(widget.chapter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.chapter >= 4)
          Text(l.obExample, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 16),

        Semantics(
          image: true,
          label: descriptions[widget.chapter],
          child: Column(
            children: [
              for (var index = 0; index < parts.length; index++) ...[
                if (index > 0) const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _motion,
                  child: RepaintBoundary(
                    child: Stack(
                      children: [
                        Image.asset(
                          OnboardingScene.previewPath(
                            context,
                            widget.chapter,
                            parts[index],
                          ),
                          key: ValueKey(
                            'onboarding-preview-${widget.chapter}-${parts[index]}',
                          ),
                          excludeFromSemantics: true,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              Text(descriptions[widget.chapter]),
                        ),
                        if (widget.chapter == 2)
                          Positioned.fill(child: _InterestLabels()),
                      ],
                    ),
                  ),
                  builder: (context, child) {
                    final t = Interval(
                      index * .12,
                      .65 + index * .1,
                      curve: Curves.easeOutCubic,
                    ).transform(_motion.value);
                    final artwork = widget.chapter == 1 && t < 1
                        ? ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) => LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: const [
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [0, (t - .12).clamp(0, 1), t],
                            ).createShader(bounds),
                            child: child,
                          )
                        : child;
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(
                          parts.length > 1
                              ? (index.isEven ? -20 : 20) * (1 - t)
                              : 0,
                          18 * (1 - t),
                        ),
                        child: Transform.scale(
                          scale: .97 + .03 * t,
                          child: artwork,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InterestLabels extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ExcludeSemantics(
      child: Stack(
        children: [
          _label(context, l.obCooking, const Alignment(-.78, -.94)),
          _label(context, l.obSoftware, const Alignment(.9, -.78)),
          _label(
            context,
            '${l.obTravel} · ${l.obMovies}',
            const Alignment(.62, .94),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text, Alignment alignment) =>
      Align(
        alignment: alignment,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 130),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xF0F6F3EA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF545D4E),
            ),
          ),
        ),
      );
}
