import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
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
    final pagePadding = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            title: Text(
              strings.lookAndFeel,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ThemePreviewStrip(colorScheme: cs),
                const SizedBox(height: 24),

                // ─── Brightness ──────────────────────────
                SettingsGroupLabel(strings.brightness),
                _Panel(
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
                            : (v) => ref
                                  .read(amoledSurfacesProvider.notifier)
                                  .set(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Accent color ────────────────────────
                SettingsGroupLabel(strings.accentColor),
                _Panel(
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
                      SizedBox(
                        height: 68,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 8),
                          itemCount: AppAccentColor.values.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final c = AppAccentColor.values[i];
                            return _AccentSwatch(
                              accent: c,
                              selected: c == accent,
                              onTap: () =>
                                  ref.read(accentColorProvider.notifier).set(c),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        strings.selectedAccent(
                          _localizedAccentLabel(strings, accent),
                        ),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded tonal panel matching [SettingsGroup]'s shape but for free-form
/// content (descriptions, segmented buttons, swatch rows).
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

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

/// Compact preview like Material “Look & feel” cards — accent + surface sample.
class _ThemePreviewStrip extends StatelessWidget {
  const _ThemePreviewStrip({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(kSettingsGroupRadius);

    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 112,
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                color: colorScheme.primary,
                alignment: Alignment.center,
                child: AppIcon(
                  AppIcons.appearance,
                  size: 36,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.themePreview,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.themePreviewDescription,
                      style: tt.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.7,
                        ),
                        height: 1.35,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cache of palette → derived [ColorScheme] so the multi-tone swatches don't
/// recompute `fromSeed` on every rebuild.
final Map<(Color, Brightness, DynamicSchemeVariant), ColorScheme>
_swatchSchemeCache = {};

ColorScheme _swatchScheme(AppAccentColor accent, Brightness brightness) {
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
  });

  final AppAccentColor accent;
  final bool selected;
  final VoidCallback onTap;

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
          width: 58,
          height: 58,
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
                          Icons.check_rounded,
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
    };
