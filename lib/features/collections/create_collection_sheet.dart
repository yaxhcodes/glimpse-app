import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user_collection.dart';
import '../../core/providers/service_providers.dart';
import 'collection_visual.dart';
import 'collections_provider.dart';

Future<UserCollection?> showCreateCollectionSheet(
  BuildContext context, {
  String? initialName,
  String? initialDescription,
  CollectionVisualStyle? initialVisual,
}) {
  return showModalBottomSheet<UserCollection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => CreateCollectionSheet(
      initialName: initialName,
      initialDescription: initialDescription,
      initialVisual: initialVisual,
    ),
  );
}

class CreateCollectionSheet extends ConsumerStatefulWidget {
  const CreateCollectionSheet({
    super.key,
    this.initialName,
    this.initialDescription,
    this.initialVisual,
  });

  final String? initialName;
  final String? initialDescription;
  final CollectionVisualStyle? initialVisual;

  @override
  ConsumerState<CreateCollectionSheet> createState() =>
      _CreateCollectionSheetState();
}

class _CreateCollectionSheetState extends ConsumerState<CreateCollectionSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String? _nameError;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name your collection');
      return;
    }

    final isar = ref.read(isarServiceProvider);
    final existing = await isar.getAllCollections();
    final duplicate = existing.any(
      (collection) => collection.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      setState(() => _nameError = 'A collection with this name already exists');
      return;
    }

    setState(() {
      _creating = true;
      _nameError = null;
    });

    try {
      final description = _descriptionController.text.trim();
      final collection = await isar.createCollection(
        name: name,
        emoji: _currentVisual.key,
        description: description.isEmpty ? null : description,
      );
      ref.invalidate(collectionsListProvider);
      ref.invalidate(collectionsSummaryProvider);
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context, collection);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final visual = _currentVisual;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: cs.outlineVariant),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    CollectionVisual(
                      style: visual,
                      size: 44,
                      seed: _nameController.text,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New collection',
                            style: tt.titleLarge?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Create a focused space for saved ideas.',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed:
                          _creating ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    setState(() => _nameError = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'Travel & Wanderlust',
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional note for this space',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _creating ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _creating ? null : _create,
                        child: _creating
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.onPrimary,
                                ),
                              )
                            : const Text('Create'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  CollectionVisualStyle get _currentVisual {
    final resolved = resolveCollectionVisualStyle(
      null,
      name: _nameController.text,
      description: _descriptionController.text,
    );
    if (resolved != CollectionVisualStyle.fallback) return resolved;
    return widget.initialVisual ?? resolved;
  }
}
