import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/widgets/category_chip.dart' show faviconUrl;
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/tag_group.dart' show tagChipColors;
import '../home/home_provider.dart';
import 'cluster_card.dart';
import 'cluster_theme.dart';
import 'interest_clusters_provider.dart';
import 'title_cleaner.dart';

// ─── Helpers ───────────────────────────────────────────────────────────────

String? _previewImageUrl(SavedUrl u) {
  final t = u.thumbnailUrl?.trim();
  if (t != null && t.isNotEmpty) return t;
  final fav = faviconUrl(u.category);
  if (fav != null) return fav;
  final d = u.domain.trim();
  if (d.isNotEmpty) {
    return 'https://www.google.com/s2/favicons?domain=${Uri.encodeComponent(d)}&sz=128';
  }
  return null;
}

// ─── Mindmap atlas ─────────────────────────────────────────────────────────

class _MindmapCanvas extends StatelessWidget {
  const _MindmapCanvas({required this.themes});

  final List<ClusterTheme> themes;

  @override
  Widget build(BuildContext context) {
    final clusters = _displayClustersForThemes(themes);
    if (clusters.isEmpty) return const _MindmapEmptyState();

    return InterestMapView(
      clusters: clusters,
      onClusterTap: (cluster) {
        final theme = _themeById(themes, int.tryParse(cluster.id) ?? -1);
        if (theme == null) return;
        HapticFeedback.lightImpact();
        context.push('/mindmap/cluster/${theme.index}');
      },
    );
  }
}

class InterestMapView extends StatelessWidget {
  const InterestMapView({
    super.key,
    required this.clusters,
    required this.onClusterTap,
  });

  final List<InterestCluster> clusters;
  final ValueChanged<InterestCluster> onClusterTap;

  @override
  Widget build(BuildContext context) {
    if (clusters.isEmpty) return const _MindmapEmptyState();

    final heroCluster = clusters.first;
    final mediumEnd = clusters.length < 5 ? clusters.length : 5;
    final medium = clusters.length <= 1
        ? <InterestCluster>[]
        : clusters.sublist(1, mediumEnd);
    final slim = clusters.length <= 5
        ? <InterestCluster>[]
        : clusters.sublist(5);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              _SectionEyebrow('Top signal'),
              ClusterCard(
                cluster: heroCluster,
                tier: ClusterCardTier.hero,
                onTap: () => onClusterTap(heroCluster),
              ),
              if (medium.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionEyebrow('Active interests'),
              ],
            ]),
          ),
        ),
        if (medium.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _MasonryClusterGrid(items: medium, onOpen: onClusterTap),
            ),
          ),
        if (slim.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                _SectionEyebrow('Smaller signals'),
              ]),
            ),
          ),
        if (slim.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index.isOdd) return const SizedBox(height: 8);
                final cluster = slim[index ~/ 2];
                return ClusterCard(
                  cluster: cluster,
                  tier: ClusterCardTier.slim,
                  onTap: () => onClusterTap(cluster),
                );
              }, childCount: slim.length * 2 - 1),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

List<InterestCluster> _displayClustersForThemes(List<ClusterTheme> themes) {
  final orderedThemes = _mergeThemesForDisplay(themes)
    ..sort((a, b) => b.urls.length.compareTo(a.urls.length));
  final totalSaves = orderedThemes.fold<int>(
    0,
    (sum, t) => sum + t.urls.length,
  );
  if (totalSaves <= 0) return const [];
  final topLabels = {
    for (final theme in orderedThemes) theme.label.trim().toLowerCase(),
  };

  return [
    for (final theme in orderedThemes)
      if (theme.urls.length >= 3 && _isDisplaySafeLabel(theme.label))
        InterestCluster(
          id: theme.index.toString(),
          label: theme.label.trim(),
          saveCount: theme.urls.length,
          subtopics: _displaySubtopics(theme, topLabels),
          dominance: theme.urls.length / totalSaves,
          coverImageUrl: null,
          accentColor: theme.accentColor,
        ),
  ].take(12).toList();
}

class _MasonryClusterGrid extends StatelessWidget {
  const _MasonryClusterGrid({required this.items, required this.onOpen});

  final List<InterestCluster> items;
  final ValueChanged<InterestCluster> onOpen;

  @override
  Widget build(BuildContext context) {
    final columns = _masonryColumns(items);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _MasonryColumn(items: columns.$1, onOpen: onOpen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MasonryColumn(items: columns.$2, onOpen: onOpen),
        ),
      ],
    );
  }
}

class _MasonryColumn extends StatelessWidget {
  const _MasonryColumn({required this.items, required this.onOpen});

  final List<InterestCluster> items;
  final ValueChanged<InterestCluster> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          ClusterCard(
            cluster: items[i],
            tier: ClusterCardTier.medium,
            onTap: () => onOpen(items[i]),
          ),
          if (i != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

(List<InterestCluster>, List<InterestCluster>) _masonryColumns(
  List<InterestCluster> items,
) {
  final left = <InterestCluster>[];
  final right = <InterestCluster>[];
  var leftHeight = 0.0;
  var rightHeight = 0.0;

  for (final item in items) {
    final height = mediumClusterTileHeight(item);
    if (leftHeight <= rightHeight) {
      left.add(item);
      leftHeight += height + 10;
    } else {
      right.add(item);
      rightHeight += height + 10;
    }
  }

  return (left, right);
}

List<ClusterTheme> _mergeThemesForDisplay(List<ClusterTheme> themes) {
  final groups = <String, List<ClusterTheme>>{};
  for (final theme in themes) {
    final key = theme.label.trim().toLowerCase();
    if (key.isEmpty) continue;
    groups.putIfAbsent(key, () => <ClusterTheme>[]).add(theme);
  }

  final merged = <ClusterTheme>[];
  for (final group in groups.values) {
    final urlsById = <int, SavedUrl>{};
    final subtopicsByLabel = <String, SubClusterTheme>{};

    for (final theme in group) {
      for (final url in theme.urls) {
        urlsById[url.id] = url;
      }
      for (final sub in theme.subClusters) {
        final key = sub.label.trim().toLowerCase();
        if (key.isEmpty) continue;
        final existing = subtopicsByLabel[key];
        if (existing == null) {
          subtopicsByLabel[key] = sub;
        } else {
          final subUrls = {for (final url in existing.urls) url.id: url};
          for (final url in sub.urls) {
            subUrls[url.id] = url;
          }
          subtopicsByLabel[key] = SubClusterTheme(
            label: existing.label,
            summary: existing.summary,
            urls: subUrls.values.toList(),
          );
        }
      }
    }

    final first = group.first;
    merged.add(
      ClusterTheme(
        index: merged.length,
        label: first.label,
        summary: first.summary,
        urls: urlsById.values.toList(),
        subClusters: subtopicsByLabel.values.toList()
          ..sort((a, b) => b.urls.length.compareTo(a.urls.length)),
      ),
    );
  }

  return merged;
}

List<String> _displaySubtopics(ClusterTheme theme, Set<String> topLabels) {
  final parent = theme.label.trim().toLowerCase();
  final seen = <String>{};
  final out = <String>[];

  void take(Iterable<String> labels) {
    for (final raw in labels) {
      final label = raw.trim();
      final key = label.toLowerCase();
      if (!_isDisplaySafeLabel(label)) continue;
      if (key == parent) continue;
      if (topLabels.contains(key)) continue;
      if (!seen.add(key)) continue;
      out.add(label);
      if (out.length >= 4) break;
    }
  }

  // Curated + tag-frequency subtopics first: these are aggregate signals, so a
  // single mis-clustered link (e.g. a stray "Food & Cooking" bookmark grouped
  // under Dev Tools) can't surface as its own chip. Raw sub-cluster labels —
  // which amplify such outliers — are only used to fill any remaining slots.
  take(_curatedFallbackSubtopics(theme));
  take(theme.subClusters.map((sub) => sub.label));
  return out;
}

List<String> _curatedFallbackSubtopics(ClusterTheme theme) {
  final label = theme.label.toLowerCase();
  final text = _themeSignalText(theme);

  if (_hasAny(label, ['ai agent', 'ai agents'])) {
    return [
      if (_hasAny(text, ['claude', 'openai', 'anthropic'])) 'Claude & OpenAI',
      if (_hasAny(text, ['workflow', 'agent'])) 'Workflows',
      if (_hasAny(text, ['llm', 'internals', 'prompt'])) 'LLMs',
      'Automation',
    ];
  }
  if (_hasAny(label, ['dev tools', 'oss'])) {
    return [
      if (_hasAny(text, ['github', 'repo'])) 'GitHub',
      if (_hasAny(text, ['oss', 'open source'])) 'OSS',
      if (_hasAny(text, ['react', 'next', 'vercel'])) 'Frameworks',
      if (_hasAny(text, ['linear', 'sync', 'backend'])) 'Backend',
      'Repos',
    ];
  }
  if (_hasAny(label, ['treks'])) {
    return [
      if (_hasAny(text, ['himalaya', 'nepal', 'kanchenjunga'])) 'Himalayan',
      if (_hasAny(text, ['new zealand', 'te araroa'])) 'New Zealand',
      if (_hasAny(text, ['iceland'])) 'Iceland',
      if (_hasAny(text, ['trail', 'mountain'])) 'Mountain routes',
    ];
  }
  if (_hasAny(label, ['website growth'])) {
    return [
      if (_hasAny(text, ['seo'])) 'SEO',
      if (_hasAny(text, ['search console'])) 'Search Console',
      if (_hasAny(text, ['revenue', 'conversion'])) 'Revenue',
    ];
  }
  if (_hasAny(label, ['typography'])) {
    return ['Fonts', 'Typography', 'UI tools'];
  }
  if (_hasAny(label, ['design system'])) {
    return ['Patterns', 'Components', 'UI tools'];
  }

  final counts = <String, int>{};
  for (final url in theme.urls) {
    for (final tag in TagNoiseFilter.filterTags(url.tags)) {
      final cleaned = tag.trim();
      final key = cleaned.toLowerCase();
      if (key.isEmpty || key.length > 22) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final ranked = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return ranked.take(4).map((entry) => _titleCaseLabel(entry.key)).toList();
}

String _themeSignalText(ClusterTheme theme) {
  return theme.urls
      .map(
        (url) => [
          url.title,
          url.description,
          url.summary ?? '',
          url.domain,
          url.tags.join(' '),
        ].join(' '),
      )
      .join(' ')
      .toLowerCase();
}

String _titleCaseLabel(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) {
        const keepUpper = {'ai', 'ui', 'ux', 'seo', 'oss', 'llm'};
        if (keepUpper.contains(word.toLowerCase())) return word.toUpperCase();
        return word.length == 1
            ? word.toUpperCase()
            : '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}

bool _hasAny(String text, List<String> needles) {
  return needles.any(text.contains);
}

bool _isDisplaySafeLabel(String label) {
  final trimmed = label.trim();
  final lower = trimmed.toLowerCase();
  if (trimmed.isEmpty) return false;
  if (lower.contains('interest group')) return false;
  if (RegExp(r'^technology\s+\d+$').hasMatch(lower)) return false;
  if (RegExp(r'\b[a-z0-9-]+\.(com|in|org|net|io|ai|dev)\b').hasMatch(lower)) {
    return false;
  }
  return true;
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
          height: 1.18,
        ),
      ),
    );
  }
}

// ─── Sub-cluster filter chip ──────────────────────────────────────────────

class _SubChip extends StatelessWidget {
  const _SubChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.cs,
    required this.tt,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Selected → calm secondaryContainer pill (the app's selected-state colour).
    // Unselected → faint surface with a hairline border.
    final bgColor = selected ? cs.secondaryContainer : cs.surfaceContainerHigh;
    final textColor = selected ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    final badgeBg = selected
        ? cs.onSecondaryContainer.withValues(alpha: 0.14)
        : cs.onSurfaceVariant.withValues(alpha: 0.10);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                  width: 1.0,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: textColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClusterUrlRow extends StatelessWidget {
  const _ClusterUrlRow({
    required this.url,
    required this.tagFrequency,
    required this.onTap,
    this.subLabel,
  });

  final SavedUrl url;
  final Map<String, int> tagFrequency;
  final VoidCallback onTap;

  /// When non-null, shown as a small tag on the row (visible in "All" view
  /// so users can see which sub-cluster each URL belongs to).
  final String? subLabel;

  static const double _thumb = 52;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final previewUrl = _previewImageUrl(url);
    final resolvedTitle = TitleResolver.resolveDetailTitle(
      url,
      tagFrequency: tagFrequency,
    );
    final title = _displayTitleForUrl(url, resolvedTitle);
    if (title == null) return const SizedBox.shrink();
    final chip = tagChipColors(cs);
    final placeholder = _UrlPlaceholder(
      letter: url.domain.isNotEmpty ? url.domain[0].toUpperCase() : '?',
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail
              Container(
                width: _thumb,
                height: _thumb,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: previewUrl != null
                    ? CachedNetworkImage(
                        imageUrl: previewUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 150),
                        placeholder: (_, _) => placeholder,
                        errorWidget: (_, _, _) => placeholder,
                      )
                    : placeholder,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: cs.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            url.domain,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (subLabel != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: chip.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              subLabel!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: chip.foreground,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrlPlaceholder extends StatelessWidget {
  const _UrlPlaceholder({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Text(
          letter.isNotEmpty ? letter[0].toUpperCase() : '?',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

String? _displayTitleForUrl(SavedUrl url, String resolvedTitle) {
  final cleanedTitle = TitleCleaner.clean(resolvedTitle);
  if (cleanedTitle != null) return cleanedTitle;

  final fallback =
      TitleCleaner.clean(url.description) ?? TitleCleaner.clean(url.summary);
  if (fallback == null) return null;
  return fallback.length <= 80 ? fallback : '${fallback.substring(0, 80)}...';
}

// ─── Empty state ───────────────────────────────────────────────────────────

class _MindmapEmptyState extends StatelessWidget {
  const _MindmapEmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/mindmap.png',
              width: 128,
              height: 128,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              'Your interest map is empty',
              style: tt.titleSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Save at least 3 links and the map will auto-generate clusters of your interests.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Main screen ───────────────────────────────────────────────────────────

class MindmapScreen extends ConsumerWidget {
  const MindmapScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final themesAsync = ref.watch(interestClusterThemesProvider);
    final subtitle = themesAsync.maybeWhen(
      data: (themes) {
        final clusters = _displayClustersForThemes(themes);
        final saveCount = clusters.fold<int>(
          0,
          (sum, cluster) => sum + cluster.saveCount,
        );
        return '${clusters.length} themes · $saveCount saves';
      },
      orElse: () => 'Mapping your saves',
    );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Interest map',
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            Text(
              subtitle,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rebuild map',
            onPressed: () async {
              HapticFeedback.lightImpact();
              await clearInterestClusterCache();
              ref.invalidate(interestClusterThemesProvider);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: themesAsync.when(
        loading: () =>
            const LoadingIndicator(message: 'Mapping your interests...'),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 40, color: cs.error),
                const SizedBox(height: 14),
                Text(
                  'Could not build clusters',
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (themes) {
          if (themes.isEmpty || themes.length < 3) {
            return const _MindmapEmptyState();
          }

          return _MindmapCanvas(themes: themes);
        },
      ),
    );
  }
}

class MindmapClusterScreen extends ConsumerStatefulWidget {
  const MindmapClusterScreen({super.key, required this.clusterId});

  final int clusterId;

  @override
  ConsumerState<MindmapClusterScreen> createState() =>
      _MindmapClusterScreenState();
}

class _MindmapClusterScreenState extends ConsumerState<MindmapClusterScreen> {
  int? _selectedSub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final themesAsync = ref.watch(interestClusterThemesProvider);
    final tagFrequency = ref.watch(tagOccurrenceMapProvider);

    return themesAsync.when(
      loading: () => const Scaffold(
        body: LoadingIndicator(message: 'Opening interest...'),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              'Could not open this interest.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (themes) {
        final theme = _themeById(themes, widget.clusterId);
        if (theme == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Interest not found')),
          );
        }

        final subClusters = theme.subClusters;
        final selectedSub =
            _selectedSub != null && _selectedSub! < subClusters.length
            ? subClusters[_selectedSub!]
            : null;
        final visibleUrls = selectedSub?.urls ?? theme.urls;
        final subLabelByUrl = <int, String>{};
        for (final sub in subClusters) {
          for (final url in sub.urls) {
            subLabelByUrl[url.id] = sub.label;
          }
        }

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            titleSpacing: 0,
            title: Text(
              theme.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
          ),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    Text(
                      _clusterDetailSummary(theme),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    if (subClusters.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _SubChip(
                              label: 'All',
                              count: theme.urls.length,
                              selected: _selectedSub == null,
                              cs: cs,
                              tt: tt,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedSub = null);
                              },
                            ),
                            for (var i = 0; i < subClusters.length; i++) ...[
                              const SizedBox(width: 8),
                              _SubChip(
                                label: subClusters[i].label,
                                count: subClusters[i].urls.length,
                                selected: _selectedSub == i,
                                cs: cs,
                                tt: tt,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedSub = i);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index.isOdd) {
                      return Divider(
                        height: 1,
                        indent: 92,
                        endIndent: 20,
                        color: cs.outlineVariant.withValues(alpha: 0.28),
                      );
                    }
                    final url = visibleUrls[index ~/ 2];
                    final clusterIds = visibleUrls.map((u) => u.id).toList();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _ClusterUrlRow(
                        url: url,
                        tagFrequency: tagFrequency,
                        subLabel: selectedSub == null
                            ? subLabelByUrl[url.id]
                            : null,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/url/${url.id}', extra: clusterIds);
                        },
                      ),
                    );
                  },
                  childCount: visibleUrls.isEmpty
                      ? 0
                      : visibleUrls.length * 2 - 1,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        );
      },
    );
  }
}

ClusterTheme? _themeById(List<ClusterTheme> themes, int id) {
  for (final theme in themes) {
    if (theme.index == id) return theme;
  }
  return null;
}

String _clusterDetailSummary(ClusterTheme theme) {
  final topics = theme.subClusters
      .map((sub) => sub.label.trim())
      .where((label) => label.isNotEmpty)
      .take(3)
      .toList();
  if (topics.isEmpty) {
    return '${theme.urls.length} saves in this interest.';
  }
  return '${theme.urls.length} saves across ${_naturalJoin(topics)} topics.';
}

String _naturalJoin(List<String> values) {
  if (values.length <= 1) return values.join();
  if (values.length == 2) return '${values[0]} and ${values[1]}';
  return '${values.take(values.length - 1).join(', ')}, and ${values.last}';
}
