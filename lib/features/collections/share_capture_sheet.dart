import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user_collection.dart';
import '../../core/providers/service_providers.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import 'collection_visual.dart';
import 'collections_provider.dart';
import 'create_collection_sheet.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

const _defaultCollectionName = 'Inbox';

enum ShareCaptureOutcomeType { captured, duplicate, schedulingFallback, error }

class ShareCaptureOutcome {
  const ShareCaptureOutcome({
    required this.type,
    this.collectionName,
    this.notificationsEnabled = false,
    this.enrichmentPending = false,
    this.savedUrlId,
  });

  final ShareCaptureOutcomeType type;
  final String? collectionName;
  final bool notificationsEnabled;
  final bool enrichmentPending;
  final int? savedUrlId;

  bool get saved => type != ShareCaptureOutcomeType.error;
}

typedef ShareCaptureCallback =
    Future<ShareCaptureOutcome> Function(
      UserCollection? collection,
      String? notes,
    );

Future<ShareCaptureOutcome?> showShareCaptureSheet(
  BuildContext context, {
  required ShareCaptureCallback onCapture,
  ShareCaptureCallback? onUpdate,
}) {
  return showModalBottomSheet<ShareCaptureOutcome>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareCaptureSheet(
      onCapture: onCapture,
      onUpdate: onUpdate ?? onCapture,
    ),
  );
}

class _ShareCaptureSheet extends ConsumerStatefulWidget {
  const _ShareCaptureSheet({required this.onCapture, required this.onUpdate});

  final ShareCaptureCallback onCapture;
  final ShareCaptureCallback onUpdate;

  @override
  ConsumerState<_ShareCaptureSheet> createState() => _ShareCaptureSheetState();
}

class _ShareCaptureSheetState extends ConsumerState<_ShareCaptureSheet> {
  final _notesController = TextEditingController();
  UserCollection? _defaultCollection;
  late final Future<UserCollection?> _defaultCollectionFuture;
  bool? _hasCollections;
  bool _choosingCollection = false;
  bool _capturing = false;
  bool _captureFailed = false;
  bool _addingNote = false;
  ShareCaptureOutcome? _outcome;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _defaultCollectionFuture = _prepareDefaultCollection();
    unawaited(_useDefaultCollection());
  }

  @override
  void dispose() {
    _notesController.dispose();
    _closeTimer?.cancel();
    super.dispose();
  }

  Future<UserCollection?> _prepareDefaultCollection() async {
    try {
      final isar = ref.read(isarServiceProvider);
      final collections = await isar.getAllCollections();
      UserCollection? inbox;
      for (final collection in collections) {
        if (collection.name.trim().toLowerCase() ==
            _defaultCollectionName.toLowerCase()) {
          inbox = collection;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _hasCollections = collections.isNotEmpty;
          _defaultCollection = inbox;
        });
      }
      return inbox;
    } catch (error, stackTrace) {
      developer.log(
        'Could not prepare the default share collection.',
        name: 'ShareCapture',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _useDefaultCollection() async {
    if (_choosingCollection || _capturing || !mounted) return;
    var collection = _defaultCollection;
    collection ??= await _defaultCollectionFuture;
    if (!mounted || _choosingCollection || _capturing) return;
    await _capture(collection);
  }

  Future<void> _saveEdits() async {
    if (_outcome == null || _capturing || !mounted) return;
    await _capture(_defaultCollection);
  }

  Future<void> _chooseCollection() async {
    _closeTimer?.cancel();
    setState(() => _choosingCollection = true);
    await _defaultCollectionFuture;
    if (!mounted) return;
    final UserCollection? selected;
    if (_hasCollections == false) {
      selected = await showCreateCollectionSheet(context);
    } else {
      selected = await showCollectionPickerSheet(context);
    }
    if (!mounted) return;
    if (selected != null) {
      setState(() {
        _choosingCollection = false;
        _defaultCollection = selected;
        _hasCollections = true;
      });
      await _capture(selected);
      return;
    }
    setState(() => _choosingCollection = false);
  }

  Future<void> _capture(UserCollection? collection) async {
    if (_capturing || !mounted) return;
    _closeTimer?.cancel();
    setState(() {
      _capturing = true;
      _captureFailed = false;
      _choosingCollection = false;
    });

    ShareCaptureOutcome outcome;
    try {
      final notes = _notesController.text.trim();
      final callback = _outcome == null ? widget.onCapture : widget.onUpdate;
      outcome = await callback(collection, notes.isEmpty ? null : notes);
    } catch (error, stackTrace) {
      developer.log(
        'Share capture failed.',
        name: 'ShareCapture',
        error: error,
        stackTrace: stackTrace,
      );
      outcome = const ShareCaptureOutcome(type: ShareCaptureOutcomeType.error);
    }
    if (!mounted) return;
    if (!outcome.saved) {
      setState(() {
        _capturing = false;
        _captureFailed = true;
      });
      return;
    }
    _notesController.clear();
    setState(() {
      _outcome = outcome;
      _capturing = false;
      _addingNote = false;
    });
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) Navigator.of(context).pop(outcome);
    });
  }

  String _outcomeTitle(BuildContext context, ShareCaptureOutcome outcome) {
    return switch (outcome.type) {
      ShareCaptureOutcomeType.captured => context.l10n.captured,
      ShareCaptureOutcomeType.duplicate => context.l10n.alreadyInGlimpse,
      ShareCaptureOutcomeType.schedulingFallback => context.l10n.captured,
      ShareCaptureOutcomeType.error => context.l10n.captureCouldNotSave,
    };
  }

  String? _outcomeDetail(BuildContext context, ShareCaptureOutcome outcome) {
    return switch (outcome.type) {
      ShareCaptureOutcomeType.captured =>
        !outcome.enrichmentPending
            ? null
            : outcome.notificationsEnabled
            ? context.l10n.captureBody
            : context.l10n.captureQueuedWithoutNotifications,
      ShareCaptureOutcomeType.schedulingFallback =>
        context.l10n.captureSchedulingFallback,
      ShareCaptureOutcomeType.duplicate ||
      ShareCaptureOutcomeType.error => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final outcome = _outcome;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_capturing || outcome == null && !_captureFailed)
                      const ExpressiveLoadingIndicator(size: 22)
                    else
                      Icon(
                        _captureFailed ? AppIcons.error : AppIcons.checkCircle,
                        size: 22,
                        color: _captureFailed ? colors.error : colors.primary,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _captureFailed
                              ? context.l10n.captureCouldNotSave
                              : outcome == null
                              ? context.l10n.savingTo
                              : _outcomeTitle(context, outcome),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.done,
                      onPressed:
                          _capturing || outcome == null && !_captureFailed
                          ? null
                          : () => Navigator.of(context).pop(outcome),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                if (outcome != null)
                  if (_outcomeDetail(context, outcome) case final String detail)
                    Padding(
                      padding: const EdgeInsets.only(left: 34, bottom: 12),
                      child: Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _capturing || _choosingCollection || outcome == null
                            ? null
                            : _chooseCollection,
                        icon: const Icon(AppIcons.folder, size: 18),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _defaultCollection?.name ??
                                    (_hasCollections == false
                                        ? context.l10n.newCollection
                                        : _defaultCollectionName),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(AppIcons.chevronDown, size: 16),
                          ],
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.onSurface,
                          side: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                    ),
                    if (!_addingNote && !_captureFailed) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: TextButton(
                          onPressed: _capturing || outcome == null
                              ? null
                              : () {
                                  _closeTimer?.cancel();
                                  setState(() => _addingNote = true);
                                },
                          child: Text(context.l10n.addNoteOptional),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                  ],
                ),
                if (_addingNote) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextField(
                      controller: _notesController,
                      autofocus: true,
                      enabled: !_capturing,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: context.l10n.addNoteOptional,
                      ),
                    ),
                  ),
                ],
                if (_addingNote || _captureFailed)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, right: 8),
                      child: FilledButton(
                        onPressed: _capturing || _choosingCollection
                            ? null
                            : (_captureFailed
                                  ? _useDefaultCollection
                                  : _saveEdits),
                        child: Text(
                          _captureFailed
                              ? context.l10n.retry
                              : context.l10n.save,
                        ),
                      ),
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

Future<UserCollection?> showCollectionPickerSheet(BuildContext context) {
  return _showCollectionPickerSheet(
    context,
  ).then((selection) => selection?.collection);
}

class CollectionPickerSelection {
  const CollectionPickerSelection(this.collection);

  final UserCollection? collection;
}

Future<CollectionPickerSelection?> showOptionalCollectionPickerSheet(
  BuildContext context, {
  int? selectedCollectionId,
}) {
  return _showCollectionPickerSheet(
    context,
    allowNoCollection: true,
    selectedCollectionId: selectedCollectionId,
  );
}

Future<CollectionPickerSelection?> _showCollectionPickerSheet(
  BuildContext context, {
  bool allowNoCollection = false,
  int? selectedCollectionId,
}) {
  return showModalBottomSheet<CollectionPickerSelection>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CollectionPickerSheet(
      allowNoCollection: allowNoCollection,
      selectedCollectionId: selectedCollectionId,
    ),
  );
}

class _CollectionPickerSheet extends ConsumerWidget {
  const _CollectionPickerSheet({
    required this.allowNoCollection,
    this.selectedCollectionId,
  });

  final bool allowNoCollection;
  final int? selectedCollectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsListProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.chooseCollection,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () async {
                final collection = await showCreateCollectionSheet(context);
                if (collection != null && context.mounted) {
                  Navigator.of(
                    context,
                  ).pop(CollectionPickerSelection(collection));
                }
              },
              icon: const Icon(AppIcons.add),
              label: Text(context.l10n.newCollection),
            ),
            const SizedBox(height: 8),
            if (allowNoCollection) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  AppIcons.folderOff,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(context.l10n.noCollection),
                trailing: selectedCollectionId == null
                    ? Icon(AppIcons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(
                  context,
                ).pop(const CollectionPickerSelection(null)),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
            ],
            collections.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: ExpressiveLoadingIndicator()),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.couldNotLoadCollections),
              ),
              data: (items) => SizedBox(
                height: (items.length * 56.0).clamp(56, 336),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final collection = items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CollectionVisual(
                        style: resolveCollectionVisual(collection),

                        size: 40,
                        iconSize: 18,
                      ),
                      title: Text(collection.name),
                      subtitle: Text(
                        context.l10n.linkCount(collection.urlIds.length),
                      ),
                      trailing: selectedCollectionId == collection.id
                          ? Icon(
                              AppIcons.check,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(
                        context,
                      ).pop(CollectionPickerSelection(collection)),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
