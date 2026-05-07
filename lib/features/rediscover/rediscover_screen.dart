import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/service_providers.dart';
import '../../core/services/rediscovery_service.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/widgets/premium_design_system.dart';
import '../home/home_provider.dart';
import 'rediscover_provider.dart';

class RediscoverScreen extends ConsumerWidget {
  const RediscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;

    final recentlyAsync = ref.watch(recentlyResurfacingProvider);
    final worthRevisitingAsync = ref.watch(worthRevisitingProvider);
    final interestsAsync = ref.watch(interestBasedRediscoveryProvider);

    return Scaffold(
      backgroundColor: premiumBackground(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: premiumBackground(context),
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Rediscover',
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Recently resurfacing',
              asyncValue: recentlyAsync,
              emptyMessage: 'No revisits yet',
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Worth revisiting',
              asyncValue: worthRevisitingAsync,
              emptyMessage: 'Nothing waiting right now',
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Based on your interests',
              asyncValue: interestsAsync,
              emptyMessage: 'Revisit links to build resurfacing memory',
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

class _Section extends ConsumerWidget {
  final String title;
  final AsyncValue<List<RediscoveryItem>> asyncValue;
  final String emptyMessage;

  const _Section({
    required this.title,
    required this.asyncValue,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tagFreq = ref.watch(tagOccurrenceMapProvider);

    return asyncValue.when(
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: -0.15,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  emptyMessage,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(title, count: items.length),
            _MemoryList(
              items: items,
              tagFrequency: tagFreq,
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: _SectionSkeleton(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MemoryList extends StatelessWidget {
  final List<RediscoveryItem> items;
  final Map<String, int> tagFrequency;

  const _MemoryList({
    required this.items,
    required this.tagFrequency,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.width > 600;

    if (isTablet) {
      final cardWidth = (size.width - 40) / 2;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 12,
          runSpacing: 14,
          children: items.map((item) {
            return SizedBox(
              width: cardWidth,
              child: _MemoryCard(
                item: item,
                tagFrequency: tagFrequency,
              ),
            );
          }).toList(),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _MemoryCard(
        item: items[i],
        tagFrequency: tagFrequency,
      ),
    );
  }
}

class _MemoryCard extends ConsumerWidget {
  final RediscoveryItem item;
  final Map<String, int> tagFrequency;

  const _MemoryCard({
    required this.item,
    required this.tagFrequency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = item.url;
    final title = TitleResolver.resolve(url, tagFrequency: tagFrequency);
    final primarySource = url.effectiveCategories.firstOrNull ?? url.domain;

    return CinematicCard(
      imageUrl: url.thumbnailUrl,
      title: title,
      subtitle: '$primarySource · ${item.timeAgo}',
      reason: item.reason,
      tags: url.tags.take(3).toList(),
      onTap: () async {
        HapticFeedback.lightImpact();
        final svc = RediscoveryService(ref.read(isarServiceProvider));
        await svc.markResurfaced(url.id);
        await svc.markOpened(url.id);
        ref.invalidate(recentlyResurfacingProvider);
        ref.invalidate(worthRevisitingProvider);
        ref.invalidate(interestBasedRediscoveryProvider);
        if (context.mounted) {
          context.push('/url/${url.id}');
        }
      },
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 140,
          height: 16,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}