import 'package:flutter/material.dart';

import '../../core/models/user_collection.dart';
import 'collection_visual.dart';
import 'collections_provider.dart';

class CollectionMoveTargetSheet extends StatefulWidget {
  const CollectionMoveTargetSheet({
    super.key,
    required this.targets,
    required this.description,
    required this.actionLabel,
  });

  final List<CollectionSummary> targets;
  final String description;
  final String actionLabel;

  @override
  State<CollectionMoveTargetSheet> createState() =>
      _CollectionMoveTargetSheetState();
}

class _CollectionMoveTargetSheetState extends State<CollectionMoveTargetSheet> {
  int? _selectedTargetId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTarget = widget.targets
        .where((summary) => summary.collection.id == _selectedTargetId)
        .firstOrNull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Move links', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              widget.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose a destination',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: (widget.targets.length * 64.0).clamp(64, 320),
              child: ListView.separated(
                itemCount: widget.targets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final summary = widget.targets[index];
                  final collection = summary.collection;
                  final selected = collection.id == _selectedTargetId;
                  return ListTile(
                    selected: selected,
                    selectedTileColor: theme.colorScheme.secondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: CollectionVisual(
                      style: resolveCollectionVisual(collection),
                      seed: collection.name,
                      size: 40,
                      iconSize: 18,
                    ),
                    title: Text(
                      collection.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${summary.linkCount} '
                      '${summary.linkCount == 1 ? 'link' : 'links'}',
                    ),
                    trailing: selected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() => _selectedTargetId = collection.id);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: selectedTarget == null
                  ? null
                  : () => Navigator.pop(context, selectedTarget.collection),
              icon: const Icon(Icons.drive_file_move_outline),
              label: Text(widget.actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

Future<UserCollection?> showMoveCollectionContentsSheet(
  BuildContext context, {
  required List<CollectionSummary> sources,
  required List<CollectionSummary> targets,
}) {
  if (sources.isEmpty || targets.isEmpty) return Future.value();
  final linkCount = sources
      .expand((summary) => summary.collection.urlIds)
      .toSet()
      .length;
  final sourceCount = sources.length;
  final description = sourceCount == 1
      ? 'Move all $linkCount ${linkCount == 1 ? 'link' : 'links'} from '
            '“${sources.single.collection.name}”. The source collection will '
            'be deleted after the move.'
      : 'Move $linkCount ${linkCount == 1 ? 'link' : 'links'} from '
            '$sourceCount collections. The source collections will be deleted '
            'after the move.';
  return showCollectionMoveTargetSheet(
    context,
    targets: targets,
    description: description,
    actionLabel: 'Move and delete',
  );
}

Future<UserCollection?> showMoveUrlsToCollectionSheet(
  BuildContext context, {
  required String sourceCollectionName,
  required int selectedCount,
  required List<CollectionSummary> targets,
}) {
  if (selectedCount == 0 || targets.isEmpty) return Future.value();
  return showCollectionMoveTargetSheet(
    context,
    targets: targets,
    description:
        'Move $selectedCount selected '
        '${selectedCount == 1 ? 'link' : 'links'} from '
        '“$sourceCollectionName” to another collection.',
    actionLabel: 'Move',
  );
}

Future<UserCollection?> showCollectionMoveTargetSheet(
  BuildContext context, {
  required List<CollectionSummary> targets,
  required String description,
  required String actionLabel,
}) {
  if (targets.isEmpty) return Future.value();
  return showModalBottomSheet<UserCollection>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => CollectionMoveTargetSheet(
      targets: targets,
      description: description,
      actionLabel: actionLabel,
    ),
  );
}
