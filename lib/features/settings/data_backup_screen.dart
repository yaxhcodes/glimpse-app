import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/backup_provider.dart';
import '../../core/services/backup/backup_models.dart';
import '../../core/services/backup/backup_service.dart';
import '../../core/services/backup_scheduler.dart';

/// Mihon-inspired Data & Backup screen.
///
/// Top section: a persistent **Storage location** (the user picks a folder
/// once and we keep writing backups straight into it via SAF). When no
/// location is configured we fall back to a one-off save dialog and the
/// "Create backup" button still works — but the friendlier flow is to
/// pick a folder first.
///
/// Below that: paired tonal **Create backup** / **Restore backup** actions,
/// a short **Folder backup** summary when a storage location is set, and
/// a footer note.
class DataBackupScreen extends ConsumerStatefulWidget {
  const DataBackupScreen({super.key});

  @override
  ConsumerState<DataBackupScreen> createState() => _DataBackupScreenState();
}

class _DataBackupScreenState extends ConsumerState<DataBackupScreen> {
  String? _lastBackupDate;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final date = prefs.getString('glimpse_last_backup_date');
    if (!mounted) return;
    setState(() {
      _lastBackupDate = date;
    });
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) {
        final m = diff.inMinutes;
        return '$m minute${m == 1 ? '' : 's'} ago';
      }
      if (diff.inDays < 1) {
        final h = diff.inHours;
        return '$h hour${h == 1 ? '' : 's'} ago';
      }
      if (diff.inDays < 7) {
        final d = diff.inDays;
        return '$d day${d == 1 ? '' : 's'} ago';
      }
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = ref.watch(backupProvider);

    ref.listen<BackupState>(backupProvider, (prev, next) {
      if (next.status == BackupStatus.success && next.filePath != null) {
        ref.read(backupProvider.notifier).shareBackup();
        _loadMetadata();
      } else if (next.status == BackupStatus.savedLocal &&
          next.filePath != null) {
        _showLocalSaveSuccess(next.filePath!, next.restoredCount);
        _loadMetadata();
        ref.read(backupProvider.notifier).reset();
      } else if (next.status == BackupStatus.error && next.error != null) {
        _showBackupError(next.error!);
        ref.read(backupProvider.notifier).reset();
      }
    });

    final isExporting = state.status == BackupStatus.exporting;
    final isSavingLocal = state.status == BackupStatus.savingLocal;
    final isImporting = state.status == BackupStatus.validating;
    final exportBusy = isExporting || isSavingLocal;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Data & backup'),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionHeader(text: 'Storage location'),
                      const SizedBox(height: 16),
                      const _StorageLocationTile(),
                      const SizedBox(height: 8),
                      const _Note(
                        text:
                            'Used for saving your backup files. Pick a folder once and Glimpse will keep writing new backups there.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionHeader(text: 'Automatic backup'),
                      const SizedBox(height: 16),
                      const _AutoBackupSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionHeader(text: 'Backup and restore'),
                      const SizedBox(height: 16),
                      _DualBackupActions(
                        isCreating: isSavingLocal,
                        isRestoring: isImporting,
                        onCreate: exportBusy
                            ? null
                            : () => _saveBackupLocally(context),
                        onRestore: isImporting ? null : _importBackup,
                      ),
                      if (_lastBackupDate != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Last backup: ${_formatDate(_lastBackupDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const _Note(
                        text:
                            'Backups contain your full library — links, collections, tags, and metadata. They stay on your device.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _RecentBackupsSection(),
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionHeader(text: 'Other'),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Share backup'),
                        subtitle: const Text(
                            'Send a backup to another app or cloud service'),
                        trailing: isExporting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.primary,
                                ),
                              )
                            : Icon(
                                Icons.chevron_right,
                                color: cs.onSurfaceVariant,
                              ),
                        onTap: exportBusy ? null : _exportBackup,
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

  Future<void> _saveBackupLocally(BuildContext context) async {
    await ref.read(backupProvider.notifier).saveBackupLocally();
  }

  Future<void> _exportBackup() async {
    ref.read(backupProvider.notifier).exportBackup();
  }

  void _showLocalSaveSuccess(String pathOrLabel, int? linkCount) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final summary = linkCount != null
        ? 'Saved $linkCount ${linkCount == 1 ? 'link' : 'links'} to '
            '${_lastSegment(pathOrLabel)}'
        : 'Backup saved to ${_lastSegment(pathOrLabel)}';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(summary),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
  }

  String _lastSegment(String pathOrLabel) {
    if (pathOrLabel.isEmpty) return pathOrLabel;
    if (pathOrLabel.startsWith('/')) {
      return pathOrLabel.split('/').where((s) => s.isNotEmpty).join('/');
    }
    return pathOrLabel.split(RegExp(r'[\\/]')).last;
  }

  void _showBackupError(BackupError error) {
    final messenger = ScaffoldMessenger.of(context);
    final detail = error.detail;

    if (kDebugMode && detail != null) {
      debugPrint('[Backup] ${error.message}\n$detail');
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(error.message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: detail == null
            ? null
            : SnackBarAction(
                label: 'Details',
                onPressed: () => _showErrorDetails(error),
              ),
      ));
  }

  Future<void> _showErrorDetails(BackupError error) async {
    final detail = error.detail ?? error.message;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error details'),
        content: SingleChildScrollView(
          child: SelectableText(
            '${error.message}\n\n$detail',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(
                text: '${error.message}\n\n$detail',
              ));
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      final file = File(filePath);
      final content = await file.readAsString();

      await ref.read(backupProvider.notifier).validateBackupContent(content);

      if (!mounted) return;

      final backupState = ref.read(backupProvider);
      if (backupState.status == BackupStatus.previewing &&
          backupState.previewData != null) {
        context.push('/settings/data-backup/preview');
      }
    } on BackupValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      ref.read(backupProvider.notifier).reset();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Could not read the selected file.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      ref.read(backupProvider.notifier).reset();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────

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

/// Matches [SettingsScreen] / [BackupPreviewScreen] — seed [ColorScheme.primary].
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

/// Material 3 hint surface inside a settings card.
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: cs.tertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Path only (no leading icon). Tap to pick folder; trailing clears.
class _StorageLocationTile extends ConsumerWidget {
  const _StorageLocationTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final asyncLocation = ref.watch(backupStorageLocationProvider);

    final value = asyncLocation.maybeWhen(
      data: (v) => v,
      orElse: () => null,
    );
    final hasLocation = value?.uri != null;
    final pathText =
        hasLocation ? (value!.label ?? 'Folder selected') : 'Pick a folder';
    final isAndroid = Platform.isAndroid;

    final row = InkWell(
      onTap: !isAndroid
          ? null
          : () async {
              try {
                await ref
                    .read(backupProvider.notifier)
                    .pickStorageLocation();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: const Text(
                        'Could not save folder permission. Please try again.'),
                    behavior: SnackBarBehavior.floating,
                  ));
              }
            },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    pathText,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: hasLocation
                          ? cs.onSurface
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  if (!hasLocation) ...[
                    const SizedBox(height: 4),
                    Text(
                      isAndroid
                          ? 'Tap to choose where backups are stored'
                          : 'Permanent backup folder is available on Android',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tap to change',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasLocation && isAndroid)
              IconButton(
                tooltip: 'Forget folder',
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                ),
                onPressed: () =>
                    ref.read(backupProvider.notifier).clearStorageLocation(),
              )
            else if (!hasLocation && isAndroid)
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );

    if (!isAndroid) {
      return Opacity(opacity: 0.65, child: row);
    }
    return row;
  }
}

/// Automatic backup frequency (WorkManager on Android).
class _AutoBackupSection extends ConsumerWidget {
  const _AutoBackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final asyncSettings = ref.watch(autoBackupSettingsProvider);
    final asyncLocation = ref.watch(backupStorageLocationProvider);

    return asyncSettings.when(
      data: (settings) {
        final hours = settings.intervalHours;
        final hasFolder = asyncLocation.maybeWhen(
          data: (v) => v.uri != null,
          orElse: () => false,
        );
        final android = Platform.isAndroid;
        final needsFolder = android && hours > 0 && !hasFolder;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                BackupScheduler.intervalLabel(hours),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                android
                    ? 'How often to save a backup to your storage location'
                    : 'Auto backup runs on Android when a storage folder is set',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.expand_more_rounded,
                color: cs.onSurfaceVariant,
              ),
              onTap: android
                  ? () => _showFrequencySheet(context, ref, hours)
                  : null,
            ),
            const _Note(
              text:
                  'Keep copies of backups in other places as well. Backups can include your full library — treat them as sensitive if you share files.',
            ),
            if (settings.lastAutoBackupIso != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Last automatic backup: ${_formatAutoBackupRelative(settings.lastAutoBackupIso!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (needsFolder)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Set a storage location above before automatic backups can run.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.error,
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => SizedBox(
        height: 48,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  static String _formatAutoBackupRelative(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) {
        final m = diff.inMinutes;
        return '$m minute${m == 1 ? '' : 's'} ago';
      }
      if (diff.inDays < 1) {
        final h = diff.inHours;
        return '$h hour${h == 1 ? '' : 's'} ago';
      }
      if (diff.inDays < 7) {
        final d = diff.inDays;
        return '$d day${d == 1 ? '' : 's'} ago';
      }
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _showFrequencySheet(
    BuildContext context,
    WidgetRef ref,
    int currentHours,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  'Automatic backup frequency',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              for (final h in BackupScheduler.intervalHourChoices)
                ListTile(
                  title: Text(BackupScheduler.intervalLabel(h)),
                  trailing: h == currentHours
                      ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, h),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null || !context.mounted) return;
    await BackupScheduler.setIntervalHours(picked);
    ref.invalidate(autoBackupSettingsProvider);
  }
}

/// Create / Restore as paired tonal buttons (Material 3, matches settings tone).
class _DualBackupActions extends StatelessWidget {
  const _DualBackupActions({
    required this.isCreating,
    required this.isRestoring,
    required this.onCreate,
    required this.onRestore,
  });

  final bool isCreating;
  final bool isRestoring;
  final VoidCallback? onCreate;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonal(
            onPressed: onCreate,
            child: isCreating
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : const Text('Create backup'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonal(
            onPressed: onRestore,
            child: isRestoring
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : const Text('Restore backup'),
          ),
        ),
      ],
    );
  }
}

/// One-row summary: last time a backup was written to the chosen folder.
/// Hidden when no folder is configured.
class _RecentBackupsSection extends ConsumerWidget {
  const _RecentBackupsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final asyncLocation = ref.watch(backupStorageLocationProvider);

    return asyncLocation.when(
      data: (loc) {
        if (loc.uri == null) return const SizedBox.shrink();
        final asyncEntries = ref.watch(backupStorageEntriesProvider);
        final asyncLast = ref.watch(lastBackupDateProvider);
        return asyncEntries.when(
          data: (entries) {
            return asyncLast.when(
              data: (isoFromPrefs) {
                final primary = entries.isNotEmpty ? entries.first : null;
                final fromPrefs =
                    isoFromPrefs != null ? DateTime.tryParse(isoFromPrefs) : null;
                final fromFile = primary?.lastModified;
                final display = fromPrefs ?? fromFile;
                final label =
                    display != null ? _formatRelative(display) : null;

                final body = label != null
                    ? Text(
                        'Last saved to folder: $label',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      )
                    : Text(
                        'No backup file in this folder yet. Use Create backup '
                        'above after picking this location.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionHeader(text: 'Folder backup'),
                          const SizedBox(height: 16),
                          body,
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  static String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 1) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return '$d day${d == 1 ? '' : 's'} ago';
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
