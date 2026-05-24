import 'package:flutter/material.dart';

import 'cluster_card.dart' show InterestCluster;
import 'hero_cluster_card.dart';
import 'medium_cluster_card.dart';
import 'slim_cluster_row.dart';

class InterestMapScreen extends StatelessWidget {
  const InterestMapScreen({
    super.key,
    required this.clusters,
    required this.onRefresh,
    this.onClusterTap,
  });

  final List<InterestCluster> clusters;
  final VoidCallback onRefresh;
  final ValueChanged<InterestCluster>? onClusterTap;

  @override
  Widget build(BuildContext context) {
    final prepared = prepareInterestClusters(clusters);
    final hero = prepared.isEmpty ? null : prepared.first;
    final mediumEnd = prepared.length < 5 ? prepared.length : 5;
    final medium =
        prepared.length <= 1 ? <InterestCluster>[] : prepared.sublist(1, mediumEnd);
    final slim = prepared.length <= 5 ? <InterestCluster>[] : prepared.sublist(5);
    final totalSaves = prepared.fold<int>(0, (sum, c) => sum + c.saveCount);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _TopBar(
              themeCount: prepared.length,
              totalSaves: totalSaves,
              onRefresh: onRefresh,
            ),
            if (hero != null) ...[
              const _SectionLabel('Top signal'),
              SliverToBoxAdapter(
                child: HeroClusterCard(
                  cluster: hero,
                  onTap: () => onClusterTap?.call(hero),
                ),
              ),
            ],
            if (medium.isNotEmpty) ...[
              const _SectionLabel('Active interests'),
              _MediumGrid(
                clusters: medium,
                onClusterTap: onClusterTap,
              ),
            ],
            if (slim.isNotEmpty) ...[
              const _SectionLabel('Smaller signals'),
              _SlimList(
                clusters: slim,
                onClusterTap: onClusterTap,
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

List<InterestCluster> prepareInterestClusters(List<InterestCluster> raw) {
  final filtered = raw.where(_isRenderableCluster).toList();
  final byLabel = <String, InterestCluster>{};

  for (final cluster in filtered) {
    final key = cluster.label.trim().toLowerCase();
    final existing = byLabel[key];
    if (existing == null) {
      byLabel[key] = _sanitizeCluster(cluster);
      continue;
    }

    final primary = existing.saveCount >= cluster.saveCount ? existing : cluster;
    final accent = primary.accentColor ?? existing.accentColor ?? cluster.accentColor;
    byLabel[key] = InterestCluster(
      id: primary.id,
      label: primary.label.trim(),
      saveCount: existing.saveCount + cluster.saveCount,
      subtopics: _mergedSubtopics(primary.label, [
        ...existing.subtopics,
        ...cluster.subtopics,
      ]),
      dominance: existing.dominance > cluster.dominance ? existing.dominance : cluster.dominance,
      coverImageUrl: primary.coverImageUrl ?? existing.coverImageUrl ?? cluster.coverImageUrl,
      accentColor: accent,
    );
  }

  final merged = byLabel.values.toList()
    ..sort((a, b) => b.saveCount.compareTo(a.saveCount));
  return merged.take(12).toList();
}

bool _isRenderableCluster(InterestCluster cluster) {
  if (cluster.saveCount < 3) return false;
  final label = cluster.label.trim();
  if (label.isEmpty) return false;
  final lower = label.toLowerCase();
  const blocked = {
    'social',
    'x',
    'instagram',
    'twitter',
    'facebook',
    'home',
    'untitled',
    'article',
    'post',
    'status',
    'photo',
    'interest group',
    'technology',
  };
  if (blocked.contains(lower)) return false;
  if (RegExp(r'(interest|technology|design)\s*\d+', caseSensitive: false).hasMatch(label)) {
    return false;
  }
  if (RegExp(r'^[a-z0-9-]+\.(com|in|org|net|io|ai|dev)$', caseSensitive: false).hasMatch(label)) {
    return false;
  }
  return true;
}

InterestCluster _sanitizeCluster(InterestCluster cluster) {
  return InterestCluster(
    id: cluster.id,
    label: cluster.label.trim(),
    saveCount: cluster.saveCount,
    subtopics: _mergedSubtopics(cluster.label, cluster.subtopics),
    dominance: cluster.dominance.clamp(0.0, 1.0).toDouble(),
    coverImageUrl: cluster.coverImageUrl,
    accentColor: cluster.accentColor,
  );
}

List<String> _mergedSubtopics(String parentLabel, List<String> values) {
  final parent = parentLabel.trim().toLowerCase();
  final seen = <String>{};
  final output = <String>[];
  for (final value in values) {
    final label = value.trim();
    final lower = label.toLowerCase();
    if (label.isEmpty || lower == parent) continue;
    if (seen.add(lower)) output.add(label);
    if (output.length == 4) break;
  }
  return output;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.themeCount,
    required this.totalSaves,
    required this.onRefresh,
  });

  final int themeCount;
  final int totalSaves;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Interest map',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  '$themeCount themes · $totalSaves saves',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRefresh,
              style: IconButton.styleFrom(
                side: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.4,
                fontFamily: null,
              ),
        ),
      ),
    );
  }
}

class _MediumGrid extends StatelessWidget {
  const _MediumGrid({required this.clusters, required this.onClusterTap});

  final List<InterestCluster> clusters;
  final ValueChanged<InterestCluster>? onClusterTap;

  @override
  Widget build(BuildContext context) {
    final hasFeaturedTail = clusters.length.isOdd;
    final gridCount = hasFeaturedTail ? clusters.length - 1 : clusters.length;
    final featured = hasFeaturedTail ? clusters.last : null;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate.fixed([
          if (gridCount > 0)
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
              ),
              itemCount: gridCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final cluster = clusters[index];
                return MediumClusterCard(
                  cluster: cluster,
                  onTap: () => onClusterTap?.call(cluster),
                );
              },
            ),
          if (featured != null) ...[
            if (gridCount > 0) const SizedBox(height: 8),
            SizedBox(
              height: 170,
              child: MediumClusterCard(
                cluster: featured,
                featured: true,
                onTap: () => onClusterTap?.call(featured),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _SlimList extends StatelessWidget {
  const _SlimList({required this.clusters, required this.onClusterTap});

  final List<InterestCluster> clusters;
  final ValueChanged<InterestCluster>? onClusterTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final cluster = clusters[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SlimClusterRow(
                cluster: cluster,
                onTap: () => onClusterTap?.call(cluster),
              ),
            );
          },
          childCount: clusters.length,
        ),
      ),
    );
  }
}
