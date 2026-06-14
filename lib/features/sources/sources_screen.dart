import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/category_chip.dart' show faviconUrl, platformColors;
import '../../shared/widgets/premium_design_system.dart';
import '../../shared/widgets/source_icon_resolver.dart';
import 'sources_provider.dart';

/// Lets the user narrow the source list to where saves actually came from —
/// apps/platforms (Instagram, X, …) vs. topic clusters.
enum _SourceFilter {
  all('All', Icons.all_inclusive_rounded),
  apps('Apps', Icons.apps_rounded),
  topics('Topics', Icons.sell_outlined);

  const _SourceFilter(this.label, this.icon);
  final String label;
  final IconData icon;

  String get listTitle => switch (this) {
    _SourceFilter.all => 'All sources',
    _SourceFilter.apps => 'Apps',
    _SourceFilter.topics => 'Topics',
  };
}

class SourcesScreen extends ConsumerStatefulWidget {
  const SourcesScreen({super.key});

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _SourceFilter _filter = _SourceFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final clustersAsync = ref.watch(filteredClustersProvider(_query));

    return Scaffold(
      backgroundColor: premiumBackground(context),
      body: clustersAsync.when(
        data: (clusters) {
          final searching = _query.trim().isNotEmpty;
          bool isApp(SourceCluster c) => platformColors.containsKey(c.name);

          final filtered = switch (_filter) {
            _SourceFilter.all => clusters,
            _SourceFilter.apps => clusters.where(isApp).toList(),
            _SourceFilter.topics =>
              clusters.where((c) => !isApp(c)).toList(),
          };
          final alphabetical = List<SourceCluster>.from(filtered)
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          // Top sources highlights topic clusters, not the app/platform a
          // link came from (Instagram, X, …), so filter known platforms out.
          final topSources =
              (clusters
                    .where((c) => !isApp(c))
                    .toList()
                ..sort((a, b) => b.count.compareTo(a.count)))
                  .take(8)
                  .toList();
          // The rail is a curated "top topics" view; hide it when the list is
          // already being narrowed by search or an explicit filter.
          final showRail = !searching &&
              _filter == _SourceFilter.all &&
              topSources.isNotEmpty;
          final listTitle = searching ? 'Results' : _filter.listTitle;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: premiumBackground(context),
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'Sources',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                actions: [
                  PopupMenuButton<_SourceFilter>(
                    tooltip: 'Filter sources',
                    icon: Icon(
                      Icons.tune_rounded,
                      color: _filter == _SourceFilter.all
                          ? cs.onSurfaceVariant
                          : cs.primary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (f) => setState(() => _filter = f),
                    itemBuilder: (context) => _SourceFilter.values.map((f) {
                      final active = _filter == f;
                      return PopupMenuItem<_SourceFilter>(
                        value: f,
                        child: Row(
                          children: [
                            Icon(
                              f.icon,
                              size: 18,
                              color: active
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              f.label,
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: active ? cs.primary : cs.onSurface,
                              ),
                            ),
                            if (active) ...[
                              const Spacer(),
                              Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: cs.primary,
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: PremiumSearchBar(
                    controller: _searchController,
                    hint: 'Search your knowledge clusters...',
                    onClear: _query.isNotEmpty
                        ? () {
                            _searchController.clear();
                            setState(() => _query = '');
                          }
                        : null,
                  ),
                ),
              ),
              if (alphabetical.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: searching
                      ? _EmptySearch(query: _query)
                      : _EmptyFilter(filter: _filter),
                )
              else ...[
                if (showRail) ...[
                  const _SectionHeader(title: 'Top sources'),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 134,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: topSources.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) =>
                            _TopSourceCard(cluster: topSources[index]),
                      ),
                    ),
                  ),
                ],
                _SectionHeader(
                  title: listTitle,
                  count: alphabetical.length,
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _KnowledgeClusterCard(
                          cluster: alphabetical[index],
                        ),
                      ),
                      childCount: alphabetical.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ],
          );
        },
        loading: () => CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: premiumBackground(context),
              surfaceTintColor: Colors.transparent,
              title: const Text('Sources'),
            ),
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (_, __) => CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: premiumBackground(context),
              surfaceTintColor: Colors.transparent,
              title: const Text('Sources'),
            ),
            const SliverFillRemaining(
              child: Center(child: Text('Could not load sources')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const _SectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: SectionTitle(title, count: count));
  }
}

class _EmptySearch extends StatelessWidget {
  final String query;

  const _EmptySearch({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No knowledge clusters match "$query"',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  final _SourceFilter filter;

  const _EmptyFilter({required this.filter});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final message = switch (filter) {
      _SourceFilter.apps => 'No saves from apps yet',
      _SourceFilter.topics => 'No topic sources yet',
      _SourceFilter.all => 'No sources yet',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filter.icon,
              size: 36,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _KnowledgeClusterCard extends StatelessWidget {
  final SourceCluster cluster;

  const _KnowledgeClusterCard({required this.cluster});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final iconSpec = resolveSourceIcon(cluster.name);
    final fav = faviconUrl(cluster.name);
    final brandColor = platformColors[cluster.name];

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          '/category/${Uri.encodeComponent(cluster.name)}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ClusterIcon(
                    faviconUrl: fav,
                    fallbackIcon: iconSpec.icon ?? Icons.folder_outlined,
                    brandColor: brandColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cluster.name,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            letterSpacing: -0.15,
                            height: 1.2,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              '${cluster.count} saves',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                            if (cluster.savesThisWeek > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '+${cluster.savesThisWeek} this week',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (cluster.isGrowing) ...[
                              const SizedBox(width: 6),
                              Text(
                                '· Growing',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.primary.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ],
              ),
              if (cluster.memoryStripUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                MemoryStrip(
                  imageUrls: cluster.memoryStripUrls,
                  height: 44,
                  totalCount: cluster.count,
                ),
              ],
              if (cluster.mostlyAbout.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: cluster.mostlyAbout
                      .map((tag) => MonochromePill(tag, compact: true))
                      .toList(),
                ),
              ],
              if (cluster.topDomain != null || cluster.lastSavedAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (cluster.topDomain != null)
                      Expanded(
                        child: Text(
                          cluster.topDomain!,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w400,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (cluster.lastSavedAt != null)
                      Text(
                        'Last saved ${_timeAgo(cluster.lastSavedAt!)}',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w400,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

class _TopSourceCard extends StatelessWidget {
  final SourceCluster cluster;

  const _TopSourceCard({required this.cluster});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final iconSpec = resolveSourceIcon(cluster.name);
    final fav = faviconUrl(cluster.name);
    final brandColor = platformColors[cluster.name];

    return SizedBox(
      width: 152,
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(
            '/category/${Uri.encodeComponent(cluster.name)}',
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ClusterIcon(
                  faviconUrl: fav,
                  fallbackIcon: iconSpec.icon ?? Icons.folder_outlined,
                  brandColor: brandColor,
                ),
                const SizedBox(height: 10),
                Text(
                  cluster.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: -0.15,
                    height: 1.2,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${cluster.count} saves',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
                if (cluster.savesThisWeek > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '+${cluster.savesThisWeek} this week',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClusterIcon extends StatelessWidget {
  final String? faviconUrl;
  final IconData fallbackIcon;
  final Color? brandColor;

  const _ClusterIcon({
    required this.faviconUrl,
    required this.fallbackIcon,
    this.brandColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = brandColor != null
        ? brandColor!.withValues(alpha: isDark ? 0.18 : 0.12)
        : cs.secondaryContainer.withValues(alpha: 0.5);
    final iconColor = brandColor ?? cs.onSurfaceVariant;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: faviconUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: faviconUrl!,
                  width: 20,
                  height: 20,
                  errorWidget: (_, __, ___) => Icon(fallbackIcon, size: 18, color: iconColor),
                ),
              )
            : Icon(fallbackIcon, size: 18, color: iconColor),
      ),
    );
  }
}