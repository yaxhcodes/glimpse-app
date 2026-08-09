import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'library_entity.dart';
import 'library_places_map.dart';
import 'library_provider.dart';
import 'library_widgets.dart';

class LibraryEntityDetailScreen extends ConsumerWidget {
  const LibraryEntityDetailScreen({super.key, required this.entityKey});

  final String entityKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(librarySnapshotProvider);
    return snapshot.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$error')),
      ),
      data: (data) {
        final entity = data.byKey(entityKey);
        if (entity == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('This Library item is unavailable.'),
            ),
          );
        }
        return _EntityDetail(
          entity: entity,
          onStatusChanged: (status) async {
            try {
              await ref
                  .read(libraryEntityActionsProvider)
                  .setStatus(entity, status);
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not update this Library item.'),
                ),
              );
            }
          },
          onHide: () async {
            await ref
                .read(libraryPreferencesProvider.notifier)
                .hide(entity.key, provisionalKey: entity.provisionalKey);
            if (context.mounted) context.pop();
          },
        );
      },
    );
  }
}

class _EntityDetail extends StatelessWidget {
  const _EntityDetail({
    required this.entity,
    required this.onStatusChanged,
    required this.onHide,
  });

  final LibraryEntity entity;
  final Future<void> Function(LibraryItemStatus status) onStatusChanged;
  final Future<void> Function() onHide;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reasons = entity.sources
        .map((source) => source.mention.whyMentioned?.trim() ?? '')
        .where((reason) => reason.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'hide') onHide();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'hide',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.visibility_off_outlined),
                  title: Text('Hide from Library'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EntityHero(entity: entity),
                      const SizedBox(height: 24),
                      Text(
                        entity.title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _EntityMetadata(entity: entity),
                      if (entity.genres.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final genre in entity.genres)
                              LibraryGenreChip(label: genre),
                          ],
                        ),
                      ],
                      if (entity.kind != LibraryEntityKind.place) ...[
                        const SizedBox(height: 24),
                        _LibraryStatusCard(
                          entity: entity,
                          onChanged: onStatusChanged,
                        ),
                      ],
                      if (reasons.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        Text(
                          reasons.length == 1
                              ? 'Why it mattered'
                              : 'Why it mattered',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        for (final reason in reasons)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              reason,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),
                      Card(
                        elevation: 0,
                        color: cs.surfaceContainerLow,
                        clipBehavior: Clip.antiAlias,
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            shape: const RoundedRectangleBorder(
                              side: BorderSide.none,
                            ),
                            collapsedShape: const RoundedRectangleBorder(
                              side: BorderSide.none,
                            ),
                            leading: const Icon(Icons.link_rounded),
                            title: const Text('Found in your saves'),
                            subtitle: Text(
                              '${entity.sources.length} ${entity.sources.length == 1 ? 'save' : 'saves'}',
                            ),
                            children: [
                              for (final source in entity.sources)
                                ListTile(
                                  dense: true,
                                  title: Text(
                                    source.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(source.domain),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () =>
                                      context.push('/url/${source.urlId}'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryStatusCard extends StatelessWidget {
  const _LibraryStatusCard({required this.entity, required this.onChanged});

  final LibraryEntity entity;
  final Future<void> Function(LibraryItemStatus status) onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = entity.status;
    final listName = entity.kind == LibraryEntityKind.book
        ? 'Reading list'
        : 'Watchlist';
    final statusLabel = status.labelFor(entity.kind);
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _chooseStatus(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _statusIcon(status),
                  color: cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listName,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status == LibraryItemStatus.unlisted
                          ? 'Add to your ${listName.toLowerCase()}'
                          : statusLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseStatus(BuildContext context) async {
    final selected = await showModalBottomSheet<LibraryItemStatus>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  entity.kind == LibraryEntityKind.book
                      ? 'Reading status'
                      : 'Watch status',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            for (final status in LibraryItemStatus.values.skip(1))
              ListTile(
                leading: Icon(_statusIcon(status)),
                title: Text(status.labelFor(entity.kind)),
                trailing: entity.status == status
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, status),
              ),
            if (entity.status != LibraryItemStatus.unlisted) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.playlist_remove_rounded),
                title: Text(
                  entity.kind == LibraryEntityKind.book
                      ? 'Remove from reading list'
                      : 'Remove from watchlist',
                ),
                onTap: () => Navigator.pop(context, LibraryItemStatus.unlisted),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || selected == entity.status) return;
    await onChanged(selected);
  }

  IconData _statusIcon(LibraryItemStatus status) => switch (status) {
    LibraryItemStatus.unlisted => Icons.playlist_add_rounded,
    LibraryItemStatus.planning => Icons.bookmark_add_outlined,
    LibraryItemStatus.active =>
      entity.kind == LibraryEntityKind.book
          ? Icons.auto_stories_rounded
          : Icons.play_circle_outline_rounded,
    LibraryItemStatus.dropped => Icons.remove_circle_outline_rounded,
    LibraryItemStatus.completed => Icons.check_circle_outline_rounded,
  };
}

class _EntityHero extends StatelessWidget {
  const _EntityHero({required this.entity});

  final LibraryEntity entity;

  @override
  Widget build(BuildContext context) {
    if (entity.kind == LibraryEntityKind.place) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 300,
            child: LibraryPlacesMap(
              entities: [entity],
              selectedKey: entity.key,
              onEntityTapped: (_) {},
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          if (entity.mention.hasCoordinates) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openInMaps(entity),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open in Maps'),
              ),
            ),
          ],
        ],
      );
    }
    return Center(
      child: SizedBox(
        width: 220,
        child: AspectRatio(
          aspectRatio: 0.68,
          child: Hero(
            tag: 'library-artwork-${entity.key}',
            child: LibraryArtwork(
              entity: entity,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openInMaps(LibraryEntity entity) async {
    final latitude = entity.mention.latitude;
    final longitude = entity.mention.longitude;
    if (latitude == null || longitude == null) return;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _EntityMetadata extends StatelessWidget {
  const _EntityMetadata({required this.entity});

  final LibraryEntity entity;

  @override
  Widget build(BuildContext context) {
    final values = switch (entity.kind) {
      LibraryEntityKind.book => [entity.mention.creator, entity.mention.year],
      LibraryEntityKind.movie => [
        entity.mention.year,
        _titleCase(entity.mention.subtype),
      ],
      LibraryEntityKind.place => [entity.mention.city, entity.mention.country],
    };
    final label = values
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');
    return Text(
      label.isEmpty ? entity.kind.singularLabel : label,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  String? _titleCase(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }
}
