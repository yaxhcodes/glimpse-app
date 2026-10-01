import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/backup_provider.dart';
import '../../core/services/backup/backup_models.dart';
import '../../core/services/backup/backup_service.dart';
import '../../core/services/backup_scheduler.dart';
import '../../l10n/l10n.dart';
import 'settings_components.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

String _localizedBackupInterval(BuildContext context, int hours) {
  if (hours == 0) return context.l10n.off;
  if (hours == 168) return context.l10n.weekly;
  return context.l10n.everyHours(hours);
}

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
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strings = context.l10n;
    final state = ref.watch(backupProvider);

    ref.listen<BackupState>(backupProvider, (prev, next) {
      if (next.status == BackupStatus.success && next.filePath != null) {
        ref.read(backupProvider.notifier).shareBackup();
        ref.invalidate(lastBackupDateProvider);
      } else if (next.status == BackupStatus.savedLocal &&
          next.filePath != null) {
        _showLocalSaveSuccess(next.filePath!, next.restoredCount);
        ref.invalidate(lastBackupDateProvider);
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

    return SettingsPageScaffold(
      title: strings.dataAndBackup,
      bottomPadding: 32,
      children: [
        // What matters most, first: when the last backup was, and the two
        // things you come here to do.
        SettingsGroupLabel(strings.backupAndRestore),
        SettingsPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BackupStatusLine(),
              const SizedBox(height: 16),
              _DualBackupActions(
                isCreating: isSavingLocal,
                isRestoring: isImporting,
                onCreate: exportBusy ? null : () => _saveBackupLocally(context),
                onRestore: isImporting ? null : _importBackup,
              ),
            ],
          ),
        ),
        SettingsFootnote(strings.backupLocalInfo),
        const SizedBox(height: 24),

        // Where, then how often.
        SettingsGroupLabel(strings.storageLocation),
        const SettingsGroup(children: [_StorageLocationTile()]),
        SettingsFootnote(strings.backupFolderInfo),
        const SizedBox(height: 24),

        SettingsGroupLabel(strings.automaticBackup),
        const _AutoBackupGroup(),
        SettingsFootnote(strings.backupSensitiveInfo),
        const SizedBox(height: 24),

        SettingsGroupLabel(strings.other),
        SettingsGroup(
          children: [
            SettingsTile(
              icon: AppIcons.share,
              iconColor: SettingsAccents.teal,
              title: strings.shareBackup,
              subtitle: strings.shareBackupDescription,
              trailing: isExporting
                  ? SizedBox.square(
                      dimension: 20,
                      child: ExpressiveLoadingIndicator(
                        size: 20,
                        color: cs.primary,
                      ),
                    )
                  : null,
              onTap: exportBusy ? null : _exportBackup,
            ),
          ],
        ),
      ],
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
        ? context.l10n.backupSavedLinksTo(linkCount, _lastSegment(pathOrLabel))
        : context.l10n.backupSavedTo(_lastSegment(pathOrLabel));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(summary),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
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
      ..showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: detail == null
              ? null
              : SnackBarAction(
                  label: context.l10n.details,
                  onPressed: () => _showErrorDetails(error),
                ),
        ),
      );
  }

  Future<void> _showErrorDetails(BackupError error) async {
    final detail = error.detail ?? error.message;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.errorDetails),
        content: SingleChildScrollView(
          child: SelectableText(
            '${error.message}\n\n$detail',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: '${error.message}\n\n$detail'),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(context.l10n.copy),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.close),
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
        ..showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      ref.read(backupProvider.notifier).reset();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldNotReadSelectedFile),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      ref.read(backupProvider.notifier).reset();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────

String _relative(BuildContext context, DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return context.l10n.justNow;
  if (diff.inHours < 1) return context.l10n.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return context.l10n.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return context.l10n.daysAgo(diff.inDays);
  return MaterialLocalizations.of(context).formatMediumDate(dt.toLocal());
}

/// One line for the state of your backups: the newest one from any source
/// (made here, automatic, or found in the folder), or the automatic attempt
/// that failed since.
class _BackupStatusLine extends ConsumerWidget {
  const _BackupStatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = context.l10n;
    final manual = ref.watch(lastBackupDateProvider).valueOrNull;
    final auto = ref.watch(autoBackupSettingsProvider).valueOrNull;
    final hasFolder =
        ref.watch(backupStorageLocationProvider).valueOrNull?.uri != null;
    final folderEntries = hasFolder
        ? ref.watch(backupStorageEntriesProvider).valueOrNull
        : null;

    final dates = <DateTime>[
      ?DateTime.tryParse(manual ?? ''),
      ?DateTime.tryParse(auto?.lastAutoBackupIso ?? ''),
      if (folderEntries != null && folderEntries.isNotEmpty)
        ?folderEntries.first.lastModified,
    ]..sort();
    final newest = dates.isEmpty ? null : dates.last;
    final failedAt = auto?.lastError == null
        ? null
        : DateTime.tryParse(auto?.lastAttemptIso ?? '');
    final failedSince =
        failedAt != null && (newest == null || failedAt.isAfter(newest));

    final chip = SettingsAccents.chip(cs, SettingsAccents.green);
    final (text, color) = failedSince
        ? (
            strings.lastBackupAttemptFailed(_relative(context, failedAt)),
            cs.error,
          )
        : newest != null
        ? (strings.lastBackup(_relative(context, newest)), cs.onSurface)
        : (strings.noBackupsYet, cs.onSurfaceVariant);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: failedSince ? cs.errorContainer : chip.background,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: AppIcon(
            failedSince ? AppIcons.error : AppIcons.backup,
            size: 22,
            filled: true,
            color: failedSince ? cs.onErrorContainer : chip.glyph,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// The folder backups are written into. Tap to choose it; the trailing
/// button forgets it.
class _StorageLocationTile extends ConsumerWidget {
  const _StorageLocationTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final strings = context.l10n;
    final location = ref.watch(backupStorageLocationProvider).valueOrNull;
    final hasLocation = location?.uri != null;
    final isAndroid = Platform.isAndroid;

    return SettingsTile(
      icon: AppIcons.folder,
      iconColor: SettingsAccents.amber,
      title: hasLocation
          ? (location!.label ?? strings.folderSelected)
          : strings.pickAFolder,
      subtitle: !isAndroid
          ? strings.permanentBackupFolderAndroid
          : hasLocation
          ? strings.tapToChange
          : strings.chooseBackupFolderDescription,
      trailing: hasLocation && isAndroid
          ? IconButton(
              tooltip: strings.forgetFolder,
              icon: const Icon(AppIcons.close),
              style: IconButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
              onPressed: () =>
                  ref.read(backupProvider.notifier).clearStorageLocation(),
            )
          : null,
      onTap: isAndroid ? () => pickBackupFolder(context, ref) : null,
    );
  }
}

/// Asks for the backup folder, explaining a refused permission.
Future<void> pickBackupFolder(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(backupProvider.notifier).pickStorageLocation();
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.couldNotSaveFolderPermission),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// Automatic backup frequency (WorkManager on Android), and — when it's on
/// without a folder to write to — a row that picks one.
class _AutoBackupGroup extends ConsumerWidget {
  const _AutoBackupGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final strings = context.l10n;
    final settings = ref.watch(autoBackupSettingsProvider).valueOrNull;
    final hasFolder =
        ref.watch(backupStorageLocationProvider).valueOrNull?.uri != null;
    final android = Platform.isAndroid;
    final hours = settings?.intervalHours ?? 0;
    final needsFolder = android && hours > 0 && !hasFolder;

    return SettingsGroup(
      children: [
        SettingsTile(
          icon: AppIcons.history,
          iconColor: SettingsAccents.blue,
          title: _localizedBackupInterval(context, hours),
          subtitle: android
              ? strings.backupFrequencyDescription
              : strings.autoBackupAndroidOnly,
          trailing: Icon(AppIcons.chevronDown, color: cs.onSurfaceVariant),
          onTap: android && settings != null
              ? () => _showFrequencySheet(context, ref, hours)
              : null,
        ),
        if (needsFolder)
          SettingsTile(
            icon: AppIcons.folderOff,
            iconColor: cs.error,
            title: strings.setStorageBeforeAutoBackup,
            titleColor: cs.error,
            onTap: () => pickBackupFolder(context, ref),
          ),
      ],
    );
  }

  Future<void> _showFrequencySheet(
    BuildContext context,
    WidgetRef ref,
    int currentHours,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  context.l10n.automaticBackup,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final h in BackupScheduler.intervalHourChoices)
                ListTile(
                  title: Text(_localizedBackupInterval(context, h)),
                  trailing: h == currentHours
                      ? Icon(
                          AppIcons.check,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
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
                    child: ExpressiveLoadingIndicator(
                      size: 22,
                      color: cs.primary,
                    ),
                  )
                : Text(context.l10n.createBackup),
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
                    child: ExpressiveLoadingIndicator(
                      size: 22,
                      color: cs.primary,
                    ),
                  )
                : Text(context.l10n.restoreBackup),
          ),
        ),
      ],
    );
  }
}
