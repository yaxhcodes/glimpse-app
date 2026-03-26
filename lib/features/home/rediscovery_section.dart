import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/rediscovery_service.dart';
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
                child: Text(
                  'Rediscover',
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  'Based on your activity',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: links.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _RediscoveryCard(
                    url: links[i],
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
    required this.onTap,
  });

  final SavedUrl url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasThumbnail =
        url.thumbnailUrl != null && url.thumbnailUrl!.isNotEmpty;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasThumbnail)
                CachedNetworkImage(
                  imageUrl: url.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: hasThumbnail
                        ? const [0.25, 1.0]
                        : null,
                    colors: hasThumbnail
                        ? [
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.80),
                          ]
                        : [
                            cs.surfaceContainerHigh,
                            cs.surfaceContainerHigh,
                          ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      url.title,
                      style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hasThumbnail ? Colors.white : cs.onSurface,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      url.domain,
                      style: tt.labelSmall?.copyWith(
                        color: hasThumbnail
                            ? Colors.white70
                            : cs.onSurfaceVariant,
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
