import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('About'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 24),
              // App icon / logo area
              Center(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    'assets/unown_bookmark_transparent.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('Glimpse',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('Version 1.0.0',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Your smart URL bookmarking companion',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),

              const Divider(height: 40, indent: 16, endIndent: 16),

              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Built with'),
                subtitle: const Text('Flutter & Material 3'),
              ),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Local storage'),
                subtitle: const Text('Isar database — all data stays on device'),
              ),
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Theming'),
                subtitle: const Text('Dynamic Color (Material You) support'),
              ),

              const Divider(height: 40, indent: 16, endIndent: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Made with ❤️',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }
}
