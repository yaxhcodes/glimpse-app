import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/bulk_selection_provider.dart';
import '../../core/providers/pinned_urls_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/bulk_selection_toolbar.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import '../ask/ask_empty_suggestions_provider.dart';
import '../collections/collections_provider.dart';
import '../home/home_provider.dart';
import '../mindmap/interest_clusters_provider.dart';
import '../rediscover/rediscover_provider.dart';
import 'bin_provider.dart';

class BinScreen extends ConsumerStatefulWidget {
  const BinScreen({super.key});

  @override
  ConsumerState<BinScreen> createState() => _BinScreenState();
}

class _BinScreenState extends ConsumerState<BinScreen> {
  static const _selectionScope = 'bin';

  bool _maintenanceComplete = false;
  final Set<int> _pendingIds = {};

  @override
  void initState() {
    super.initState();
    unawaited(_purgeExpiredItems());
  }

  Future<void> _purgeExpiredItems() async {
    final ids = await ref.read(isarServiceProvider).purgeExpiredBinItems();
    if (ids.isNotEmpty) {
      await ref.read(pinnedUrlsProvider.notifier).unpinAll(ids);
    }
    if (mounted) setState(() => _maintenanceComplete = true);
  }

  void _refreshActiveSurfaces() {
    ref.invalidate(categoriesProvider);
    ref.invalidate(collectionsSummaryProvider);
    ref.invalidate(askEmptySuggestionsProvider);
    ref.invalidate(interestClusterThemesProvider);
    ref.invalidate(rediscoverRecapsProvider);
    ref.invalidate(recentlyResurfacedProvider);
    ref.invalidate(relatedSavesProvider);
  }

  void _markPending(Iterable<int> ids) {
    if (!mounted) return;
    setState(() => _pendingIds.addAll(ids));
  }

  void _releasePending(Iterable<int> ids) {
    if (!mounted) return;
    setState(() => _pendingIds.removeAll(ids));
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _restore(SavedUrl url) async {
    final ids = [url.id];
    _markPending(ids);
    try {
      final restored = await ref
          .read(isarServiceProvider)
          .restoreUrlFromBin(url.id);
      if (!restored) {
        _releasePending(ids);
        _showSnackBar('This item is no longer in Bin');
        return;
      }
      _refreshActiveSurfaces();
      _showSnackBar('Restored');
    } catch (error, stackTrace) {
      debugPrint('Could not restore Bin item: $error\n$stackTrace');
      _releasePending(ids);
      _showSnackBar('Could not restore item');
    }
  }

  Future<void> _restoreMany(List<SavedUrl> urls) async {
    if (urls.isEmpty) return;
    final ids = urls.map((url) => url.id).toList(growable: false);
    _markPending(ids);
    ref.read(bulkSelectionProvider(_selectionScope).notifier).clear();
    try {
      final restored = await ref
          .read(isarServiceProvider)
          .restoreUrlsFromBin(ids);
      if (restored != ids.length) _releasePending(ids);
      if (restored == 0) {
        _showSnackBar('No items were restored');
        return;
      }
      _refreshActiveSurfaces();
      _showSnackBar('$restored ${restored == 1 ? 'item' : 'items'} restored');
    } catch (error, stackTrace) {
      debugPrint('Could not restore Bin items: $error\n$stackTrace');
      _releasePending(ids);
      _showSnackBar('Could not restore items');
    }
  }

  Future<bool> _confirmPermanentDelete({required String title}) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete permanently'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deletePermanently(
    SavedUrl url, {
    bool alreadyConfirmed = false,
  }) async {
    final confirmed =
        alreadyConfirmed ||
        await _confirmPermanentDelete(title: 'Delete permanently?');
    if (!confirmed) return;
    final ids = [url.id];
    _markPending(ids);
    try {
      final deleted = await ref
          .read(isarServiceProvider)
          .deleteUrlPermanently(url.id);
      if (!deleted) {
        _releasePending(ids);
        _showSnackBar('This item is no longer in Bin');
        return;
      }
      await ref.read(pinnedUrlsProvider.notifier).unpin(url.id);
      _showSnackBar('Permanently deleted');
    } catch (error, stackTrace) {
      debugPrint('Could not permanently delete Bin item: $error\n$stackTrace');
      _releasePending(ids);
      _showSnackBar('Could not delete item');
    }
  }

  Future<void> _deleteManyPermanently(List<SavedUrl> urls) async {
    if (urls.isEmpty) return;
    final count = urls.length;
    final confirmed = await _confirmPermanentDelete(
      title: count == 1
          ? 'Delete permanently?'
          : 'Delete $count items permanently?',
    );
    if (!confirmed) return;
    final ids = urls.map((url) => url.id).toList(growable: false);
    _markPending(ids);
    ref.read(bulkSelectionProvider(_selectionScope).notifier).clear();
    try {
      final deletedIds = await ref
          .read(isarServiceProvider)
          .deleteUrlsPermanently(ids);
      if (deletedIds.length != ids.length) _releasePending(ids);
      await ref.read(pinnedUrlsProvider.notifier).unpinAll(deletedIds);
      _showSnackBar(
        '${deletedIds.length} '
        '${deletedIds.length == 1 ? 'item' : 'items'} permanently deleted',
      );
    } catch (error, stackTrace) {
      debugPrint('Could not permanently delete Bin items: $error\n$stackTrace');
      _releasePending(ids);
      _showSnackBar('Could not delete items');
    }
  }

  Future<void> _emptyBin(List<SavedUrl> urls) async {
    final confirmed = await _confirmPermanentDelete(title: 'Empty Bin?');
    if (!confirmed) return;
    final visibleIds = urls.map((url) => url.id).toList(growable: false);
    _markPending(visibleIds);
    try {
      final deletedIds = await ref.read(isarServiceProvider).emptyBin();
      if (deletedIds.length != visibleIds.length) {
        _releasePending(visibleIds);
      }
      await ref.read(pinnedUrlsProvider.notifier).unpinAll(deletedIds);
      _showSnackBar('Bin emptied');
    } catch (error, stackTrace) {
      debugPrint('Could not empty Bin: $error\n$stackTrace');
      _releasePending(visibleIds);
      _showSnackBar('Could not empty Bin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final padding = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );
    final urlsAsync = ref.watch(binUrlsProvider);
    final allUrls = urlsAsync.valueOrNull ?? const <SavedUrl>[];
    final urls = allUrls
        .where((url) => !_pendingIds.contains(url.id))
        .toList(growable: false);
    final selectionState = ref.watch(bulkSelectionProvider(_selectionScope));
    final selectionNotifier = ref.read(
      bulkSelectionProvider(_selectionScope).notifier,
    );
    final selectedUrls = urls
        .where((url) => selectionState.selectedIds.contains(url.id))
        .toList(growable: false);

    final currentIds = allUrls.map((url) => url.id).toSet();
    final stalePendingIds = _pendingIds
        .where((id) => !currentIds.contains(id))
        .toList(growable: false);
    if (stalePendingIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _releasePending(stalePendingIds);
      });
    }
    if (selectionState.enabled && selectedUrls.length != selectionState.count) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        selectionNotifier.pruneToVisible(urls.map((url) => url.id));
      });
    }

    return PopScope(
      canPop: !selectionState.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectionState.isActive) selectionNotifier.clear();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        body: CustomScrollView(
          slivers: [
            if (selectionState.isActive)
              SliverAppBar(
                pinned: true,
                backgroundColor: cs.surface,
                foregroundColor: cs.onSurface,
                leading: IconButton(
                  tooltip: 'Exit selection',
                  onPressed: selectionNotifier.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
                title: BulkSelectionTitle(count: selectedUrls.length),
                actions: [
                  IconButton(
                    tooltip: 'Select all',
                    onPressed: urls.isEmpty
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            selectionNotifier.selectAll(
                              urls.map((url) => url.id),
                            );
                          },
                    icon: const Icon(Icons.select_all_rounded),
                  ),
                  IconButton(
                    tooltip: 'Restore selected',
                    onPressed: selectedUrls.isEmpty
                        ? null
                        : () => unawaited(_restoreMany(selectedUrls)),
                    icon: const Icon(Icons.restore_rounded),
                  ),
                  IconButton(
                    tooltip: 'Delete selected permanently',
                    color: cs.error,
                    onPressed: selectedUrls.isEmpty
                        ? null
                        : () => unawaited(_deleteManyPermanently(selectedUrls)),
                    icon: const Icon(Icons.delete_forever_rounded),
                  ),
                ],
              )
            else
              SliverAppBar.large(
                backgroundColor: cs.surface,
                foregroundColor: cs.onSurface,
                title: const Text('Bin'),
                actions: [
                  if (_maintenanceComplete && urls.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: 'Bin actions',
                      onSelected: (value) {
                        if (value == 'restore') {
                          unawaited(_restoreMany(urls));
                        } else if (value == 'empty') {
                          unawaited(_emptyBin(urls));
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'restore',
                          child: ListTile(
                            leading: Icon(Icons.restore_rounded),
                            title: Text('Restore all'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'empty',
                          child: ListTile(
                            leading: Icon(Icons.delete_forever_rounded),
                            title: Text('Empty Bin'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            if (!_maintenanceComplete || urlsAsync.isLoading)
              const SliverFillRemaining(
                child: Center(child: ExpressiveLoadingIndicator()),
              )
            else if (urlsAsync.hasError)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Could not load Bin',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              )
            else if (urls.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyBin(colorScheme: cs),
              )
            else ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 4, padding, 12),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Deleted items are kept for 30 days, then removed '
                      'permanently the next time Glimpse runs cleanup.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, 32),
                sliver: SliverList.separated(
                  itemCount: urls.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final url = urls[index];
                    return _BinItem(
                      url: url,
                      selectionMode: selectionState.isActive,
                      isSelected: selectionState.isSelected(url.id),
                      onSelectionStart: () {
                        HapticFeedback.selectionClick();
                        selectionNotifier.startWith(url.id);
                      },
                      onSelectionToggle: () {
                        HapticFeedback.selectionClick();
                        selectionNotifier.toggle(url.id);
                      },
                      onRestore: () => unawaited(_restore(url)),
                      onConfirmPermanentDelete: () =>
                          _confirmPermanentDelete(title: 'Delete permanently?'),
                      onDeletePermanently: () =>
                          unawaited(_deletePermanently(url)),
                      onDeletePermanentlyConfirmed: () => unawaited(
                        _deletePermanently(url, alreadyConfirmed: true),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BinItem extends StatelessWidget {
  const _BinItem({
    required this.url,
    required this.selectionMode,
    required this.isSelected,
    required this.onSelectionStart,
    required this.onSelectionToggle,
    required this.onRestore,
    required this.onConfirmPermanentDelete,
    required this.onDeletePermanently,
    required this.onDeletePermanentlyConfirmed,
  });

  final SavedUrl url;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onSelectionStart;
  final VoidCallback onSelectionToggle;
  final VoidCallback onRestore;
  final Future<bool> Function() onConfirmPermanentDelete;
  final VoidCallback onDeletePermanently;
  final VoidCallback onDeletePermanentlyConfirmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final deletedAt = url.deletedAt!;
    final expiresAt = deletedAt.add(const Duration(days: 30));
    final remainingHours = expiresAt.difference(DateTime.now()).inHours;
    final remainingDays = (remainingHours / 24).ceil().clamp(0, 30);
    final expiryLabel = remainingDays == 0
        ? 'Expires today'
        : '$remainingDays ${remainingDays == 1 ? 'day' : 'days'} left';

    return Dismissible(
      key: ValueKey('bin-${url.id}'),
      direction: selectionMode
          ? DismissDirection.none
          : DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.32,
        DismissDirection.endToStart: 0.32,
      },
      background: _SwipeActionBackground(
        alignment: Alignment.centerLeft,
        backgroundColor: cs.tertiaryContainer,
        foregroundColor: cs.onTertiaryContainer,
        icon: Icons.restore_rounded,
        label: 'Restore',
      ),
      secondaryBackground: _SwipeActionBackground(
        alignment: Alignment.centerRight,
        backgroundColor: cs.errorContainer,
        foregroundColor: cs.onErrorContainer,
        icon: Icons.delete_forever_rounded,
        label: 'Delete',
      ),
      confirmDismiss: (direction) {
        if (direction == DismissDirection.endToStart) {
          return onConfirmPermanentDelete();
        }
        return Future.value(true);
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          onRestore();
        } else {
          onDeletePermanentlyConfirmed();
        }
      },
      child: Semantics(
        selected: isSelected,
        child: Card(
          elevation: 0,
          color: isSelected ? cs.secondaryContainer : cs.surfaceContainerLow,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            onTap: selectionMode ? onSelectionToggle : null,
            onLongPress: selectionMode ? onSelectionToggle : onSelectionStart,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    child: selectionMode
                        ? _SelectionIndicator(
                            key: const ValueKey('selection'),
                            selected: isSelected,
                          )
                        : Container(
                            key: const ValueKey('link'),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: AppIcon(
                              AppIcons.link,
                              size: 20,
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TitleResolver.resolveStableDisplayTitle(url),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${url.domain}  ·  $expiryLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!selectionMode)
                    PopupMenuButton<String>(
                      tooltip: 'Item actions',
                      onSelected: (value) {
                        if (value == 'restore') {
                          onRestore();
                        } else if (value == 'delete') {
                          onDeletePermanently();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'restore',
                          child: _ItemMenuRow(
                            icon: Icons.restore_rounded,
                            label: 'Restore',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: _ItemMenuRow(
                            icon: Icons.delete_forever_rounded,
                            label: 'Delete permanently',
                            color: cs.error,
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 40,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? cs.primary : Colors.transparent,
            border: Border.all(
              color: selected ? cs.primary : cs.outline,
              width: selected ? 0 : 1.5,
            ),
          ),
          child: selected
              ? Icon(Icons.check_rounded, size: 19, color: cs.onPrimary)
              : null,
        ),
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final leftAligned = alignment == Alignment.centerLeft;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        alignment: alignment,
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: leftAligned
              ? [
                  Icon(icon, color: foregroundColor),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(color: foregroundColor)),
                ]
              : [
                  Text(label, style: TextStyle(color: foregroundColor)),
                  const SizedBox(width: 8),
                  Icon(icon, color: foregroundColor),
                ],
        ),
      ),
    );
  }
}

class _ItemMenuRow extends StatelessWidget {
  const _ItemMenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }
}

class _EmptyBin extends StatelessWidget {
  const _EmptyBin({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 52,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('Bin is empty', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Items you delete will appear here for 30 days.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
