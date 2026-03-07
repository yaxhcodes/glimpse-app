import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/service_providers.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              const Divider(indent: 16, endIndent: 16),

              // ─── Data ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
