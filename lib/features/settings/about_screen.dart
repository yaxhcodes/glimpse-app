import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_assets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<String> _versionString() async {
    final info = await PackageInfo.fromPlatform();
    return 'Version ${info.version} (Build ${info.buildNumber})';
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('About'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),

                // ── Header ──
                Center(
                  child: Image.asset(
                    AppAssets.logo,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Glimpse',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Save something worth keeping',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: FutureBuilder<String>(
                    future: _versionString(),
                    builder: (context, snapshot) {
                      final text = snapshot.data ?? 'Loading version…';
                      return Text(
                        text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.outline,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // ── Legal ──
                _SectionHeader(text: 'Legal'),
                const SizedBox(height: 8),
                _LinkTile(
                  label: 'Terms of Service',
                  onTap: () => _openUrl(
                    context,
                    'https://glimpse-app-gray.vercel.app/terms',
                  ),
                ),
                const Divider(height: 1),
                _LinkTile(
                  label: 'Privacy Policy',
                  onTap: () => _openUrl(
                    context,
                    'https://glimpse-app-gray.vercel.app/privacy',
                  ),
                ),

                const SizedBox(height: 24),

                // ── Help ──
                _SectionHeader(text: 'Help'),
                const SizedBox(height: 8),
                _LinkTile(
                  label: 'FAQ',
                  onTap: () => _openUrl(
                    context,
                    'https://glimpse-app-gray.vercel.app/faq',
                  ),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
