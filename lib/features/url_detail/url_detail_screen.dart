import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/category_taxonomy.dart';
import '../../core/services/intent_classifier.dart';
import '../../core/services/recipe_state_service.dart';
import '../../core/services/saved_media_resolver.dart';
import '../../core/services/summary_rewriter.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/text_cleaner.dart';
import '../../core/services/title_resolver.dart';
import '../../core/services/transcript_enrichment_service.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/category_chip.dart'
    show faviconUrl, platformColors;
import '../../shared/widgets/content_recommendation_section.dart';
import '../../shared/widgets/creator_profile_link.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/metadata_pill.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/tag_group.dart';
import '../collections/add_to_collection_sheet.dart';
import '../home/home_provider.dart';
import '../search/search_provider.dart';
import 'detail_expansion_section.dart';
import 'url_detail_provider.dart';

class UrlDetailScreen extends ConsumerStatefulWidget {
  final int urlId;
  final ValueChanged<bool>? onMediaPointerActiveChanged;

  const UrlDetailScreen({
    super.key,
    required this.urlId,
    this.onMediaPointerActiveChanged,
  });

  @override
  ConsumerState<UrlDetailScreen> createState() => _UrlDetailScreenState();
}

/// Wraps [UrlDetailScreen] in a horizontal [PageView] so the user can
/// swipe between posts in the same context list (like Reddit).
class UrlDetailPagerScreen extends StatefulWidget {
  /// Ordered list of URL IDs in the current context (e.g. home section, category).
  final List<int> urlIds;

  /// Index of the URL that was tapped — this page is shown first.
  final int initialIndex;

  const UrlDetailPagerScreen({
    super.key,
    required this.urlIds,
    required this.initialIndex,
  });

  @override
  State<UrlDetailPagerScreen> createState() => _UrlDetailPagerScreenState();
}

class _UrlDetailPagerScreenState extends State<UrlDetailPagerScreen> {
  late final PageController _pageController;

  // Drag tracking for custom horizontal-swipe detection.
  double _dragStartX = 0;
  double _dragDeltaX = 0;
  double _dragStartScrollOffset = 0; // PageController offset at drag start
  bool _isDraggingHorizontal = false;
  bool _mediaPointerActive = false;

  // Snap threshold: must drag at least this far to flip pages.
  static const double _snapFraction = 0.3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    if (_mediaPointerActive) return;
    _dragStartX = d.globalPosition.dx;
    _dragDeltaX = 0;
    _isDraggingHorizontal = false;
    // Snapshot the scroll position at the moment the finger lands so every
    // subsequent update is relative to a stable baseline.
    _dragStartScrollOffset = _pageController.hasClients
        ? _pageController.offset
        : widget.initialIndex * MediaQuery.sizeOf(context).width;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_mediaPointerActive) return;
    _dragDeltaX = d.globalPosition.dx - _dragStartX;

    // Only engage once the gesture is clearly horizontal.
    if (!_isDraggingHorizontal && _dragDeltaX.abs() > 8) {
      _isDraggingHorizontal = true;
    }
    if (!_isDraggingHorizontal) return;

    // Translate finger offset directly to page position for 1:1 feel.
    // Clamp so we don't scroll past the first/last page.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxOffset = (widget.urlIds.length - 1) * screenWidth;
    final target = (_dragStartScrollOffset - _dragDeltaX).clamp(0.0, maxOffset);
    _pageController.jumpTo(target);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_mediaPointerActive) {
      _isDraggingHorizontal = false;
      return;
    }
    if (!_isDraggingHorizontal) return;
    _isDraggingHorizontal = false;

    final screenWidth = MediaQuery.sizeOf(context).width;
    // The page the swipe originated from (stable, not drifted).
    final originPage = (_dragStartScrollOffset / screenWidth).round().clamp(
      0,
      widget.urlIds.length - 1,
    );
    final fraction = _dragDeltaX.abs() / screenWidth;
    final velocity = d.velocity.pixelsPerSecond.dx.abs();

    // Commit to next/prev if dragged far enough or flicked fast enough.
    int targetPage = originPage;
    if (_dragDeltaX < 0 && originPage < widget.urlIds.length - 1) {
      if (fraction >= _snapFraction || velocity > 600) {
        targetPage = originPage + 1;
      }
    } else if (_dragDeltaX > 0 && originPage > 0) {
      if (fraction >= _snapFraction || velocity > 600) {
        targetPage = originPage - 1;
      }
    }

    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _mediaPointerActive ? null : _onDragStart,
      onHorizontalDragUpdate: _mediaPointerActive ? null : _onDragUpdate,
      onHorizontalDragEnd: _mediaPointerActive ? null : _onDragEnd,
      // Exclude the gesture from competing with vertical scrolls inside pages.
      excludeFromSemantics: true,
      child: PageView.builder(
        controller: _pageController,
        // Let our GestureDetector drive paging; disable built-in page physics
        // so there's no double-handling and no scroll-axis fight.
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.urlIds.length,
        itemBuilder: (context, index) {
          return _KeepAlivePage(
            child: UrlDetailScreen(
              key: ValueKey(widget.urlIds[index]),
              urlId: widget.urlIds[index],
              onMediaPointerActiveChanged: (active) {
                if (_mediaPointerActive == active) return;
                setState(() => _mediaPointerActive = active);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Keeps a pager page alive in the widget tree so it isn't rebuilt
/// every time the user swipes away and back.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});
  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Fullscreen, pinch-to-zoom gallery for saved media. The detail page itself
/// owns horizontal post-to-post swipes, so gallery swipes live here where they
/// do not compete with the outer pager.
class _ImageViewerScreen extends StatefulWidget {
  const _ImageViewerScreen({
    required this.imageUrls,
    required this.initialIndex,
    required this.heroTagPrefix,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String heroTagPrefix;

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imageUrls.length - 1).toInt();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final imageUrl = widget.imageUrls[index];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Hero(
                      tag: '${widget.heroTagPrefix}-$index',
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        httpHeaders: SavedMediaResolver.imageHttpHeaders(
                          imageUrl,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 18,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_index + 1}/${widget.imageUrls.length}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.42),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetadata {
  const _DetailMetadata({
    this.likesLabel,
    this.commentsLabel,
    this.creatorUsername,
  });

  final String? likesLabel;
  final String? commentsLabel;
  final String? creatorUsername;

  bool get hasStats => likesLabel != null || commentsLabel != null;
  bool get hasSocialRow => hasStats || creatorUsername != null;
}

class _GlimpseSavedNote {
  const _GlimpseSavedNote({required this.answer, this.asked, this.question});

  final String answer;
  final String? asked;
  final String? question;
}

class _GlimpseSavedNoteCard extends StatelessWidget {
  const _GlimpseSavedNoteCard({
    required this.note,
    required this.theme,
    required this.colorScheme,
  });

  final _GlimpseSavedNote note;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final accent = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.42),
      colorScheme.onSurfaceVariant,
    );
    final mutedSurface = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.035),
      colorScheme.surfaceContainerHighest,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mutedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Ask Glimpse',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              if ((note.asked ?? '').isNotEmpty)
                Text(
                  note.asked!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1,
                  ),
                ),
            ],
          ),
          if ((note.question ?? '').isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              note.question!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
          if (note.answer.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note.answer,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteSuggestionChip extends StatelessWidget {
  const _NoteSuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.intent = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Whether this chip sets an on-device intent ("Watch Later", "Already Read")
  /// rather than just appending note text.
  final bool intent;

  /// Whether the intent this chip represents is currently set on the save.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chipColor = selected
        ? colorScheme.primary
        : Color.alphaBlend(
            colorScheme.primary.withValues(alpha: intent ? 0.14 : 0.08),
            colorScheme.surfaceContainerHighest,
          );
    final fgColor = selected ? colorScheme.onPrimary : colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: chipColor,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_rounded : icon,
                  size: 15,
                  color: fgColor,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w600,
                    height: 1,
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

class _ReadStatePill extends StatelessWidget {
  const _ReadStatePill({required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isRead ? 'Read' : 'Unread',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

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

class _UrlDetailScreenState extends ConsumerState<UrlDetailScreen> {
  late TextEditingController _notesController;
  final ScrollController _scrollController = ScrollController();
  final PageController _mediaPageController = PageController();
  final FocusNode _notesFocusNode = FocusNode();
  bool _notesEdited = false;
  bool _showExactSavedDate = false;
  bool _retryingEnrichment = false;
  int _mediaPageIndex = 0;
  String? _localNotesOverride;
  // Reflects the intent chip the user just tapped, before the provider refetches
  // (avoids reloading the whole detail body just to flip a chip's set-state).
  // Sentinel '' means "explicitly cleared".
  String? _localIntentActionOverride;
  Timer? _notesTimer;
  RecipeStateService? _recipeStateService;
  int? _loadedRecipeStateId;
  bool _recipeStateLoading = false;
  Set<String> _checkedIngredientKeys = {};
  List<ShoppingListItem> _shoppingList = const [];

  @override
  void didUpdateWidget(covariant UrlDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urlId != widget.urlId) {
      _showExactSavedDate = false;
      _localNotesOverride = null;
      _localIntentActionOverride = null;
      _loadedRecipeStateId = null;
      _checkedIngredientKeys = {};
      _mediaPageIndex = 0;
      if (_mediaPageController.hasClients) {
        _mediaPageController.jumpToPage(0);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _notesFocusNode.addListener(_handleNotesFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repaired = await ref
          .read(urlDetailNotifierProvider.notifier)
          .refreshContentIfLikelyTruncated(widget.urlId);
      if (repaired && mounted) {
        ref.invalidate(urlDetailProvider(widget.urlId));
      }
    });
  }

  @override
  void dispose() {
    _notesTimer?.cancel();
    if (_notesEdited) {
      ref
          .read(urlDetailNotifierProvider.notifier)
          .updateNotes(widget.urlId, _notesController.text);
    }
    _notesFocusNode.removeListener(_handleNotesFocusChange);
    _notesFocusNode.dispose();
    _notesController.dispose();
    _mediaPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleNotesFocusChange() {
    if (!_notesFocusNode.hasFocus && _notesEdited) {
      _notesTimer?.cancel();
      _autoSaveNotes();
    }
  }

  void _showAddToCollection(SavedUrl url) {
    showAddToCollectionSheet(context, url);
  }

  void _copyUrlToClipboard(String raw) {
    Clipboard.setData(ClipboardData(text: raw));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Link copied'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
  }

  Future<void> _launchUrl(String url) async {
    await ref
        .read(isarServiceProvider)
        .updateOpenedAt(widget.urlId, DateTime.now());
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openImageGallery({
    required List<String> imageUrls,
    required int initialIndex,
    required int urlId,
  }) {
    if (imageUrls.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => _ImageViewerScreen(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          heroTagPrefix: 'detail-image-$urlId-slide',
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _saveNotes() async {
    final success = await ref
        .read(urlDetailNotifierProvider.notifier)
        .updateNotes(widget.urlId, _notesController.text);
    if (success && mounted) {
      setState(() {
        _localNotesOverride = _notesController.text;
        _notesEdited = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Notes saved'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
    }
  }

  /// Persists notes without invalidating [urlDetailProvider] — a refetch shows
  /// loading and replaces the whole body, which disposed the field and dropped focus.
  Future<void> _autoSaveNotes() async {
    final success = await ref
        .read(urlDetailNotifierProvider.notifier)
        .updateNotes(widget.urlId, _notesController.text);
    if (success && mounted) {
      setState(() {
        _localNotesOverride = _notesController.text;
        _notesEdited = false;
      });
    }
  }

  void _scheduleNotesAutosave() {
    if (!_notesEdited) {
      setState(() => _notesEdited = true);
    }
    _notesTimer?.cancel();
    _notesTimer = Timer(const Duration(milliseconds: 1500), _autoSaveNotes);
  }

  /// Append a suggestion label to the notes as plain text (dedup by line).
  void _appendNoteLine(String suggestion, {bool focus = true}) {
    final current = _notesController.text.trim();
    final next = current.isEmpty
        ? suggestion
        : current
              .toLowerCase()
              .split('\n')
              .map((line) => line.trim())
              .contains(suggestion.toLowerCase())
        ? current
        : '$current\n$suggestion';

    _notesController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _localNotesOverride = next;
    _scheduleNotesAutosave();
    if (focus) _notesFocusNode.requestFocus();
  }

  /// The intent currently set on this save, accounting for the optimistic
  /// override from a chip the user just tapped this session.
  String? _effectiveIntentAction(SavedUrl url) {
    if (_localIntentActionOverride == null) return url.intentAction;
    return _localIntentActionOverride!.isEmpty
        ? null
        : _localIntentActionOverride;
  }

  /// Route a suggested-action chip tap. "Queue"/"Done" chips set a real,
  /// on-device intent signal that Rediscovery and notifications read; every
  /// other chip keeps the original behaviour of appending text to the notes.
  Future<void> _handleSuggestionTap(String suggestion, SavedUrl url) async {
    final classified = IntentClassifier.classify(suggestion);
    if (classified.kind == IntentKind.note) {
      _appendNoteLine(suggestion);
      return;
    }

    final isar = ref.read(isarServiceProvider);
    final alreadySet = _effectiveIntentAction(url) == classified.action;

    if (alreadySet) {
      // Toggle the intent back off (leaves any note text in place).
      await isar.clearIntent(widget.urlId);
      if (!mounted) return;
      setState(() => _localIntentActionOverride = '');
      _showSnack('Cleared');
      return;
    }

    final status = classified.kind == IntentKind.done ? 'done' : 'queued';
    await isar.updateIntent(
      widget.urlId,
      status: status,
      action: classified.action,
      revisitAfter: classified.revisitAfter,
    );
    if (!mounted) return;
    setState(() => _localIntentActionOverride = classified.action);
    // Record the user's decision in their notes too, without stealing focus.
    _appendNoteLine(suggestion, focus: false);
    _showSnack(
      classified.kind == IntentKind.done
          ? 'Marked as done — moved to Done'
          : 'Saved — we\'ll bring this back for you',
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _retryEnrichment() async {
    if (_retryingEnrichment) return;
    setState(() => _retryingEnrichment = true);
    final success = await ref
        .read(urlDetailNotifierProvider.notifier)
        .retryEnrichment(widget.urlId);
    if (!mounted) return;
    setState(() => _retryingEnrichment = false);
    ref.invalidate(urlDetailProvider(widget.urlId));
    _showSnack(success ? 'Retrying enrichment' : 'Could not retry enrichment');
  }

  Future<void> _deleteUrl() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete URL?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(urlDetailNotifierProvider.notifier)
          .deleteUrl(widget.urlId);
      if (success && mounted) {
        context.pop();
      }
    }
  }

  Future<void> _removeTag(SavedUrl url, String tag) async {
    final isarService = ref.read(isarServiceProvider);
    url.tags = url.tags.where((t) => t != tag).toList();
    await isarService.updateUrl(url);
    ref.invalidate(urlDetailProvider(widget.urlId));
  }

  void _ensureRecipeStateLoaded(int recipeId) {
    if (_loadedRecipeStateId == recipeId || _recipeStateLoading) return;
    _recipeStateLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipeState(recipeId);
    });
  }

  Future<void> _loadRecipeState(int recipeId) async {
    final service = _recipeStateService ?? await RecipeStateService.create();
    if (!mounted) return;
    setState(() {
      _recipeStateService = service;
      _loadedRecipeStateId = recipeId;
      _checkedIngredientKeys = service.checkedIngredientKeys(recipeId);
      _shoppingList = service.shoppingList();
      _recipeStateLoading = false;
    });
  }

  Future<void> _setIngredientChecked(
    int recipeId,
    String key,
    bool checked,
  ) async {
    final service = _recipeStateService ?? await RecipeStateService.create();
    setState(() {
      checked
          ? _checkedIngredientKeys.add(key)
          : _checkedIngredientKeys.remove(key);
    });
    await service.setIngredientChecked(recipeId, key, checked);
  }

  Future<void> _checkAllIngredients(int recipeId, EnrichedRecipe recipe) async {
    final service = _recipeStateService ?? await RecipeStateService.create();
    final keys = recipe.ingredients
        .asMap()
        .entries
        .map(
          (entry) => RecipeStateService.ingredientKey(entry.value, entry.key),
        )
        .toSet();
    setState(() => _checkedIngredientKeys = keys);
    await service.setAllIngredientsChecked(recipeId, keys);
  }

  Future<void> _resetIngredientChecks(int recipeId) async {
    final service = _recipeStateService ?? await RecipeStateService.create();
    setState(() => _checkedIngredientKeys = {});
    await service.resetIngredientChecks(recipeId);
  }

  Future<void> _addRecipeIngredientsToShoppingList({
    required int recipeId,
    required EnrichedRecipe recipe,
    required bool selectedOnly,
  }) async {
    final entries = recipe.ingredients.asMap().entries.where((entry) {
      if (!selectedOnly) return true;
      final key = RecipeStateService.ingredientKey(entry.value, entry.key);
      return _checkedIngredientKeys.contains(key);
    }).toList();
    if (entries.isEmpty) {
      _showRecipeMessage('Check ingredients first, or add all ingredients.');
      return;
    }

    final service = _recipeStateService ?? await RecipeStateService.create();
    final added = await service.addToShoppingList(
      recipeId: recipeId,
      recipeTitle: recipe.title.isEmpty ? 'Recipe' : recipe.title,
      ingredients: entries,
    );
    if (!mounted) return;
    setState(() {
      _recipeStateService = service;
      _shoppingList = service.shoppingList();
    });
    _showRecipeMessage(
      added == 0
          ? 'Those ingredients are already on your shopping list.'
          : 'Added $added ingredient${added == 1 ? '' : 's'} to shopping list.',
    );
  }

  void _showRecipeMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _showShoppingList() async {
    final service = _recipeStateService ?? await RecipeStateService.create();
    var items = service.shoppingList();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Shopping List',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (items.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              await service.clearShoppingList();
                              setSheetState(() => items = const []);
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Text('Your shopping list is empty.'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final colorScheme = Theme.of(context).colorScheme;
                              // Build display: name on top, quantity + sources below
                              final qtyLabel =
                                  item.mergedQuantityLabel?.trim().isNotEmpty ==
                                      true
                                  ? item.mergedQuantityLabel!
                                  : item.ingredient.amountLabel.trim();
                              final sourceLine = item.allRecipeTitles.join(
                                ' · ',
                              );
                              return Dismissible(
                                key: ValueKey(item.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: colorScheme.errorContainer,
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                                onDismissed: (_) async {
                                  await service.removeShoppingItem(item.id);
                                  setSheetState(
                                    () => items = service.shoppingList(),
                                  );
                                },
                                child: CheckboxListTile(
                                  value: item.isChecked,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(
                                    item.ingredient.name,
                                    style: item.isChecked
                                        ? TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.4),
                                          )
                                        : null,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (qtyLabel.isNotEmpty)
                                        Text(
                                          item.isMerged
                                              ? 'Total: $qtyLabel'
                                              : qtyLabel,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: item.isMerged
                                                    ? _recipeAccent(colorScheme)
                                                    : colorScheme
                                                          .onSurfaceVariant,
                                                fontWeight: item.isMerged
                                                    ? FontWeight.w700
                                                    : null,
                                              ),
                                        ),
                                      Text(
                                        sourceLine,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.7),
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                  isThreeLine: qtyLabel.isNotEmpty,
                                  secondary: IconButton(
                                    tooltip: 'Remove',
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () async {
                                      await service.removeShoppingItem(item.id);
                                      setSheetState(
                                        () => items = service.shoppingList(),
                                      );
                                    },
                                  ),
                                  onChanged: (checked) async {
                                    await service.setShoppingItemChecked(
                                      item.id,
                                      checked ?? false,
                                    );
                                    setSheetState(
                                      () => items = service.shoppingList(),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    setState(() {
      _recipeStateService = service;
      _shoppingList = service.shoppingList();
    });
  }

  void _openTagSearch(String tag) {
    ref
        .read(searchShellQueryRequestProvider.notifier)
        .state = SearchShellQueryRequest(
      query: tag,
      revision: DateTime.now().microsecondsSinceEpoch,
    );
    context.go('/');
  }

  Future<void> _showTagMenu(SavedUrl url, String tag) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tag,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.travel_explore_rounded),
                  title: const Text('Related saves'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openTagSearch(tag);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.remove_circle_outline_rounded,
                    color: colorScheme.error,
                  ),
                  title: Text(
                    'Remove tag',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeTag(url, tag);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addTag(SavedUrl url) async {
    final controller = TextEditingController();
    final newTag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. design, recipe…'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newTag == null || newTag.isEmpty || !mounted) return;
    if (url.tags.contains(newTag)) return;
    final isarService = ref.read(isarServiceProvider);
    url.tags = [...url.tags, newTag];
    await isarService.updateUrl(url);
    ref.invalidate(urlDetailProvider(widget.urlId));
  }

  Future<void> _changeCategory(SavedUrl url) async {
    final theme = Theme.of(context);
    final isarService = ref.read(isarServiceProvider);

    // Get existing categories to show as suggestions
    final categories = await isarService.getCategories();
    final existingNames = categories
        .map((c) => c['category'] as String)
        .toList();

    if (!mounted) return;

    final customController = TextEditingController();
    final emojiController = TextEditingController(text: '📁');

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Change Category', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Pick an existing one or create your own',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Existing categories
              if (existingNames.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: existingNames.map((name) {
                    final cat = categories.firstWhere(
                      (c) => c['category'] == name,
                    );
                    final emoji = cat['emoji'] as String;
                    final isCurrentCat = name == url.category;
                    final fav = faviconUrl(name);
                    return ActionChip(
                      avatar: fav != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: CachedNetworkImage(
                                imageUrl: fav,
                                width: 18,
                                height: 18,
                                errorWidget: (_, _, _) => Text(emoji),
                              ),
                            )
                          : Text(emoji),
                      label: Text(name),
                      side: isCurrentCat
                          ? BorderSide(
                              color: _recipeAccent(theme.colorScheme),
                              width: 1.5,
                            )
                          : null,
                      onPressed: () => Navigator.pop(ctx, {
                        'category': name,
                        'emoji': emoji,
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: theme.colorScheme.outlineVariant),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or create new',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: theme.colorScheme.outlineVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // New custom category
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: emojiController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22),
                      decoration: const InputDecoration(
                        hintText: '📁',
                        counterText: '',
                      ),
                      maxLength: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: customController,
                      autofocus: existingNames.isEmpty,
                      decoration: const InputDecoration(
                        hintText: 'Category name',
                        labelText: 'New category',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final name = customController.text.trim();
                  if (name.isEmpty) return;
                  final emoji = emojiController.text.trim().isEmpty
                      ? '📁'
                      : emojiController.text.trim();
                  Navigator.pop(ctx, {'category': name, 'emoji': emoji});
                },
                child: const Text('Create & Apply'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    final newCat = result['category']!;
    final newEmoji = result['emoji']!;

    if (newCat == url.category) return;

    final additionalCategories = url.effectiveCategories
        .where((item) => item != url.category)
        .toList();
    url.category = newCat;
    url.categoryEmoji = newEmoji;
    url.categories = CategoryResolver.buildCategories(
      primaryCategory: newCat,
      additionalCategories: additionalCategories,
    );
    await isarService.updateUrl(url);
    ref.invalidate(urlDetailProvider(widget.urlId));
    ref.invalidate(categoriesProvider);

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Moved to "$newCat"'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final urlAsync = ref.watch(urlDetailProvider(widget.urlId));
    final tagFreq = ref.watch(tagOccurrenceMapProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final url = urlAsync.valueOrNull;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: const AppGlassSurface(),
            foregroundColor: colorScheme.onSurfaceVariant,
            title: const Text('Details'),
            actions: [
              if (url != null) ...[
                IconButton(
                  icon: const AppIcon(AppIcons.addToCollection),
                  tooltip: 'Add to collection',
                  onPressed: () => _showAddToCollection(url),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'More',
                  onSelected: (value) {
                    if (value == 'open_original') {
                      _launchUrl(url.rawUrl);
                    } else if (value == 'copy_link') {
                      _copyUrlToClipboard(url.rawUrl);
                    } else if (value == 'share') {
                      Share.share(url.rawUrl);
                    } else if (value == 'add_tag') {
                      _addTag(url);
                    } else if (value == 'change_category') {
                      _changeCategory(url);
                    } else if (value == 'delete') {
                      _deleteUrl();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'open_original',
                      child: Row(
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          const Text('Open Original'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'copy_link',
                      child: Row(
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          const Text('Copy Link'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          const Text('Share'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'add_tag',
                      child: Row(
                        children: [
                          Icon(
                            Icons.sell_outlined,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          const Text('Add tag'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'change_category',
                      child: Row(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          const Text('Change category'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Delete',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (urlAsync.isLoading)
            const SliverFillRemaining(child: LoadingIndicator())
          else if (urlAsync.hasError)
            SliverFillRemaining(
              child: Center(child: Text('Error: ${urlAsync.error}')),
            )
          else if (url == null)
            const SliverFillRemaining(
              child: Center(child: Text('URL not found')),
            )
          else
            _buildBody(url, theme, colorScheme, tagFreq),
        ],
      ),
    );
  }

  Widget _buildBody(
    SavedUrl url,
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, int> tagFreq,
  ) {
    if (!_notesEdited && !_notesFocusNode.hasFocus) {
      _notesController.text = _localNotesOverride ?? url.userNotes ?? '';
    }
    final live = _savedEnrichment(url);
    final metadata = _extractDetailMetadata(
      description: url.description,
      creator: live?.creator,
      likeCount: live?.likeCount,
      commentCount: live?.commentCount,
      rawUrl: url.rawUrl,
    );
    final formattedDescription = _formatDescription(url.description);
    final captionText = _stripHashtagsFromCaption(formattedDescription);
    final displaySourceName = CategoryResolver.displaySourceName(
      rawUrl: url.rawUrl,
      fallbackDomain: url.domain,
    );
    final normalizedCategories = url.effectiveCategories
        .map((item) => item.toLowerCase())
        .toSet();
    final mentionTitles = (live?.mentions ?? const <EnrichedMention>[])
        .map((item) => TagNoiseFilter.cleanTag(item.title))
        .where((item) => item.isNotEmpty)
        .toSet();
    final sourceTags = url.tags;
    final rawTagPool = sourceTags
        .where((tag) => !normalizedCategories.contains(tag.toLowerCase()))
        .where((tag) => tag.toLowerCase() != displaySourceName.toLowerCase())
        .where((tag) => !mentionTitles.contains(TagNoiseFilter.cleanTag(tag)))
        .toList();
    final visibleTags = TagNoiseFilter.orderByRarity(
      TagNoiseFilter.filterTags(rawTagPool),
      tagFreq,
    );
    final carouselImages = _detailMediaImages(url, live);
    final showImage = carouselImages.isNotEmpty;
    final categoryLabels = _displayCategories(url);
    final summaryText = TextCleaner.clean(url.summary?.trim() ?? '');
    final displayTitle = TitleResolver.resolveDetailTitle(
      url,
      tagFrequency: tagFreq,
    );
    final cleanedSummary = SummaryRewriter.clean(summaryText);
    final cleanedBrief = SummaryRewriter.clean(live?.brief);
    final summaryDisplayText = _summaryForDetail(
      cleanedBrief.isNotEmpty
          ? cleanedBrief
          : cleanedSummary.isNotEmpty
          ? cleanedSummary
          : summaryText,
      caption: captionText,
    );
    final showSummary =
        summaryDisplayText.isNotEmpty && live?.recipe?.hasUsefulContent != true;
    final noteSuggestions = _buildNoteSuggestions(
      url: url,
      live: live,
      tags: visibleTags,
      caption: captionText,
      summary: summaryDisplayText,
    );
    final bottomPad = MediaQuery.paddingOf(context).bottom + 28;

    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxReadableContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image ───────────────────────────────────────────────────
                _buildDetailMedia(
                  url: url,
                  showImage: showImage,
                  imageUrls: carouselImages,
                  categoryLabels: categoryLabels,
                  displaySourceName: displaySourceName,
                  theme: theme,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 16),

                // ── Hero recognition ────────────────────────────────────────
                Text(
                  displayTitle,
                  style: AppTypography.editorial(
                    theme.textTheme.titleLarge,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: colorScheme.onSurface,
                    letterSpacing: 0,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // ── Source ──────────────────────────────────────────────────
                _buildSourceSavedRow(
                  url: url,
                  displaySourceName: displaySourceName,
                  colorScheme: colorScheme,
                  theme: theme,
                ),

                if (url.isProcessingFailed) ...[
                  const SizedBox(height: 12),
                  _buildEnrichmentFailedPanel(theme, colorScheme),
                ],

                if (metadata.hasSocialRow) ...[
                  const SizedBox(height: 10),
                  _buildSocialMetadata(
                    metadata: metadata,
                    displaySourceName: displaySourceName,
                    colorScheme: colorScheme,
                  ),
                ],

                const SizedBox(height: 14),
                _buildOpenButton(url, displaySourceName),

                if (showSummary) ...[
                  const SizedBox(height: 20),
                  _buildSummarySection(
                    summary: summaryDisplayText,
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                ],

                ..._buildEnrichmentSections(
                  url: url,
                  live: live,
                  theme: theme,
                  colorScheme: colorScheme,
                ),

                // ── Description ─────────────────────────────────────────────
                // ── Tags ────────────────────────────────────────────────────
                const SizedBox(height: 16),
                TagGroup(
                  tags: visibleTags,
                  onTap: _openTagSearch,
                  onLongPress: (tag) => _showTagMenu(url, tag),
                  accent: _recipeAccent(colorScheme),
                ),

                // ── Notes ───────────────────────────────────────────────────
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SectionHeader(
                          title: 'Your Notes',
                          accent: _recipeAccent(colorScheme),
                        ),
                        const Spacer(),
                        if (_notesEdited)
                          TextButton(
                            onPressed: _saveNotes,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            child: const Text('Save'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildNotesComposer(theme: theme, colorScheme: colorScheme),
                    if (noteSuggestions.isNotEmpty)
                      _buildNoteQuickAdd(
                        url: url,
                        suggestions: noteSuggestions,
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _summaryForDetail(String raw, {required String caption}) {
    final cleaned = SummaryRewriter.clean(raw);
    if (cleaned.isEmpty) return '';
    if (caption.trim().isNotEmpty &&
        cleaned.toLowerCase() == caption.trim().toLowerCase()) {
      return '';
    }
    return cleaned;
  }

  Widget _buildOpenButton(SavedUrl url, String displaySourceName) {
    final accent = _recipeAccent(Theme.of(context).colorScheme);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _launchUrl(url.rawUrl),
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: Text(_openButtonLabel(displaySourceName)),
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: 0.55)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildEnrichmentFailedPanel(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Couldn't finish enrichment",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _retryingEnrichment ? null : _retryEnrichment,
            icon: _retryingEnrichment
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.error,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// "Open in Instagram" when we know the source, else a neutral fallback.
  String _openButtonLabel(String displaySourceName) {
    final name = displaySourceName.trim();
    if (name.isEmpty || name.toLowerCase() == 'web') return 'Open original';
    return 'Open in $name';
  }

  Widget _buildDetailMedia({
    required SavedUrl url,
    required bool showImage,
    required List<String> imageUrls,
    required List<String> categoryLabels,
    required String displaySourceName,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final currentIndex =
        (imageUrls.isEmpty ? 0 : _mediaPageIndex.clamp(0, imageUrls.length - 1))
            .toInt();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Listener(
        onPointerDown: (_) => widget.onMediaPointerActiveChanged?.call(true),
        onPointerUp: (_) => widget.onMediaPointerActiveChanged?.call(false),
        onPointerCancel: (_) => widget.onMediaPointerActiveChanged?.call(false),
        child: InkWell(
          onTap: showImage
              ? () => _openImageGallery(
                  imageUrls: imageUrls,
                  initialIndex: currentIndex,
                  urlId: url.id,
                )
              : () => _launchUrl(url.rawUrl),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showImage)
                  PageView.builder(
                    controller: _mediaPageController,
                    physics: imageUrls.length > 1
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    itemCount: imageUrls.length,
                    onPageChanged: (index) {
                      setState(() => _mediaPageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final imageUrl = imageUrls[index];
                      return Hero(
                        tag: 'detail-image-${url.id}-slide-$index',
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          httpHeaders: SavedMediaResolver.imageHttpHeaders(
                            imageUrl,
                          ),
                          errorWidget: (_, _, _) => _buildMediaPlaceholder(
                            url: url,
                            displaySourceName: displaySourceName,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        ),
                      );
                    },
                  )
                else
                  _buildMediaPlaceholder(
                    url: url,
                    displaySourceName: displaySourceName,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.26),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (showImage && imageUrls.length > 1)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            '${currentIndex + 1}/${imageUrls.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (categoryLabels.isNotEmpty)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    right: 10,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          child: Text(
                            categoryLabels.take(3).join('  /  '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                              letterSpacing: 0,
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
    );
  }

  List<String> _detailMediaImages(
    SavedUrl url,
    TranscriptEnrichmentResult? live,
  ) {
    final seen = <String>{};
    final out = <String>[];
    void add(String? value) {
      final imageUrl = value?.trim() ?? '';
      if (imageUrl.isEmpty || !imageUrl.startsWith(RegExp(r'https?://'))) {
        return;
      }
      if (seen.add(imageUrl)) out.add(imageUrl);
    }

    for (final imageUrl in SavedMediaResolver.imageCandidates(url)) {
      add(imageUrl);
    }
    for (final imageUrl in live?.imageUrls ?? const <String>[]) {
      add(imageUrl);
    }
    return out.take(12).toList();
  }

  Widget _buildMediaPlaceholder({
    required SavedUrl url,
    required String displaySourceName,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final favicon = _faviconUrlForSource(url, displaySourceName);
    final accent = _sourceAccentColor(url, displaySourceName, colorScheme);
    final base = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      colorScheme.surfaceContainerHigh,
    );
    final glow = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      colorScheme.surfaceContainerHighest,
    );
    final label = displaySourceName.trim().isNotEmpty
        ? displaySourceName.trim()
        : url.domain.trim();
    final initial = _placeholderInitial(label);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [glow, base],
        ),
      ),
      child: Center(
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.58),
            ),
          ),
          alignment: Alignment.center,
          child: favicon != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: favicon,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Text(
                      initial,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              : Text(
                  initial,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }

  String _placeholderInitial(String value) {
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[A-Za-z0-9]').hasMatch(char)) {
        return char.toUpperCase();
      }
    }
    return 'G';
  }

  List<String> _displayCategories(SavedUrl url) {
    return CategoryTaxonomy.sourceHierarchyLabels(
      categories: url.effectiveCategories,
      primaryCategory: url.category,
      tags: url.tags,
      text: '${url.title} ${url.summary ?? ''} ${url.description}',
    );
  }

  Widget _buildSummarySection({
    required String summary,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Summary', accent: _recipeAccent(colorScheme)),
        const SizedBox(height: 8),
        Text(
          summary,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesComposer({
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final glimpseNotes = _parseGlimpseNoteBlocks(_notesController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (glimpseNotes.isNotEmpty) ...[
          ...glimpseNotes.map(
            (note) => _GlimpseSavedNoteCard(
              note: note,
              theme: theme,
              colorScheme: colorScheme,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          constraints: const BoxConstraints(maxHeight: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _notesController,
            focusNode: _notesFocusNode,
            minLines: 2,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            cursorColor: _recipeAccent(colorScheme),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: colorScheme.onSurface,
            ),
            // Soft rounded surface provides the shape; keep the field itself
            // borderless so the themed outline pill doesn't reappear.
            decoration: InputDecoration(
              hintText: 'What stood out to you?',
              hintStyle: TextStyle(color: colorScheme.outline),
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onChanged: (_) => _scheduleNotesAutosave(),
          ),
        ),
      ],
    );
  }

  /// Quick-add chips that live *inside* the Your Notes section (under the
  /// composer) rather than as a separate "Suggested Actions" block — a light
  /// inline label keeps them feeling like part of note-taking.
  Widget _buildNoteQuickAdd({
    required SavedUrl url,
    required List<String> suggestions,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final activeAction = _effectiveIntentAction(url);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_rounded,
                size: 15,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                'Quick add',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((suggestion) {
              final classified = IntentClassifier.classify(suggestion);
              final isIntent = classified.kind != IntentKind.note;
              final selected = isIntent && activeAction == classified.action;
              return _NoteSuggestionChip(
                label: suggestion,
                icon: _quickAddIconFor(suggestion),
                selected: selected,
                intent: isIntent,
                onTap: () => _handleSuggestionTap(suggestion, url),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMetadata({
    required _DetailMetadata metadata,
    required String displaySourceName,
    required ColorScheme colorScheme,
  }) {
    final metrics = <Widget>[
      if (metadata.likesLabel != null)
        MetadataPill(
          value: metadata.likesLabel!,
          icon: Icons.favorite_border_rounded,
        ),
      if (metadata.commentsLabel != null)
        MetadataPill(
          value: metadata.commentsLabel!,
          icon: Icons.chat_bubble_outline_rounded,
        ),
    ];
    final creator = metadata.creatorUsername;
    if (creator == null && metrics.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          metrics[index],
        ],
        if (creator != null && metrics.isNotEmpty) const SizedBox(width: 8),
        if (creator != null)
          Flexible(
            fit: FlexFit.loose,
            child: CreatorProfileLink(
              username: creator,
              platform: displaySourceName,
              accent: colorScheme.onSurfaceVariant,
              compact: true,
            ),
          ),
      ],
    );
  }

  Widget _buildSourceSavedRow({
    required SavedUrl url,
    required String displaySourceName,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final savedLabel = _showExactSavedDate
        ? _formatExactSavedDate(url.savedAt)
        : _formatDate(url.savedAt);
    return Row(
      children: [
        _buildSourceLeadingIcon(url, displaySourceName, colorScheme),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            displaySourceName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _recipeAccent(colorScheme),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '•',
            style: TextStyle(color: colorScheme.outline, fontSize: 12),
          ),
        ),
        Flexible(
          flex: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() => _showExactSavedDate = !_showExactSavedDate);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                savedLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ReadStatePill(isRead: url.openedAt != null),
      ],
    );
  }

  List<Widget> _buildEnrichmentSections({
    required SavedUrl url,
    required TranscriptEnrichmentResult? live,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    if (live == null) return const [];
    final sections = <Widget>[];
    final recipe = live.recipe;
    if (recipe?.hasUsefulContent ?? false) {
      _ensureRecipeStateLoaded(url.id);
      // Use live.steps as fallback instructions when recipe has no steps.
      // The transcript backend sometimes puts cooking steps in live.steps
      // rather than inside the recipe object.
      final fallbackSteps = recipe!.steps.isEmpty && live.steps.isNotEmpty
          ? live.steps.map((s) => s.title).where((t) => t.isNotEmpty).toList()
          : const <String>[];
      sections.addAll([
        const SizedBox(height: 18),
        _buildRecipeSection(
          url: url,
          recipe: recipe,
          fallbackSteps: fallbackSteps,
          theme: theme,
          colorScheme: colorScheme,
        ),
      ]);
    }

    // Only show key takeaways when there's no recipe (recipe handles its own steps).
    final showContentSteps = _shouldShowKeyTakeaways(url, live);
    if (showContentSteps) {
      sections.addAll([
        const SizedBox(height: 18),
        _buildContentStepsSection(
          steps: live.steps.take(5).toList(),
          theme: theme,
          colorScheme: colorScheme,
        ),
      ]);
    }

    final structuredMentionTypes = live.mentions
        .map((mention) => _mentionSectionKey(mention.type))
        .where((type) => type != 'person' && type != 'other')
        .toSet();
    final showContentSections =
        live.contentSections.isNotEmpty &&
        recipe?.hasUsefulContent != true &&
        structuredMentionTypes.isEmpty;
    if (showContentSections) {
      sections.addAll([
        const SizedBox(height: 18),
        _buildFullBreakdownSection(
          sections: live.contentSections,
          theme: theme,
          colorScheme: colorScheme,
        ),
      ]);
    }

    if (live.notableItems.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 18),
        _buildNotableItemsSection(
          items: live.notableItems,
          theme: theme,
          colorScheme: colorScheme,
        ),
      ]);
    }

    final grouped = <String, List<EnrichedMention>>{};
    for (final mention in live.mentions) {
      final key = _mentionSectionKey(mention.type);
      grouped.putIfAbsent(key, () => []).add(mention);
    }

    for (final key in _mentionSectionOrder) {
      final items = grouped[key] ?? const <EnrichedMention>[];
      if (items.isEmpty) continue;
      sections.addAll([
        const SizedBox(height: 18),
        ContentRecommendationSection<EnrichedMention>(
          title: _mentionSectionTitle(key),
          subtitle: key == 'person'
              ? '${items.length} ${items.length == 1 ? 'person' : 'people'} mentioned'
              : null,
          accent: _sectionAccent(key, colorScheme),
          items: items,
          itemBuilder: (context, mention) => _buildMentionRow(
            mention: mention,
            theme: theme,
            colorScheme: colorScheme,
          ),
        ),
      ]);
    }

    if (_hasSourceMaterial(live)) {
      sections.addAll([
        const SizedBox(height: 18),
        _buildSourceMaterialSection(
          live: live,
          theme: theme,
          colorScheme: colorScheme,
        ),
      ]);
    }

    return sections;
  }

  TranscriptEnrichmentResult? _savedEnrichment(SavedUrl url) {
    final raw = url.enrichmentJson;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final result = TranscriptEnrichmentResult.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return result?.hasUsefulContent == true ? result : null;
    } catch (_) {
      return null;
    }
  }

  static const _mentionSectionOrder = [
    'movie',
    'book',
    'product',
    'app',
    'person',
    'place',
    'other',
  ];

  String _mentionSectionKey(String type) {
    final lower = type.toLowerCase().trim();
    if (_mentionSectionOrder.contains(lower)) return lower;
    if (lower == 'show' || lower == 'anime' || lower == 'documentary') {
      return 'movie';
    }
    return 'other';
  }

  String _mentionSectionTitle(String type) {
    return switch (type) {
      'movie' => 'Worth watching',
      'book' => 'Worth reading',
      'product' => 'Worth a look',
      'app' => 'Apps to try',
      'person' => 'People mentioned',
      'place' => 'Places to visit',
      _ => 'Also mentioned',
    };
  }

  bool _shouldShowKeyTakeaways(SavedUrl url, TranscriptEnrichmentResult live) {
    if (live.steps.isEmpty) return false;
    // Suppress key takeaways when recipe exists AND has its own steps
    // (live.steps are used as fallback inside the recipe block instead).
    final recipe = live.recipe;
    if (recipe?.hasUsefulContent == true && recipe!.steps.isNotEmpty) {
      return false;
    }
    // If recipe exists but has no steps, live.steps are shown as fallback
    // inside the recipe block — don't double-render them here.
    if (recipe?.hasUsefulContent == true) {
      return false;
    }

    final mentionTypes = live.mentions
        .map((mention) => _mentionSectionKey(mention.type))
        .where((type) => type != 'person' && type != 'other')
        .toSet();
    // When the save has real extracted entities (places/movies/books/products),
    // those entity cards carry the content — a separate formal "Key Takeaways"
    // list on top reads like a museum placard and duplicates them. Reserve
    // takeaways for genuine how-to/insight content with no entities.
    if (mentionTypes.isNotEmpty) return false;
    final text = [
      url.title,
      url.category,
      url.summary ?? '',
      url.description,
      ...url.tags,
      live.meaningfulTitle,
      live.category,
      live.summary,
      ...live.tags,
    ].join(' ').toLowerCase();

    final learningContent = _hasAny(text, const [
      'tutorial',
      'how to',
      'how-to',
      'guide',
      'explainer',
      'lesson',
      'learn',
      'framework',
      'principle',
      'strategy',
      'educational',
      'workflow',
      'steps',
    ]);

    if (learningContent) return true;
    return live.steps.length >= 3;
  }

  Color _sectionAccent(String type, ColorScheme colorScheme) {
    return _recipeAccent(colorScheme);
  }

  Widget _buildContentStepsSection({
    required List<EnrichedContentStep> steps,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Key Takeaways',
          accent: _recipeAccent(colorScheme),
        ),
        const SizedBox(height: 10),
        for (final step in steps)
          _buildContentStep(step: step, theme: theme, colorScheme: colorScheme),
      ],
    );
  }

  Widget _buildContentStep({
    required EnrichedContentStep step,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final description = step.description?.trim() ?? '';
    final text = description.isEmpty
        ? step.title
        : '${step.title}: $description';
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: _recipeAccent(colorScheme),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBreakdownSection({
    required List<EnrichedContentSection> sections,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return DetailExpansionSection(
      title: 'Full breakdown',
      accent: _recipeAccent(colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < sections.length; index++) ...[
            if (index > 0) const SizedBox(height: 22),
            Text(
              sections[index].title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            for (final point in sections[index].points)
              _buildBreakdownPoint(
                point: point,
                theme: theme,
                colorScheme: colorScheme,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownPoint({
    required String point,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: _recipeAccent(colorScheme),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              point,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasSourceMaterial(TranscriptEnrichmentResult live) {
    return live.schemaVersion >= 2 &&
        ((live.caption?.trim().isNotEmpty ?? false) ||
            (live.transcript?.trim().isNotEmpty ?? false) ||
            (live.ocrText?.trim().isNotEmpty ?? false));
  }

  Widget _buildSourceMaterialSection({
    required TranscriptEnrichmentResult live,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final sourceBlocks = <(String, String)>[
      if (live.caption?.trim().isNotEmpty == true)
        ('Caption', live.caption!.trim()),
      if (live.transcript?.trim().isNotEmpty == true)
        ('Transcript', live.transcript!.trim()),
      if (live.ocrText?.trim().isNotEmpty == true)
        ('On-screen text', live.ocrText!.trim()),
    ];
    return DetailExpansionSection(
      title: 'Transcript & Caption',
      accent: _recipeAccent(colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < sourceBlocks.length; index++) ...[
            if (index > 0) const SizedBox(height: 16),
            Text(
              sourceBlocks[index].$1,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            SelectionArea(
              child: _buildSourceText(
                label: sourceBlocks[index].$1,
                text: sourceBlocks[index].$2,
                theme: theme,
                colorScheme: colorScheme,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _quickAddIconFor(String suggestion) {
    return switch (suggestion) {
      'Try This Weekend' => Icons.event_available_outlined,
      'Need Ingredients' => Icons.shopping_basket_outlined,
      'Share With Someone' => Icons.ios_share_rounded,
      'Already Tried' => Icons.task_alt_rounded,
      'Watch Later' ||
      'Read Later' ||
      'Revisit Later' => Icons.schedule_rounded,
      'Add to Watchlist' => Icons.playlist_add_rounded,
      'Already Watched' ||
      'Already Read' ||
      'Already Checked' => Icons.check_circle_outline_rounded,
      'Add to Reading List' => Icons.menu_book_outlined,
      'Research This' => Icons.manage_search_rounded,
      'Try This Tool' || 'Worth Trying' => Icons.explore_outlined,
      'Compare Alternatives' => Icons.compare_arrows_rounded,
      'Use in Project' => Icons.handyman_outlined,
      'Share With Team' => Icons.group_outlined,
      'Plan Itinerary' => Icons.map_outlined,
      'Check Best Season' => Icons.calendar_month_outlined,
      'Save Route' => Icons.route_outlined,
      'Practice Later' => Icons.school_outlined,
      'Make Checklist' => Icons.checklist_rounded,
      'Revisit Notes' => Icons.note_alt_outlined,
      _ => Icons.add_circle_outline_rounded,
    };
  }

  Widget _buildSourceText({
    required String label,
    required String text,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.5,
    );
    if (label != 'Transcript') return Text(text, style: style);

    final paragraphs = splitTranscriptParagraphs(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < paragraphs.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          Text(paragraphs[index], style: style),
        ],
      ],
    );
  }

  Widget _buildNotableItemsSection({
    required List<EnrichedNotableItem> items,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final displayItems = items.take(8).toList();
    final title = _notableItemsSectionTitle(displayItems);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, accent: _recipeAccent(colorScheme)),
        if (displayItems.every(
          (item) => item.type.toLowerCase() == 'claim',
        )) ...[
          const SizedBox(height: 3),
          Text(
            '${displayItems.length} ${displayItems.length == 1 ? 'claim' : 'claims'} extracted',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 10),
        for (final item in displayItems)
          _buildNotableItemRow(
            item: item,
            theme: theme,
            colorScheme: colorScheme,
          ),
      ],
    );
  }

  String _notableItemsSectionTitle(List<EnrichedNotableItem> items) {
    if (items.isEmpty) return 'Notable details';
    final types = items.map((item) => item.type.toLowerCase()).toSet();
    if (types.length == 1) {
      final type = types.first;
      if (type == 'quote') return 'Quotes';
      if (type == 'website') return 'Websites mentioned';
      if (type == 'tool' || type == 'app' || type == 'product') {
        return 'Tools mentioned';
      }
      if (type == 'claim') return 'Claims to remember';
      if (type == 'term') return 'Terms mentioned';
    }
    return 'Notable details';
  }

  Widget _buildNotableItemRow({
    required EnrichedNotableItem item,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final itemType = item.type.toLowerCase();
    final isQuote = itemType == 'quote';
    final isClaim = itemType == 'claim';
    final leadingIcon = itemType == 'term'
        ? AppIcons.termMentioned
        : isQuote
        ? Icons.format_quote_rounded
        : isClaim
        ? Icons.lightbulb_outline_rounded
        : Icons.bookmark_border_rounded;
    final attribution = item.attribution?.trim() ?? '';
    final label = item.label?.trim() ?? '';
    final why = item.whyImportant?.trim() ?? '';
    final meta = [
      if (!isQuote && label.isNotEmpty && label != item.text) label,
      if (attribution.isNotEmpty) attribution,
      if (why.isNotEmpty) why,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      leadingIcon,
                      size: isQuote || itemType == 'term' ? 18 : 16,
                      color: _recipeAccent(colorScheme),
                    ),
                  ),
                ),
                TextSpan(text: item.text),
              ],
            ),
            style:
                (isClaim
                        ? theme.textTheme.bodyLarge
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                      height: 1.42,
                    ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              meta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecipeSection({
    required SavedUrl url,
    required EnrichedRecipe recipe,
    required ThemeData theme,
    required ColorScheme colorScheme,
    List<String> fallbackSteps = const [],
  }) {
    final hook = _recipeHookText(recipe);
    final nutrition = recipe.nutrition;
    final recipeAccent = _recipeAccent(colorScheme);
    // Use recipe steps if available, otherwise fall back to transcript steps.
    final displaySteps = recipe.steps.isNotEmpty ? recipe.steps : fallbackSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header: "Recipe" label + shopping list shortcut ──────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Recipe',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _showShoppingList,
              icon: Icon(
                _shoppingList.isEmpty
                    ? Icons.shopping_cart_outlined
                    : Icons.shopping_cart_rounded,
                size: 17,
              ),
              label: Text(
                _shoppingList.isEmpty
                    ? 'Shopping List'
                    : 'Shopping List (${_shoppingList.length})',
              ),
              style: TextButton.styleFrom(
                foregroundColor: recipeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),

        // ── Description hook ─────────────────────────────────────────────
        if (hook.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildRecipeIntro(text: hook, theme: theme, colorScheme: colorScheme),
        ],

        // ── Quick Facts block ────────────────────────────────────────────
        ..._buildQuickFacts(
          recipe: recipe,
          theme: theme,
          colorScheme: colorScheme,
        ),

        // ── Nutrition ────────────────────────────────────────────────────
        if (nutrition?.hasAnyValue == true) ...[
          const SizedBox(height: 20),
          _buildNutritionSection(
            nutrition: nutrition!,
            theme: theme,
            colorScheme: colorScheme,
          ),
        ],

        // ── Instructions first ───────────────────────────────────────────
        if (displaySteps.isNotEmpty) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Instructions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => _RecipeCookingModeScreen(
                      recipe: recipe.steps.isNotEmpty
                          ? recipe
                          : recipe.copyWith(steps: displaySteps),
                    ),
                  ),
                ),
                icon: const Icon(Icons.soup_kitchen_outlined, size: 17),
                label: const Text('Cook Mode'),
                style: FilledButton.styleFrom(
                  backgroundColor: _recipeAccentSurface(colorScheme),
                  foregroundColor: recipeAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...displaySteps.asMap().entries.map(
            (entry) => _buildRecipeInstruction(
              number: entry.key + 1,
              instruction: entry.value,
              theme: theme,
              colorScheme: colorScheme,
            ),
          ),
        ],

        // ── Ingredients (below instructions) ─────────────────────────────
        if (recipe.ingredients.isNotEmpty) ...[
          const SizedBox(height: 22),
          _buildIngredientsSection(
            url: url,
            recipe: recipe,
            theme: theme,
            colorScheme: colorScheme,
          ),
        ],

        // ── Extraction provenance ─────────────────────────────────────────
        if (recipe.extractionSources.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildExtractionSources(
            sources: recipe.extractionSources,
            theme: theme,
            colorScheme: colorScheme,
          ),
        ],
      ],
    );
  }

  String _recipeHookText(EnrichedRecipe recipe) {
    final summary = recipe.summary?.trim().isNotEmpty == true
        ? recipe.summary!.trim()
        : recipe.description?.trim() ?? '';
    if (summary.isNotEmpty) return _trimRecipeHook(summary);

    final title = recipe.title.trim().isNotEmpty
        ? _cleanRecipeTitle(recipe.title.trim())
        : 'This recipe';
    final time = recipe.totalTime?.trim().isNotEmpty == true
        ? recipe.totalTime!.trim()
        : recipe.cookTime?.trim().isNotEmpty == true
        ? recipe.cookTime!.trim()
        : recipe.prepTime?.trim();
    final titleLower = title.toLowerCase();
    final cuisine = (recipe.cuisine ?? '').trim();
    final category = (recipe.category ?? '').trim();
    final descriptor =
        titleLower.contains('mexican') &&
            cuisine.toLowerCase().contains('indian')
        ? 'Indian-Mexican fusion'
        : cuisine.isNotEmpty
        ? cuisine
        : recipe.tags
              .map((item) => item.trim())
              .firstWhere(
                (item) => item.isNotEmpty && item.toLowerCase() != 'recipe',
                orElse: () => '',
              );
    final dishKind = titleLower.contains('wrap')
        ? 'wrap'
        : category.isNotEmpty
        ? category.toLowerCase()
        : 'recipe';
    final ingredients = recipe.ingredients
        .map((item) => _ingredientPhrase(item.name))
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(4)
        .toList();
    final ingredientText = _naturalList(ingredients);
    if (ingredientText.isNotEmpty) {
      final lead = [
        'A quick',
        if (descriptor.isNotEmpty) descriptor,
        dishKind,
      ].join(' ');
      final timeTail = time == null || time.isEmpty ? '' : ', ready in $time';
      final sentence = dishKind == 'wrap'
          ? '$lead filled with $ingredientText, then tucked into a warm wrap$timeTail.'
          : '$lead made with $ingredientText$timeTail.';
      return _trimRecipeHook(
        '$sentence Lightly seasoned, hearty, and easy to put together without feeling heavy.',
      );
    }
    if (recipe.steps.isNotEmpty) {
      return _trimRecipeHook(
        '$title is broken into ${recipe.steps.length} clear cooking steps for an easy start-to-finish prep.',
      );
    }
    return title;
  }

  String _cleanRecipeTitle(String title) {
    return title
        .replaceAll(
          RegExp(
            r'\s*[•\-–]\s*\d+[-\s]*(?:minute|min)\s*recipe.*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+recipe$', caseSensitive: false), '')
        .trim();
  }

  String _ingredientPhrase(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^britannia\s+', caseSensitive: false), '')
        .replaceFirst(
          RegExp(r'\bthe laughing cow\b', caseSensitive: false),
          'cheese',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Widget _buildRecipeIntro({
    required String text,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurface,
        height: 1.55,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _naturalList(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items.first} and ${items.last}';
    return '${items.take(items.length - 1).join(', ')}, and ${items.last}';
  }

  String _trimRecipeHook(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 230) return cleaned;
    final clipped = cleaned.substring(0, 230);
    final lastBreak = clipped.lastIndexOf(RegExp(r'[,.;]'));
    if (lastBreak > 120) return '${clipped.substring(0, lastBreak).trim()}.';
    return '${clipped.trim()}...';
  }

  Color _recipeAccent(ColorScheme colorScheme) {
    return Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.42),
      colorScheme.onSurfaceVariant,
    );
  }

  Color _recipeAccentSurface(ColorScheme colorScheme) {
    return Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.055),
      colorScheme.surfaceContainerHighest,
    );
  }

  List<Widget> _buildQuickFacts({
    required EnrichedRecipe recipe,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final facts = <_QuickFact>[];

    // Time — prefer total, then cook, then prep
    final timeLabel = recipe.totalTime?.trim().isNotEmpty == true
        ? recipe.totalTime!
        : (recipe.cookTime?.trim().isNotEmpty == true
              ? recipe.cookTime!
              : recipe.prepTime?.trim());
    if (timeLabel != null && timeLabel.isNotEmpty) {
      facts.add(_QuickFact(label: timeLabel));
    }

    // Category
    if ((recipe.category ?? '').trim().isNotEmpty) {
      facts.add(_QuickFact(label: recipe.category!.trim()));
    }

    // Cuisine
    if ((recipe.cuisine ?? '').trim().isNotEmpty) {
      facts.add(_QuickFact(label: recipe.cuisine!.trim()));
    }

    // Servings
    if ((recipe.servings ?? '').trim().isNotEmpty) {
      facts.add(_QuickFact(label: recipe.servings!.trim()));
    }

    // Difficulty
    if ((recipe.difficulty ?? '').trim().isNotEmpty) {
      facts.add(_QuickFact(label: recipe.difficulty!.trim()));
    }

    if (facts.isEmpty) return const [];

    return [
      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: facts
            .map(
              (fact) => _QuickFactChip(
                fact: fact,
                theme: theme,
                colorScheme: colorScheme,
              ),
            )
            .toList(),
      ),
    ];
  }

  Widget _buildNutritionSection({
    required RecipeNutrition nutrition,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final recipeAccent = _recipeAccent(colorScheme);
    final metrics = <_NutritionMetric>[];
    if (nutrition.proteinG != null) {
      metrics.add(
        _NutritionMetric(
          label: 'Protein',
          value: nutrition.proteinG!,
          unit: 'g',
          target: 50,
          color: recipeAccent,
        ),
      );
    }
    if (nutrition.carbsG != null) {
      metrics.add(
        _NutritionMetric(
          label: 'Carbs',
          value: nutrition.carbsG!,
          unit: 'g',
          target: 275,
          color: recipeAccent.withValues(alpha: 0.74),
        ),
      );
    }
    if (nutrition.fatG != null) {
      metrics.add(
        _NutritionMetric(
          label: 'Fat',
          value: nutrition.fatG!,
          unit: 'g',
          target: 78,
          color: recipeAccent.withValues(alpha: 0.62),
        ),
      );
    }
    final fiber = nutrition.fiberG == null
        ? null
        : _NutritionMetric(
            label: 'Fiber',
            value: nutrition.fiberG!,
            unit: 'g',
            target: 28,
            color: recipeAccent.withValues(alpha: 0.72),
          );
    if (nutrition.calories == null && metrics.isEmpty && fiber == null) {
      return const SizedBox.shrink();
    }

    final cardColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.012),
      colorScheme.surfaceContainerLow,
    );
    final bandColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.025),
      colorScheme.surfaceContainerHighest,
    );
    final calories = nutrition.calories?.round();
    final energyPercent = calories == null
        ? null
        : (calories / 2000 * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrition',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Per serving',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (nutrition.isEstimated)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.68,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nutrition.source == RecipeNutritionSource.calculated
                            ? 'Calculated'
                            : 'Estimated',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (nutrition.servings != null ||
              nutrition.source == RecipeNutritionSource.calculated) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (nutrition.servings != null)
                  'Recipe makes ${nutrition.servings} servings',
                if (nutrition.source == RecipeNutritionSource.calculated)
                  'Calculated using ingredient nutrition data',
              ].join(' · '),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.25,
              ),
            ),
          ],
          if (calories != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              decoration: BoxDecoration(
                color: bandColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text: '$calories',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: '\n kcal',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (energyPercent != null)
                    Text(
                      '~$energyPercent% of\ndaily energy',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (final metric in metrics)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: metric == metrics.last ? 0 : 8,
                      ),
                      child: _NutritionMetricTile(
                        metric: metric,
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (fiber != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(
                    fiber.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NutritionBar(
                      value: fiber.progress,
                      color: fiber.color,
                      backgroundColor: colorScheme.outlineVariant.withValues(
                        alpha: 0.42,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_formatNutrientG(fiber.value)}${fiber.unit}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (nutrition.unmatchedIngredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Could not match: ${nutrition.unmatchedIngredients.take(3).join(', ')}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatNutrientG(double v) {
    return v == v.truncateToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(1);
  }

  Widget _buildIngredientsSection({
    required SavedUrl url,
    required EnrichedRecipe recipe,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final recipeAccent = _recipeAccent(colorScheme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Ingredients',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: '  (${recipe.ingredients.length})',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => _checkAllIngredients(url.id, recipe),
              style: TextButton.styleFrom(
                foregroundColor: recipeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('All'),
            ),
            TextButton(
              onPressed: () => _resetIngredientChecks(url.id),
              style: TextButton.styleFrom(
                foregroundColor: recipeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...recipe.ingredients.asMap().entries.map((entry) {
          final key = RecipeStateService.ingredientKey(entry.value, entry.key);
          final checked = _checkedIngredientKeys.contains(key);
          return _IngredientRow(
            ingredient: entry.value,
            isChecked: checked,
            onToggle: (v) => _setIngredientChecked(url.id, key, v ?? false),
            theme: theme,
            colorScheme: colorScheme,
          );
        }),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _addRecipeIngredientsToShoppingList(
                  recipeId: url.id,
                  recipe: recipe,
                  selectedOnly: true,
                ),
                icon: const Icon(Icons.playlist_add_rounded, size: 18),
                label: const Text('Add Selected'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: recipeAccent,
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.72),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _addRecipeIngredientsToShoppingList(
                  recipeId: url.id,
                  recipe: recipe,
                  selectedOnly: false,
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: const Text('Add All'),
                style: FilledButton.styleFrom(
                  backgroundColor: _recipeAccentSurface(colorScheme),
                  foregroundColor: recipeAccent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExtractionSources({
    required List<String> sources,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final labels = <String, String>{
      'transcript': 'Video transcript',
      'on_screen_text': 'On-screen text',
      'caption': 'Creator caption',
      'description': 'Page description',
      'metadata': 'Structured metadata',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Extracted from',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: sources.map((src) {
              final label = labels[src.toLowerCase()] ?? src;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: _recipeAccent(colorScheme),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeInstruction({
    required int number,
    required String instruction,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final recipeAccent = _recipeAccent(colorScheme);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _recipeAccentSurface(colorScheme),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelSmall?.copyWith(
                color: recipeAccent,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                instruction,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.55,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_GlimpseSavedNote> _parseGlimpseNoteBlocks(String raw) {
    final blocks = <_GlimpseSavedNote>[];
    final matches = RegExp(
      r'(?:^|\n)## Ask Glimpse\n([\s\S]*?)(?=\n## Ask Glimpse\n|$)',
    ).allMatches(raw);
    for (final match in matches) {
      final block = match.group(1)?.trim() ?? '';
      if (block.isEmpty) continue;
      final lines = block.split('\n').map((line) => line.trimRight()).toList();
      String? asked;
      String? question;
      final body = <String>[];
      for (final line in lines) {
        if (line.startsWith('Asked:')) {
          asked = line.substring('Asked:'.length).trim();
        } else if (line.startsWith('Question:')) {
          question = line.substring('Question:'.length).trim();
        } else {
          body.add(line);
        }
      }
      final answer = body.join('\n').trim();
      if ((question ?? '').isEmpty && answer.isEmpty) continue;
      blocks.add(
        _GlimpseSavedNote(asked: asked, question: question, answer: answer),
      );
    }
    return blocks.reversed.take(3).toList();
  }

  Widget _buildMentionRow({
    required EnrichedMention mention,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final reason = _trimRelevanceDescription(
      _cleanMentionReason(mention.whyMentioned),
    );
    final posterUrl = mention.posterUrl?.trim() ?? '';
    final metadata = _mentionMetadataLine(mention);
    // Places have no poster art, so the tall poster slot looks empty/wrong for
    // them — show a compact location pin tile instead (matches a travel guide).
    final isPlace = mention.type.toLowerCase() == 'place';
    final isPerson = mention.type.toLowerCase() == 'person';
    final accent = _recipeAccent(colorScheme);

    return Material(
      color: isPerson ? colorScheme.surfaceContainerLow : Colors.transparent,
      borderRadius: BorderRadius.circular(isPerson ? 14 : 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(isPerson ? 14 : 12),
        onTap: () => _launchMentionSearch(mention),
        child: Padding(
          padding: isPerson
              ? const EdgeInsets.all(12)
              : const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPerson)
                _buildPersonAvatar(
                  mention: mention,
                  posterUrl: posterUrl,
                  colorScheme: colorScheme,
                )
              else if (isPlace)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    size: 22,
                    color: accent,
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 54,
                    height: 72,
                    child: posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                _mentionPlaceholder(mention, colorScheme),
                          )
                        : _mentionPlaceholder(mention, colorScheme),
                  ),
                ),
              SizedBox(width: isPerson ? 14 : 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mention.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (isPerson
                                    ? theme.textTheme.titleMedium
                                    : theme.textTheme.bodyLarge)
                                ?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: isPerson
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  height: isPerson ? 1.3 : 1.25,
                                ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          metadata,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _recipeAccent(colorScheme),
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                      if (reason.isNotEmpty) ...[
                        SizedBox(height: isPerson ? 6 : 5),
                        Text(
                          _sentenceCase(reason),
                          style:
                              (isPerson
                                      ? theme.textTheme.bodyMedium
                                      : theme.textTheme.bodySmall)
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: isPerson ? 1.45 : 1.42,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonAvatar({
    required EnrichedMention mention,
    required String posterUrl,
    required ColorScheme colorScheme,
  }) {
    const size = 52.0;
    if (posterUrl.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: CachedNetworkImage(
            imageUrl: posterUrl,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => _personMonogram(mention, colorScheme),
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: _personMonogram(mention, colorScheme),
    );
  }

  Widget _personMonogram(EnrichedMention mention, ColorScheme colorScheme) {
    final initial = mention.title.trim().isEmpty
        ? 'P'
        : mention.title.trim().substring(0, 1).toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: colorScheme.onSecondaryContainer,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _mentionMetadataLine(EnrichedMention mention) {
    final type = mention.type.toLowerCase();
    final year = mention.year?.trim() ?? '';
    if (type == 'movie' && year.isNotEmpty) return year;
    return '';
  }

  String _cleanMentionReason(String? raw) {
    final reason = raw?.trim() ?? '';
    if (reason.isEmpty) return '';
    final lower = reason.toLowerCase();
    const lowValueReasons = {
      'recommended by creator',
      'recommended by the creator',
      'mentioned by creator',
      'mentioned by the creator',
    };
    if (lowValueReasons.contains(lower)) return '';
    return reason;
  }

  Future<void> _launchMentionSearch(EnrichedMention mention) async {
    final suffix = switch (mention.type) {
      'movie' => 'movie',
      'book' => 'book',
      'place' => 'place',
      'product' => 'product',
      _ => '',
    };
    final query = [
      mention.title,
      suffix,
    ].where((item) => item.isNotEmpty).join(' ');
    final uri = Uri.https('www.google.com', '/search', {'q': query});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _trimRelevanceDescription(String text) {
    return TextCleaner.cleanLoose(text);
  }

  Widget _mentionPlaceholder(EnrichedMention mention, ColorScheme colorScheme) {
    final initial = mention.title.trim().isEmpty
        ? 'M'
        : mention.title.trim().substring(0, 1).toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ),
    );
  }

  String _sentenceCase(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.substring(0, 1).toUpperCase() + trimmed.substring(1);
  }

  _DetailMetadata _extractDetailMetadata({
    required String description,
    required String? creator,
    required int? likeCount,
    required int? commentCount,
    required String rawUrl,
  }) {
    final text = TextCleaner.cleanLoose(description);
    String? matchFirst(String pattern) {
      return RegExp(pattern, caseSensitive: false).firstMatch(text)?.group(1);
    }

    final likes = matchFirst(r'\b([\d,.]+[KMBkmb]?)\s+likes?\b');
    final comments = matchFirst(r'\b([\d,.]+[KMBkmb]?)\s+comments?\b');
    final fromDescription = matchFirst(r'-\s*@?([A-Za-z0-9._]+)\s+on\s+');
    final parsedUsername = _supportsProfileUsername(rawUrl)
        ? _cleanUsername(creator) ??
              _cleanUsername(fromDescription) ??
              _usernameFromUrl(rawUrl)
        : null;

    return _DetailMetadata(
      likesLabel: likeCount != null
          ? _compactCountLabel(likeCount.toString())
          : likes == null
          ? null
          : _compactCountLabel(likes),
      commentsLabel: commentCount != null
          ? _compactCountLabel(commentCount.toString())
          : comments == null
          ? null
          : _compactCountLabel(comments),
      creatorUsername: parsedUsername,
    );
  }

  String? _cleanUsername(String? value) {
    if (value == null) return null;
    final cleaned = value.replaceFirst('@', '').trim();
    if (!RegExp(r'^[A-Za-z0-9._]{2,}$').hasMatch(cleaned)) return null;
    return cleaned;
  }

  String? _usernameFromUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return null;
    if (!_supportsProfileUsername(rawUrl)) return null;
    final segments = uri.pathSegments.where((item) => item.isNotEmpty).toList();
    if (segments.length >= 2 &&
        !{'reel', 'reels', 'p', 'tv'}.contains(segments.first.toLowerCase())) {
      return _cleanUsername(segments.first);
    }
    return null;
  }

  bool _supportsProfileUsername(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;
    var host = uri.host.toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);
    return host == 'instagram.com' ||
        host.endsWith('.instagram.com') ||
        host == 'x.com' ||
        host.endsWith('.x.com') ||
        host == 'twitter.com' ||
        host.endsWith('.twitter.com') ||
        host == 'tiktok.com' ||
        host.endsWith('.tiktok.com') ||
        host == 'threads.net' ||
        host.endsWith('.threads.net');
  }

  String _compactCountLabel(String raw) {
    final clean = raw.replaceAll(',', '').trim();
    if (RegExp(r'[KMBkmb]$').hasMatch(clean)) {
      return clean.toUpperCase();
    }
    final value = double.tryParse(clean);
    if (value == null) return raw.trim();
    if (value >= 1000000) return '${_trimDecimal(value / 1000000)}M';
    if (value >= 1000) return '${_trimDecimal(value / 1000)}K';
    return value.round().toString();
  }

  String _trimDecimal(double value) {
    return value >= 10
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  }

  List<String> _buildNoteSuggestions({
    required SavedUrl url,
    required TranscriptEnrichmentResult? live,
    required List<String> tags,
    required String caption,
    required String summary,
  }) {
    final mentionTypes = (live?.mentions ?? const <EnrichedMention>[])
        .map((mention) => mention.type.toLowerCase())
        .toSet();
    final text = [
      url.title,
      url.category,
      url.description,
      url.summary ?? '',
      caption,
      summary,
      ...url.tags,
      ...tags,
      if (live != null) ...[
        live.meaningfulTitle,
        live.category,
        live.summary,
        ...live.tags,
        ...live.mentions.map((mention) => mention.title),
        if (live.recipe != null) live.recipe!.title,
      ],
    ].join(' ').toLowerCase();

    if (live?.recipe?.hasUsefulContent == true ||
        _hasAny(text, const [
          'recipe',
          'cook',
          'ingredient',
          'meal',
          'protein',
          'vegan',
          'paneer',
          'pasta',
          'ramen',
          'smoothie',
          'dessert',
          'food',
          'dairy',
        ])) {
      return const [
        'Try This Weekend',
        'Need Ingredients',
        'Share With Someone',
        'Already Tried',
      ];
    }

    if (mentionTypes.contains('movie') ||
        _hasAny(text, const [
          'movie',
          'film',
          'cinema',
          'watchlist',
          'sci-fi',
          'series',
          'anime',
        ])) {
      return const [
        'Watch Later',
        'Add to Watchlist',
        'Share With Someone',
        'Already Watched',
      ];
    }

    if (mentionTypes.contains('book') ||
        _hasAny(text, const [
          'book',
          'reading',
          'author',
          'novel',
          'essay',
          'newsletter',
        ])) {
      return const [
        'Add to Reading List',
        'Read Later',
        'Research This',
        'Already Read',
      ];
    }

    if (mentionTypes.contains('product') ||
        _hasAny(text, const [
          'tool',
          'app',
          'software',
          'github',
          'repo',
          'agent',
          'workflow',
          'design system',
          'product',
        ])) {
      return const [
        'Try This Tool',
        'Compare Alternatives',
        'Use in Project',
        'Share With Team',
      ];
    }

    if (mentionTypes.contains('place') ||
        _hasAny(text, const [
          'travel',
          'trek',
          'route',
          'hike',
          'trip',
          'itinerary',
          'hotel',
          'restaurant',
          'destination',
        ])) {
      return const [
        'Plan Itinerary',
        'Check Best Season',
        'Save Route',
        'Share With Someone',
      ];
    }

    if (_hasAny(text, const [
      'tutorial',
      'guide',
      'framework',
      'learn',
      'course',
      'productivity',
      'strategy',
    ])) {
      return const [
        'Practice Later',
        'Make Checklist',
        'Use in Project',
        'Revisit Notes',
      ];
    }

    return const [
      'Revisit Later',
      'Share With Someone',
      'Worth Trying',
      'Already Checked',
    ];
  }

  bool _hasAny(String text, List<String> needles) {
    return needles.any((needle) => text.contains(needle));
  }

  String _formatDescription(String description) {
    var text = TextCleaner.clean(
      description,
    ).replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

    if (text.isEmpty) return '';

    text = _stripScrapedMetadataPrefix(text);
    text = text.replaceFirst(RegExp(r'^@[A-Za-z0-9_]+:\s*'), '');
    text = text
        .replaceFirst(RegExp(r'^["“]+'), '')
        .replaceFirst(RegExp(r'["”]+\s*\.?$'), '')
        .trim();

    final lines = text.split('\n');
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    if (lines.isNotEmpty && _isRedundantMetadataLine(lines.last)) {
      lines.removeLast();
    }

    final normalizedLines = lines.map(_normalizeDescriptionLine).toList();
    text = normalizedLines.join('\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return text;
  }

  String _stripScrapedMetadataPrefix(String text) {
    return text
        .replaceFirst(
          RegExp(
            r'^[\d,.]+[KMBkmb]?\s+likes?,\s*[\d,.]+[KMBkmb]?\s+comments?\s*-\s*[A-Za-z0-9._]+\s+on\s+[^:"]+:\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(
          RegExp(
            r'^[\d,.]+[KMBkmb]?\s+likes?,\s*[\d,.]+[KMBkmb]?\s+comments?\s*-\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  String _stripHashtagsFromCaption(String text) {
    final lines = text
        .split('\n')
        .map((line) {
          final kept = line
              .split(RegExp(r'\s+'))
              .where((token) => token.trim().isNotEmpty)
              .where((token) => !token.trimLeft().startsWith('#'))
              .join(' ')
              .trim();
          return kept;
        })
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.join('\n').trim();
  }

  String _normalizeDescriptionLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return '';

    final numbered = RegExp(r'^(\d+)\s*\\\.?\s*(.+)$').firstMatch(trimmed);
    if (numbered != null) {
      final number = numbered.group(1)!;
      final content = numbered.group(2)!.trim();
      return '$number. $content';
    }

    return trimmed.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  }

  bool _isRedundantMetadataLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;

    final hasHandle = RegExp(r'\(@[A-Za-z0-9_]+\)').hasMatch(trimmed);
    final hasDate = RegExp(
      r'(?:\b\d{4}\b|\b\d{1,2}:\d{2}\b|\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\b|\b(?:today|yesterday|ago)\b)',
      caseSensitive: false,
    ).hasMatch(trimmed);

    return hasHandle && hasDate;
  }

  /// Favicon for the byline: known platform name, else URL host, else globe.
  String? _faviconUrlForSource(SavedUrl url, String displaySourceName) {
    final byName = faviconUrl(displaySourceName);
    if (byName != null) return byName;
    final parsed = Uri.tryParse(url.rawUrl.trim());
    final host = (parsed?.host.isNotEmpty ?? false)
        ? parsed!.host
        : url.domain.trim();
    if (host.isEmpty) return null;
    return 'https://www.google.com/s2/favicons?domain=$host&sz=64';
  }

  Color _sourceAccentColor(
    SavedUrl url,
    String displaySourceName,
    ColorScheme colorScheme,
  ) {
    final byName = platformColors[displaySourceName.trim()];
    if (byName != null) {
      return Color.alphaBlend(
        byName.withValues(alpha: 0.36),
        colorScheme.onSurfaceVariant,
      );
    }
    final parsed = Uri.tryParse(url.rawUrl.trim());
    final seed =
        ((parsed?.host.isNotEmpty ?? false) ? parsed!.host : url.domain.trim())
            .toLowerCase();
    if (seed.isEmpty) return _recipeAccent(colorScheme);
    final hue = seed.codeUnits.fold<int>(0, (sum, item) => sum + item) % 360;
    final generated = HSLColor.fromAHSL(
      1,
      hue.toDouble(),
      0.24,
      colorScheme.brightness == Brightness.dark ? 0.62 : 0.44,
    ).toColor();
    return Color.alphaBlend(
      generated.withValues(alpha: 0.42),
      colorScheme.onSurfaceVariant,
    );
  }

  Widget _buildSourceLeadingIcon(
    SavedUrl url,
    String displaySourceName,
    ColorScheme colorScheme,
  ) {
    final variant = colorScheme.onSurfaceVariant;
    final fav = _faviconUrlForSource(url, displaySourceName);
    if (fav != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CachedNetworkImage(
          imageUrl: fav,
          width: 14,
          height: 14,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) =>
              Icon(Icons.public_outlined, size: 14, color: variant),
        ),
      );
    }
    return Icon(Icons.public_outlined, size: 14, color: variant);
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  String _formatExactSavedDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} • $hour12:$minute $period';
  }
}

// ---------------------------------------------------------------------------
// Helper data classes for recipe UI
// ---------------------------------------------------------------------------

class _QuickFact {
  const _QuickFact({required this.label});
  final String label;
}

class _NutritionMetric {
  const _NutritionMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.target,
    required this.color,
  });

  final String label;
  final double value;
  final String unit;
  final double target;
  final Color color;

  double get progress {
    if (target <= 0) return 0;
    return (value / target).clamp(0, 1).toDouble();
  }
}

class _NutritionMetricTile extends StatelessWidget {
  const _NutritionMetricTile({
    required this.metric,
    required this.theme,
    required this.colorScheme,
  });

  final _NutritionMetric metric;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final value = metric.value == metric.value.truncateToDouble()
        ? metric.value.toInt().toString()
        : metric.value.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: metric.unit,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 9),
          _NutritionBar(
            value: metric.progress,
            color: metric.color,
            backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.38),
          ),
        ],
      ),
    );
  }
}

class _NutritionBar extends StatelessWidget {
  const _NutritionBar({
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  final double value;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * value.clamp(0, 1);
        return Stack(
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 3,
              width: width,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickFactChip extends StatelessWidget {
  const _QuickFactChip({
    required this.fact,
    required this.theme,
    required this.colorScheme,
  });

  final _QuickFact fact;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        fact.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          height: 1.15,
        ),
      ),
    );
  }
}

/// A single ingredient row with checkbox, name, and quantity sub-label.
class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.isChecked,
    required this.onToggle,
    required this.theme,
    required this.colorScheme,
  });

  final EnrichedRecipeIngredient ingredient;
  final bool isChecked;
  final ValueChanged<bool?> onToggle;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final amount = ingredient.amountLabel.trim();
    final notes = (ingredient.notes ?? '').trim();
    final subLabel = [
      if (amount.isNotEmpty) amount,
      if (notes.isNotEmpty) notes,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onToggle(!isChecked),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: onToggle,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isChecked
                              ? colorScheme.onSurface.withValues(alpha: 0.38)
                              : colorScheme.onSurface,
                          decoration: isChecked
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: colorScheme.onSurface.withValues(
                            alpha: 0.38,
                          ),
                          height: 1.3,
                        ),
                      ),
                      if (subLabel.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          subLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isChecked
                                ? colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.4,
                                  )
                                : colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
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
