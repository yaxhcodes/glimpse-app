import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user_collection.dart';
import '../../core/providers/service_providers.dart';
import 'collection_visual.dart';
import 'collections_provider.dart';
import 'create_collection_sheet.dart';

const _defaultCollectionName = 'Inbox';

Future<UserCollection?> showShareCaptureSheet(BuildContext context) {
  return showModalBottomSheet<UserCollection>(
    context: context,
    useRootNavigator: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ShareCaptureSheet(),
  );
}

class _ShareCaptureSheet extends ConsumerStatefulWidget {
  const _ShareCaptureSheet();

  @override
  ConsumerState<_ShareCaptureSheet> createState() =>
      _ShareCaptureSheetState();
}

class _ShareCaptureSheetState extends ConsumerState<_ShareCaptureSheet> {
  Timer? _autoSaveTimer;
  UserCollection? _defaultCollection;
  late final Future<UserCollection?> _defaultCollectionFuture;
  bool? _hasCollections;
  bool _choosingCollection = false;

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
    if (_choosingCollection || !mounted) return;
    var collection = _defaultCollection;
    if (collection == null) {
      collection = await _defaultCollectionFuture;
    }
    if (!mounted || _choosingCollection) return;
    Navigator.of(context).pop(collection);
  }

  Future<void> _chooseCollection() async {
    _autoSaveTimer?.cancel();
    setState(() => _choosingCollection = true);
    await _defaultCollectionFuture;
    if (!mounted) return;
    final selected = _hasCollections == false
        ? await showCreateCollectionSheet(context)
        : await showCollectionPickerSheet(context);
    if (!mounted) return;
    if (selected != null) {
      Navigator.of(context).pop(selected);
      return;
    }
    setState(() => _choosingCollection = false);
    _autoSaveTimer = Timer(
      const Duration(seconds: 1),
      _useDefaultCollection,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
            Text(
              'Saving to',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: _choosingCollection ? null : _chooseCollection,
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
                            ? 'New collection'
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _choosingCollection
                      ? 'Choose a collection'
                      : 'Processing link...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<UserCollection?> showCollectionPickerSheet(BuildContext context) {
  return _showCollectionPickerSheet(context).then(
    (selection) => selection?.collection,
  );
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
            Text('Choose collection', style: theme.textTheme.titleLarge),
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
              label: const Text('New collection'),
            ),
            const SizedBox(height: 8),
            if (allowNoCollection) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.folder_off_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: const Text('No Collection'),
                trailing: selectedCollectionId == null
                    ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
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
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Could not load collections.'),
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
                      subtitle: Text('${collection.urlIds.length} links'),
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
