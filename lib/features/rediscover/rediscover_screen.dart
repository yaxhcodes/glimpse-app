import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/rediscovery_service.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/widgets/premium_design_system.dart';
import '../home/home_provider.dart';
import 'rediscover_provider.dart';

class RediscoverScreen extends ConsumerStatefulWidget {
  const RediscoverScreen({super.key});

  @override
  ConsumerState<RediscoverScreen> createState() => _RediscoverScreenState();
}

class _RediscoverScreenState extends ConsumerState<RediscoverScreen> {
  /// Picks the user has acted on in the hero this session, so it advances
  /// without re-shuffling the underlying queue mid-flow.
  final Set<int> _handled = {};

  RediscoveryService get _svc =>
      RediscoveryService(ref.read(isarServiceProvider));

  void _invalidateShelves() {
    ref.invalidate(revisitQueueProvider);
    ref.invalidate(onThisDayProvider);
    ref.invalidate(forgottenGemsProvider);
    ref.invalidate(interestShelfProvider);
    ref.invalidate(rediscoveryStatsProvider);
  }

  Future<void> _open(SavedUrl url, {bool fromHero = false}) async {
    HapticFeedback.lightImpact();
    await _svc.markResurfaced(url.id);
    await _svc.markOpened(url.id);
    // They came back to a bookmarked item — the queued intent is fulfilled.
    if (url.isQueued) {
      await ref.read(isarServiceProvider).clearIntent(url.id);
    }
    if (fromHero) setState(() => _handled.add(url.id));
    _invalidateShelves();
    if (mounted) context.push('/url/${url.id}');
  }

  void _dismiss(SavedUrl url, {bool fromHero = false}) {
    HapticFeedback.selectionClick();
    _svc.markDismissed(url.id);
    if (fromHero) {
      setState(() => _handled.add(url.id));
    }
    _invalidateShelves();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Hidden from Rediscover'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _svc.restoreDismissed(url.id);
            if (fromHero) setState(() => _handled.remove(url.id));
            _invalidateShelves();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final tagFreq = ref.watch(tagOccurrenceMapProvider);
    final statsAsync = ref.watch(rediscoveryStatsProvider);
    final picksAsync = ref.watch(todaysPicksProvider);

    return Scaffold(
      backgroundColor: premiumBackground(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: premiumBackground(context),
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Rediscover',
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _IntentHeader(statsAsync: statsAsync)),
          SliverToBoxAdapter(
            child: picksAsync.when(
              skipLoadingOnReload: true,
              data: (picks) {
                final remaining =
                    picks.where((p) => !_handled.contains(p.url.id)).toList();
                if (picks.isEmpty) return const SizedBox.shrink();
                if (remaining.isEmpty) return const _CaughtUp();
                final item = remaining.first;
                return _HeroDeck(
                  key: ValueKey(item.url.id),
                  item: item,
                  next: remaining.length > 1 ? remaining[1] : null,
                  remaining: remaining.length,
                  tagFrequency: tagFreq,
                  onOpen: () => _open(item.url, fromHero: true),
                  onDismiss: () => _dismiss(item.url, fromHero: true),
                );
              },
              loading: () => const _HeroSkeleton(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          _Shelf(
            title: 'Ready to revisit',
            provider: revisitQueueProvider,
            tagFrequency: tagFreq,
            onOpen: (u) => _open(u),
            onDismiss: (u) => _dismiss(u),
          ),
          _Shelf(
            title: 'On this day',
            provider: onThisDayProvider,
            tagFrequency: tagFreq,
            onOpen: (u) => _open(u),
            onDismiss: (u) => _dismiss(u),
          ),
          _Shelf(
            title: 'Forgotten gems',
            provider: forgottenGemsProvider,
            tagFrequency: tagFreq,
            onOpen: (u) => _open(u),
            onDismiss: (u) => _dismiss(u),
          ),
          _InterestShelf(
            tagFrequency: tagFreq,
            onOpen: (u) => _open(u),
            onDismiss: (u) => _dismiss(u),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

class _IntentHeader extends StatelessWidget {
  final AsyncValue<RediscoveryStats> statsAsync;

  const _IntentHeader({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final stats = statsAsync.valueOrNull;
    final unopened = stats?.unopened ?? 0;

    final headline = unopened > 0
        ? "$unopened saves you haven't opened yet"
        : 'A few things worth a second look';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Revisit a few before they slip away.',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipeable card deck around the hero pick: drag right to open, left to
/// dismiss, with a tilt, intent stamps and a peek of the next pick behind.
class _HeroDeck extends StatefulWidget {
  final RediscoveryItem item;
  final RediscoveryItem? next;
  final int remaining;
  final Map<String, int> tagFrequency;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const _HeroDeck({
    super.key,
    required this.item,
    required this.next,
    required this.remaining,
    required this.tagFrequency,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  State<_HeroDeck> createState() => _HeroDeckState();
}

class _HeroDeckState extends State<_HeroDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Animation<Offset>? _anim;
  Offset _drag = Offset.zero;
  bool _animating = false;
  double _width = 320;

  double get _threshold => _width * 0.28;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        final a = _anim;
        if (a != null && mounted) setState(() => _drag = a.value);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _animateTo(Offset target, {VoidCallback? onDone}) {
    _anim = Tween<Offset>(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _animating = true;
    _ctrl
      ..reset()
      ..forward().whenComplete(() {
        _animating = false;
        onDone?.call();
      });
  }

  void _flyOff(bool open) {
    _animateTo(
      Offset(open ? _width * 1.5 : -_width * 1.5, _drag.dy),
      onDone: open ? widget.onOpen : widget.onDismiss,
    );
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_animating) return;
    setState(() => _drag += Offset(d.delta.dx, 0));
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx;
    if (_drag.dx.abs() > _threshold || v.abs() > 800) {
      _flyOff(_drag.dx != 0 ? _drag.dx > 0 : v > 0);
    } else {
      _animateTo(Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _width = constraints.maxWidth;
          final progRight = (_drag.dx / _threshold).clamp(0.0, 1.0);
          final progLeft = (-_drag.dx / _threshold).clamp(0.0, 1.0);
          final mag = progRight > progLeft ? progRight : progLeft;
          final swipingRight = _drag.dx >= 0;
          final angle = (_drag.dx / _width) * 0.16;

          return Stack(
            children: [
              if (widget.next != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.55 + 0.45 * mag,
                      child: Transform.scale(
                        scale: 0.93 + 0.07 * mag,
                        child: _HeroPick(
                          item: widget.next!,
                          remaining: widget.remaining - 1,
                          tagFrequency: widget.tagFrequency,
                          onOpen: () {},
                          onDismiss: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: _drag,
                child: Transform.rotate(
                  angle: angle,
                  child: GestureDetector(
                    onHorizontalDragUpdate: _onDragUpdate,
                    onHorizontalDragEnd: _onDragEnd,
                    child: Stack(
                      children: [
                        _HeroPick(
                          item: widget.item,
                          remaining: widget.remaining,
                          tagFrequency: widget.tagFrequency,
                          onOpen: () => _flyOff(true),
                          onDismiss: () => _flyOff(false),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: (swipingRight
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFFF3B30))
                                    .withValues(alpha: mag * 0.22),
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
          );
        },
      ),
    );
  }
}

/// The focal "pick of the day" with explicit Open / Not now triage.
class _HeroPick extends StatelessWidget {
  final RediscoveryItem item;
  final int remaining;
  final Map<String, int> tagFrequency;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const _HeroPick({
    required this.item,
    required this.remaining,
    required this.tagFrequency,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final url = item.url;
    final title = TitleResolver.resolve(url, tagFrequency: tagFrequency);
    final source = url.effectiveCategories.firstOrNull ?? url.domain;
    final hasImage = url.thumbnailUrl != null && url.thumbnailUrl!.isNotEmpty;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 196,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: cs.surfaceContainerHighest),
                    if (hasImage)
                      CachedNetworkImage(
                        imageUrl: url.thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            ColoredBox(color: cs.surfaceContainerHighest),
                        errorWidget: (_, __, ___) => Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 30,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Icon(
                          Icons.bookmark_outline_rounded,
                          size: 30,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    // Fade the image into the card surface so it merges into
                    // the text section below (theme-driven: white / dark).
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.45, 0.8, 1.0],
                          colors: [
                            cs.surfaceContainerLow.withValues(alpha: 0.0),
                            cs.surfaceContainerLow.withValues(alpha: 0.55),
                            cs.surfaceContainerLow,
                          ],
                        ),
                      ),
                    ),
                    if (remaining > 1)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$remaining left',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReasonChip(item.reason),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -0.2,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$source · ${item.timeAgo}',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDismiss,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Not now'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.onSurfaceVariant,
                          side: BorderSide(color: cs.outlineVariant),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Open'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
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

class _ReasonChip extends StatelessWidget {
  final String label;

  const _ReasonChip(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: tt.labelSmall?.copyWith(
          fontSize: 10,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
          color: cs.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: cs.onSecondaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "You're all caught up",
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Browse the shelves below, or come back tomorrow for fresh picks.',
              textAlign: TextAlign.center,
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        height: 330,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

/// A bounded horizontal rail backed by a list provider.
class _Shelf extends ConsumerWidget {
  final String title;
  final ProviderListenable<AsyncValue<List<RediscoveryItem>>> provider;
  final Map<String, int> tagFrequency;
  final void Function(SavedUrl) onOpen;
  final void Function(SavedUrl) onDismiss;

  const _Shelf({
    required this.title,
    required this.provider,
    required this.tagFrequency,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // valueOrNull retains the previous list while the provider reloads after a
    // dismiss, so the rail swaps in place instead of blanking out.
    final items = ref.watch(provider).valueOrNull ?? const <RediscoveryItem>[];
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: _ShelfBody(
        title: title,
        items: items,
        tagFrequency: tagFrequency,
        onOpen: onOpen,
        onDismiss: onDismiss,
      ),
    );
  }
}

/// Interest shelf carries a dynamic, topic-derived title.
class _InterestShelf extends ConsumerWidget {
  final Map<String, int> tagFrequency;
  final void Function(SavedUrl) onOpen;
  final void Function(SavedUrl) onDismiss;

  const _InterestShelf({
    required this.tagFrequency,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(interestShelfProvider);
    final shelf = async.valueOrNull;
    if (shelf == null || shelf.items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: _ShelfBody(
        title: shelf.title,
        items: shelf.items,
        tagFrequency: tagFrequency,
        onOpen: onOpen,
        onDismiss: onDismiss,
      ),
    );
  }
}

class _ShelfBody extends StatelessWidget {
  final String title;
  final List<RediscoveryItem> items;
  final Map<String, int> tagFrequency;
  final void Function(SavedUrl) onOpen;
  final void Function(SavedUrl) onDismiss;

  const _ShelfBody({
    required this.title,
    required this.items,
    required this.tagFrequency,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title, count: items.length),
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final item = items[i];
              return SizedBox(
                width: 236,
                child: GestureDetector(
                  onLongPress: () => onDismiss(item.url),
                  child: CinematicCard(
                    imageUrl: item.url.thumbnailUrl,
                    title: TitleResolver.resolve(
                      item.url,
                      tagFrequency: tagFrequency,
                    ),
                    subtitle:
                        '${item.url.effectiveCategories.firstOrNull ?? item.url.domain} · ${item.timeAgo}',
                    reason: item.reason,
                    tags: item.url.tags.take(2).toList(),
                    onTap: () => onOpen(item.url),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
