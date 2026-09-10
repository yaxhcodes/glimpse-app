import 'package:flutter/material.dart';

import '../../core/models/saved_url.dart';
import '../../core/services/title_resolver.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/widgets/notifications/curated_notification_media.dart';

class GlimpseSaveTile extends StatelessWidget {
  const GlimpseSaveTile({
    super.key,
    required this.url,
    required this.onTap,
    this.featured = false,
  });
  final SavedUrl url;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          leading: CuratedNotificationThumbStripItem(
            url: url,
            size: 52,
            squareRadius: 14,
          ),
          title: Text(
            TitleResolver.resolveDetailTitle(url),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: featured ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          subtitle: Text(
            MaterialLocalizations.of(context).formatMediumDate(url.savedAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(AppIcons.chevronRight, size: 18),
          onTap: onTap,
        ),
      ),
    );
  }
}
