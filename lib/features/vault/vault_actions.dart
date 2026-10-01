import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/pinned_urls_provider.dart';
import '../../core/services/app_haptics.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/title_resolver.dart';
import '../../core/services/url_enrichment_job.dart';
import '../../l10n/l10n.dart';
import '../ask/ask_empty_suggestions_provider.dart';
import '../collections/collections_provider.dart';
import '../home/home_provider.dart';
import '../mindmap/interest_clusters_provider.dart';
import '../rediscover/rediscover_provider.dart';
import 'vault_provider.dart';

/// Moves [url] into the Vault, after the plan, the phone's lock and the
/// person have all said yes. True once it has left the saves.
Future<bool> moveSaveToVault(
  BuildContext context,
  WidgetRef ref,
  SavedUrl url,
) async {
  final strings = context.l10n;
  final repository = ref.read(vaultRepositoryProvider);

  if (!await canAddToVault(liveIsPro: ref.read(isProUserProvider))) {
    if (!context.mounted) return false;
    final seePro = await _ask(
      context,
      title: strings.vaultProTitle,
      body: strings.vaultProBody,
      action: strings.vaultSeePro,
    );
    if (seePro && context.mounted) {
      await context.push('/settings/subscription');
    }
    return false;
  }

  final device = await repository.deviceStatus();
  if (!context.mounted) return false;
  if (!device.hasScreenLock || device.keyInvalidated) {
    await _tell(
      context,
      title: device.hasScreenLock
          ? strings.vaultInvalidatedTitle
          : strings.vaultNoScreenLockTitle,
      body: device.hasScreenLock
          ? strings.vaultInvalidatedBody
          : strings.vaultNoScreenLockBody,
    );
    return false;
  }

  final confirmed = await _ask(
    context,
    title: strings.vaultMoveQuestion,
    body: strings.vaultMoveBody,
    action: strings.vaultMoveTo,
  );
  if (!confirmed || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final title = TitleResolver.resolveDetailTitle(url);
    await repository.moveIn(url, title: title);
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(strings.vaultCouldNotMove),
          behavior: SnackBarBehavior.floating,
        ),
      );
    return false;
  }

  // Nothing of it stays behind: no enrichment still to run, no thumbnail
  // in the image cache.
  try {
    await UrlEnrichmentScheduler.cancel(url.id);
    final thumbnail = url.thumbnailUrl;
    if (thumbnail != null && thumbnail.isNotEmpty) {
      await CachedNetworkImage.evictFromCache(thumbnail);
    }
  } catch (_) {}

  if (ref.read(pinnedUrlsProvider).contains(url.id)) {
    await ref.read(pinnedUrlsProvider.notifier).unpin(url.id);
  }
  // Everywhere a save shows, it shouldn't any more.
  ref
    ..invalidate(urlStreamProvider)
    ..invalidate(categoriesProvider)
    ..invalidate(collectionsListProvider)
    ..invalidate(collectionsSummaryProvider)
    ..invalidate(askEmptySuggestionsProvider)
    ..invalidate(interestClusterThemesProvider)
    ..invalidate(rediscoverRecapsProvider)
    ..invalidate(recentlyResurfacedProvider)
    ..invalidate(relatedSavesProvider);

  AppHaptics.play(AppHaptics.success);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(strings.vaultMoved),
        behavior: SnackBarBehavior.floating,
      ),
    );
  return true;
}

Future<bool> _ask(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _tell(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(dialogContext.l10n.gotIt),
        ),
      ],
    ),
  );
}
