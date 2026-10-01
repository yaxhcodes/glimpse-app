import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_motion.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/theme_provider.dart';
import '../../l10n/l10n.dart';
import 'settings_components.dart';

class LookAndFeelScreen extends ConsumerWidget {
  const LookAndFeelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final amoledSurfaces = ref.watch(amoledSurfacesProvider);
    final accent = ref.watch(accentColorProvider);
    final strings = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lightOnly = themeMode == ThemeMode.light;

    return SettingsPageScaffold(
      title: strings.lookAndFeel,
      children: [
        const _ThemePreview(),
        const SizedBox(height: 24),

        // ─── Brightness ──────────────────────────
        SettingsGroupLabel(strings.brightness),
        SettingsPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.brightnessDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const AppIcon(AppIcons.automaticTheme),
                      label: Text(strings.systemTheme),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const AppIcon(AppIcons.lightTheme),
                      label: Text(strings.lightTheme),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const AppIcon(AppIcons.darkTheme),
                      label: Text(strings.darkTheme),
                    ),
                  ],
                  selected: {themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    ref.read(themeModeProvider.notifier).set(s.first);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsGroup(
          children: [
            SettingsTile(
              icon: AppIcons.amoledTheme,
              iconColor: lightOnly
                  ? cs.onSurfaceVariant
                  : SettingsAccents.indigo,
              title: strings.amoledBlack,
              subtitle: lightOnly
                  ? strings.amoledUnavailable
                  : strings.amoledDescription,
              onTap: lightOnly
                  ? null
                  : () => ref
                        .read(amoledSurfacesProvider.notifier)
                        .set(!amoledSurfaces),
              trailing: Switch(
                value: amoledSurfaces,
                thumbIcon: settingsSwitchThumbIcon(),
                onChanged: lightOnly
                    ? null
                    : (v) => ref.read(amoledSurfacesProvider.notifier).set(v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ─── Accent color ────────────────────────
        SettingsGroupLabel(strings.accentColor),
        SettingsPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.dynamicAccentDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),
              // Every accent in view: a grid, not a row that hides
              // most of them off the edge.
              LayoutBuilder(
                builder: (context, constraints) {
                  const columns = 5;
                  const gap = 12.0;
                  final size =
                      ((constraints.maxWidth - gap * (columns - 1)) / columns)
                          .clamp(40.0, 60.0);
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final c in _accentPickerOrder)
                        _AccentSwatch(
                          accent: c,
                          size: size,
                          selected: c == accent,
                          onTap: () =>
                              ref.read(accentColorProvider.notifier).set(c),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                strings.selectedAccent(_localizedAccentLabel(strings, accent)),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small, text-free mock of the app in the current colours — a save card,
/// a chip, a button and a switch — so a change of theme or accent shows
/// where it lands. Theme changes animate app-wide, so it animates too.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget bar(double width, double height, Color color) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );

    return ExcludeSemantics(
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(kSettingsGroupRadius),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A save card.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: AppIcon(
                        AppIcons.sparkle,
                        size: 20,
                        color: cs.onPrimaryContainer,
                        filled: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(150, 10, cs.onSurface.withValues(alpha: 0.82)),
                          const SizedBox(height: 7),
                          bar(
                            96,
                            8,
                            cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  // A chip.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: bar(
                      40,
                      7,
                      cs.onSecondaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // A button.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: bar(52, 7, cs.onPrimary.withValues(alpha: 0.85)),
                  ),
                  const Spacer(),
                  // A switch, on.
                  Container(
                    width: 44,
                    height: 26,
                    padding: const EdgeInsets.all(3),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: cs.onPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cache of palette → derived [ColorScheme] so the multi-tone swatches don't
/// recompute `fromSeed` on every rebuild.
final Map<(Color, Brightness, DynamicSchemeVariant), ColorScheme>
_swatchSchemeCache = {};

/// Dynamic, then the house palette, then the seeded accents.
final List<AppAccentColor> _accentPickerOrder = [
  AppAccentColor.dynamic,
  AppAccentColor.glimpse,
  for (final accent in AppAccentColor.values)
    if (accent != AppAccentColor.dynamic && accent != AppAccentColor.glimpse)
      accent,
];

ColorScheme _swatchScheme(AppAccentColor accent, Brightness brightness) {
  if (accent == AppAccentColor.glimpse) {
    return AppTheme.brandScheme(brightness);
  }
  final seed = accent.seedColor!;
  final key = (seed, brightness, accent.schemeVariant);
  return _swatchSchemeCache[key] ??= ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: accent.schemeVariant,
  );
}

/// Android 16 "Basic colors" style swatch: a perfectly round circle split
/// into four tonal sectors derived from the seed (a bold tone + softer
/// complements), with a ringed, checked selected state.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
    this.size = 58,
  });

  final AppAccentColor accent;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  /// Four tones laid into crisp quadrants via a hard-stop sweep gradient —
  /// a true circle with no clip seams.
  static Gradient _quadrantGradient(List<Color> tones) {
    return SweepGradient(
      colors: [
        tones[0],
        tones[0],
        tones[1],
        tones[1],
        tones[2],
        tones[2],
        tones[3],
        tones[3],
      ],
      stops: const [0.0, 0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1.0],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDynamic = accent == AppAccentColor.dynamic;

    final Gradient gradient;
    if (isDynamic) {
      // Live wallpaper-derived sweep.
      gradient = SweepGradient(
        colors: [
          cs.primary,
          cs.secondary,
          cs.tertiary,
          cs.primaryContainer,
          cs.secondaryContainer,
          cs.tertiaryContainer,
          cs.error,
          cs.primary,
        ],
      );
    } else {
      final s = _swatchScheme(accent, theme.brightness);
      gradient = _quadrantGradient([
        s.primary,
        s.tertiary,
        s.secondary,
        s.primaryContainer,
      ]);
    }

    return Tooltip(
      message: _localizedAccentLabel(context.l10n, accent),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: AppMotion.short,
          curve: AppMotion.emphasizedDecelerate,
          width: size,
          height: size,
          // Outer ring (with a gap) appears only when selected.
          padding: EdgeInsets.all(selected ? 4 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? cs.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.short,
              reverseDuration: AppMotion.short,
              switchInCurve: AppMotion.emphasizedDecelerate,
              switchOutCurve: AppMotion.emphasizedAccelerate,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.78,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: selected
                  ? Center(
                      key: ValueKey('accent-selected-${accent.name}'),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: cs.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          AppIcons.check,
                          size: 18,
                          color: cs.primary,
                        ),
                      ),
                    )
                  : isDynamic
                  ? const Center(
                      key: ValueKey('accent-dynamic-icon'),
                      child: AppIcon(
                        AppIcons.automaticTheme,
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  : SizedBox(key: ValueKey('accent-idle-${accent.name}')),
            ),
          ),
        ),
      ),
    );
  }
}

String _localizedAccentLabel(AppLocalizations strings, AppAccentColor accent) =>
    switch (accent) {
      AppAccentColor.dynamic => strings.accentDynamic,
      AppAccentColor.purple => strings.accentPurple,
      AppAccentColor.blue => strings.accentBlue,
      AppAccentColor.teal => strings.accentTeal,
      AppAccentColor.green => strings.accentGreen,
      AppAccentColor.lime => strings.accentLime,
      AppAccentColor.yellow => strings.accentYellow,
      AppAccentColor.orange => strings.accentOrange,
      AppAccentColor.red => strings.accentRed,
      AppAccentColor.pink => strings.accentPink,
      AppAccentColor.sakura => strings.accentSakura,
      AppAccentColor.indigo => strings.accentIndigo,
      AppAccentColor.slate => strings.accentSlate,
      AppAccentColor.monochrome => strings.accentMonochrome,
      // Brand name: the same in every language.
      AppAccentColor.glimpse => 'Glimpse',
    };
