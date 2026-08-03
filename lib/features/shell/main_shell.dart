import 'dart:async';

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
import '../collections/collections_screen.dart';
import '../mindmap/mindmap_screen.dart';
import '../search/search_provider.dart';
import '../search/search_screen.dart';
import '../../shared/widgets/expressive_fab.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const int _searchTabIndex = 3;

  static const _destinations = [
    (label: 'Home', icon: AppIcons.home),
    (label: 'Collections', icon: AppIcons.collections),
    (label: 'Interests', icon: AppIcons.interests),
    (label: 'Search', icon: AppIcons.search),
  ];

  int _currentIndex = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    CollectionsScreen(embedded: true),
    MindmapScreen(embedded: true),
    SearchScreen(embedded: true),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(analyticsServiceProvider).trackScreen(AnalyticsScreen.home),
      );
      final request = ref.read(searchShellQueryRequestProvider);
      if (!mounted || request == null) return;
      setState(() => _currentIndex = _searchTabIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SearchShellQueryRequest?>(searchShellQueryRequestProvider, (
      previous,
      next,
    ) {
      if (next == null) return;
      if (_currentIndex == _searchTabIndex) return;
      setState(() => _currentIndex = _searchTabIndex);
    });

    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final urlsAsync = ref.watch(displayedUrlsProvider);
    final hasLinks = (urlsAsync.valueOrNull?.length ?? 0) > 0;
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
          setState(() => _currentIndex = 0);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final usesRail = AppLayout.usesNavigationRail(constraints.maxWidth);
          final usesExtendedRail = AppLayout.usesExtendedNavigationRail(
            constraints.maxWidth,
          );
          final content = _buildShellContent(constrainWidth: usesRail);

          return Scaffold(
            backgroundColor: cs.surface,
            extendBody: !usesRail,
            body: usesRail
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
                            for (final destination in _destinations)
                              NavigationRailDestination(
                                icon: AppIcon(destination.icon),
                                selectedIcon: AppIcon(
                                  destination.icon,
                                  selected: true,
                                ),
                                label: Text(destination.label),
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
            floatingActionButton: _currentIndex == 0 && hasLinks
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
                      'Ask Glimpse',
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
                : AppGlassSurface(
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
                        for (final destination in _destinations)
                          NavigationDestination(
                            icon: AppIcon(destination.icon),
                            selectedIcon: AppIcon(
                              destination.icon,
                              selected: true,
                            ),
                            label: destination.label,
                          ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildShellContent({required bool constrainWidth}) {
    final content = IndexedStack(index: _currentIndex, children: _screens);
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
    setState(() => _currentIndex = index);
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

  AnalyticsScreen _screenForIndex(int index) {
    return switch (index) {
      0 => AnalyticsScreen.home,
      1 => AnalyticsScreen.collections,
      2 => AnalyticsScreen.interests,
      _ => AnalyticsScreen.search,
    };
  }
}
