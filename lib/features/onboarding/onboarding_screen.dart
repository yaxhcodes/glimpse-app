import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_assets.dart';
import '../../core/providers/dev_simulation_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/demo_seed_service.dart';
import 'onboarding_motion.dart';

/// Simmr-inspired guided onboarding.
///
/// Walks a brand-new user through a simulated capture — a faux book reel, the
/// share sheet, and the enriched reveal — then seeds that reel as a real entry
/// so the app is alive on first open. Shown by the root gate while
/// [hasSeenOnboardingProvider] is `false`.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  bool _completing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    HapticFeedback.lightImpact();
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    HapticFeedback.mediumImpact();
    // Seed the reel as a real entry so Home is never empty on first open.
    await DemoSeedService(ref.read(isarServiceProvider)).seed();
    // The share gesture has just been taught — don't re-tip it in-app.
    await ref.read(hasSeenShareTipProvider.notifier).set(true);
    // Flipping this swaps the root gate over to the main app.
    await ref.read(hasSeenOnboardingProvider.notifier).set(true);
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    // Onboarding is a deliberately cinematic, dark experience. Force a dark
    // colour scheme (tinted to the dynamic primary) so it looks consistent even
    // when the system / app is in light mode.
    final darkScheme = base.colorScheme.brightness == Brightness.dark
        ? base.colorScheme
        : ColorScheme.fromSeed(
            seedColor: base.colorScheme.primary,
            brightness: Brightness.dark,
          );
    return Theme(
      data: base.copyWith(colorScheme: darkScheme),
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: PageView(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _IntroStep(onStart: () => _goTo(1), onSkip: _complete),
            _ReelStep(onShare: () => _goTo(2)),
            _ShareSheetStep(onPickGlimpse: () => _goTo(3)),
            _RevealStep(onContinue: _complete, busy: _completing),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Step 1 · Intro
// ─────────────────────────────────────────────────────────────────────────
class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.onStart, required this.onSkip});

  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: AuroraBackground(intensity: 0.9)),
        SafeArea(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          children: [
            const Spacer(),
            Image.asset(AppAssets.logo, width: 88, height: 88),
            const SizedBox(height: 22),
            Text(
              'Glimpse',
              style: tt.displaySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Save it once. We bring it back\nwhen it matters.',
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onSkip,
              child: Text(
                'Skip — I know my way around',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Show me how'),
              ),
            ),
          ],
        ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Step 2 · The (fake) reel
// ─────────────────────────────────────────────────────────────────────────
class _ReelStep extends StatelessWidget {
  const _ReelStep({required this.onShare});

  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.5, 1.0],
              colors: [
                const Color(0xFF0B0B0E),
                Color.alphaBlend(
                    cs.primary.withValues(alpha: 0.20), const Color(0xFF0B0B0E)),
                const Color(0xFF050505),
              ],
            ),
          ),
        ),
        Center(child: _CoverStack(coverWidth: width * 0.26)),
        // Bottom scrim so the creator caption stays legible over art.
        const Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            child: SizedBox(
              height: 280,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Text(
                  'i read 30 books this year',
                  style: tt.titleMedium?.copyWith(
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'these 5 changed me',
                  style: tt.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _coachmark(context),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.account_circle,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 6),
                              Text('quietpages',
                                  style: tt.bodyMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '5 books that rewired how I think 📚',
                            style: tt.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    _RightRail(onShare: onShare, accent: cs.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _coachmark(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Tap ', style: TextStyle(color: cs.onSurface)),
          Icon(Icons.send_outlined, size: 16, color: cs.onSurface),
          Text(' to send this reel', style: TextStyle(color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _RightRail extends StatelessWidget {
  const _RightRail({required this.onShare, required this.accent});

  final VoidCallback onShare;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _railItem(Icons.favorite_border, '24.1k'),
        const SizedBox(height: 20),
        _railItem(Icons.chat_bubble_outline, '402'),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onShare,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                ),
                child: const Icon(Icons.send_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(height: 4),
              const Text('Share',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Icon(Icons.more_vert, color: Colors.white, size: 24),
      ],
    );
  }

  Widget _railItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 27),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Step 3 · The (real) Android share sheet
// ─────────────────────────────────────────────────────────────────────────
class _ShareSheetStep extends StatelessWidget {
  const _ShareSheetStep({required this.onPickGlimpse});

  final VoidCallback onPickGlimpse;

  static const _sheetColor = Color(0xFF26252A);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0B0B0E)),
        Align(
          alignment: const Alignment(0, -0.5),
          child: Opacity(
            opacity: 0.35,
            child: _CoverStack(
              coverWidth: MediaQuery.of(context).size.width * 0.18,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(
              color: _sheetColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.only(top: 12),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _urlRow(context),
                  const SizedBox(height: 12),
                  _nearbyRow(context),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _appTile(
                          context,
                          bg: const Color(0xFFEDE6D7),
                          label: 'Glimpse\nSave',
                          highlight: true,
                          onTap: onPickGlimpse,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(AppAssets.logo),
                          ),
                        ),
                        _appTile(
                          context,
                          bg: const Color(0xFF25D366),
                          label: 'WhatsApp',
                          child: const Icon(Icons.chat,
                              color: Colors.white, size: 26),
                        ),
                        _appTile(
                          context,
                          bg: const Color(0xFFF1F1F3),
                          label: 'Gemini',
                          child: const Icon(Icons.auto_awesome,
                              color: Color(0xFF1A73E8), size: 24),
                        ),
                        _appTile(
                          context,
                          bg: const Color(0xFF5865F2),
                          label: 'Discord',
                          child: const Icon(Icons.forum,
                              color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 8; i++)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == 0
                                ? Colors.white70
                                : Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, 0.18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'Tap Glimpse to turn it into a reading list',
              style: tt.bodySmall
                  ?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _urlRow(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.link, color: Color(0xFF26252A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'https://www.instagram.com/reel/DZdXbJ2...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.content_copy, color: Colors.white54, size: 20),
        ],
      ),
    );
  }

  Widget _nearbyRow(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.near_me, color: Color(0xFF4DA3FF), size: 22),
          const SizedBox(width: 14),
          Text('Share via "Nearby Share"',
              style: tt.bodyMedium?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _appTile(
    BuildContext context, {
    required Widget child,
    required Color bg,
    required String label,
    bool highlight = false,
    VoidCallback? onTap,
  }) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: highlight
                    ? Border.all(color: cs.primary, width: 2.5)
                    : null,
              ),
              child: child,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                  color: Colors.white70, fontSize: 11, height: 1.15),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Step 4 · The reveal (mirrors Glimpse's real detail screen)
// ─────────────────────────────────────────────────────────────────────────
class _RevealStep extends StatelessWidget {
  const _RevealStep({required this.onContinue, required this.busy});

  final VoidCallback onContinue;
  final bool busy;

  static const _books = [
    (
      'Thinking, Fast and Slow',
      'The two-systems model the reel opens with.',
      'https://covers.openlibrary.org/b/isbn/9780374533557-L.jpg',
    ),
    (
      'Atomic Habits',
      'The habit-stacking idea at 0:14.',
      'https://covers.openlibrary.org/b/isbn/9780735211292-L.jpg',
    ),
    (
      'Deep Work',
      'Why she deleted the apps for a month.',
      'https://covers.openlibrary.org/b/isbn/9781455586691-L.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 168,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Stack(
                      children: [
                        const Positioned.fill(
                            child: AuroraBackground(intensity: 0.7)),
                        const Center(child: _CoverStack(coverWidth: 62)),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: _chip(context, '📚 Books', strong: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('5 books that rewired how I think',
                      style: tt.headlineSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                          height: 1.2)),
                  const SizedBox(height: 12),
                  _sourceRow(context),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _stat(context, Icons.favorite_border, '24.1k'),
                      _stat(context, Icons.chat_bubble_outline, '402'),
                      _creatorChip(context, '@quietpages'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionHeader(context, 'Summary'),
                  const SizedBox(height: 8),
                  Text(
                    'Five books on attention, habit and how the mind works — '
                    'each with a one-line reason it made the cut.',
                    style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  _sectionHeader(context, 'Worth reading'),
                  const SizedBox(height: 12),
                  for (final book in _books) _bookRow(context, book),
                  const SizedBox(height: 12),
                  _sectionHeader(context, 'Tags'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(context, 'mindset'),
                      _chip(context, 'focus'),
                      _chip(context, 'reading'),
                      _chip(context, 'psychology'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onContinue,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('This is yours now — continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [Color(0xFFFEC053), Color(0xFFE0306A), Color(0xFF9C36B5)],
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Icon(Icons.photo_camera, size: 11, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text('Instagram • now',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text('Unread',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurface)),
        ],
      ),
    );
  }

  Widget _creatorChip(BuildContext context, String handle) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(handle, style: tt.bodySmall?.copyWith(color: cs.onSurface)),
          const SizedBox(width: 4),
          Icon(Icons.north_east, size: 13, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, {bool strong = false}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: strong ? cs.secondaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: tt.bodySmall?.copyWith(
          color: strong ? cs.onSecondaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(title,
        style: tt.titleLarge?.copyWith(
            color: cs.primary, fontWeight: FontWeight.w600));
  }

  Widget _bookRow(BuildContext context, (String, String, String) book) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 44,
              height: 60,
              child: CachedNetworkImage(
                imageUrl: book.$3,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    ColoredBox(color: cs.surfaceContainerHighest),
                errorWidget: (_, _, _) => Container(
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.menu_book_outlined,
                      size: 18, color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.$1,
                    style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(book.$2,
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.open_in_new,
              size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
        ],
      ),
    );
  }
}

/// Real book covers (Open Library) used as the onboarding hero visual.
const _kCoverUrls = [
  'https://covers.openlibrary.org/b/isbn/9780374533557-L.jpg',
  'https://covers.openlibrary.org/b/isbn/9780735211292-L.jpg',
  'https://covers.openlibrary.org/b/isbn/9781455586691-L.jpg',
];

/// A premium fanned stack of real book covers — front cover upright, two behind
/// it angled out. Fans open on entry. Replaces clip-art with actual content.
class _CoverStack extends StatelessWidget {
  const _CoverStack({required this.coverWidth});

  final double coverWidth;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, t, _) {
        return SizedBox(
          width: coverWidth * 2.5,
          height: coverWidth * 1.5 + coverWidth * 0.35,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _cover(context, _kCoverUrls[2],
                  angle: -0.22 * t,
                  dx: -coverWidth * 0.6 * t,
                  dy: coverWidth * 0.12 * t,
                  scale: 0.88,
                  t: t),
              _cover(context, _kCoverUrls[1],
                  angle: 0.22 * t,
                  dx: coverWidth * 0.6 * t,
                  dy: coverWidth * 0.12 * t,
                  scale: 0.88,
                  t: t),
              _cover(context, _kCoverUrls[0],
                  angle: 0,
                  dx: 0,
                  dy: -coverWidth * 0.06 * t,
                  scale: 1.0,
                  t: t),
            ],
          ),
        );
      },
    );
  }

  Widget _cover(
    BuildContext context,
    String url, {
    required double angle,
    required double dx,
    required double dy,
    required double scale,
    required double t,
  }) {
    final cs = Theme.of(context).colorScheme;
    Widget fallback() => Container(
          color: cs.surfaceContainerHigh,
          alignment: Alignment.center,
          child: Icon(Icons.menu_book_outlined,
              color: cs.onSurfaceVariant, size: coverWidth * 0.3),
        );
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translateByDouble(dx, dy, 0, 1)
        ..rotateZ(angle)
        ..scaleByDouble(scale, scale, 1, 1),
      child: Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Container(
          width: coverWidth,
          height: coverWidth * 1.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHigh),
            errorWidget: (_, _, _) => fallback(),
          ),
        ),
      ),
    );
  }
}
