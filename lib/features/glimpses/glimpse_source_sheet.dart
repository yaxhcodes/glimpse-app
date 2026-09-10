import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/saved_url.dart';
import '../../core/services/title_resolver.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/widgets/notifications/curated_notification_media.dart';

Future<void> showGlimpseSources(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<SavedUrl> sources,
}) async {
  final id = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: sources.isEmpty
                  ? Center(child: Text(context.l10n.glimpsesNoSavesPeriod))
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount: sources.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 80, endIndent: 24),
                      itemBuilder: (context, index) {
                        final url = sources[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 6,
                          ),
                          title: Text(TitleResolver.resolveDetailTitle(url)),
                          leading: CuratedNotificationThumbStripItem(
                            url: url,
                            size: 40,
                            squareRadius: 10,
                          ),
                          subtitle: Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(url.savedAt),
                          ),
                          trailing: const Icon(AppIcons.chevronRight, size: 18),
                          onTap: () => Navigator.pop(context, url.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  if (id != null && context.mounted) context.push('/url/$id');
}
