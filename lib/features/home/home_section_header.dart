import 'package:flutter/material.dart';

import '../../shared/theme/app_icons.dart';

/// The one heading voice for Home's sections (Rediscover, Sources, Your
/// saves): same size, weight and colour, an optional quiet subtitle, and a
/// chevron when the whole line opens a page.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
    this.tooltip,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 8, 4),
  });

  final String title;
  final String? subtitle;

  /// Opens the section's page; shows a chevron unless [trailing] is given.
  final VoidCallback? onTap;
  final String? tooltip;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final subtitle = this.subtitle;

    Widget line = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ?trailing,
          if (trailing == null && onTap != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Icon(
                AppIcons.chevronRight,
                size: 20,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      line = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: line,
      );
      if (tooltip != null) line = Tooltip(message: tooltip!, child: line);
    }

    return Padding(padding: padding, child: line);
  }
}
