import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'collection_visual.dart';
import 'collections_provider.dart';

Future<List<int>?> showCollectionReorderSheet(
  BuildContext context,
  List<CollectionSummary> collections,
) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _CollectionReorderSheet(collections: collections),
  );
}

class _CollectionReorderSheet extends StatefulWidget {
  const _CollectionReorderSheet({required this.collections});

  final List<CollectionSummary> collections;

  @override
  State<_CollectionReorderSheet> createState() =>
      _CollectionReorderSheetState();
}

class _CollectionReorderSheetState extends State<_CollectionReorderSheet> {
  late final List<CollectionSummary> _draft = [...widget.collections];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.reorderCollections,
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.dragToSetManualOrder,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _draft.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  _draft.insert(newIndex, _draft.removeAt(oldIndex));
                });
              },
              itemBuilder: (context, index) {
                final summary = _draft[index];
                final collection = summary.collection;
                return ListTile(
                  key: ValueKey('reorder-collection-${collection.id}'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: CollectionVisual(
                    style: resolveCollectionVisual(collection),
                    seed: collection.name,
                    size: 42,
                    iconSize: 19,
                  ),
                  title: Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(context.l10n.linkCount(summary.linkCount)),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.drag_handle_rounded),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _draft
                          .map((summary) => summary.collection.id)
                          .toList(growable: false),
                    ),
                    child: Text(context.l10n.done),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
