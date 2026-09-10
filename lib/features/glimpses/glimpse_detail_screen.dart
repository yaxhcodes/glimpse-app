import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/models/engagement_event.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/title_resolver.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../rediscover/journey_visual.dart';
import '../rediscover/rediscover_memory.dart';
import 'glimpse.dart';
import 'glimpse_copy.dart';
import 'glimpse_journey.dart';
import 'glimpse_save_tile.dart';
import 'glimpse_service.dart';
import 'glimpse_source_sheet.dart';
import 'glimpse_store.dart';
import 'glimpse_synthesis.dart';
import 'glimpse_tile.dart';
import 'glimpse_weekly_review.dart';
import 'glimpse_weekly_preparation.dart';

class GlimpseDetailScreen extends ConsumerStatefulWidget {
  const GlimpseDetailScreen({super.key, required this.glimpseKey});
  final String glimpseKey;
  @override
  ConsumerState<GlimpseDetailScreen> createState() =>
      _GlimpseDetailScreenState();
}

class _GlimpseDetailScreenState extends ConsumerState<GlimpseDetailScreen> {
  String? _openedKey;
  bool _busy = false;

  Future<void> _act(
    Glimpse g,
    GlimpseAction action, {
    bool close = true,
  }) async {
    if (_busy) return;
    if (close) setState(() => _busy = true);
    try {
      await ref.read(glimpseServiceProvider).act(g, action);
      if (close) {
        ref.invalidate(glimpsesProvider);
        if (mounted) context.pop();
      }
    } on Object catch (error, stack) {
      developer.log(
        'Could not update glimpse',
        name: 'GlimpseDetail',
        error: error,
        stackTrace: stack,
      );
      if (close && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.glimpsesActionFailed)),
        );
      }
    } finally {
      if (close && mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSource(Glimpse g, SavedUrl url) async {
    try {
      await ref
          .read(isarServiceProvider)
          .logEvent(
            type: EngagementEventType.cardOpened,
            url: url,
            memoryId: g.key,
            topicKey: g.topicKey,
            surface: 'glimpses',
            algorithmVersion: 'glimpses-v1',
          );
    } on Object catch (error, stack) {
      developer.log(
        'Could not record return',
        name: 'GlimpseDetail',
        error: error,
        stackTrace: stack,
      );
    }
    if (mounted) context.push('/url/${url.id}');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(glimpsesProvider);
    final urls = ref.watch(glimpseSourcesProvider).valueOrNull ?? {};
    final item = state.valueOrNull
        ?.where((s) => s.glimpse.key == widget.glimpseKey)
        .firstOrNull;
    final g = item?.glimpse;
    final l = context.l10n;
    if (g != null && _openedKey != g.key) {
      _openedKey = g.key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_act(g, GlimpseAction.opened, close: false));
      });
    }
    if (g?.isRecap == true) ref.watch(prepareWeeklyReviewProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(g?.isRecap == true ? l.glimpsesWeeklyReview : l.rediscover),
      ),
      body: g == null
          ? Center(
              child: state.isLoading
                  ? const CircularProgressIndicator()
                  : Text(l.glimpsesMissing),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
              children: g.isRecap
                  ? _review(item!, state.valueOrNull ?? [], urls)
                  : _rediscover(g, urls),
            ),
    );
  }

  List<Widget> _rediscover(Glimpse g, Map<int, SavedUrl> urls) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final journey = glimpseJourney(g, l, urls);
    final memory = RediscoverMemory.fromJourney(journey);
    final first =
        g.evidence
            .map((e) => urls[e.sourceId])
            .whereType<SavedUrl>()
            .firstOrNull ??
        g.sourceIds.map((id) => urls[id]).whereType<SavedUrl>().firstOrNull;
    final remaining = g.sourceIds
        .toSet()
        .where((id) => id != first?.id)
        .map((id) => urls[id])
        .whereType<SavedUrl>();
    return [
      RediscoverArtworkCard(
        journey: journey,
        title: glimpseTitle(g, l, urls),
        supportingText: memory.rediscoverCopy.subtitle,
        metadata: l.saveCount(g.sourceIds.length),
        height: 252,
        hero: true,
      ),
      const SizedBox(height: 24),
      Text(l.glimpsesWhyToday, style: theme.textTheme.labelLarge),
      const SizedBox(height: 8),
      Text(
        glimpseWhy(g, l, urls),
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _act(g, GlimpseAction.later),
              icon: const Icon(AppIcons.clock, size: 18),
              label: Text(l.notNow),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _act(g, GlimpseAction.lessLikeThis),
              icon: const Icon(AppIcons.dislike, size: 18),
              label: Text(l.lessLikeThis),
            ),
          ),
        ],
      ),
      if (first != null) ...[
        const SizedBox(height: 24),
        Text(l.glimpsesStartHere, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        GlimpseSaveTile(
          url: first,
          featured: true,
          onTap: () => _openSource(g, first),
        ),
      ],
      if (remaining.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(l.glimpsesMoreToExplore, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final url in remaining)
          GlimpseSaveTile(url: url, onTap: () => _openSource(g, url)),
      ],
    ];
  }

  List<Widget> _review(
    StoredGlimpse item,
    List<StoredGlimpse> all,
    Map<int, SavedUrl> urls,
  ) {
    final g = item.glimpse;
    final review = GlimpseWeeklyReview.build(g, all, urls);
    final l = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final explanation = GlimpseSynthesis.cached(item, locale);
    return [
      Text(
        MaterialLocalizations.of(
          context,
        ).formatMediumDate(g.periodStart ?? g.createdAt),
        style: theme.textTheme.headlineSmall,
      ),
      if (explanation.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(l.glimpsesWhatExplored, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l.glimpsesAiLabel, style: theme.textTheme.labelSmall),
        for (final p in explanation) ...[
          const SizedBox(height: 12),
          SelectableText(
            p.text,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          for (final c in p.citations)
            if (urls[c.sourceId] != null)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  TitleResolver.resolveDetailTitle(urls[c.sourceId]!),
                  style: theme.textTheme.labelLarge,
                ),
                children: [
                  Text(c.quote, style: theme.textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => _openSource(g, urls[c.sourceId]!),
                    child: Text(l.openSavedItem),
                  ),
                ],
              ),
        ],
      ],
      if (review.start != null) ...[
        const SizedBox(height: 24),
        Text(l.glimpsesStartHere, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(switch (review.evidence?.kind) {
          GlimpseEvidenceKind.highlight => l.glimpsesWhyHighlight,
          GlimpseEvidenceKind.note => l.glimpsesWhyNote,
          _ => l.glimpsesReviewStartReason,
        }, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        GlimpseSaveTile(
          url: review.start!,
          featured: true,
          onTap: () => _openSource(g, review.start!),
        ),
        if (review.evidence != null) ...[
          Text(
            glimpseEvidenceLabel(review.evidence!, l),
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          SelectableText(
            review.evidence!.text,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ],
      if (review.connection != null) ...[
        const SizedBox(height: 28),
        Text(l.glimpsesReviewConnection, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        GlimpseTile(
          glimpse: review.connection!,
          urls: urls,
          onTap: () =>
              context.push('/glimpses/detail', extra: review.connection!.key),
        ),
      ],
      const SizedBox(height: 24),
      TextButton(
        onPressed: () => showGlimpseSources(
          context,
          title: l.glimpsesWeeklyReview,
          sources: g.sourceIds
              .map((id) => urls[id])
              .whereType<SavedUrl>()
              .toList(),
        ),
        child: Text(l.glimpsesBrowsePeriod),
      ),
    ];
  }
}
