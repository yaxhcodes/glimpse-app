import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/bulk_selection_provider.dart';
import '../../shared/widgets/bulk_selection_toolbar.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import 'sources_provider.dart';

class SourceDetailScreen extends ConsumerWidget {
  const SourceDetailScreen({super.key, required this.sourceName});

  final String sourceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlsAsync = ref.watch(sourceUrlsProvider(sourceName));
    final cs = Theme.of(context).colorScheme;
    final selectionScope = 'source-$sourceName';
    final selectionState = ref.watch(bulkSelectionProvider(selectionScope));
    final selectionNotifier = ref.read(
      bulkSelectionProvider(selectionScope).notifier,
    );
    final visibleUrls = urlsAsync.valueOrNull ?? [];
    final selectedUrls = visibleUrls
        .where((url) => selectionState.selectedIds.contains(url.id))
        .toList();

    return PopScope(
      canPop: !selectionState.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectionState.isActive) {
          selectionNotifier.clear();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        body: urlsAsync.when(
          loading: () => CustomScrollView(
            slivers: [
              SliverAppBar.large(title: Text(sourceName)),
              const SliverFillRemaining(child: LoadingIndicator()),
            ],
          ),
          error: (err, stack) => CustomScrollView(
            slivers: [
              SliverAppBar.large(title: Text(sourceName)),
              SliverFillRemaining(
                child: Center(child: Text('Could not load this source')),
              ),
            ],
          ),
          data: (urls) {
            if (selectionState.enabled &&
                selectedUrls.length != selectionState.count) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                selectionNotifier.pruneToVisible(urls.map((url) => url.id));
              });
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar.large(
                  title: selectionState.isActive
                      ? BulkSelectionTitle(count: selectedUrls.length)
                      : Text(
                          sourceName,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                  leading: selectionState.isActive
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Exit selection',
                          onPressed: selectionNotifier.clear,
                        )
                      : null,
                  actions: selectionState.isActive
                      ? [
                          BulkSelectionActionButtons(
                            scope: selectionScope,
                            selectedUrls: selectedUrls,
                            visibleUrls: urls,
                            onDone: () {
                              selectionNotifier.clear();
                              ref.invalidate(sourceUrlsProvider(sourceName));
                            },
                          ),
                        ]
                      : null,
                ),
                if (urls.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('No saves from this source')),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        '${urls.length} ${urls.length == 1 ? 'save' : 'saves'} from this source',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final url = urls[index];
                      final allIds = urls.map((u) => u.id).toList();
                      return SwipeableUrlCard(
                        key: ValueKey(url.id),
                        url: url,
                        selectionMode: selectionState.isActive,
                        isSelected: selectionState.isSelected(url.id),
                        onSelectionStart: () =>
                            selectionNotifier.startWith(url.id),
                        onSelectionToggle: () =>
                            selectionNotifier.toggle(url.id),
                        onTap: () =>
                            context.push('/url/${url.id}', extra: allIds),
                        onDelete: (context, ref, url) async {
                          await deleteUrlWithUndo(context, ref, url);
                          ref.invalidate(sourceUrlsProvider(sourceName));
                        },
                        onChanged: () {
                          ref.invalidate(sourceUrlsProvider(sourceName));
                        },
                      );
                    }, childCount: urls.length),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
