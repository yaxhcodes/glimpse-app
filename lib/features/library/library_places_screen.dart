import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final PageController _pageController = PageController(viewportFraction: 0.9);
  String? _selectedKey;

  @override
  void dispose() {
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
          final mapped = places
              .where((entity) => entity.mention.hasCoordinates)
              .toList(growable: false);
          final unmapped = places
              .where((entity) => !entity.mention.hasCoordinates)
              .toList(growable: false);
          if (places.isEmpty) return const _PlacesEmptyState();
          _selectedKey ??= mapped.isEmpty ? null : mapped.first.key;
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 760) {
                return _TabletPlacesLayout(
                  mapped: mapped,
                  unmapped: unmapped,
                  selectedKey: _selectedKey,
                  onSelected: _selectFromMap,
                  onOpen: _open,
                );
              }
              return _PhonePlacesLayout(
                mapped: mapped,
                unmapped: unmapped,
                selectedKey: _selectedKey,
                pageController: _pageController,
                onMapSelected: (entity) {
                  _selectFromMap(entity);
                  final index = mapped.indexWhere(
                    (item) => item.key == entity.key,
                  );
                  if (index >= 0 && _pageController.hasClients) {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                onCardChanged: (index) {
                  if (index >= mapped.length) return;
                  setState(() => _selectedKey = mapped[index].key);
                },
                onOpen: _open,
              );
            },
          );
        },
      ),
    );
  }

  void _selectFromMap(LibraryEntity entity) {
    setState(() => _selectedKey = entity.key);
  }

  void _open(LibraryEntity entity) {
    context.push('/library/entity/${Uri.encodeComponent(entity.key)}');
  }
}

class _PhonePlacesLayout extends StatelessWidget {
  const _PhonePlacesLayout({
    required this.mapped,
    required this.unmapped,
    required this.selectedKey,
    required this.pageController,
    required this.onMapSelected,
    required this.onCardChanged,
    required this.onOpen,
  });

  final List<LibraryEntity> mapped;
  final List<LibraryEntity> unmapped;
  final String? selectedKey;
  final PageController pageController;
  final ValueChanged<LibraryEntity> onMapSelected;
  final ValueChanged<int> onCardChanged;
  final ValueChanged<LibraryEntity> onOpen;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 330,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: LibraryPlacesMap(
                entities: mapped,
                selectedKey: selectedKey,
                onEntityTapped: onMapSelected,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        if (mapped.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 140,
              child: PageView.builder(
                controller: pageController,
                itemCount: mapped.length,
                onPageChanged: onCardChanged,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                  child: _PlaceCard(
                    entity: mapped[index],
                    selected: mapped[index].key == selectedKey,
                    onTap: () => onOpen(mapped[index]),
                  ),
                ),
              ),
            ),
          ),
        if (unmapped.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _UnmappedHeading()),
          SliverList.builder(
            itemCount: unmapped.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _PlaceCard(
                entity: unmapped[index],
                onTap: () => onOpen(unmapped[index]),
              ),
            ),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

class _TabletPlacesLayout extends StatelessWidget {
  const _TabletPlacesLayout({
    required this.mapped,
    required this.unmapped,
    required this.selectedKey,
    required this.onSelected,
    required this.onOpen,
  });

  final List<LibraryEntity> mapped;
  final List<LibraryEntity> unmapped;
  final String? selectedKey;
  final ValueChanged<LibraryEntity> onSelected;
  final ValueChanged<LibraryEntity> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: LibraryPlacesMap(
              entities: mapped,
              selectedKey: selectedKey,
              onEntityTapped: onSelected,
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ListView(
              children: [
                for (final entity in mapped)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PlaceCard(
                      entity: entity,
                      selected: entity.key == selectedKey,
                      onTap: () {
                        onSelected(entity);
                        onOpen(entity);
                      },
                    ),
                  ),
                if (unmapped.isNotEmpty) const _UnmappedHeading(),
                for (final entity in unmapped)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PlaceCard(
                      entity: entity,
                      onTap: () => onOpen(entity),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.entity,
    required this.onTap,
    this.selected = false,
  });

  final LibraryEntity entity;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locality = [
      entity.mention.city,
      entity.mention.country,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
    return Card(
      elevation: 0,
      color: selected ? cs.secondaryContainer : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected
              ? cs.primary.withValues(alpha: 0.4)
              : cs.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.tertiaryContainer,
                foregroundColor: cs.onTertiaryContainer,
                child: const Icon(Icons.place_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (locality.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        locality,
                        style: Theme.of(context).textTheme.bodySmall,
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

class _UnmappedHeading extends StatelessWidget {
  const _UnmappedHeading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unmapped places',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 3),
          Text(
            'Kept visible without guessing a location.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
