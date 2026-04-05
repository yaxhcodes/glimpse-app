import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/saved_url.dart';
import '../../core/services/title_resolver.dart';
import '../home/home_provider.dart';
import 'synthesis_provider.dart';

class SynthesisScreen extends ConsumerStatefulWidget {
  /// URLs pre-selected before navigating here.
  final List<SavedUrl> initialUrls;

  const SynthesisScreen({super.key, required this.initialUrls});

  @override
  ConsumerState<SynthesisScreen> createState() => _SynthesisScreenState();
}

class _SynthesisScreenState extends ConsumerState<SynthesisScreen> {
  final _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(synthesisProvider.notifier).setUrls(widget.initialUrls);
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(synthesisProvider);
    final tagFreq = ref.watch(tagOccurrenceMapProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synthesize'),
        actions: [
          if (state.result != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Re-synthesize',
              onPressed: () => ref
                  .read(synthesisProvider.notifier)
                  .synthesize(question: _questionController.text),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Selected links ────────────────────────────────────────
            Text(
              '${state.selectedUrls.length} links selected',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            ...state.selectedUrls.map((u) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Text(
                        TitleResolver.resolve(u, tagFrequency: tagFreq),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(u.domain,
                        style: theme.textTheme.bodySmall),
                    leading: Text(u.categoryEmoji,
                        style: const TextStyle(fontSize: 20)),
                  ),
                )),
            const SizedBox(height: 20),

            // ─── Optional question ──────────────────────────────────────
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Optional: focus question',
                hintText: 'e.g. What are the key techniques?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Synthesize button ──────────────────────────────────────
            FilledButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () => ref
                      .read(synthesisProvider.notifier)
                      .synthesize(question: _questionController.text),
              icon: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label:
                  Text(state.isLoading ? 'Synthesizing...' : 'Synthesize'),
            ),

            // ─── Result ─────────────────────────────────────────────────
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    state.error!,
                    style: TextStyle(
                        color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ],
            if (state.result != null) ...[
              const SizedBox(height: 20),
              Text('Synthesis',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    state.result!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
