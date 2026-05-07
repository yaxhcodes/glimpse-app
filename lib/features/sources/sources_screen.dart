import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/category_chip.dart' show faviconUrl, platformColors;
import '../../shared/widgets/premium_design_system.dart';
import '../../shared/widgets/source_icon_resolver.dart';
import 'sources_provider.dart';

class SourcesScreen extends ConsumerStatefulWidget {
  const SourcesScreen({super.key});

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

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
    final clustersAsync = ref.watch(filteredClustersProvider(_query));

    return Scaffold(
      backgroundColor: premiumBackground(context),
      body: clustersAsync.when(
        data: (clusters) {
          final mostUsed = List<SourceCluster>.from(clusters)
            ..sort((a, b) => b.count.compareTo(a.count));
          final recentlyActive = List<SourceCluster>.from(clusters)
            ..sort((a, b) {
              final aTime = a.lastSavedAt;
              final bTime = b.lastSavedAt;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });
          final allClusters = List<SourceCluster>.from(clusters)
            ..sort((a, b) => a.name.compareTo(b.name));

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
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
              if (clusters.isEmpty && _query.isNotEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptySearch(query: _query),
                )
              else ...[
                if (mostUsed.isNotEmpty) ...[
                  _SectionHeader(title: 'Most Used', count: mostUsed.length),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _KnowledgeClusterCard(cluster: mostUsed[index]),
                        ),
                        childCount: mostUsed.length,
                      ),
                    ),
                  ),
                ],
                if (recentlyActive.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Recently Active',
                    count: recentlyActive.length,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _KnowledgeClusterCard(cluster: recentlyActive[index]),
                        ),
                        childCount: recentlyActive.length,
                      ),
                    ),
                  ),
                ],
                if (allClusters.isNotEmpty) ...[
                  _SectionHeader(title: 'All Sources', count: allClusters.length),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _KnowledgeClusterCard(cluster: allClusters[index]),
                        ),
                        childCount: allClusters.length,
                      ),
                    ),
                  ),
                ],
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
  final int count;

  const _SectionHeader({required this.title, required this.count});

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
                  overlap: 16,
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