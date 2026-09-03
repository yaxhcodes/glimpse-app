import 'package:flutter/material.dart';

import '../../core/models/music_provider.dart';
import '../../l10n/l10n.dart';
import 'music_provider_icon.dart';

Future<MusicProvider?> showMusicProviderSheet(
  BuildContext context, {
  MusicProvider? selected,
}) {
  return showModalBottomSheet<MusicProvider>(
    context: context,
    showDragHandle: true,
    builder: (context) => _MusicProviderSheet(selected: selected),
  );
}

class _MusicProviderSheet extends StatelessWidget {
  const _MusicProviderSheet({this.selected});

  final MusicProvider? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.whereDoYouListen,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.l10n.chooseMusicProvider,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          for (final provider in MusicProvider.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.pop(context, provider),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        MusicProviderIcon(provider: provider),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            provider.label,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (provider == selected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.primary,
                            size: 22,
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
