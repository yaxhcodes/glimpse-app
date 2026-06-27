import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/bulk_selection_provider.dart';
import '../../shared/widgets/bulk_selection_toolbar.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/premium_design_system.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import 'sources_provider.dart';

class SourceDetailScreen extends ConsumerWidget {
  const SourceDetailScreen({super.key, required this.sourceName});

  final String sourceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlsAsync = ref.watch(sourceUrlsProvider(sourceName));
    final sourceCluster = ref.watch(sourceClustersProvider).valueOrNull
        ?.where((cluster) => cluster.name == sourceName)
        .firstOrNull;
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
                    child: _SourceMetadataHeader(
                      urls: urls,
                      cluster: sourceCluster,
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

class _SourceMetadataHeader extends StatelessWidget {
  const _SourceMetadataHeader({
    required this.urls,
    required this.cluster,
  });

  final List<SavedUrl> urls;
  final SourceCluster? cluster;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lastSaved = cluster?.lastSavedAt ?? _lastSavedFromUrls(urls);
    final topics = cluster?.mostlyAbout ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Metric(
                label: urls.length == 1 ? 'Save' : 'Saves',
                value: urls.length.toString(),
              ),
              const SizedBox(width: 18),
              if (lastSaved != null)
                _Metric(label: 'Last saved', value: _timeAgo(lastSaved)),
            ],
          ),
          if (topics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Topics',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final topic in topics.take(5))
                  MonochromePill(topic, compact: true),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Content',
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _lastSavedFromUrls(List<SavedUrl> urls) {
    DateTime? latest;
    for (final item in urls) {
      final savedAt = item.savedAt;
      if (latest == null || savedAt.isAfter(latest)) latest = savedAt;
    }
    return latest;
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: tt.titleMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
