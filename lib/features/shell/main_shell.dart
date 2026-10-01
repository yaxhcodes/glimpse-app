import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/analytics_provider.dart';
import '../../core/providers/bulk_selection_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/scroll_capture_service.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/theme/app_motion.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../home/home_screen.dart';
import '../home/home_provider.dart';
import '../library/library_provider.dart';
import '../collections/collections_screen.dart';
import '../mindmap/mindmap_screen.dart';
import '../mindmap/interest_clusters_provider.dart';
import '../search/search_provider.dart';
import '../search/search_screen.dart';
import 'navigation_discovery_icon.dart';
import 'navigation_discovery_provider.dart';
import 'navigation_tab_bounce.dart';
import 'shell_bottom_navigation_transition.dart';
import 'shell_chrome_provider.dart';
import 'shell_status_bar_accent.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/expressive_fab.dart';
import '../../l10n/l10n.dart';
import '../../core/services/app_haptics.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const int _searchTabIndex = 3;

  int _currentIndex = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    CollectionsScreen(embedded: true),
    MindmapScreen(embedded: true),
    SearchScreen(embedded: true),
  ];

  final Set<int> _loadedTabIndexes = {0};
  Timer? _initialAnalyticsTimer;

  /// "Ask Glimpse" spells itself out for a moment when Home appears, then
  /// settles into the round button so it doesn't sit across the saves.
  /// Until someone has used Ask once it stays spelled out, so it's found.
  static const _askLearnedKey = 'ask_fab_learned_v1';
  static const _askLabelFor = Duration(seconds: 4);
  bool _askLabelShown = true;
  bool _askLearned = false;
  Timer? _askLabelTimer;

  @override
  void initState() {
    super.initState();
    _showAskLabelBriefly();
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final learned = prefs.getBool(_askLearnedKey) ?? false;
        if (mounted && learned) setState(() => _askLearned = true);
      } catch (_) {}
    }());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initialAnalyticsTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted || _currentIndex != 0) return;
        unawaited(
          ref.read(analyticsServiceProvider).trackScreen(AnalyticsScreen.home),
        );
      });
      final request = ref.read(searchShellQueryRequestProvider);
      if (!mounted || request == null) return;
      _activateTab(_searchTabIndex);
    });
  }

  @override
  void dispose() {
    _initialAnalyticsTimer?.cancel();
    _askLabelTimer?.cancel();
    super.dispose();
  }

  void _showAskLabelBriefly() {
    _askLabelTimer?.cancel();
    if (!_askLabelShown) setState(() => _askLabelShown = true);
    _askLabelTimer = Timer(_askLabelFor, () {
      if (mounted) setState(() => _askLabelShown = false);
    });
  }

  void _learnAsk() {
    if (_askLearned) return;
    setState(() => _askLearned = true);
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_askLearnedKey, true);
      } catch (_) {}
    }());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SearchShellQueryRequest?>(searchShellQueryRequestProvider, (
      previous,
      next,
    ) {
      if (next == null) return;
      if (_currentIndex == _searchTabIndex) return;
      _activateTab(_searchTabIndex);
    });
    ref.listen<NavigationDiscoveryState>(navigationDiscoveryProvider, (
      previous,
      next,
    ) {
      if ((_currentIndex == 1 && next.hasNewCollections) ||
          (_currentIndex == 2 && next.hasNewInterests)) {
        _acknowledgeDiscoveryWhenReady(_currentIndex);
      }
    });
    ref.listen(bulkSelectionProvider('home'), (previous, next) {
      if (next.isActive) {
        ref.read(shellChromeVisibilityProvider.notifier).show();
      }
    });
    ref.listen(bulkSelectionProvider('collections'), (previous, next) {
      if (next.isActive) {
        ref.read(shellChromeVisibilityProvider.notifier).show();
      }
    });
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final strings = context.l10n;
    final discovery = ref.watch(navigationDiscoveryProvider);
    final destinations = [
      (
        label: strings.home,
        icon: AppIcons.home,
        hasUpdate: false,
        badgeKey: 'home',
      ),
      (
        label: strings.collections,
        icon: AppIcons.collections,
        hasUpdate: discovery.hasNewCollections,
        badgeKey: 'collections',
      ),
      (
        label: strings.interests,
        icon: AppIcons.interests,
        hasUpdate: discovery.hasNewInterests,
        badgeKey: 'interests',
      ),
      (
        label: strings.search,
        icon: AppIcons.search,
        hasUpdate: false,
        badgeKey: 'search',
      ),
    ];
    // One widget shape for both the idle and selected slot, so a tab switch
    // updates the icon in place instead of mounting a new SVG.
    Widget navigationIcon(int index) {
      final destination = destinations[index];
      final selected = _currentIndex == index;
      return NavigationDiscoveryIcon(
        key: ValueKey('${destination.badgeKey}-navigation-discovery-badge'),
        semanticsLabel: destination.label,
        discoveryLabel: strings.notificationNewDiscovery,
        showBadge: destination.hasUpdate && !selected,
        icon: NavigationTabBounce(
          selected: selected,
          child: _NavigationGlyph(icon: destination.icon, selected: selected),
        ),
      );
    }

    final hasLinks = ref.watch(
      displayedUrlsProvider.select(
        (value) => value.valueOrNull?.isNotEmpty ?? false,
      ),
    );
    final shellChromeVisible = ref.watch(shellChromeVisibilityProvider);
    final homeSelection = ref.watch(bulkSelectionProvider('home'));
    final collectionsSelection = ref.watch(
      bulkSelectionProvider('collections'),
    );
    final searchSelection = ref.watch(bulkSelectionProvider('search'));
    final scrollCaptureActive = ScrollCaptureScope.isCapturingOf(context);
    final currentSelectionScope = switch (_currentIndex) {
      0 => 'home',
      1 => 'collections',
      _searchTabIndex => 'search',
      _ => null,
    };
    final hasActiveSelection = switch (_currentIndex) {
      0 => homeSelection.isActive,
      1 => collectionsSelection.isActive,
      _searchTabIndex => searchSelection.isActive,
      _ => false,
    };

    return PopScope(
      canPop: _currentIndex == 0 && !hasActiveSelection,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (hasActiveSelection && currentSelectionScope != null) {
          ref
              .read(bulkSelectionProvider(currentSelectionScope).notifier)
              .clear();
        } else if (_currentIndex != 0) {
          _activateTab(0);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final usesRail = AppLayout.usesNavigationRail(constraints.maxWidth);
          final usesExtendedRail = AppLayout.usesExtendedNavigationRail(
            constraints.maxWidth,
          );
          final showCompactChrome = hasActiveSelection || shellChromeVisible;
          final content = _buildShellContent(constrainWidth: usesRail);
          final navigationBarHeight =
              (Theme.of(context).navigationBarTheme.height ?? 80) +
              MediaQuery.viewPaddingOf(context).bottom;

          return ScrollCaptureViewportScope(
            bottomObstruction: usesRail ? 0 : navigationBarHeight,
            child: Scaffold(
              backgroundColor: cs.surface,
              extendBody: !usesRail,
              resizeToAvoidBottomInset: false,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: usesRail
                        ? Row(
                            children: [
                              SafeArea(
                                right: false,
                                child: NavigationRail(
                                  selectedIndex: _currentIndex,
                                  onDestinationSelected: _selectDestination,
                                  extended: usesExtendedRail,
                                  labelType: usesExtendedRail
                                      ? NavigationRailLabelType.none
                                      : NavigationRailLabelType.all,
                                  minWidth: 80,
                                  minExtendedWidth: 216,
                                  groupAlignment: -0.72,
                                  leading: Padding(
                                    padding: const EdgeInsets.only(bottom: 18),
                                    child: SvgPicture.asset(
                                      AppAssets.brandMark,
                                      width: 28,
                                      height: 28,
                                      colorFilter: ColorFilter.mode(
                                        cs.primary,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  destinations: [
                                    for (
                                      var index = 0;
                                      index < destinations.length;
                                      index++
                                    )
                                      NavigationRailDestination(
                                        icon: navigationIcon(index),
                                        selectedIcon: navigationIcon(index),
                                        label: Text(destinations[index].label),
                                      ),
                                  ],
                                ),
                              ),
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: cs.outlineVariant.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                              Expanded(child: content),
                            ],
                          )
                        : content,
                  ),
                  if (!usesRail)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ShellStatusBarAccent(
                        visible:
                            !showCompactChrome &&
                            _currentIndex != _searchTabIndex,
                      ),
                    ),
                ],
              ),
              floatingActionButton:
                  !scrollCaptureActive &&
                      _currentIndex == 0 &&
                      hasLinks &&
                      !homeSelection.isActive
                  ? ExpressiveExtendedFab(
                      isExtended:
                          shellChromeVisible &&
                          (_askLabelShown || !_askLearned),
                      tooltip: strings.askGlimpse,
                      onPressed: () {
                        AppHaptics.play(AppHaptics.tap);
                        _learnAsk();
                        context.push('/ask');
                      },
                      icon: SvgPicture.asset(
                        AppAssets.brandMark,
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          cs.onSecondaryContainer,
                          BlendMode.srcIn,
                        ),
                      ),
                      label: Text(
                        strings.askGlimpse,
                        style: tt.labelLarge?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
              bottomNavigationBar: usesRail
                  ? null
                  : IgnorePointer(
                      ignoring: scrollCaptureActive,
                      child: Opacity(
                        opacity: scrollCaptureActive ? 0 : 1,
                        child: ShellBottomNavigationTransition(
                          visible: showCompactChrome,
                          child: AppGlassSurface(
                            backgroundColor: cs.surfaceContainerLow,
                            // No live blur: the nav bar is always on screen
                            // while lists scroll under it (see profile notes).
                            blur: false,
                            opacity: 0.97,
                            child: NavigationBar(
                              selectedIndex: _currentIndex,
                              onDestinationSelected: _selectDestination,
                              labelBehavior:
                                  NavigationDestinationLabelBehavior.alwaysShow,
                              destinations: [
                                for (
                                  var index = 0;
                                  index < destinations.length;
                                  index++
                                )
                                  NavigationDestination(
                                    icon: navigationIcon(index),
                                    selectedIcon: navigationIcon(index),
                                    label: destinations[index].label,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShellContent({required bool constrainWidth}) {
    final content = NotificationListener<ScrollNotification>(
      onNotification: _handleShellScrollNotification,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < _screens.length; index++)
            Offstage(
              offstage: index != _currentIndex,
              child: TickerMode(
                enabled: index == _currentIndex,
                child: ScrollCaptureVisibilityScope(
                  isVisible: index == _currentIndex,
                  child: RepaintBoundary(
                    child: _TabReveal(
                      active: index == _currentIndex,
                      child: _loadedTabIndexes.contains(index)
                          ? _screens[index]
                          : const Center(child: ExpressiveLoadingIndicator()),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!constrainWidth) return content;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppLayout.maxShellContentWidth,
        ),
        child: SizedBox.expand(child: content),
      ),
    );
  }

  void _selectDestination(int index) {
    AppHaptics.play(AppHaptics.detent);
    final wasAlreadyHome = _currentIndex == 0 && index == 0;
    final wasAlreadySearch =
        _currentIndex == _searchTabIndex && index == _searchTabIndex;
    _activateTab(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentIndex == index) {
        _acknowledgeDiscoveryWhenReady(index);
      }
    });
    unawaited(
      ref.read(analyticsServiceProvider).trackScreen(_screenForIndex(index)),
    );
    if (wasAlreadyHome) {
      ref.read(homeScrollToTopSignalProvider.notifier).state++;
    }
    if (wasAlreadySearch) {
      ref.read(searchShellRefocusProvider.notifier).state++;
    }
  }

  void _activateTab(int index) {
    ref.read(shellChromeVisibilityProvider.notifier).show();
    if (_currentIndex == index && _loadedTabIndexes.contains(index)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _currentIndex = index;
    });
    if (index == 0) _showAskLabelBriefly();
    if (!_loadedTabIndexes.contains(index)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _currentIndex != index) return;
        setState(() => _loadedTabIndexes.add(index));
      });
    }
  }

  bool _handleShellScrollNotification(ScrollNotification notification) {
    final visibility = ref.read(shellChromeVisibilityProvider.notifier);
    final usesRail = AppLayout.usesNavigationRail(
      MediaQuery.sizeOf(context).width,
    );
    if (usesRail || _currentIndex == _searchTabIndex) {
      visibility.show();
      return false;
    }

    final selectionActive = switch (_currentIndex) {
      0 => ref.read(bulkSelectionProvider('home')).isActive,
      1 => ref.read(bulkSelectionProvider('collections')).isActive,
      _ => false,
    };
    if (selectionActive) {
      visibility.show();
      return false;
    }
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification case ScrollUpdateNotification(
      :final dragDetails,
      :final scrollDelta,
    ) when dragDetails != null) {
      visibility.handleUserScroll(
        delta: scrollDelta ?? 0,
        isAtTop:
            notification.metrics.pixels <= notification.metrics.minScrollExtent,
      );
    } else if (notification is ScrollEndNotification) {
      visibility.endGesture();
    }
    return false;
  }

  void _acknowledgeDiscoveryWhenReady(int index) {
    if (index == 1) {
      unawaited(_acknowledgeCollectionsWhenReady());
    } else if (index == 2) {
      unawaited(_acknowledgeInterestsWhenReady());
    }
  }

  Future<void> _acknowledgeCollectionsWhenReady() async {
    try {
      await loadLibrarySnapshot(ref);
      if (!mounted || _currentIndex != 1) return;
      await ref
          .read(navigationDiscoveryProvider.notifier)
          .acknowledgeCollections();
    } catch (error, stackTrace) {
      developer.log(
        'Collections discovery remains pending because the tab did not load.',
        name: 'MainShell',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _acknowledgeInterestsWhenReady() async {
    try {
      await ref.read(interestClusterThemesProvider.future);
      if (!mounted || _currentIndex != 2) return;
      await ref
          .read(navigationDiscoveryProvider.notifier)
          .acknowledgeInterests();
    } catch (error, stackTrace) {
      developer.log(
        'Interests discovery remains pending because the tab did not load.',
        name: 'MainShell',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  AnalyticsScreen _screenForIndex(int index) {
    return switch (index) {
      0 => AnalyticsScreen.home,
      1 => AnalyticsScreen.collections,
      2 => AnalyticsScreen.interests,
      _ => AnalyticsScreen.search,
    };
  }
}

/// Keeps the outline and filled artwork mounted together and swaps their
/// opacity. The glyphs are SVGs: mounting the filled one only on selection
/// decoded it asynchronously, and the destination drew nothing until it
/// arrived (visible as a vanishing Interests icon while its heavy first
/// frame was building).
class _NavigationGlyph extends StatelessWidget {
  const _NavigationGlyph({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: selected ? 0 : 1, child: AppIcon(icon)),
        Opacity(
          opacity: selected ? 1 : 0,
          child: AppIcon(icon, selected: true),
        ),
      ],
    );
  }
}

/// Material "fade through" for tab switches: the incoming tab fades in and
/// settles 6px upward. Tabs keep their state (the child element is never
/// rebuilt); only an opacity/offset layer animates, and only on activation.
class _TabReveal extends StatefulWidget {
  const _TabReveal({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_TabReveal> createState() => _TabRevealState();
}

class _TabRevealState extends State<_TabReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.emphasizedDecelerate,
  );

  @override
  void didUpdateWidget(covariant _TabReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _progress.value) * 6),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
