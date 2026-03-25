import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/user_display_name_provider.dart';
import '../ask/ask_empty_suggestions_provider.dart';
import '../mindmap/interest_clusters_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all saved URLs. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete All')),
        ],
      ),
    );

    if (confirmed == true) {
      final isarService = ref.read(isarServiceProvider);
      await isarService.deleteAll();
      await clearAskSuggestionsCache();
      await clearInterestClusterCache();
      ref.invalidate(askEmptySuggestionsProvider);
      ref.invalidate(interestClusterThemesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared')),
        );
      }
    }
  }

  Future<void> _editDisplayName() async {
    final prefsName = await ref.read(userDisplayNameProvider.future);
    if (!mounted) return;
    final controller = TextEditingController(text: prefsName ?? '');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Your name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Used in Ask Glimpse greetings',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        await setUserDisplayName(controller.text);
        ref.invalidate(userDisplayNameProvider);
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayNameAsync = ref.watch(userDisplayNameProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Settings'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // ─── Look & Feel ────────────────────────
              ListTile(
                title: const Text('Look & Feel'),
                subtitle: const Text('Theme, colors, dynamic color'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/look-and-feel'),
              ),
              ListTile(
                title: const Text('Your name'),
                subtitle: Text(
                  displayNameAsync.when(
                    data: (n) =>
                        n == null || n.isEmpty ? 'Optional — for Ask greetings' : n,
                    loading: () => '…',
                    error: (_, _) => 'Optional — for Ask greetings',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _editDisplayName,
              ),
              const Divider(indent: 16, endIndent: 16),

              // ─── AI ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('AI',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary)),
              ),
              ListTile(
                title: const Text('Subscription'),
                subtitle: const Text('Manage your Glimpse plan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/subscription'),
              ),

              const Divider(indent: 16, endIndent: 16),

              // ─── Data ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Data',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary)),
              ),
              ListTile(
                title: const Text('Clear All Data'),
                subtitle: const Text('Delete all saved URLs'),
                onTap: _clearData,
              ),

              const Divider(indent: 16, endIndent: 16),

              // ─── About ─────────────────────────────
              ListTile(
                title: const Text('About'),
                subtitle: const Text('Version & info'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/about'),
              ),

              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }
}
