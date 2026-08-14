import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/engagement_event.dart';
import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/rediscovery_service.dart';
import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import 'rediscover_provider.dart';

class RediscoverRecapDetailScreen extends ConsumerWidget {
  const RediscoverRecapDetailScreen({super.key, required this.recap});

  final RediscoverRecap recap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final urls = _uniqueUrls(recap);
    final ids = urls.map((url) => url.id).toList();
    final cadence = switch (recap.cadence) {
      RediscoverRecapCadence.daily => 'Daily recap',
      RediscoverRecapCadence.weekly => 'Weekly recap',
      RediscoverRecapCadence.monthly => 'Monthly recap',
    };

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: const AppGlassSurface(),
            title: Text(
              cadence,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recap.title,
                    style: tt.headlineSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    recap.subtitle,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final url = urls[index];
              return SwipeableUrlCard(
                key: ValueKey(url.id),
                url: url,
                onTap: () => _openUrl(context, ref, url, ids),
              );
            }, childCount: urls.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Future<void> _openUrl(
    BuildContext context,
    WidgetRef ref,
    SavedUrl url,
    List<int> ids,
  ) async {
    HapticFeedback.lightImpact();
    final service = RediscoveryService(ref.read(isarServiceProvider));
    await service.markResurfaced(url.id);
    await service.markOpened(url.id);
    unawaited(
      ref
          .read(isarServiceProvider)
          .logEvent(
            type: EngagementEventType.cardOpened,
            url: url,
            clusterLabel: recap.title,
          ),
    );
    if (context.mounted) {
      context.push('/url/${url.id}', extra: ids);
    }
  }
}

List<SavedUrl> _uniqueUrls(RediscoverRecap recap) {
  final seen = <int>{};
  return [
    for (final item in recap.items)
      if (seen.add(item.url.id)) item.url,
  ];
}
