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

const _defaultCollectionName = 'Inbox';

enum ShareCaptureOutcomeType { captured, duplicate, schedulingFallback, error }

class ShareCaptureOutcome {
  const ShareCaptureOutcome({
    required this.type,
    this.collectionName,
    this.notificationsEnabled = false,
    this.enrichmentPending = false,
  });

  final ShareCaptureOutcomeType type;
  final String? collectionName;
  final bool notificationsEnabled;
  final bool enrichmentPending;

  bool get saved => type != ShareCaptureOutcomeType.error;
}

typedef ShareCaptureCallback =
    Future<ShareCaptureOutcome> Function(UserCollection? collection);

Future<ShareCaptureOutcome?> showShareCaptureSheet(
  BuildContext context, {
  required ShareCaptureCallback onCapture,
}) {
  return showModalBottomSheet<ShareCaptureOutcome>(
    context: context,
    useRootNavigator: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareCaptureSheet(onCapture: onCapture),
  );
}

class _ShareCaptureSheet extends ConsumerStatefulWidget {
  const _ShareCaptureSheet({required this.onCapture});

  final ShareCaptureCallback onCapture;

  @override
  ConsumerState<_ShareCaptureSheet> createState() => _ShareCaptureSheetState();
}

class _ShareCaptureSheetState extends ConsumerState<_ShareCaptureSheet> {
  Timer? _autoSaveTimer;
  UserCollection? _defaultCollection;
  late final Future<UserCollection?> _defaultCollectionFuture;
  bool? _hasCollections;
  bool _choosingCollection = false;
  bool _capturing = false;
  ShareCaptureOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _defaultCollectionFuture = _prepareDefaultCollection();
    unawaited(_defaultCollectionFuture);
    _autoSaveTimer = Timer(const Duration(seconds: 1), _useDefaultCollection);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
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

  Future<void> _chooseCollection() async {
    _autoSaveTimer?.cancel();
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
      setState(() => _choosingCollection = false);
      await _capture(selected);
      return;
    }
    setState(() => _choosingCollection = false);
    _autoSaveTimer = Timer(const Duration(seconds: 1), _useDefaultCollection);
  }

  Future<void> _capture(UserCollection? collection) async {
    if (_capturing || !mounted) return;
    setState(() {
      _capturing = true;
      _choosingCollection = false;
    });

    ShareCaptureOutcome outcome;
    try {
      outcome = await widget.onCapture(collection);
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
    setState(() => _outcome = outcome);
    await Future<void>.delayed(
      Duration(milliseconds: outcome.saved ? 700 : 1200),
    );
    if (!mounted) return;
    Navigator.of(context).pop(outcome);
  }

  String _outcomeTitle(BuildContext context, ShareCaptureOutcome outcome) {
    return switch (outcome.type) {
      ShareCaptureOutcomeType.captured =>
        outcome.collectionName == null
            ? context.l10n.captured
            : context.l10n.savedToCollection(outcome.collectionName!),
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
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (outcome == null) ...[
              Text(
                context.l10n.savingTo,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: _choosingCollection || _capturing
                    ? null
                    : _chooseCollection,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _hasCollections == false
                            ? Icons.create_new_folder_outlined
                            : Icons.folder_outlined,
                        size: 22,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _hasCollections == false
                              ? context.l10n.newCollection
                              : _defaultCollection?.name ??
                                    _defaultCollectionName,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: ExpressiveLoadingIndicator(
                      size: 16,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _choosingCollection
                        ? context.l10n.chooseACollection
                        : context.l10n.processingLink,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    outcome.saved
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: outcome.saved ? colors.primary : colors.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _outcomeTitle(context, outcome),
                          style: theme.textTheme.titleMedium,
                        ),
                        if (_outcomeDetail(context, outcome)
                            case final detail?) ...[
                          const SizedBox(height: 4),
                          Text(
                            detail,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
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
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.newCollection),
            ),
            const SizedBox(height: 8),
            if (allowNoCollection) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.folder_off_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(context.l10n.noCollection),
                trailing: selectedCollectionId == null
                    ? Icon(
                        Icons.check_rounded,
                        color: theme.colorScheme.primary,
                      )
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
                        seed: collection.name,
                        size: 40,
                        iconSize: 18,
                      ),
                      title: Text(collection.name),
                      subtitle: Text(
                        context.l10n.linkCount(collection.urlIds.length),
                      ),
                      trailing: selectedCollectionId == collection.id
                          ? Icon(
                              Icons.check_rounded,
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
