import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/rediscovery_service.dart';
import '../../core/services/title_resolver.dart';
import 'home_provider.dart';
import 'rediscovery_provider.dart';

class RediscoverySection extends ConsumerWidget {
  const RediscoverySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rediscoveryLinksProvider);
    return async.when(
      data: (links) {
        if (links.isEmpty) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final tagFreq = ref.watch(tagOccurrenceMapProvider);
        final size = MediaQuery.sizeOf(context);
        final isTablet = size.width > 600;

        final cardWidth = isTablet
            ? (size.width - 48) / 2.8
            : (size.width - 36) / 1.7;
        final cardHeight = cardWidth * 0.65;
        final previewCount = isTablet ? links.length : links.length.clamp(0, 5);

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tappable header row with chevron
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 2),
                child: InkWell(
                  onTap: () => context.push('/rediscover'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 0, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rediscover',
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                  letterSpacing: -0.15,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Based on your activity',
                                style: tt.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: cardHeight + 8, // breathing room
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: previewCount,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _RediscoveryCard(
                    url: links[i],
                    tagFrequency: tagFreq,
                    width: cardWidth,
                    height: cardHeight,
                    onTap: () async {
                      final svc = RediscoveryService(
                        ref.read(isarServiceProvider),
                      );
                      await svc.markResurfaced(links[i].id);
                      await svc.markOpened(links[i].id);
                      ref.invalidate(rediscoveryLinksProvider);
                      if (context.mounted) {
                        context.push('/url/${links[i].id}');
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RediscoveryCard extends StatelessWidget {
  const _RediscoveryCard({
    required this.url,
    required this.tagFrequency,
    required this.onTap,
    required this.width,
    required this.height,
  });

  final SavedUrl url;
  final Map<String, int> tagFrequency;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    final photoTextColor = isLight ? cs.scrim : cs.inverseSurface;
    final photoMetaColor = isLight
        ? cs.scrim.withValues(alpha: 0.60)
        : cs.inverseSurface.withValues(alpha: 0.50);
    final hasThumbnail =
        url.thumbnailUrl != null && url.thumbnailUrl!.isNotEmpty;
    final title = TitleResolver.resolve(url, tagFrequency: tagFrequency);

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      elevation: isLight ? 1 : 0,
      shadowColor: cs.shadow.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasThumbnail)
                CachedNetworkImage(
                  imageUrl: url.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              // Stronger cinematic gradient
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: hasThumbnail
                        ? isLight
                            ? [
                                cs.surface.withValues(alpha: 0.04),
                                cs.surface.withValues(alpha: 0.18),
                                cs.surface.withValues(alpha: 0.62),
                                cs.surface.withValues(alpha: 0.88),
                              ]
                            : [
                                cs.scrim.withValues(alpha: 0.08),
                                cs.scrim.withValues(alpha: 0.30),
                                cs.scrim.withValues(alpha: 0.70),
                                cs.scrim.withValues(alpha: 0.92),
                              ]
                        : [
                            cs.surfaceContainerLow,
                            cs.surfaceContainerLow,
                          ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: hasThumbnail
                            ? photoTextColor.withValues(alpha: 0.92)
                            : cs.onSurface,
                        height: 1.2,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      url.domain,
                      style: tt.labelSmall?.copyWith(
                        fontSize: 10,
                        color: hasThumbnail
                            ? photoMetaColor
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
