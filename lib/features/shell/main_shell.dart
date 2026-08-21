import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/analytics_provider.dart';
import '../../core/providers/bulk_selection_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
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
import 'shell_chrome_provider.dart';
import 'shell_status_bar_accent.dart';
import '../../shared/widgets/expressive_fab.dart';
import '../../l10n/l10n.dart';

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

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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
    final urlsAsync = ref.watch(displayedUrlsProvider);
    final hasLinks = (urlsAsync.valueOrNull?.length ?? 0) > 0;
    final shellChromeVisible = ref.watch(shellChromeVisibilityProvider);
    final homeSelection = ref.watch(bulkSelectionProvider('home'));
    final collectionsSelection = ref.watch(
      bulkSelectionProvider('collections'),
    );
    final searchSelection = ref.watch(bulkSelectionProvider('search'));
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

          return Scaffold(
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
                                    'assets/glimpse.svg',
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
                                      icon: NavigationDiscoveryIcon(
                                        key: ValueKey(
                                          '${destinations[index].badgeKey}-navigation-discovery-badge',
                                        ),
                                        semanticsLabel:
                                            destinations[index].label,
                                        discoveryLabel:
                                            strings.notificationNewDiscovery,
                                        showBadge:
                                            destinations[index].hasUpdate &&
                                            _currentIndex != index,
                                        icon: AppIcon(destinations[index].icon),
                                      ),
                                      selectedIcon: NavigationDiscoveryIcon(
                                        semanticsLabel:
                                            destinations[index].label,
                                        discoveryLabel:
                                            strings.notificationNewDiscovery,
                                        icon: AppIcon(
                                          destinations[index].icon,
                                          selected: true,
                                        ),
                                      ),
                                      label: Text(destinations[index].label),
                                    ),
                                ],
                              ),
                            ),
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: cs.outlineVariant.withValues(alpha: 0.55),
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
                _currentIndex == 0 &&
                    hasLinks &&
                    !homeSelection.isActive &&
                    (usesRail || shellChromeVisible)
                ? ExpressiveExtendedFab(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/ask');
                    },
                    icon: SvgPicture.asset(
                      'assets/glimpse.svg',
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
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            bottomNavigationBar: usesRail
                ? null
                : _AnimatedShellBottomNavigation(
                    visible: showCompactChrome,
                    child: AppGlassSurface(
                      backgroundColor: cs.surfaceContainerLow,
                      opacity: Theme.of(context).brightness == Brightness.dark
                          ? 0.72
                          : 0.80,
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
                              icon: NavigationDiscoveryIcon(
                                key: ValueKey(
                                  '${destinations[index].badgeKey}-navigation-discovery-badge',
                                ),
                                semanticsLabel: destinations[index].label,
                                discoveryLabel:
                                    strings.notificationNewDiscovery,
                                showBadge:
                                    destinations[index].hasUpdate &&
                                    _currentIndex != index,
                                icon: AppIcon(destinations[index].icon),
                              ),
                              selectedIcon: NavigationDiscoveryIcon(
                                semanticsLabel: destinations[index].label,
                                discoveryLabel:
                                    strings.notificationNewDiscovery,
                                icon: AppIcon(
                                  destinations[index].icon,
                                  selected: true,
                                ),
                              ),
                              label: destinations[index].label,
                            ),
                        ],
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
      child: IndexedStack(
        index: _currentIndex,
        children: [
          for (var index = 0; index < _screens.length; index += 1)
            _loadedTabIndexes.contains(index)
                ? _screens[index]
                : const SizedBox.shrink(),
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
    HapticFeedback.selectionClick();
    final wasAlreadyHome = _currentIndex == 0 && index == 0;
    final wasAlreadySearch =
        _currentIndex == _searchTabIndex && index == _searchTabIndex;
    _activateTab(index);
    _acknowledgeDiscoveryWhenReady(index);
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
      _loadedTabIndexes.add(index);
      _currentIndex = index;
    });
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
      var snapshot = ref.read(librarySnapshotProvider).valueOrNull;
      if (snapshot == null) {
        await ref.read(urlStreamProvider.future);
        snapshot = ref.read(librarySnapshotProvider).valueOrNull;
      }
      if (!mounted || _currentIndex != 1 || snapshot == null) return;
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

class _AnimatedShellBottomNavigation extends StatefulWidget {
  const _AnimatedShellBottomNavigation({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<_AnimatedShellBottomNavigation> createState() =>
      _AnimatedShellBottomNavigationState();
}

class _AnimatedShellBottomNavigationState
    extends State<_AnimatedShellBottomNavigation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      value: widget.visible ? 1 : 0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(_AnimatedShellBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      excluding: !widget.visible,
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: AnimatedBuilder(
          animation: _animation,
          child: widget.child,
          builder: (context, child) {
            final progress = _animation.value;
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: progress,
                child: Opacity(
                  opacity: progress,
                  child: Transform.translate(
                    offset: Offset(0, 18 * (1 - progress)),
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
