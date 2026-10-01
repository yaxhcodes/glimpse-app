part of 'url_detail_screen.dart';

/// Wraps [UrlDetailScreen] in a horizontal [PageView] so the user can
/// swipe between posts in the same context list (like Reddit).
class UrlDetailPagerScreen extends StatefulWidget {
  /// Ordered list of URL IDs in the current context (e.g. home section, category).
  final List<int> urlIds;

  /// Index of the URL that was tapped — this page is shown first.
  final int initialIndex;
  final RediscoverOpenContext? rediscoverContext;

  const UrlDetailPagerScreen({
    super.key,
    required this.urlIds,
    required this.initialIndex,
    this.rediscoverContext,
  });

  @override
  State<UrlDetailPagerScreen> createState() => _UrlDetailPagerScreenState();
}

class _UrlDetailPagerScreenState extends State<UrlDetailPagerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;

  /// Settles a released swipe on the deck's spring, carrying the finger's
  /// speed into the page it lands on.
  late final AnimationController _settle = AnimationController.unbounded(
    vsync: this,
  )..addListener(_followSettle);

  /// Where [_settle] started and is headed. The page stays between them even
  /// if a fast flick would carry the spring past: overshooting shows a
  /// sliver of the page beyond.
  double _settleFrom = 0;
  double _settleTarget = 0;
  late int _currentIndex;

  // Drag tracking for custom horizontal-swipe detection.
  double _dragStartX = 0;
  double _dragDeltaX = 0;
  double _dragStartScrollOffset = 0; // PageController offset at drag start
  bool _isDraggingHorizontal = false;
  bool _mediaPointerActive = false;

  /// The route's settings, not the route: [ModalRoute.of] would rebuild
  /// every page in the pager whenever the route's status changes.
  RouteSettings? _settings;

  /// Each page's state, so the pager's one app bar can offer the showing
  /// save's actions.
  final Map<int, GlobalKey<_UrlDetailScreenState>> _pageKeys = {};

  GlobalKey<_UrlDetailScreenState> _pageKey(int urlId) =>
      _pageKeys[urlId] ??= GlobalKey<_UrlDetailScreenState>();

  // Snap threshold: must drag at least this far to flip pages.
  static const double _snapFraction = 0.3;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // The first page exists after this frame: give the app bar its actions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = ModalRoute.settingsOf(context);
  }

  @override
  void dispose() {
    _settle.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _followSettle() {
    if (!_pageController.hasClients) return;
    final from = _settleFrom;
    final target = _settleTarget;
    _pageController.jumpTo(
      from < target
          ? _settle.value.clamp(from, target)
          : _settle.value.clamp(target, from),
    );
  }

  void _onDragStart(DragStartDetails d) {
    if (_mediaPointerActive) return;
    _settle.stop();
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

    final target = targetPage * screenWidth;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpTo(target);
      return;
    }
    _settleFrom = _pageController.offset;
    _settleTarget = target;
    _settle.value = _settleFrom;
    _settle
        .animateWith(
          SpringSimulation(
            SwipeDeckPhysics.settleSpring,
            _pageController.offset,
            target,
            // The finger moving right scrolls the pages left.
            -d.velocity.pixelsPerSecond.dx,
            tolerance: const Tolerance(distance: 0.5, velocity: 20),
          ),
        )
        // A spring stops within a pixel of the page: land exactly on it.
        .then((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpTo(target);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final currentId = widget.urlIds[_currentIndex];
    // The app bar never changes from save to save, so it stays still while
    // the pages swipe underneath it.
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onHorizontalDragStart: _mediaPointerActive ? null : _onDragStart,
          onHorizontalDragUpdate: _mediaPointerActive ? null : _onDragUpdate,
          onHorizontalDragEnd: _mediaPointerActive ? null : _onDragEnd,
          // Exclude the gesture from competing with vertical scrolls inside pages.
          excludeFromSemantics: true,
          // Pages become cards while a swipe is under way.
          child: SwipeDeck(
            controller: _pageController,
            onPageChanged: (index) {
              if (_currentIndex == index) return;
              setState(() => _currentIndex = index);
              // Closing lands in the card for the save now showing.
              CardOpenRoute.reportVisibleUrl(_settings, widget.urlIds[index]);
            },
            // Let our GestureDetector drive paging; disable built-in page physics
            // so there's no double-handling and no scroll-axis fight.
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.urlIds.length,
            itemBuilder: (context, index) {
              return _KeepAlivePage(
                child: UrlDetailScreen(
                  key: _pageKey(widget.urlIds[index]),
                  showAppBar: false,
                  urlId: widget.urlIds[index],
                  rediscoverContext: widget.rediscoverContext,
                  isActive: index == _currentIndex,
                  onMediaPointerActiveChanged: (active) {
                    if (_mediaPointerActive == active) return;
                    setState(() => _mediaPointerActive = active);
                  },
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          // An app bar outside a Scaffold sizes to what it's given.
          height: MediaQuery.paddingOf(context).top + kToolbarHeight,
          child: _PagerAppBar(urlId: currentId, page: _pageKey(currentId)),
        ),
      ],
    );
  }
}

/// The pager's app bar, over every page: the showing save's actions, from
/// that page.
class _PagerAppBar extends ConsumerWidget {
  const _PagerAppBar({required this.urlId, required this.page});

  final int urlId;
  final GlobalKey<_UrlDetailScreenState> page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url =
        ref.watch(urlDetailProvider(urlId)).valueOrNull ??
        UrlDetailSeed.peek(urlId);
    final isPinned = ref.watch(
      pinnedUrlsProvider.select((ids) => ids.contains(urlId)),
    );
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: const AppGlassSurface(),
      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      title: Text(context.l10n.details),
      actions:
          page.currentState?._appBarActions(url, isPinned: isPinned) ??
          const [],
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
                        // Details' copy is already decoded: fly and show it
                        // until the full-resolution image is ready.
                        placeholder: (context, _) => CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          memCacheWidth:
                              _UrlDetailScreenState._detailImageDecodeWidth(
                                context,
                              ),
                          fadeInDuration: Duration.zero,
                          httpHeaders: SavedMediaResolver.imageHttpHeaders(
                            imageUrl,
                          ),
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
                icon: const Icon(AppIcons.close, color: Colors.white),
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
