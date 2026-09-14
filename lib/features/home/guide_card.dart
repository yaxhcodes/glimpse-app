import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../l10n/l10n.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/dev_simulation_providers.dart';
import '../../shared/theme/app_icons.dart';

/// Compact first-save coach shown above the seeded onboarding memory.
class GuideCard extends ConsumerWidget {
  const GuideCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
      child: Material(
        color: cs.secondaryContainer.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (sheet) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.l10n.obFirstSave, style: tt.headlineSmall),
                      const SizedBox(height: 16),
                      Text(
                        Platform.isAndroid
                            ? context.l10n.obShare
                            : context.l10n.obCopy,
                      ),
                      const SizedBox(height: 12),
                      Text(context.l10n.obBody2),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(sheet);
                          context.push('/add');
                        },
                        child: Text(context.l10n.obFirstSave),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(
                    AppIcons.share,
                    size: 24,
                    color: cs.primary,
                    semanticLabel: 'Share',
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.obFirstSave,
                        style: tt.titleSmall?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        Platform.isAndroid
                            ? context.l10n.obShare
                            : context.l10n.obCopy,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSecondaryContainer.withValues(
                            alpha: 0.76,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(hasSeenGuideCardProvider.notifier).set(true),
                  tooltip: context.l10n.obDismiss,
                  icon: AppIcon(
                    AppIcons.close,
                    size: 19,
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
