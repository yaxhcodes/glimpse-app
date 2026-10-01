import 'package:flutter/material.dart';

import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/expressive_tap_scale.dart';
import '../../core/services/app_haptics.dart';

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

/// Every settings page: a large bold title that collapses into an opaque
/// bar (content never shows through it), then the page's groups in the
/// shared gutter. [bottomBar] stays pinned under the scroll (a plan's
/// call to action, say).
class SettingsPageScaffold extends StatelessWidget {
  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.bottomBar,
    this.bottomPadding = 40,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gutter = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );
    return Scaffold(
      backgroundColor: cs.surface,
      bottomNavigationBar: bottomBar,
      body: CustomScrollView(
        slivers: [
          SettingsLargeAppBar(title: title, actions: actions),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, bottomPadding),
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
        ],
      ),
    );
  }
}

/// The settings pages' large title bar. Opaque in both states, with no
/// scrolled-under tint, so collapsing it never shows the page through.
class SettingsLargeAppBar extends StatelessWidget {
  const SettingsLargeAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SliverAppBar.large(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      foregroundColor: cs.onSurface,
      actions: actions,
      title: Text(
        title,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A rounded tonal panel in the groups' shape, for free-form content: a
/// status line with buttons, a segmented control, a swatch grid.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(kSettingsGroupRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: child,
      ),
    );
  }
}

/// A short, quiet note under a group — the Android settings footer, not a
/// boxed callout.
class SettingsFootnote extends StatelessWidget {
  const SettingsFootnote(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color ?? theme.colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    );
  }
}

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

  /// Phosphor icon for the chip. Ignored when [leading] is supplied.
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
    final chip = destructive
        ? (background: cs.errorContainer, glyph: cs.onErrorContainer)
        : SettingsAccents.chip(cs, iconColor);
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
                color: chip.background,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child:
                  leading ??
                  AppIcon(icon!, color: chip.glyph, size: 22, filled: true),
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
            // A chevron only on a row that goes somewhere.
            if (trailing != null || onTap != null) const SizedBox(width: 12),
            ?trailing ??
                (onTap == null
                    ? null
                    : Icon(
                        AppIcons.chevronRight,
                        size: 24,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      )),
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return ExpressiveTapScale(
      pressedScale: .99,
      child: InkWell(
        onTap: () {
          AppHaptics.play(AppHaptics.tick);
          onTap!();
        },
        child: row,
      ),
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
    final bg = emphasized ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = emphasized ? cs.onPrimaryContainer : cs.onSurfaceVariant;

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
            AppIcon(icon, size: 14, color: fg),
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
      return const Icon(AppIcons.check);
    }
    return const Icon(AppIcons.close);
  });
}

/// Muted, palette-harmonious chip accents that remain distinct without
/// competing with the settings content.
class SettingsAccents {
  const SettingsAccents._();

  static Color resolve(ColorScheme cs, Color accent) {
    if (accent == cs.error) return cs.error;
    final hsl = HSLColor.fromColor(accent);
    return hsl
        .withLightness(cs.brightness == Brightness.dark ? 0.72 : 0.40)
        .toColor();
  }

  /// A tonal icon chip for [accent], the Material container / on-container
  /// pairing: a deep, clearly coloured tile under a light glyph in dark
  /// mode, a pale tile under a deep glyph in light — never a faint tint.
  static ({Color background, Color glyph}) chip(ColorScheme cs, Color accent) {
    if (accent == cs.error) {
      return (background: cs.errorContainer, glyph: cs.onErrorContainer);
    }
    final hsl = HSLColor.fromColor(accent);
    // Muted accents still read as a colour at these lightnesses.
    final saturation = hsl.saturation.clamp(0.36, 0.62);
    final tone = hsl.withSaturation(saturation);
    final dark = cs.brightness == Brightness.dark;
    return (
      background: tone.withLightness(dark ? 0.27 : 0.90).toColor(),
      glyph: tone.withLightness(dark ? 0.84 : 0.34).toColor(),
    );
  }

  static const Color violet = Color(0xFF917EDD);
  static const Color teal = Color(0xFF3B8783);
  static const Color amber = Color(0xFFB17E48);
  static const Color rose = Color(0xFFC7758A);
  static const Color gold = Color(0xFFA79049);
  static const Color blue = Color(0xFF5F84C3);
  static const Color green = Color(0xFF548E5C);
  static const Color indigo = Color(0xFF6D77B1);
  static const Color slate = Color(0xFF6F737C);
}
