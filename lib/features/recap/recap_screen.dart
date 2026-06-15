import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/upgrade_gate.dart';
import 'recap_provider.dart';

class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key});

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recapProvider.notifier).loadRecap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recapProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              'Weekly Recap',
              style: theme.textTheme.headlineMedium,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    ref.read(recapProvider.notifier).loadRecap(),
              ),
            ],
          ),
          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
else if (state.error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.isProFeature
                            ? Icons.auto_stories_outlined
                            : Icons.error_outline_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.isProFeature
                            ? 'Weekly Recap is a Pro feature'
                            : 'Something went wrong',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.isProFeature
                            ? 'Get a concise AI-powered summary of your week in saves — topics, patterns, and highlights.'
                            : state.error ?? 'Please try again later.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (state.isProFeature)
                        FilledButton.icon(
                          onPressed: () async {
                            final upgraded = await showUpgradeGate(
                              context,
                              UpgradeFeature.recap,
                            );
                            if (upgraded == true && context.mounted) {
                              ref.read(recapProvider.notifier).loadRecap();
                            }
                          },
                          icon: const Icon(Icons.auto_stories_outlined),
                          label: const Text('Upgrade for Weekly Recap'),
                        )
                      else
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              ref.read(recapProvider.notifier).loadRecap(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ─── Stat pill ───────────────────────────────────────
                  Row(
                    children: [
                      _StatChip(
                        label: '${state.urls.length}',
                        sublabel: 'links saved',
                        icon: Icons.bookmark_added_outlined,
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        label: '${state.topicCounts.length}',
                        sublabel: 'topic${state.topicCounts.length == 1 ? '' : 's'}',
                        icon: Icons.category_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── AI Narrative ─────────────────────────────────────
                  if (state.narrative != null) ...[
                    Text('AI Summary',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: theme.colorScheme.primary)),
                    const SizedBox(height: 8),
                    Card(
                      color: theme.colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          state.narrative!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─── Topics breakdown ─────────────────────────────────
                  if (state.topicCounts.isNotEmpty) ...[
                    Text('Topics This Week',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: theme.colorScheme.primary)),
                    const SizedBox(height: 8),
                    ...() {
                      final sorted = state.topicCounts.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      return sorted.map((e) => _TopicRow(
                            category: e.key,
                            count: e.value,
                            total: state.urls.length,
                          ));
                    }(),
                    const SizedBox(height: 20),
                  ],

                  // ─── Empty state ──────────────────────────────────────
                  if (state.urls.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 56,
                                color: theme.colorScheme.primary
                                    .withAlpha(100)),
                            const SizedBox(height: 12),
                            Text(
                              'No links saved this week',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share some links into Glimpse to start building your knowledge base.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () => context.push('/add'),
                              icon: const Icon(Icons.add_link),
                              label: const Text('Add a link'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.sublabel,
    required this.icon,
  });

  final String label;
  final String sublabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.category,
    required this.count,
    required this.total,
  });

  final String category;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: theme.textTheme.bodyMedium),
              Text('$count', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
