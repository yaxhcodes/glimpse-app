import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/analytics_provider.dart';
import '../../core/providers/bulk_selection_provider.dart';
import '../../core/services/analytics_service.dart';
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
    final searchSelection = ref.watch(bulkSelectionProvider('search'));
    final currentSelectionScope = switch (_currentIndex) {
      0 => 'home',
      _searchTabIndex => 'search',
      _ => null,
    };
    final hasActiveSelection = switch (_currentIndex) {
      0 => homeSelection.isActive,
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
      child: Scaffold(
        backgroundColor: cs.surface,
        body: IndexedStack(index: _currentIndex, children: _screens),
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            final wasAlreadyHome = _currentIndex == 0 && i == 0;
            final wasAlreadySearch =
                _currentIndex == _searchTabIndex && i == _searchTabIndex;
            setState(() => _currentIndex = i);
            unawaited(
              ref
                  .read(analyticsServiceProvider)
                  .trackScreen(_screenForIndex(i)),
            );
            if (wasAlreadyHome) {
              ref.read(homeScrollToTopSignalProvider.notifier).state++;
            }
            if (wasAlreadySearch) {
              ref.read(searchShellRefocusProvider.notifier).state++;
            }
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder_rounded),
              label: 'Collections',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_tree_outlined),
              selectedIcon: Icon(Icons.account_tree_rounded),
              label: 'Interests',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
          ],
        ),
      ),
    );
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
