import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/premium_design_system.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import 'sources_provider.dart';

/// Lists saves the user marked "done" (Already Watched / Read / Tried /
/// Checked). They're archived: hidden from the library, Rediscover and
/// notifications, but never deleted — restorable from here.
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final urlsAsync = ref.watch(archivedUrlsProvider);

    return Scaffold(
      backgroundColor: premiumBackground(context),
      body: urlsAsync.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (urls) => CustomScrollView(
          slivers: [
            SliverAppBar.large(
              backgroundColor: premiumBackground(context),
              surfaceTintColor: Colors.transparent,
              title: Text('Done', style: tt.headlineMedium),
            ),
            if (urls.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 44,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Nothing here yet',
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Saves you mark "Already watched/read/tried" land here.',
                          textAlign: TextAlign.center,
                          style: tt.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '${urls.length} ${urls.length == 1 ? 'save' : 'saves'} · open one to restore it',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final url = urls[index];
                    return SwipeableUrlCard(
                      key: ValueKey(url.id),
                      url: url,
                      onTap: () => context.push('/url/${url.id}'),
                      onDelete: (context, ref, url) async {
                        await deleteUrlWithUndo(context, ref, url);
                        ref.invalidate(archivedUrlsProvider);
                      },
                      onChanged: () => ref.invalidate(archivedUrlsProvider),
                    );
                  },
                  childCount: urls.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ],
        ),
      ),
    );
  }
}
