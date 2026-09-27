import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/music_provider.dart';
import '../../core/providers/music_provider_preference_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/music_actions.dart';
import 'library_entity.dart';
import 'library_provider.dart';
import 'library_widgets.dart';
import 'music_library_provider.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

class LibraryMusicScreen extends ConsumerStatefulWidget {
  const LibraryMusicScreen({super.key});

  @override
  ConsumerState<LibraryMusicScreen> createState() => _LibraryMusicScreenState();
}

class _LibraryMusicScreenState extends ConsumerState<LibraryMusicScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(librarySnapshotProvider);
    final catalog = ref.watch(musicLibraryProvider);
    final checking = catalog.isLoading || catalog.isChecking;
    final horizontal = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.libraryMusic),
        actions: const [MusicProviderMenuButton()],
      ),
      body: CustomScrollView(
        slivers: [
          if (checking || catalog.hasFailure)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    if (checking) const ExpressiveLoadingIndicator(size: 18),
                    if (checking) const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        checking
                            ? context.l10n.loadingMusicDetails
                            : context.l10n.musicDetailsUnavailable,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (!checking)
                      TextButton(
                        onPressed: () =>
                            ref.read(musicLibraryProvider.notifier).retry(),
                        child: Text(context.l10n.retry),
                      ),
                  ],
                ),
              ),
            ),
          ...snapshot.when(
            loading: () => [
              const SliverFillRemaining(
                child: Center(child: ExpressiveLoadingIndicator()),
              ),
            ],
            error: (_, _) => [
              SliverFillRemaining(
                child: Center(child: Text(context.l10n.libraryUnavailable)),
              ),
            ],
            data: (data) {
              final music = data.songs;
              if (music.isEmpty) {
                return [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.all(horizontal),
                      child: Center(
                        child: Text(
                          context.l10n.libraryMusicEmptyDescription,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ];
              }
              final filtered = music
                  .where(
                    (entity) =>
                        '${entity.title} ${entity.mention.creator ?? ''}'
                            .toLowerCase()
                            .contains(_query),
                  )
                  .toList(growable: false);
              final songs = filtered;
              return [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 8),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      height: 52,
                      child: SearchBar(
                        hintText: context.l10n.searchYourLibrary,
                        leading: const AppIcon(AppIcons.search),
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                      ),
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(context.l10n.nothingMatchesFilters),
                    ),
                  )
                else ...[
                  if (songs.isNotEmpty) ...[
                    _header(
                      context,
                      horizontal: horizontal,
                      title: context.l10n.libraryMusicSongs,
                      count: songs.length,
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: horizontal - 8),
                      sliver: SliverList.builder(
                        itemCount: songs.length,
                        itemBuilder: (context, index) => _SongRow(
                          entity: songs[index],
                          siblingKeys: [for (final song in songs) song.key],
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context, {
    required double horizontal,
    required String title,
    required int count,
  }) {
    final tt = Theme.of(context).textTheme;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 10),
      sliver: SliverToBoxAdapter(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$count',
              style: tt.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens an item with its section, so the detail page swipes through the
/// same songs in the same order.
void _openEntity(
  BuildContext context,
  LibraryEntity entity,
  List<String> siblingKeys,
) => context.push(
  '/library/entity/${Uri.encodeComponent(entity.key)}',
  extra: siblingKeys,
);

class _SongRow extends ConsumerWidget {
  const _SongRow({required this.entity, required this.siblingKeys});

  final LibraryEntity entity;
  final List<String> siblingKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final artist = entity.mention.creator?.trim() ?? '';
    final provider = ref.watch(musicProviderPreferenceProvider).provider;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openEntity(context, entity, siblingKeys),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 0, 7),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 52,
              child: Hero(
                tag: 'library-artwork-${entity.key}',
                child: LibraryArtwork(
                  entity: entity,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (artist.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: provider == null
                  ? context.l10n.chooseWhereSongsOpen
                  : context.l10n.openInSource(provider.label),
              icon: AppIcon(AppIcons.play, color: cs.onSurfaceVariant),
              onPressed: () => openMusicItem(
                context,
                ref,
                title: entity.title,
                artist: entity.mention.creator,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
