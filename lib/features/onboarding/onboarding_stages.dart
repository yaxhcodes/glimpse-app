import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/services/transcript_enrichment_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/section_header.dart';
import '../library/library_entity.dart';
import '../library/places_world_preview.dart';

/// The visuals of the first-run story. One example reel runs through every
/// stage: shared from Instagram, read into a page, found again by search.
/// Everything is bundled and drawn with the app's own theme; nothing here
/// touches the network, the database or the AI proxy.
abstract final class OnboardingArt {
  static const opening = 'assets/onboarding/opening.webp';

  /// The example reel's frame.
  static const reel = 'assets/onboarding/editorial.webp';

  static String media(String name) => 'assets/onboarding/media/$name.webp';

  static const all = [
    opening,
    reel,
    'atomic_habits',
    'deep_work',
    'thinking_fast_slow',
    'interstellar',
    'past_lives',
    'con_todo_el_mundo',
    'metaphorical_music',
  ];

  static String path(String entry) =>
      entry.startsWith('assets/') ? entry : media(entry);
}

/// Drives a stage from 0→1 while its page is on screen: once, or looping.
/// Reduced motion shows the [still] frame.
class OnboardingTimeline extends StatefulWidget {
  const OnboardingTimeline({
    super.key,
    required this.active,
    required this.duration,
    required this.builder,
    this.loop = false,
    this.still = 1,
  });
  final bool active;
  final Duration duration;
  final bool loop;
  final double still;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<OnboardingTimeline> createState() => _OnboardingTimelineState();
}

class _OnboardingTimelineState extends State<OnboardingTimeline>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(OnboardingTimeline old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _c
        ..stop()
        ..value = widget.still;
    } else if (widget.loop) {
      if (widget.active) {
        if (!_c.isAnimating) _c.repeat();
      } else {
        _c
          ..stop()
          ..value = 0;
      }
    } else if (widget.active && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => widget.builder(context, _c.value),
  );
}

/// Eased progress of [t] through the window [a]..[b].
double _seg(
  double t,
  double a,
  double b, [
  Curve curve = Curves.easeOutCubic,
]) => curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

/// Fades and lifts [child] in as [v] goes 0→1.
Widget _rise(double v, Widget child) => Opacity(
  opacity: v,
  child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
);

/// A fingertip, as in a screen recording with "show taps" on: it lands,
/// presses in slightly and lifts. [v] runs 0→1 across one tap; outside a
/// tap pass 0 and nothing is drawn.
class _Touch extends StatelessWidget {
  const _Touch({required this.v, required this.color, this.size = 40});
  final double v;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (v <= 0 || v >= 1) return SizedBox.square(dimension: size);
    return Opacity(
      opacity: math.sin(v * math.pi).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 1 - .12 * Curves.easeOut.transform(v),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: Colors.white.withValues(alpha: .7),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover(this.name, {this.aspectRatio = 2 / 3});
  final String name;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(8);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: .14),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            // A hairline keeps pale covers from bleeding into a light page.
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: cs.onSurface.withValues(alpha: .08),
                width: .6,
              ),
            ),
            child: Image.asset(
              OnboardingArt.media(name),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 1 · Welcome ────────────────────────────────────────────────────────────

class OnboardingWelcomeArt extends StatelessWidget {
  const OnboardingWelcomeArt({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The painting dissolves into the page itself (alpha, not a colour
          // wash), so it sits right in light and dark alike.
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.white,
                Color(0xCCFFFFFF),
                Color(0x73FFFFFF),
                Color(0x26FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0, .5, .66, .8, .91, 1],
            ).createShader(rect),
            // A slow push-in keeps the painting alive without calling for
            // attention.
            child: OnboardingTimeline(
              active: active,
              duration: const Duration(seconds: 14),
              still: 0,
              builder: (context, t) => Transform.scale(
                scale: 1 + .07 * Curves.easeOutSine.transform(t),
                alignment: const Alignment(.2, .3),
                child: Image.asset(
                  OnboardingArt.opening,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -.2),
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          // Shade under the status bar so the chrome stays legible.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x61000000), Color(0x00000000)],
                stops: [0, .2],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2 · Share ──────────────────────────────────────────────────────────────

/// A looping demo: tap Share on a reel → share sheet → Glimpse → saved.
class OnboardingShareStage extends StatelessWidget {
  const OnboardingShareStage({super.key, required this.active});
  final bool active;

  static double _tap(double t, double a, double b) =>
      t > a && t < b ? (t - a) / (b - a) : 0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: context.l10n.obShareStage,
      child: ExcludeSemantics(
        child: OnboardingTimeline(
          active: active,
          loop: true,
          still: .8,
          duration: const Duration(milliseconds: 6400),
          builder: (context, t) {
            // Material motion: sheets enter decelerating and leave
            // accelerating, with no overshoot.
            final enter = _seg(t, .2, .31, Curves.easeOutQuart);
            final exit = _seg(t, .55, .62, Curves.easeInCubic);
            final sheet = enter * (1 - exit);
            final toast = _seg(t, .63, .7) * (1 - _seg(t, .93, .99));
            return Stack(
              children: [
                Positioned.fill(
                  child: _ReelMock(progress: t, shareTap: _tap(t, .08, .2)),
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: .4 * sheet),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: FractionalTranslation(
                    translation: Offset(0, 1 - sheet),
                    child: _ShareSheetMock(tap: _tap(t, .38, .52)),
                  ),
                ),
                Positioned(
                  top: 56 + 10 * (1 - toast),
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: toast,
                    child: const Center(child: _SavedToast()),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReelMock extends StatelessWidget {
  const _ReelMock({required this.progress, required this.shareTap});
  final double progress;
  final double shareTap;

  static const _white = Colors.white;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const shadow = [Shadow(color: Colors.black38, blurRadius: 8)];
    const label = TextStyle(
      color: _white,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      shadows: shadow,
    );
    Widget action(IconData icon, String count, {double tap = 0}) => Column(
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: _white, size: 25, shadows: shadow),
            _Touch(v: tap, color: Colors.black.withValues(alpha: .18)),
          ],
        ),
        const SizedBox(height: 3),
        Text(count, style: label),
      ],
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          OnboardingArt.reel,
          fit: BoxFit.cover,
          alignment: const Alignment(-.25, 0),
          excludeFromSemantics: true,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0xB3000000),
              ],
              stops: [0, .2, .5, 1],
            ),
          ),
        ),
        const Positioned(
          left: 18,
          top: 18,
          child: Text(
            'Reels',
            style: TextStyle(
              color: _white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              shadows: shadow,
            ),
          ),
        ),
        const Positioned(
          right: 18,
          top: 20,
          child: Icon(
            PhosphorIconsRegular.camera,
            color: _white,
            size: 24,
            shadows: shadow,
          ),
        ),
        Positioned(
          right: 4,
          bottom: 26,
          child: Column(
            children: [
              action(PhosphorIconsRegular.heart, '12.4K'),
              const SizedBox(height: 12),
              action(PhosphorIconsRegular.chatCircle, '318'),
              const SizedBox(height: 12),
              action(
                PhosphorIconsRegular.paperPlaneTilt,
                '2,041',
                tap: shareTap,
              ),
              const SizedBox(height: 12),
              const Icon(
                PhosphorIconsBold.dotsThree,
                color: _white,
                size: 22,
                shadows: shadow,
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 72,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _white,
                    ),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFB08A5C), Color(0xFF6E7B5E)],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _demoCreator,
                      overflow: TextOverflow.ellipsis,
                      style: label.copyWith(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _white.withValues(alpha: .7)),
                    ),
                    child: Text(l.obReelFollow, style: label),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l.obReelCaption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _white,
                  fontSize: 13,
                  height: 1.3,
                  shadows: shadow,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    PhosphorIconsFill.musicNotesSimple,
                    color: _white,
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$_demoCreator · ${l.obReelAudio}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label.copyWith(fontWeight: FontWeight.w400),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: .15 + .75 * progress,
              child: Container(height: 2, color: _white.withValues(alpha: .9)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareSheetMock extends StatelessWidget {
  const _ShareSheetMock({required this.tap});
  final double tap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    Widget target(String label, Widget icon, {bool glimpse = false}) =>
        Expanded(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  SizedBox.square(dimension: 52, child: icon),
                  if (glimpse)
                    _Touch(
                      v: tap,
                      size: 52,
                      color: cs.onSurface.withValues(alpha: .16),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: glimpse ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
    Widget brand(String asset, Color color) => DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surfaceContainerHigh,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SvgPicture.asset(
          asset,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(l.share, style: tt.titleSmall?.copyWith(color: cs.onSurface)),
          const SizedBox(height: 16),
          Row(
            children: [
              target(
                l.obShareMessages,
                brand(AppAssets.googleMessages, const Color(0xFF1A73E8)),
              ),
              target(
                'WhatsApp',
                brand(AppAssets.whatsapp, const Color(0xFF25D366)),
              ),
              target('Gmail', brand(AppAssets.gmail, const Color(0xFFEA4335))),
              target(
                'Glimpse',
                ClipOval(child: Image.asset(AppAssets.launcherIcon)),
                glimpse: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedToast extends StatelessWidget {
  const _SavedToast();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
      decoration: BoxDecoration(
        color: cs.inverseSurface,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: Image.asset(AppAssets.launcherIcon, width: 26, height: 26),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              context.l10n.obSavedToast,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: cs.onInverseSurface),
            ),
          ),
          const SizedBox(width: 8),
          AppIcon(AppIcons.checkCircle, size: 16, color: cs.inversePrimary),
        ],
      ),
    );
  }
}

// ── 3 · Read ───────────────────────────────────────────────────────────────

/// The reel, read: a moment of "reading", then the page assembles in the
/// reader's own section order and scrolls itself when it runs long.
class OnboardingReadStage extends StatelessWidget {
  const OnboardingReadStage({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      image: true,
      label: context.l10n.obReadStage,
      child: ExcludeSemantics(
        child: OnboardingTimeline(
          active: active,
          duration: const Duration(milliseconds: 5200),
          builder: (context, t) {
            final reading = 1 - _seg(t, .16, .24);
            final pulse = .55 + .45 * math.sin(t * math.pi * 5).abs();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SourceRow(done: reading < .5),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Stack(
                      children: [
                        if (reading > 0)
                          Opacity(
                            opacity: reading * pulse,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.obReading,
                                  style: tt.labelMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                for (final w in [.9, .7, 1.0, .55]) ...[
                                  FractionallySizedBox(
                                    widthFactor: w,
                                    child: Container(
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ),
                          ),
                        _AutoScroll(
                          progress: _seg(t, .74, .98, Curves.easeInOutCubic),
                          child: _ReadResult(t: t),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            OnboardingArt.reel,
            width: 42,
            height: 56,
            fit: BoxFit.cover,
            alignment: const Alignment(-.25, 0),
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _demoCreator,
                style: tt.labelLarge?.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/brands/instagram.svg',
                    width: 12,
                    height: 12,
                    colorFilter: ColorFilter.mode(
                      cs.onSurfaceVariant,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.l10n.obReelSource,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: done
              ? AppIcon(
                  AppIcons.checkCircle,
                  key: const ValueKey('done'),
                  size: 20,
                  color: cs.primary,
                )
              : SizedBox.square(
                  key: const ValueKey('reading'),
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Scrolls [child] from top to bottom as [progress] goes 0→1. Content that
/// fits simply stays put, so the stage works on any screen height.
class _AutoScroll extends StatefulWidget {
  const _AutoScroll({required this.progress, required this.child});
  final double progress;
  final Widget child;

  @override
  State<_AutoScroll> createState() => _AutoScrollState();
}

class _AutoScrollState extends State<_AutoScroll> {
  final _scroll = ScrollController();

  /// Whether the content is longer than the stage; only then do the edges
  /// fade.
  bool _overflows = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(max * widget.progress);
      if ((max > 0) != _overflows) setState(() => _overflows = max > 0);
    });
    final top = _overflows
        ? 1 - _seg(widget.progress, 0, .15, Curves.linear)
        : 1.0;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      // Soft edges once content scrolls, so nothing looks cut off.
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: top),
          Colors.white,
          Colors.white,
          Colors.white.withValues(alpha: _overflows ? 0 : 1),
        ],
        stops: const [0, .1, .9, 1],
      ).createShader(rect),
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
        child: widget.child,
      ),
    );
  }
}

class _ReadResult extends StatelessWidget {
  const _ReadResult({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    // The reader's section accent, as on a real save's page.
    final accent = Color.alphaBlend(
      cs.primary.withValues(alpha: .42),
      cs.onSurfaceVariant,
    );
    Widget header(String title) => SectionHeader(
      title: title,
      accent: accent,
      emphasis: SectionHeaderEmphasis.secondary,
    );
    final body = tt.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.5,
    );
    Widget point(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: body)),
        ],
      ),
    );
    Widget term(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: tt.labelMedium?.copyWith(color: cs.onSurface)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rise(
          _seg(t, .22, .34),
          Text(
            l.obDemoTitle,
            style: AppTypography.editorial(
              tt.headlineSmall,
              color: cs.onSurface,
              fontSize: 22,
              // Regular is bundled; first run should not fetch fonts.
              fontWeight: FontWeight.w400,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _rise(
          _seg(t, .28, .4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(l.inBrief),
              const SizedBox(height: 6),
              Text(l.obDemoBrief, style: body),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _rise(_seg(t, .34, .46), header(l.keyTakeaways)),
        const SizedBox(height: 8),
        _rise(_seg(t, .38, .5), point(l.obDemoPoint1)),
        _rise(_seg(t, .42, .54), point(l.obDemoPoint2)),
        _rise(_seg(t, .46, .58), point(l.obDemoPoint3)),
        const SizedBox(height: 12),
        _rise(
          _seg(t, .5, .62),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(l.termsMentioned),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  term(l.obTermTwoMinute),
                  term(l.obTermDeepWork),
                  term(l.obTermSystems),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _rise(_seg(t, .56, .66), header(l.worthReading)),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: Row(
            children: [
              for (final (i, book) in _demoBooks.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                _rise(_seg(t, .6 + i * .04, .72 + i * .04), _Cover(book)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── 4 · Find ───────────────────────────────────────────────────────────────

class OnboardingFindStage extends StatelessWidget {
  const OnboardingFindStage({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final question = l.obSearchQuery;
    Widget heading(String label, int count) => Row(
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: tt.titleSmall?.copyWith(color: cs.onSurface),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
    return Semantics(
      image: true,
      label: l.obFindStage,
      child: ExcludeSemantics(
        child: OnboardingTimeline(
          active: active,
          duration: const Duration(milliseconds: 3400),
          builder: (context, t) {
            final typed = (question.length * _seg(t, .38, .66, Curves.linear))
                .round();
            final answer = _seg(t, .72, .9);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading(l.obFilmsMusic, _demoMedia.length),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, c) {
                      // Covers share one height, capped so the row always
                      // fits the width.
                      const gap = 10.0;
                      final ratios = _demoMedia.fold(0.0, (a, m) => a + m.$2);
                      final height = math.min(
                        88.0,
                        (c.maxWidth - gap * (_demoMedia.length - 1)) / ratios,
                      );
                      return SizedBox(
                        height: height,
                        child: Row(
                          children: [
                            for (final (i, (name, ratio))
                                in _demoMedia.indexed) ...[
                              if (i > 0) const SizedBox(width: gap),
                              Opacity(
                                opacity: _seg(t, i * .05, .2 + i * .05),
                                child: _Cover(name, aspectRatio: ratio),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  heading(l.libraryPlaces, _demoPlaces.length),
                  const SizedBox(height: 10),
                  // The map takes what height is left, up to its own shape.
                  Expanded(
                    child: Opacity(
                      opacity: _seg(t, .12, .35),
                      child: LayoutBuilder(
                        builder: (context, c) => Align(
                          alignment: Alignment.topCenter,
                          child: PlacesWorldPreview(
                            places: _demoPlaces,
                            width: c.maxWidth,
                            height: math.max(
                              0,
                              math.min(c.maxWidth * .4, c.maxHeight - 18),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The search field types a vague question, then answers it
                  // from a saved idea, not just a title.
                  Opacity(
                    opacity: _seg(t, .3, .4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        children: [
                          AppIcon(
                            AppIcons.search,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: question.substring(0, typed)),
                                  if (answer == 0)
                                    TextSpan(
                                      text: '|',
                                      style: TextStyle(color: cs.primary),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _rise(
                    answer,
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              OnboardingArt.reel,
                              width: 40,
                              height: 52,
                              fit: BoxFit.cover,
                              alignment: const Alignment(-.25, 0),
                              excludeFromSemantics: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.obTermTwoMinute,
                                  style: tt.titleSmall?.copyWith(
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l.obSearchAnswer,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.35,
                                  ),
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
            );
          },
        ),
      ),
    );
  }
}

// ── 5 · Grow ───────────────────────────────────────────────────────────────

/// What unlocks as the library grows: honest about what a new user sees
/// today, so nothing is shown that an empty account can't deliver yet.
class OnboardingGrowStage extends StatelessWidget {
  const OnboardingGrowStage({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final steps = [
      (AppIcons.library, l.obGrowToday, l.library, l.obGrowLibrary),
      (AppIcons.interests, l.obGrowSoon, l.interests, l.obGrowInterests),
      (AppIcons.rediscover, l.obGrowLater, l.rediscover, l.obGrowRediscover),
      (
        AppIcons.collections,
        l.obGrowAnytime,
        l.collections,
        l.obGrowCollections,
      ),
    ];
    return OnboardingTimeline(
      active: active,
      duration: const Duration(milliseconds: 1800),
      builder: (context, t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, step) in steps.indexed)
              _rise(
                _seg(t, i * .16, .4 + i * .16),
                MergeSemantics(
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The rail: a lit node for what exists today, quiet
                        // nodes for what's ahead.
                        Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == 0
                                    ? cs.primary
                                    : cs.surfaceContainerHighest,
                              ),
                              child: AppIcon(
                                step.$1,
                                size: 20,
                                color: i == 0
                                    ? cs.onPrimary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                            if (i < steps.length - 1)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.outlineVariant,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: 1,
                              bottom: i < steps.length - 1 ? 26 : 0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.$2.toUpperCase(),
                                  style: tt.labelSmall?.copyWith(
                                    color: i == 0
                                        ? cs.primary
                                        : cs.onSurfaceVariant.withValues(
                                            alpha: .85,
                                          ),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  step.$3,
                                  style: tt.titleMedium?.copyWith(
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  step.$4,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
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
    );
  }
}

// ── Demo data ──────────────────────────────────────────────────────────────

/// A fictional creator, so the example never points at a real account.
const _demoCreator = 'thereadingroom';

const _demoBooks = ['atomic_habits', 'deep_work', 'thinking_fast_slow'];

/// Films are posters (2:3), albums are square, as in the Library.
const _demoMedia = [
  ('interstellar', 2 / 3),
  ('past_lives', 2 / 3),
  ('con_todo_el_mundo', 1.0),
  ('metaphorical_music', 1.0),
];

LibraryEntity _place(String title, double lat, double lng) => LibraryEntity(
  key: 'onboarding-$title',
  provisionalKey: 'onboarding-$title',
  kind: LibraryEntityKind.place,
  mention: EnrichedMention(
    title: title,
    type: 'place',
    latitude: lat,
    longitude: lng,
  ),
  sources: const [],
  discoveredAt: DateTime(2026),
);

final _demoPlaces = [
  _place('Kyoto', 35.01, 135.77),
  _place('Udaipur', 24.58, 73.71),
  _place('Lisbon', 38.72, -9.14),
  _place('Banff', 51.18, -115.57),
  _place('Cape Town', -33.92, 18.42),
  _place('Oaxaca', 17.07, -96.72),
  _place('Reykjavík', 64.15, -21.94),
];
