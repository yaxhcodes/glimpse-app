import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/theme_provider.dart';

class LookAndFeelScreen extends ConsumerWidget {
  const LookAndFeelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Look & Feel'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // ─── Theme mode ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Theme',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.auto_mode)),
                    ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode)),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (value) {
                    ref.read(themeModeProvider.notifier).set(value.first);
                  },
                ),
              ),

              const SizedBox(height: 28),

              // ─── Color ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Text('Color',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ColorPaletteGrid(
                  selected: accent,
                  onSelect: (c) =>
                      ref.read(accentColorProvider.notifier).set(c),
                ),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Color palette grid ──────────────────────────────────────────────────────

class _ColorPaletteGrid extends StatelessWidget {
  const _ColorPaletteGrid({
    required this.selected,
    required this.onSelect,
  });

  final AppAccentColor selected;
  final ValueChanged<AppAccentColor> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppAccentColor.values;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((c) {
        final isSelected = c == selected;
        final isDynamic = c == AppAccentColor.dynamic;

        final Color displayColor = c.seedColor ?? theme.colorScheme.primary;

        return GestureDetector(
          onTap: () => onSelect(c),
          child: Tooltip(
            message: c.label,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
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
                border: isSelected
                    ? Border.all(
                        color: theme.colorScheme.onSurface,
                        width: 3,
                      )
                    : Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: isDynamic
                          ? Colors.white
                          : _contrastForeground(displayColor),
                      size: 22,
                    )
                  : isDynamic
                      ? const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 20)
                      : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _contrastForeground(Color bg) {
    return bg.computeLuminance() > 0.4 ? Colors.black : Colors.white;
  }
}
