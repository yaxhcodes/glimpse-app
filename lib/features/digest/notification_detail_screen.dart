import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/category_resolver.dart';
import '../../core/services/notification_category_summary.dart';
import '../../core/services/title_resolver.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/notifications/curated_notification_media.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../../shared/widgets/url_card.dart';
import '../home/home_provider.dart';

/// Shows links for a single notification by exact Isar IDs (no category filter).
class NotificationDetailScreen extends ConsumerStatefulWidget {
  const NotificationDetailScreen({
    super.key,
    required this.title,
    required this.linkIds,
    this.insightLine,
  });

  final String title;
  final List<int> linkIds;

  /// From notification body when opened via router payload.
  final String? insightLine;

  @override
  ConsumerState<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState
    extends ConsumerState<NotificationDetailScreen>
    with SingleTickerProviderStateMixin {
  List<SavedUrl> _urls = [];
  bool _loading = true;
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    );
    _load();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final isar = ref.read(isarServiceProvider);
    final out = await isar.getUrlsByIdsOrdered(widget.linkIds);
    if (!mounted) return;
    setState(() {
      _urls = out;
      _loading = false;
    });
    _entrance.forward(from: 0);
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

  String _effectiveInsight() {
    final direct = widget.insightLine?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return _syntheticInsight(_urls);
  }

  /// Fallback when no stored notification body exists — conversational, no raw counts.
  static String _syntheticInsight(List<SavedUrl> urls) {
    if (urls.length < 2) return '';
    final ranked = NotificationCategorySummary.ranked(urls);
    if (ranked.isEmpty) return '';

    final a = ranked.first.label;
    if (ranked.length >= 2 && ranked[1].count >= 2) {
      return 'Reads like a blend of $a and ${ranked[1].label}.';
    }
    return 'Mostly in the vein of $a.';
  }

  Widget _leadingThumb(SavedUrl u) {
    return CuratedNotificationThumbStripItem(url: u, size: 56);
  }

  /// Unified card row with curated thumbnails (same priority rules as hub).
  Widget _linkRow(
    BuildContext context,
    SavedUrl u,
    ThemeData theme,
    ColorScheme cs,
    Map<String, int> tagFreq,
    int animationIndex,
    double entranceT,
  ) {
    final resolvedTitle = TitleResolver.resolveDetailTitle(
      u,
      tagFrequency: tagFreq,
    );
    final isRead = u.openedAt != null;
    final isLight = theme.brightness == Brightness.light;
    final platformLabel = CategoryResolver.displaySourceName(
      rawUrl: u.rawUrl,
      fallbackDomain: u.domain,
    );
    final metaStyle = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);

    final stagger = (animationIndex * 0.06).clamp(0.0, 0.35);
    final rowT = ((entranceT - stagger) / (1 - stagger)).clamp(0.0, 1.0);

    return Opacity(
      opacity: rowT,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - rowT)),
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          color: UrlCard.listCardFillColor(theme),
          elevation: 0,
          shape: UrlCard.listCardShape(theme, radius: 12),
          child: InkWell(
            onTap: () => context.push(
              '/url/${u.id}',
              extra: _urls.map((url) => url.id).toList(),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _leadingThumb(u),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedOpacity(
                          opacity: (isRead && isLight) ? 0.45 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            resolvedTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                (theme.textTheme.titleSmall ??
                                        const TextStyle())
                                    .copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize:
                                          (theme
                                                  .textTheme
                                                  .titleSmall
                                                  ?.fontSize ??
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
                              UrlCard.timeAgoSaved(context, u.savedAt),
                              style: metaStyle,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tagFreq = ref.watch(tagOccurrenceMapProvider);
    final entranceAnim = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutCubic,
    );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(context.l10n.notification),
        actions: [
          if (_urls.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: Text(context.l10n.markAllRead),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: ExpressiveLoadingIndicator())
          : _urls.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link_off_outlined,
                      size: 56,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'These links have been removed',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => context.pop(),
                      child: Text(context.l10n.back),
                    ),
                  ],
                ),
              ),
            )
          : AnimatedBuilder(
              animation: _entrance,
              builder: (context, _) {
                final t = entranceAnim.value;
                final insight = _effectiveInsight();
                final onVar = cs.onSurfaceVariant.withValues(alpha: 0.84);

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: entranceAnim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.06),
                            end: Offset.zero,
                          ).animate(entranceAnim),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                        color: cs.onSurface,
                                      ),
                                ),
                                if (insight.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    insight,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      height: 1.45,
                                      color: onVar,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final u = _urls[index];
                          return _linkRow(
                            context,
                            u,
                            theme,
                            cs,
                            tagFreq,
                            index,
                            t,
                          );
                        }, childCount: _urls.length),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
