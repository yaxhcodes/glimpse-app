import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme/app_icons.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Android 16 / Material 3 Expressive settings building blocks.
///
/// The look: small muted labels sitting *above* large, extra-rounded tonal
/// containers (instead of bold colored headers inside flat cards). Every row
/// carries a colorful tinted icon chip, generous touch targets, and big
/// switches with a check / ✕ in the handle.
/// ─────────────────────────────────────────────────────────────────────────────

/// Corner radius for grouped containers — the expressive "large" shape.
const double kSettingsGroupRadius = 28;

/// Small, muted label that sits above a [SettingsGroup].
class SettingsGroupLabel extends StatelessWidget {
  const SettingsGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Rounded tonal container that groups related rows, separating them with
/// inset dividers — the core Android 16 settings shape.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 72,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        );
      }
    }

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(kSettingsGroupRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// A single settings row with a colorful tinted icon chip, title, optional
/// subtitle and a flexible trailing widget (chevron by default).
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    this.icon,
    this.leading,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.destructive = false,
  }) : assert(icon != null || leading != null, 'Provide icon or leading');

  /// Material icon for the chip. Ignored when [leading] is supplied.
  final IconData? icon;

  /// Custom chip glyph (e.g. swipe-action icon). Takes precedence over [icon].
  final Widget? leading;

  /// Accent used for the chip glyph and (tinted) chip background.
  final Color iconColor;

  final String title;
  final String? subtitle;

  /// Defaults to a muted chevron. Pass a badge, switch, version label, etc.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Overrides the title color. [destructive] is a shortcut for the error tone.
  final Color? titleColor;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = destructive ? cs.error : iconColor;
    final effectiveTitleColor =
        titleColor ?? (destructive ? cs.error : cs.onSurface);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child:
                  leading ??
                  AppIcon(icon!, color: accent, size: 22, weight: 450),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: effectiveTitleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: row,
    );
  }
}

/// Small pill badge — used for plan state (Free / Pro) and similar.
class SettingsBadge extends StatelessWidget {
  const SettingsBadge({
    super.key,
    required this.label,
    this.emphasized = false,
    this.icon,
  });

  final String label;

  /// Filled accent treatment (e.g. an active "Pro" plan).
  final bool emphasized;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = emphasized ? cs.primary : cs.surfaceContainerHighest;
    final fg = emphasized ? cs.onPrimary : cs.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.fromLTRB(icon != null ? 8 : 12, 5, 12, 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Android 16 switch handle: a check when on, a ✕ when off.
WidgetStateProperty<Icon?> settingsSwitchThumbIcon() {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) {
      return const Icon(Icons.check_rounded);
    }
    return const Icon(Icons.close_rounded);
  });
}

/// A curated, palette-harmonious set of chip accents so icons feel colorful
/// (Android 16) without turning into a random rainbow against the warm theme.
class SettingsAccents {
  const SettingsAccents._();

  static const Color violet = Color(0xFF7C5CFF);
  static const Color teal = Color(0xFF1FA39B);
  static const Color amber = Color(0xFFE8973A);
  static const Color rose = Color(0xFFE5577B);
  static const Color gold = Color(0xFFC9A227);
  static const Color blue = Color(0xFF3A7BE8);
  static const Color green = Color(0xFF3FA34D);
  static const Color indigo = Color(0xFF5566C9);
  static const Color slate = Color(0xFF6B7280);
}
