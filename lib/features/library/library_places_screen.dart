import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_layout.dart';
import 'library_entity.dart';
import 'library_places_map.dart';
import 'library_provider.dart';

class LibraryPlacesScreen extends ConsumerStatefulWidget {
  const LibraryPlacesScreen({super.key});

  @override
  ConsumerState<LibraryPlacesScreen> createState() =>
      _LibraryPlacesScreenState();
}

class _LibraryPlacesScreenState extends ConsumerState<LibraryPlacesScreen> {
  static const _initialSheetSize = 0.28;

  final PageController _pageController = PageController(viewportFraction: 0.9);
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ValueNotifier<double> _sheetExtent = ValueNotifier(_initialSheetSize);
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_handleSheetExtentChanged);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_handleSheetExtentChanged);
    _sheetController.dispose();
    _sheetExtent.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(librarySnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Places')),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) {
          final places = data.ofKind(LibraryEntityKind.place);
          if (places.isEmpty) return const _PlacesEmptyState();
          final mapped = places
              .where((entity) => entity.mention.hasCoordinates)
              .toList(growable: false);
          final unmapped = places
              .where((entity) => !entity.mention.hasCoordinates)
              .toList(growable: false);
          if (_selectedKey == null ||
              !mapped.any((entity) => entity.key == _selectedKey)) {
            _selectedKey = mapped.firstOrNull?.key;
          }
          return _PlacesExperience(
            mapped: mapped,
            unmapped: unmapped,
            selectedKey: _selectedKey,
            pageController: _pageController,
            sheetController: _sheetController,
            sheetExtent: _sheetExtent,
            onMapSelected: (entity) => _selectFromMap(entity, mapped),
            onCardChanged: (index) {
              if (index >= mapped.length) return;
              setState(() => _selectedKey = mapped[index].key);
            },
            onOpen: _open,
          );
        },
      ),
    );
  }

  void _handleSheetExtentChanged() {
    if (!_sheetController.isAttached) return;
    _sheetExtent.value = _sheetController.size;
  }

  void _selectFromMap(LibraryEntity entity, List<LibraryEntity> mapped) {
    setState(() => _selectedKey = entity.key);
    final index = mapped.indexWhere((item) => item.key == entity.key);
    if (index >= 0 && _pageController.hasClients) {
      final media = MediaQuery.of(context);
      if (media.disableAnimations || media.accessibleNavigation) {
        _pageController.jumpToPage(index);
      } else {
        unawaited(
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    }
  }

  void _open(LibraryEntity entity) {
    context.push('/library/entity/${Uri.encodeComponent(entity.key)}');
  }
}

class _PlacesExperience extends StatelessWidget {
  const _PlacesExperience({
    required this.mapped,
    required this.unmapped,
    required this.selectedKey,
    required this.pageController,
    required this.sheetController,
    required this.sheetExtent,
    required this.onMapSelected,
    required this.onCardChanged,
    required this.onOpen,
  });

  final List<LibraryEntity> mapped;
  final List<LibraryEntity> unmapped;
  final String? selectedKey;
  final PageController pageController;
  final DraggableScrollableController sheetController;
  final ValueNotifier<double> sheetExtent;
  final ValueChanged<LibraryEntity> onMapSelected;
  final ValueChanged<int> onCardChanged;
  final ValueChanged<LibraryEntity> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= AppLayout.expandedWidth;
        return Stack(
          fit: StackFit.expand,
          children: [
            LibraryPlacesMap(
              entities: mapped,
              selectedKey: selectedKey,
              onEntityTapped: onMapSelected,
              showAttribution: false,
              bottomObstructionFraction: sheetExtent,
            ),
            ValueListenableBuilder<double>(
              valueListenable: sheetExtent,
              builder: (context, extent, _) => Positioned(
                right: 8,
                bottom: constraints.maxHeight * extent + 8,
                child: const _MapAttribution(),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(
                width: isTablet ? 440 : constraints.maxWidth,
                child: DraggableScrollableSheet(
                  controller: sheetController,
                  initialChildSize: _LibraryPlacesScreenState._initialSheetSize,
                  minChildSize: 0.2,
                  maxChildSize: isTablet ? 0.82 : 0.76,
                  snap: true,
                  snapSizes: const [0.28, 0.76],
                  builder: (context, scrollController) => _PlacesSheet(
                    mapped: mapped,
                    unmapped: unmapped,
                    selectedKey: selectedKey,
                    pageController: pageController,
                    scrollController: scrollController,
                    onCardChanged: onCardChanged,
                    onOpen: onOpen,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlacesSheet extends StatelessWidget {
  const _PlacesSheet({
    required this.mapped,
    required this.unmapped,
    required this.selectedKey,
    required this.pageController,
    required this.scrollController,
    required this.onCardChanged,
    required this.onOpen,
  });

  final List<LibraryEntity> mapped;
  final List<LibraryEntity> unmapped;
  final String? selectedKey;
  final PageController pageController;
  final ScrollController scrollController;
  final ValueChanged<int> onCardChanged;
  final ValueChanged<LibraryEntity> onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      shadowColor: cs.shadow.withValues(alpha: 0.18),
      color: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${mapped.length + unmapped.length} places',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (mapped.isNotEmpty)
                  Text(
                    'Swipe to explore',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (mapped.isNotEmpty)
            SizedBox(
              height: 126,
              child: PageView.builder(
                controller: pageController,
                itemCount: mapped.length,
                onPageChanged: onCardChanged,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: _PlaceCard(
                    entity: mapped[index],
                    selected: mapped[index].key == selectedKey,
                    onTap: () => onOpen(mapped[index]),
                  ),
                ),
              ),
            ),
          if (mapped.isNotEmpty) ...[
            const _SectionHeading(title: 'All mapped places'),
            for (final entity in mapped)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _PlaceCard(
                  entity: entity,
                  selected: entity.key == selectedKey,
                  compact: true,
                  onTap: () => onOpen(entity),
                ),
              ),
          ],
          if (unmapped.isNotEmpty) ...[
            const _SectionHeading(
              title: 'Unmapped places',
              subtitle: 'Kept visible without guessing a location.',
            ),
            for (final entity in unmapped)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _PlaceCard(
                  entity: entity,
                  compact: true,
                  onTap: () => onOpen(entity),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          width: 34,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.entity,
    required this.onTap,
    this.selected = false,
    this.compact = false,
  });

  final LibraryEntity entity;
  final VoidCallback onTap;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locality = [
      entity.mention.city,
      entity.mention.country,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: selected ? cs.secondaryContainer : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        side: BorderSide(
          color: selected
              ? cs.primary.withValues(alpha: 0.42)
              : cs.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 15),
          child: Row(
            children: [
              CircleAvatar(
                radius: compact ? 20 : 23,
                backgroundColor: cs.tertiaryContainer,
                foregroundColor: cs.onTertiaryContainer,
                child: const Icon(Icons.place_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (locality.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        locality,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          '© Geoapify · © OpenStreetMap',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 9,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PlacesEmptyState extends StatelessWidget {
  const _PlacesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No places discovered yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
