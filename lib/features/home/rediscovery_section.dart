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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'From your archive',
                  style: tt.labelMedium?.copyWith(
                    color: cs.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: links.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _RediscoveryMiniCard(
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

class _RediscoveryMiniCard extends StatelessWidget {
  const _RediscoveryMiniCard({
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
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasThumbnail)
                CachedNetworkImage(
                  imageUrl: url.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              // Gradient scrim so text is always readable
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: hasThumbnail
                        ? [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.78),
                          ]
                        : [
                            cs.surfaceContainerHigh,
                            cs.surfaceContainerHigh,
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
                      url.title,
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hasThumbnail ? Colors.white : null,
                        height: 1.25,
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
