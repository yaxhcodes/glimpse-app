import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/tag_noise_filter.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/widgets/url_card.dart';
import '../home/home_provider.dart';

/// Shows links for a single notification by exact Isar IDs (no category filter).
class NotificationDetailScreen extends ConsumerStatefulWidget {
  const NotificationDetailScreen({
    super.key,
    required this.title,
    required this.linkIds,
  });

  final String title;
  final List<int> linkIds;

  @override
  ConsumerState<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState
    extends ConsumerState<NotificationDetailScreen> {
  List<SavedUrl> _urls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isar = ref.read(isarServiceProvider);
    final out = <SavedUrl>[];
    for (final id in widget.linkIds) {
      final u = await isar.getUrlById(id);
      if (u != null) out.add(u);
    }
    if (!mounted) return;
    setState(() {
      _urls = out;
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    final isar = ref.read(isarServiceProvider);
    final now = DateTime.now();
    for (final u in _urls) {
      await isar.updateOpenedAt(u.id, now);
    }
    if (!mounted) return;
    await _load();
    ref.invalidate(urlStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tagFreq = ref.watch(tagOccurrenceMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification'),
        actions: [
          if (_urls.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _urls.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_off_outlined,
                            size: 56, color: cs.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'These links have been removed',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => context.pop(),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          widget.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final u = _urls[index];
                            final resolvedTitle =
                                TitleResolver.formatForCompactCard(
                              u,
                              TitleResolver.collapseWhitespace(
                                TitleResolver.resolve(u, tagFrequency: tagFreq),
                              ),
                            );
                            final tagPool = TagNoiseFilter.filterTags(u.tags);
                            final chips = TagNoiseFilter.visibleTagsForCard(
                              tagPool,
                              tagFreq,
                            );
                            final isRead = u.openedAt != null;
                            final isLight = theme.brightness == Brightness.light;
                            final platformLabel =
                                CategoryResolver.displaySourceName(
                              rawUrl: u.rawUrl,
                              fallbackDomain: u.domain,
                            );
                            final metaStyle =
                                TextStyle(fontSize: 12, color: cs.onSurfaceVariant);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              clipBehavior: Clip.antiAlias,
                              color: UrlCard.listCardFillColor(theme),
                              elevation: 0,
                              shape: UrlCard.listCardShape(theme, radius: 12),
                              child: InkWell(
                                onTap: () => context.push('/url/${u.id}'),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AnimatedOpacity(
                                        opacity:
                                            (isRead && isLight) ? 0.45 : 1.0,
                                        duration:
                                            const Duration(milliseconds: 300),
                                        child: Text(
                                          resolvedTitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: (theme.textTheme.titleSmall ??
                                                  const TextStyle())
                                              .copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: (theme.textTheme
                                                        .titleSmall?.fontSize ??
                                                    14) +
                                                0.5,
                                            color: cs.onSurface,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(platformLabel, style: metaStyle),
                                          Text(' · ', style: metaStyle),
                                          Text(
                                            UrlCard.timeAgoSaved(u.savedAt),
                                            style: metaStyle,
                                          ),
                                        ],
                                      ),
                                      if (chips.visible.isNotEmpty ||
                                          chips.overflow > 0) ...[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            ...chips.visible.map(
                                              (t) => Chip(
                                                label: Text(
                                                  t,
                                                  style: theme.textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                    color: cs.onSurfaceVariant
                                                        .withValues(
                                                            alpha: 0.85),
                                                  ),
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ),
                                            if (chips.overflow > 0)
                                              Chip(
                                                label: Text(
                                                  '+${chips.overflow}',
                                                  style: theme.textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: _urls.length,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
