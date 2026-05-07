import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'batch_save_models.dart';
import 'batch_save_provider.dart';

/// The batch preview screen: a cinematic review surface for a captured
/// "rabbit hole" of URLs before saving them as one session.
class BatchPreviewScreen extends ConsumerStatefulWidget {
  final List<String> urls;

  const BatchPreviewScreen({super.key, required this.urls});

  @override
  ConsumerState<BatchPreviewScreen> createState() => _BatchPreviewScreenState();
}

class _BatchPreviewScreenState extends ConsumerState<BatchPreviewScreen> {
  late final List<String> _urls;

  @override
  void initState() {
    super.initState();
    _urls = List.unmodifiable(widget.urls);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchSaveProvider(_urls));
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    final isSaving = state.status == BatchSaveStatus.saving;
    final isDone = state.status == BatchSaveStatus.done;
    final isEnriching = state.status == BatchSaveStatus.enriching;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button row
                    Row(
                      children: [
                        IconButton(
                          onPressed: isSaving ? null : () => context.pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                    if (isSaving)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      ),
                    if (!isSaving && !isDone)
                      TextButton(
                        onPressed: () => context.pop(),
                        child: Text(
                          'Close',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Count
                    Text(
                      'Save ${state.items.length} link${state.items.length == 1 ? '' : 's'}',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Subtitle
                    Text(
                      _subtitle(state),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Meta pills
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (state.readyCount > 0)
                          _MetaPill(
                            label: '${state.readyCount} ready',
                            color: cs.primaryContainer,
                            textColor: cs.onPrimaryContainer,
                          ),
                        if (state.duplicateCount > 0)
                          _MetaPill(
                            label: '${state.duplicateCount} already saved',
                            color: cs.errorContainer.withValues(alpha: 0.7),
                            textColor: cs.onErrorContainer,
                          ),
                        if (state.errorCount > 0)
                          _MetaPill(
                            label: '${state.errorCount} preview failed',
                            color: cs.tertiaryContainer.withValues(alpha: 0.6),
                            textColor: cs.onTertiaryContainer,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── URL List ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = state.items[index];
                  return _BatchItemCard(
                    item: item,
                    isFirst: index == 0,
                    isLast: index == state.items.length - 1,
                  );
                },
                childCount: state.items.length,
              ),
            ),
          ),
        ],
      ),

      // ── Bottom action bar ──
      bottomNavigationBar: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDone) ...[
                Row(
                  children: [
                    Icon(Icons.check_circle, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${state.savedCount} link${state.savedCount == 1 ? '' : 's'} saved',
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Organizing your rabbit hole...',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ] else if (isEnriching) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${state.savedCount} link${state.savedCount == 1 ? '' : 's'} saved — organizing...',
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ] else if (isSaving) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Saving ${state.savedCount + 1} of ${state.totalToSave}...',
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Saving...'),
                ),
              ] else ...[
                FilledButton(
                  onPressed: state.canSave && !isSaving && !isEnriching
                      ? () async {
                          HapticFeedback.mediumImpact();
                          await ref
                              .read(batchSaveProvider(_urls).notifier)
                              .saveAll();
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text('Save ${state.readyCount} link${state.readyCount == 1 ? '' : 's'}'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(BatchSaveState state) {
    if (state.status == BatchSaveStatus.saving) {
      return 'Saving your links...';
    }
    if (state.status == BatchSaveStatus.enriching) {
      return 'Organizing your rabbit hole in the background...';
    }
    if (state.status == BatchSaveStatus.done) {
      return 'Your rabbit hole has been captured.';
    }
    if (state.items.length > 1) {
      return 'Captured from your research session — review before saving';
    }
    return 'Review before saving';
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _MetaPill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

/// A single URL row inside the batch preview.
class _BatchItemCard extends StatelessWidget {
  final BatchUrlItem item;
  final bool isFirst;
  final bool isLast;

  const _BatchItemCard({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    final isLoading = item.status == BatchItemStatus.fetching ||
        item.status == BatchItemStatus.pending;
    final isDuplicate = item.isDuplicate;

    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 4 : 6,
        bottom: isLast ? 4 : 6,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isDuplicate
              ? cs.errorContainer.withValues(alpha: 0.15)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: isDuplicate
              ? Border.all(
                  color: cs.error.withValues(alpha: 0.25),
                  width: 1,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              _Thumbnail(item: item, size: 56),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoading) ...[
                      _ShimmerLine(width: double.infinity, cs: cs),
                      const SizedBox(height: 6),
                      _ShimmerLine(width: 120, cs: cs),
                    ] else ...[
                      Text(
                        item.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          fontSize: (tt.titleSmall?.fontSize ?? 14) + 0.5,
                          color: isDuplicate
                              ? cs.onSurface.withValues(alpha: 0.5)
                              : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.displayDomain,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Status chip
                    _StatusChip(
                      status: item.status,
                      error: item.error,
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

class _Thumbnail extends StatelessWidget {
  final BatchUrlItem item;
  final double size;

  const _Thumbnail({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: item.thumbnailUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _Placeholder(size: size, cs: cs),
          errorWidget: (context, url, error) => _Placeholder(size: size, cs: cs),
        ),
      );
    }

    if (item.status == BatchItemStatus.fetching ||
        item.status == BatchItemStatus.pending) {
      return _Placeholder(size: size, cs: cs, showShimmer: true);
    }

    return _DomainLetter(item: item, size: size);
  }
}

class _DomainLetter extends StatelessWidget {
  final BatchUrlItem item;
  final double size;

  const _DomainLetter({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final letter = item.displayDomain.isNotEmpty
        ? item.displayDomain[0].toUpperCase()
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w700,
          color: cs.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double size;
  final ColorScheme cs;
  final bool showShimmer;

  const _Placeholder({
    required this.size,
    required this.cs,
    this.showShimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: showShimmer
          ? Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary.withValues(alpha: 0.5),
                ),
              ),
            )
          : null,
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double width;
  final ColorScheme cs;

  const _ShimmerLine({required this.width, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final BatchItemStatus status;
  final String? error;

  const _StatusChip({required this.status, this.error});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (label, color, textColor, icon) = switch (status) {
      BatchItemStatus.pending => (
          'Waiting',
          cs.surfaceContainerHighest.withValues(alpha: 0.5),
          cs.onSurfaceVariant,
          null,
        ),
      BatchItemStatus.fetching => (
          'Fetching preview',
          cs.primaryContainer.withValues(alpha: 0.45),
          cs.onPrimaryContainer,
          null,
        ),
      BatchItemStatus.ready => (
          'Ready',
          cs.primaryContainer.withValues(alpha: 0.35),
          cs.onPrimaryContainer.withValues(alpha: 0.8),
          Icons.check_rounded,
        ),
      BatchItemStatus.duplicate => (
          'Already saved',
          cs.errorContainer.withValues(alpha: 0.6),
          cs.onErrorContainer,
          Icons.bookmark_added_rounded,
        ),
      BatchItemStatus.error => (
          error ?? 'Preview failed',
          cs.tertiaryContainer.withValues(alpha: 0.5),
          cs.onTertiaryContainer,
          null,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
