import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/service_providers.dart';
import 'collections_provider.dart';

class CreateCollectionScreen extends ConsumerStatefulWidget {
  const CreateCollectionScreen({super.key});

  @override
  ConsumerState<CreateCollectionScreen> createState() =>
      _CreateCollectionScreenState();
}

class _CreateCollectionScreenState extends ConsumerState<CreateCollectionScreen> {
  final _nameController = TextEditingController();
  String _emoji = '📁';
  bool _suggesting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _suggestName() async {
    final gemini = ref.read(geminiServiceProvider);
    if (gemini == null) return;
    setState(() => _suggesting = true);
    try {
      final isar = ref.read(isarServiceProvider);
      final recent = await isar.getRecentUrls(limit: 5);
      if (recent.isEmpty) return;
      final suggestion = await gemini.suggestCollectionName(recent);
      if (!mounted) return;
      final t = suggestion.trim();
      if (t.isEmpty) return;
      final parts = t.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts.first.length <= 4) {
        _emoji = parts.first;
        _nameController.text = parts.sublist(1).join(' ');
      } else {
        _nameController.text = t;
      }
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final isar = ref.read(isarServiceProvider);
    await isar.createCollection(name: name, emoji: _emoji);
    ref.invalidate(collectionsListProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final geminiAvailable = ref.watch(geminiServiceProvider) != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New collection'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (geminiAvailable)
            FilledButton.tonalIcon(
              onPressed: _suggesting ? null : _suggestName,
              icon: _suggesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('Suggest name from recent saves'),
            ),
          if (geminiAvailable) const SizedBox(height: 20),
          Row(
            children: [
              Material(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () async {
                    final picked = await showModalBottomSheet<String>(
                      context: context,
                      showDragHandle: true,
                      builder: (ctx) => SizedBox(
                        height: 320,
                        child: EmojiPicker(
                          onEmojiSelected: (category, emoji) {
                            Navigator.pop(ctx, emoji.emoji);
                          },
                        ),
                      ),
                    );
                    if (picked != null) setState(() => _emoji = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_emoji, style: const TextStyle(fontSize: 32)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Trip planning',
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _create(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _create,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
