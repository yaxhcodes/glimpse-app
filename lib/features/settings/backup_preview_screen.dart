import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/backup_provider.dart';
import '../../core/services/backup/backup_models.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';

class BackupPreviewScreen extends ConsumerStatefulWidget {
  const BackupPreviewScreen({super.key});

  @override
  ConsumerState<BackupPreviewScreen> createState() =>
      _BackupPreviewScreenState();
}
class _BackupPreviewScreenState extends ConsumerState<BackupPreviewScreen> {
  RestoreMode _restoreMode = RestoreMode.merge;

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = ref.watch(backupProvider);
    final backup = state.previewData;

    ref.listen<BackupState>(backupProvider, (prev, next) {
      if (next.status == BackupStatus.success && next.restoredCount != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(
              next.restoredCount! > 0
                  ? 'Restored ${next.restoredCount} links'
                  : 'Restore complete',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ));
        ref.read(backupProvider.notifier).reset();
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (next.status == BackupStatus.error && next.error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(next.error!.message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
      }
    });

    if (backup == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(),
        body: const Center(child: Text('No backup data')),
      );
    }

    final isRestoring = state.status == BackupStatus.restoring;
    final progress = state.progress;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              'Backup Preview',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionHeader(text: 'Backup Details'),
                      const SizedBox(height: 16),
                      _DetailRow(
                        label: 'Date',
                        value: _formatDate(backup.createdAt),
                      ),
                      if (backup.appVersion.isNotEmpty)
                        _DetailRow(
                          label: 'App version',
                          value: backup.appVersion,
                        ),
                      if (backup.device != null && backup.device!.isNotEmpty)
                        _DetailRow(
                          label: 'Device',
                          value: backup.device!,
                        ),
                      const Divider(height: 24),
                      _DetailRow(
                        label: 'Links',
                        value: '${backup.links.length}',
                      ),
                      _DetailRow(
                        label: 'Collections',
                        value: '${backup.collections.length}',
                      ),
                      if (backup.saveSessions.isNotEmpty)
                        _DetailRow(
                          label: 'Save sessions',
                          value: '${backup.saveSessions.length}',
                        ),
                      if (backup.links.any((l) => l.embedding != null))
                        _DetailRow(
                          label: 'Embeddings included',
                          value:
                              '${backup.links.where((l) => l.embedding != null).length}',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionHeader(text: 'Restore Mode'),
                      const SizedBox(height: 12),
                      _RestoreModeOption(
                        icon: Icons.merge_outlined,
                        title: 'Merge with existing library',
                        subtitle:
                            'Adds new links from the backup (including ones you\u2019ve deleted) and updates existing ones. Nothing in your current library is removed.',
                        isSelected: _restoreMode == RestoreMode.merge,
                        onTap: () =>
                            setState(() => _restoreMode = RestoreMode.merge),
                      ),
                      const SizedBox(height: 8),
                      _RestoreModeOption(
                        icon: Icons.swap_horiz,
                        title: 'Replace current library',
                        subtitle:
                            'Replaces all current data with the backup. Your current library will be deleted.',
                        isSelected: _restoreMode == RestoreMode.replace,
                        isDestructive: true,
                        onTap: () => setState(
                            () => _restoreMode = RestoreMode.replace),
                      ),
                      const SizedBox(height: 16),
                      _RestoreImpactSummary(mode: _restoreMode),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (isRestoring) ...[
                  Column(
                    children: [
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      Text(
                        'Restoring... ${(progress * 100).round()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  FilledButton(
                    onPressed: _confirmRestore,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Restore'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      ref.read(backupProvider.notifier).reset();
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore() async {
    final isReplace = _restoreMode == RestoreMode.replace;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isReplace ? 'Replace library?' : 'Merge backup?'),
        content: Text(isReplace
            ? 'This will replace your current library with the backup. All your current links and collections will be permanently deleted.'
            : 'Links from the backup will be merged into your current library. Duplicates will be skipped.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: isReplace
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error)
                : null,
            child: Text(isReplace ? 'Replace' : 'Merge'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(backupProvider.notifier).restoreBackup(_restoreMode);
    }
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
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: child,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          )),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }
}

class _RestoreImpactSummary extends ConsumerWidget {
  const _RestoreImpactSummary({required this.mode});

  final RestoreMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(restoreImpactProvider(mode));

    final body = async.when(
      data: (impact) {
        if (impact == null) {
          return const SizedBox.shrink();
        }
        if (mode == RestoreMode.replace) {
          return Text(
            'Your current library will be deleted, then ${impact.addedLinks} '
            '${_links(impact.addedLinks)} and ${impact.addedCollections} '
            '${_collections(impact.addedCollections)} will be restored from the backup.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          );
        }
        // Merge mode — call out the "deleted links come back" case if any
        // backup links aren't in the current library.
        final added = impact.addedLinks;
        final updated = impact.updatedLinks;
        final addedCol = impact.addedCollections;
        final updatedCol = impact.updatedCollections;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImpactRow(
              label: 'New links to restore',
              value: added,
              hint: added > 0
                  ? 'Includes any links you previously deleted.'
                  : null,
              tint: cs.primary,
            ),
            const SizedBox(height: 6),
            _ImpactRow(
              label: 'Existing links to update',
              value: updated,
              tint: cs.tertiary,
            ),
            if (addedCol > 0 || updatedCol > 0) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              if (addedCol > 0)
                _ImpactRow(
                  label: 'New collections',
                  value: addedCol,
                  tint: cs.primary,
                ),
              if (addedCol > 0 && updatedCol > 0) const SizedBox(height: 6),
              if (updatedCol > 0)
                _ImpactRow(
                  label: 'Collections to update',
                  value: updatedCol,
                  tint: cs.tertiary,
                ),
            ],
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: ExpressiveLoadingIndicator(size: 14, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Text(
              'Calculating changes\u2026',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      error: (e, _) => Text(
        'Could not preview changes.',
        style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: body,
    );
  }

  static String _links(int n) => n == 1 ? 'link' : 'links';
  static String _collections(int n) => n == 1 ? 'collection' : 'collections';
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.label,
    required this.value,
    required this.tint,
    this.hint,
  });

  final String label;
  final int value;
  final Color tint;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$value',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (hint != null && value > 0) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RestoreModeOption extends StatelessWidget {
  const _RestoreModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final borderColor = isSelected
        ? (isDestructive ? cs.error : cs.primary)
        : cs.outlineVariant;

    final bgColor = isSelected
        ? (isDestructive
            ? cs.errorContainer.withValues(alpha: 0.3)
            : cs.primaryContainer.withValues(alpha: 0.3))
        : cs.surfaceContainerHighest.withValues(alpha: 0.5);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDestructive ? cs.errorContainer : cs.primaryContainer)
                      : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? (isDestructive ? cs.error : cs.primary)
                      : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDestructive && isSelected
                            ? cs.error
                            : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: isDestructive ? cs.error : cs.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
