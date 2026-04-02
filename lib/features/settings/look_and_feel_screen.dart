import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/theme_provider.dart';

class LookAndFeelScreen extends ConsumerWidget {
  const LookAndFeelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final amoledSurfaces = ref.watch(amoledSurfacesProvider);
    final accent = ref.watch(accentColorProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lightOnly = themeMode == ThemeMode.light;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('Look & feel'),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ThemePreviewStrip(colorScheme: cs),
                const SizedBox(height: 20),
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel(text: 'Brightness', colorScheme: cs),
                      const SizedBox(height: 4),
                      Text(
                        'Choose when to use light or dark colors.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...ThemeMode.values.map(
                        (mode) => RadioListTile<ThemeMode>(
                          value: mode,
                          groupValue: themeMode,
                          onChanged: (v) {
                            if (v != null) {
                              ref.read(themeModeProvider.notifier).set(v);
                            }
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_themeModeTitle(mode)),
                          secondary: Icon(_themeModeIcon(mode), size: 22),
                        ),
                      ),
                      Divider(height: 28, color: cs.outlineVariant.withValues(alpha: 0.5)),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.contrast_rounded,
                          color: lightOnly
                              ? cs.onSurfaceVariant.withValues(alpha: 0.45)
                              : cs.primary,
                        ),
                        title: const Text('AMOLED black'),
                        subtitle: Text(
                          lightOnly
                              ? 'Available when not using light theme.'
                              : 'Pure black backgrounds on OLED screens — saves power.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        trailing: Switch.adaptive(
                          value: amoledSurfaces,
                          onChanged: lightOnly
                              ? null
                              : (v) => ref
                                  .read(amoledSurfacesProvider.notifier)
                                  .set(v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel(text: 'Accent color', colorScheme: cs),
                      const SizedBox(height: 4),
                      Text(
                        'Dynamic uses your wallpaper palette on supported devices.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 64,
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
                        'Selected: ${accent.label}',
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

  static String _themeModeTitle(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System default',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  static IconData _themeModeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => Icons.brightness_auto_rounded,
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
    };
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.colorScheme});

  final String text;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
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
    final radius = BorderRadius.circular(20);

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 112,
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                color: colorScheme.primaryContainer,
                alignment: Alignment.center,
                child: Icon(
                  Icons.palette_rounded,
                  size: 36,
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
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
                      'Theme preview',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Accent and surfaces update from your choices below.',
                      style: tt.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: child,
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccentColor accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDynamic = accent == AppAccentColor.dynamic;
    final displayColor = accent.seedColor ?? cs.primary;

    return Tooltip(
      message: accent.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDynamic ? null : displayColor,
            gradient: isDynamic
                ? const SweepGradient(
                    colors: [
                      Color(0xFF1565C0),
                      Color(0xFF00796B),
                      Color(0xFF2E7D32),
                      Color(0xFFF9A825),
                      Color(0xFFEF6C00),
                      Color(0xFFC62828),
                      Color(0xFFAD1457),
                      Color(0xFF6750A4),
                      Color(0xFF1565C0),
                    ],
                  )
                : null,
            border: Border.all(
              color: selected ? cs.onSurface : cs.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  color: isDynamic
                      ? Colors.white
                      : (displayColor.computeLuminance() > 0.45
                          ? Colors.black87
                          : Colors.white),
                  size: 26,
                )
              : isDynamic
                  ? const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 22)
                  : null,
        ),
      ),
    );
  }
}
