import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
              final music = data.ofKind(LibraryEntityKind.music);
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
              final songs = [
                for (final entity in filtered)
                  if (!LibraryIndex.isArtistMention(entity.mention)) entity,
              ];
              final artists = [
                for (final entity in filtered)
                  if (LibraryIndex.isArtistMention(entity.mention)) entity,
              ];
              return [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 16),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: context.l10n.searchYourLibrary,
                        prefixIcon: const AppIcon(AppIcons.search),
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
                  ..._section(
                    context,
                    horizontal: horizontal,
                    title: context.l10n.libraryMusicSongs,
                    entities: songs,
                  ),
                  ..._section(
                    context,
                    horizontal: horizontal,
                    title: context.l10n.libraryMusicArtists,
                    entities: artists,
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ];
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _section(
    BuildContext context, {
    required double horizontal,
    required String title,
    required List<LibraryEntity> entities,
  }) {
    if (entities.isEmpty) return const [];
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 4),
        sliver: SliverToBoxAdapter(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        sliver: SliverList.builder(
          itemCount: entities.length,
          itemBuilder: (context, index) => _MusicTile(entity: entities[index]),
        ),
      ),
    ];
  }
}

class _MusicTile extends StatelessWidget {
  const _MusicTile({required this.entity});

  final LibraryEntity entity;

  @override
  Widget build(BuildContext context) {
    final isArtist = LibraryIndex.isArtistMention(entity.mention);
    final creator = !isArtist
        ? entity.mention.creator?.trim() ?? ''
        : entity.sources.length == 1
        ? entity.sources.single.title
        : context.l10n.libraryArtistMentions(entity.sources.length);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      leading: SizedBox.square(
        dimension: 56,
        child: Hero(
          tag: 'library-artwork-${entity.key}',
          child: LibraryArtwork(
            entity: entity,
            borderRadius: BorderRadius.circular(isArtist ? 28 : 12),
          ),
        ),
      ),
      title: Text(entity.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: creator.isEmpty
          ? null
          : Text(creator, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () =>
          context.push('/library/entity/${Uri.encodeComponent(entity.key)}'),
    );
  }
}
