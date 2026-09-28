import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_haptics.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/widgets/category_chip.dart' show platformColors;
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/expressive_tap_scale.dart';
import '../../shared/widgets/premium_design_system.dart';
import '../../shared/widgets/url_card.dart';
import 'source_visuals.dart';
import 'sources_provider.dart';

/// Where saves come from. The most-saved sources lead as picture cards made
/// of their own newest saves; everything else is a calm grouped list, apps
/// first, then websites, each ordered by how much has been saved from it.
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
      if (_searchController.text != _query) {
        setState(() => _query = _searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final clustersAsync = ref.watch(filteredClustersProvider(_query));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _SourcesAppBar(title: strings.sources),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: PremiumSearchBar(
                controller: _searchController,
                hint: strings.searchSources,
                onClear: _query.isNotEmpty ? _searchController.clear : null,
              ),
            ),
          ),
          ...clustersAsync.when(
            data: (clusters) => _content(context, clusters),
            loading: () => const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: ExpressiveLoadingIndicator()),
              ),
            ],
            error: (_, _) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyMessage(strings.couldNotLoadSources),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, List<SourceCluster> clusters) {
    final strings = context.l10n;
    final searching = _query.trim().isNotEmpty;
    final sources = clusters.where((c) => !c.isEmpty).toList()..sort(_byVolume);
    if (sources.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyMessage(
            searching ? strings.noSourcesMatch(_query) : strings.noSourcesYet,
          ),
        ),
      ];
    }

    if (searching) {
      return [
        _Section(title: strings.results, count: sources.length),
        _SourceGroup(sources: sources),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ];
    }

    bool isApp(SourceCluster c) => platformColors.containsKey(c.name);
    final top = topSourceClusters(sources);
    final apps = sources.where(isApp).toList();
    final websites = sources.where((c) => !isApp(c)).toList();
    return [
      if (top.isNotEmpty) ...[
        _Section(title: strings.topSources),
        SliverToBoxAdapter(child: TopSourcesRail(sources: top)),
      ],
      if (apps.isNotEmpty) ...[
        _Section(title: strings.apps, count: apps.length),
        _SourceGroup(sources: apps),
      ],
      if (websites.isNotEmpty) ...[
        _Section(title: strings.websites, count: websites.length),
        _SourceGroup(sources: websites),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 48)),
    ];
  }

  static int _byVolume(SourceCluster a, SourceCluster b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}

class _SourcesAppBar extends StatelessWidget {
  const _SourcesAppBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar.large(
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      title: Text(
        title,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: context.l10n.done,
          icon: const AppIcon(AppIcons.checkCircle),
          onPressed: () {
            AppHaptics.play(AppHaptics.tap);
            context.push('/archive');
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SectionTitle(title, count: count),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

void _openSource(BuildContext context, SourceCluster source) {
  AppHaptics.play(AppHaptics.tap);
  context.push('/sources/${Uri.encodeComponent(source.name)}');
}

/// One-line summary under a source's name: how much, and how lately.
String _sourceSummary(BuildContext context, SourceCluster source) {
  final strings = context.l10n;
  final parts = [strings.saveCount(source.count)];
  if (source.savesThisWeek > 0) {
    parts.add(strings.savesThisWeek(source.savesThisWeek));
  } else if (source.lastSavedAt != null) {
    parts.add(UrlCard.timeAgoSaved(context, source.lastSavedAt!));
  }
  return parts.join(' · ');
}

/// Sources as one grouped surface, rows divided by hairlines, the way the
/// app's settings read. Built lazily: a library can have hundreds of sites.
class _SourceGroup extends StatelessWidget {
  const _SourceGroup({required this.sources});

  final List<SourceCluster> sources;

  static const _radius = Radius.circular(24);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: sources.length,
        itemBuilder: (context, index) {
          final first = index == 0;
          final last = index == sources.length - 1;
          return Material(
            color: cs.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.vertical(
              top: first ? _radius : Radius.zero,
              bottom: last ? _radius : Radius.zero,
            ),
            child: _SourceRow(source: sources[index], divider: !last),
          );
        },
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.divider});

  final SourceCluster source;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _openSource(context, source),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                SourceLogoTile(
                  name: source.name,
                  fallbackFaviconUrl: source.faviconUrl,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _sourceSummary(context, source),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  AppIcons.chevronRight,
                  size: 20,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          if (divider)
            Positioned(
              left: 70,
              right: 0,
              bottom: 0,
              child: Divider(
                height: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
        ],
      ),
    );
  }
}

/// The most-saved sources as picture cards: a mosaic of their newest saves,
/// the logo seated on its edge, then the name and how much came from it.
class TopSourcesRail extends StatelessWidget {
  const TopSourcesRail({super.key, required this.sources});

  final List<SourceCluster> sources;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < sources.length; index++) ...[
              if (index > 0) const SizedBox(width: 10),
              _TopSourceCard(cluster: sources[index]),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopSourceCard extends StatelessWidget {
  const _TopSourceCard({required this.cluster});

  final SourceCluster cluster;

  static const _width = 164.0;
  static const _mosaicHeight = 124.0;
  static const _badge = 36.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final strings = context.l10n;
    final hasPreviews = cluster.previews.isNotEmpty;

    return SizedBox(
      width: _width,
      child: ExpressiveTapScale(
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openSource(context, cluster),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: _mosaicHeight + _badge / 2,
                  child: Stack(
                    children: [
                      SizedBox(
                        height: _mosaicHeight,
                        width: double.infinity,
                        child: hasPreviews
                            ? SourcePreviewMosaic(previews: cluster.previews)
                            : ColoredBox(color: cs.surfaceContainerHigh),
                      ),
                      // The logo sits half on the pictures, half on the card,
                      // ringed in the card colour.
                      Positioned(
                        left: 12,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: SourceLogoTile(
                            name: cluster.name,
                            fallbackFaviconUrl: cluster.faviconUrl,
                            size: _badge,
                            color: cs.surfaceContainerHighest,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cluster.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.saveCount(cluster.count),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (cluster.savesThisWeek > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          strings.savesThisWeek(cluster.savesThisWeek),
                          style: tt.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
