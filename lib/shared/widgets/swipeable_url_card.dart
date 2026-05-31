import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/pinned_urls_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/swipe_preferences_provider.dart';
import '../../core/services/title_resolver.dart';
import '../../features/collections/add_to_collection_sheet.dart';
import '../../features/collections/collections_provider.dart';
import '../../features/home/home_provider.dart';
import 'premium_swipe_card.dart';
import 'url_card.dart';

class SwipeableUrlCard extends ConsumerWidget {
  const SwipeableUrlCard({
    super.key,
    required this.url,
    this.onTap,
    this.leftSwipeAction,
    this.rightSwipeAction,
    this.onDelete,
    this.onChanged,
    this.onViewPinned,
  });

  final SavedUrl url;
  final VoidCallback? onTap;
  final SwipeActionType? leftSwipeAction;
  final SwipeActionType? rightSwipeAction;
  final Future<void> Function(BuildContext context, WidgetRef ref, SavedUrl url)?
      onDelete;
  final VoidCallback? onChanged;
  final VoidCallback? onViewPinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(swipePreferencesProvider);
    final pinnedIds = ref.watch(pinnedUrlsProvider);
    final left = leftSwipeAction ?? prefs.leftSwipeAction;
    final right = rightSwipeAction ?? prefs.rightSwipeAction;

    return PremiumSwipeCard(
      leftSwipeAction: left,
      rightSwipeAction: right,
      onAction: (action) => _handleAction(context, ref, action),
      onDismissed: (action) async {
        if (action != SwipeActionType.delete) return;
        final delete = onDelete ?? deleteUrlWithUndo;
        await delete(context, ref, url);
      },
      child: UrlCard(
        savedUrl: url,
        isPinned: pinnedIds.contains(url.id),
        onTap: onTap,
      ),
    );
  }

  Future<bool> _handleAction(
    BuildContext context,
    WidgetRef ref,
    SwipeActionType action,
  ) async {
    switch (action) {
      case SwipeActionType.delete:
        return true;
      case SwipeActionType.addToCollection:
        showAddToCollectionSheet(context, url);
        return true;
      case SwipeActionType.pin:
        return _togglePin(context, ref);
      case SwipeActionType.toggleRead:
        await _toggleRead(context, ref);
        return true;
      case SwipeActionType.askGlimpse:
        context.push('/ask');
        return true;
      case SwipeActionType.share:
        await Share.share(url.rawUrl);
        return true;
      case SwipeActionType.none:
        return false;
    }
  }

  Future<bool> _togglePin(BuildContext context, WidgetRef ref) async {
    final pins = ref.read(pinnedUrlsProvider);
    final notifier = ref.read(pinnedUrlsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final wasPinned = pins.contains(url.id);

    if (wasPinned) {
      await notifier.unpin(url.id);
      if (context.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Unpinned'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
      }
      return true;
    }

    if (pins.length >= maxPinnedUrls) {
      if (context.mounted) {
        _showPinLimitSheet(context, ref, onViewPinned: onViewPinned);
      }
      return false;
    }

    await notifier.pin(url.id);
    if (context.mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Pinned'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
    }
    return true;
  }

  Future<void> _toggleRead(BuildContext context, WidgetRef ref) async {
    final isar = ref.read(isarServiceProvider);
    final wasRead = url.openedAt != null;
    final previousOpenedAt = url.openedAt;
    if (wasRead) {
      await isar.clearOpenedAt(url.id);
    } else {
      await isar.updateOpenedAt(url.id, DateTime.now());
    }
    onChanged?.call();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(wasRead ? 'Marked unread' : 'Marked read'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              if (wasRead) {
                await isar.updateOpenedAt(
                  url.id,
                  previousOpenedAt ?? DateTime.now(),
                );
              } else {
                await isar.clearOpenedAt(url.id);
              }
              onChanged?.call();
            },
          ),
        ),
      );
  }
}

Future<void> deleteUrlWithUndo(
  BuildContext context,
  WidgetRef ref,
  SavedUrl url,
) async {
  final isarService = ref.read(isarServiceProvider);
  final pins = ref.read(pinnedUrlsProvider);
  final wasPinned = pins.contains(url.id);
  await isarService.deleteUrl(url.id);
  if (wasPinned) {
    await ref.read(pinnedUrlsProvider.notifier).unpin(url.id);
  }
  ref.invalidate(categoriesProvider);
  ref.invalidate(collectionsListProvider);
  ref.invalidate(collectionsSummaryProvider);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('Deleted'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await isarService.saveUrl(url);
            if (wasPinned) {
              await ref.read(pinnedUrlsProvider.notifier).pin(url.id);
            }
            ref.invalidate(categoriesProvider);
            ref.invalidate(collectionsListProvider);
            ref.invalidate(collectionsSummaryProvider);
          },
        ),
      ),
    );
}

Future<void> removeUrlFromCollectionWithUndo({
  required BuildContext context,
  required WidgetRef ref,
  required SavedUrl url,
  required int collectionId,
}) async {
  final isarService = ref.read(isarServiceProvider);
  await isarService.removeUrlFromCollection(
    collectionId: collectionId,
    urlId: url.id,
  );
  ref.invalidate(collectionsListProvider);
  ref.invalidate(collectionsSummaryProvider);
  ref.invalidate(collectionUrlsProvider(collectionId));

  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('Removed from collection'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await isarService.addUrlToCollection(
              collectionId: collectionId,
              urlId: url.id,
            );
            ref.invalidate(collectionsListProvider);
            ref.invalidate(collectionsSummaryProvider);
            ref.invalidate(collectionUrlsProvider(collectionId));
          },
        ),
      ),
    );
}

void _showPinLimitSheet(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onViewPinned,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _PinLimitSheet(onViewPinned: onViewPinned),
  );
}

class _PinLimitSheet extends ConsumerWidget {
  const _PinLimitSheet({this.onViewPinned});

  final VoidCallback? onViewPinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pinnedIds = ref.watch(pinnedUrlsProvider);
    final urls = ref.watch(urlStreamProvider).valueOrNull ?? const <SavedUrl>[];
    final tagFreq = ref.watch(tagOccurrenceMapProvider);
    final byId = {for (final url in urls) url.id: url};
    final pinnedUrls = [
      for (final id in pinnedIds)
        if (byId[id] != null) byId[id]!,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You\'ve reached your pin limit.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (pinnedUrls.isEmpty)
              Text(
                'Pinned items will appear here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: pinnedUrls.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final pinned = pinnedUrls[index];
                    final title = TitleResolver.resolve(
                      pinned,
                      tagFrequency: tagFreq,
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.push_pin_outlined,
                        color: cs.onSurfaceVariant,
                      ),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          ref
                              .read(pinnedUrlsProvider.notifier)
                              .unpin(pinned.id);
                          Navigator.pop(context);
                        },
                        child: const Text('Unpin'),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onViewPinned?.call();
              },
              icon: const Icon(Icons.vertical_align_top_rounded),
              label: const Text('View pinned items'),
            ),
          ],
        ),
      ),
    );
  }
}
