import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/expressive_fab.dart';
import '../../shared/widgets/expressive_tap_scale.dart';
import 'collection_card.dart';
import 'collections_provider.dart';
import 'create_collection_sheet.dart';

enum _CollectionsLayout { grid, list }

const _collectionsLayoutPrefsKey = 'glimpse_collections_layout';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  _CollectionsLayout _layout = _CollectionsLayout.grid;

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_collectionsLayoutPrefsKey);
    final layout = switch (stored) {
      'list' => _CollectionsLayout.list,
      'grid' => _CollectionsLayout.grid,
      _ => null,
    };
    if (layout != null && mounted) {
      setState(() => _layout = layout);
    }
  }

  Future<void> _setLayout(_CollectionsLayout layout) async {
    if (_layout == layout) return;
    setState(() => _layout = layout);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_collectionsLayoutPrefsKey, layout.name);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(collectionsSummaryProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasCollections = async.valueOrNull?.isNotEmpty ?? false;
    final shellBottomInset =
        widget.embedded &&
            !AppLayout.usesNavigationRail(MediaQuery.sizeOf(context).width)
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;
    final scrollBottomPadding = 24.0 + shellBottomInset;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        titleSpacing: widget.embedded ? 20 : null,
        automaticallyImplyLeading: !widget.embedded,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collections',
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Your saved spaces',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (hasCollections)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _LayoutToggle(value: _layout, onChanged: _setLayout),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (collections) {
          if (collections.isEmpty) {
            return _CollectionsEmptyState(
              colorScheme: cs,
              textTheme: tt,
              onCreate: () => _createCollection(context),
            );
          }
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.surface,
                  cs.surfaceContainerLow.withValues(alpha: 0.42),
                ],
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    child: _layout == _CollectionsLayout.grid
                        ? GridView.builder(
                            key: const ValueKey('collections-grid'),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              scrollBottomPadding,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 224,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.96,
                                ),
                            itemCount: collections.length,
                            itemBuilder: (context, i) => ExpressiveTapScale(
                              child: CollectionCard(summary: collections[i]),
                            ),
                          )
                        : ListView.builder(
                            key: const ValueKey('collections-list'),
                            padding: EdgeInsets.fromLTRB(
                              0,
                              8,
                              0,
                              scrollBottomPadding,
                            ),
                            itemCount: collections.length,
                            itemBuilder: (context, i) => ExpressiveTapScale(
                              child: CollectionListCard(
                                summary: collections[i],
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: hasCollections
          ? Padding(
              padding: EdgeInsets.only(bottom: shellBottomInset),
              child: ExpressiveFab(
                heroTag: 'collections-create',
                tooltip: 'New collection',
                onPressed: () => _createCollection(context),
                child: const AppIcon(AppIcons.addToCollection),
              ),
            )
          : null,
    );
  }

  Future<void> _createCollection(BuildContext context) async {
    final collection = await showCreateCollectionSheet(context);
    if (collection == null || !context.mounted) return;
    ref.invalidate(collectionsListProvider);
    ref.invalidate(collectionsSummaryProvider);
    context.push('/collections/${collection.id}');
  }
}

class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.value, required this.onChanged});

  final _CollectionsLayout value;
  final ValueChanged<_CollectionsLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SegmentedButton<_CollectionsLayout>(
      showSelectedIcon: false,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10),
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return cs.primary;
          }
          return cs.onSurfaceVariant;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return cs.secondaryContainer;
          }
          return cs.surfaceContainerHigh;
        }),
      ),
      segments: const [
        ButtonSegment(
          value: _CollectionsLayout.grid,
          icon: Icon(Icons.grid_view_rounded, size: 18),
          tooltip: 'Grid view',
        ),
        ButtonSegment(
          value: _CollectionsLayout.list,
          icon: Icon(Icons.view_agenda_outlined, size: 18),
          tooltip: 'List view',
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _CollectionsEmptyState extends StatelessWidget {
  const _CollectionsEmptyState({
    required this.colorScheme,
    required this.textTheme,
    required this.onCreate,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/empty_collection.png',
                width: 132,
                height: 132,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              Text(
                'Create your first collection',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Group links into calm, focused spaces.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const AppIcon(AppIcons.addToCollection),
                label: const Text('New collection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
