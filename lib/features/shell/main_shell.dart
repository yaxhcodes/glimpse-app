import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../home/home_screen.dart';
import '../home/home_provider.dart';
import '../collections/collections_screen.dart';
import '../mindmap/mindmap_screen.dart';
import '../search/search_provider.dart';
import '../search/search_screen.dart';

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
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final urlsAsync = ref.watch(displayedUrlsProvider);
    final hasLinks = (urlsAsync.valueOrNull?.length ?? 0) > 0;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        floatingActionButton: _currentIndex == 0 && hasLinks
            ? FloatingActionButton.extended(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/ask');
                },
                icon: SvgPicture.asset(
                  'assets/glimpse.svg',
                  width: 26,
                  height: 26,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.onPrimaryContainer,
                    BlendMode.srcIn,
                  ),
                ),
                label: Text(
                  'Ask Glimpse',
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                elevation: 2,
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            final wasAlreadySearch =
                _currentIndex == _searchTabIndex && i == _searchTabIndex;
            setState(() => _currentIndex = i);
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
              label: 'Mind Map',
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
}
