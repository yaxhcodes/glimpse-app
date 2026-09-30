import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

/// One look for every overflow-menu row in the app: a filled 18px glyph in
/// the quiet variant colour, the label in the menu's body voice, an optional
/// supporting line, a check on the current choice, and a muted red for
/// actions that remove something.
PopupMenuItem<T> appMenuItem<T>({
  required T value,
  required IconData icon,
  required String label,
  String? subtitle,
  bool selected = false,
  bool destructive = false,
  bool enabled = true,
  Key? key,
}) {
  return PopupMenuItem<T>(
    key: key,
    value: value,
    enabled: enabled,
    // Compact rows sized to the 14sp label, so the menu hugs its text.
    height: subtitle == null ? 40 : 48,
    padding: EdgeInsets.zero,
    child: AppMenuRow(
      icon: icon,
      label: label,
      subtitle: subtitle,
      selected: selected,
      destructive: destructive,
      enabled: enabled,
    ),
  );
}

/// The divider between menu groups, trimmed from the default 16px band.
const PopupMenuDivider appMenuDivider = PopupMenuDivider(height: 9);

class AppMenuRow extends StatelessWidget {
  const AppMenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.selected = false,
    this.destructive = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final disabled = cs.onSurface.withValues(alpha: 0.38);
    // A muted red: the warning reads without the full error saturation
    // shouting against the paper palette.
    final destructiveColor = Color.lerp(cs.error, cs.onSurfaceVariant, 0.35)!;
    final iconColor = !enabled
        ? disabled
        : destructive
        ? destructiveColor
        : cs.onSurfaceVariant;
    final textColor = !enabled
        ? disabled
        : destructive
        ? destructiveColor
        : cs.onSurface;
    final subtitle = this.subtitle;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: subtitle == null ? 0 : 8,
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 18, color: iconColor, filled: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 12),
            Icon(AppIcons.check, size: 18, color: cs.primary),
          ],
        ],
      ),
    );
  }
}
