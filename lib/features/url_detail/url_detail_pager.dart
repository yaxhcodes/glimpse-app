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

class _UrlDetailPagerScreenState extends State<UrlDetailPagerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

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
    _currentIndex = widget.initialIndex;
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
        onPageChanged: (index) {
          if (_currentIndex == index) return;
          setState(() => _currentIndex = index);
        },
        // Let our GestureDetector drive paging; disable built-in page physics
        // so there's no double-handling and no scroll-axis fight.
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.urlIds.length,
        itemBuilder: (context, index) {
          return _KeepAlivePage(
            child: UrlDetailScreen(
              key: ValueKey(widget.urlIds[index]),
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
