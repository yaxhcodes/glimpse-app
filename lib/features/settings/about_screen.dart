import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_assets.dart';
import 'settings_components.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<String> _versionString() async {
    final info = await PackageInfo.fromPlatform();
    return 'Version ${info.version} (Build ${info.buildNumber})';
  }

  Future<void> _openUrl(String url) async {
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
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            title: Text(
              'About',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Brand hero ──
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(AppAssets.logo, fit: BoxFit.contain),
                    ),
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
                const SettingsGroupLabel('Legal'),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: Icons.description_outlined,
                      iconColor: SettingsAccents.indigo,
                      title: 'Terms of Service',
                      trailing: const _OpenLinkIcon(),
                      onTap: () => _openUrl(
                        'https://glimpse-app-gray.vercel.app/terms',
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: SettingsAccents.green,
                      title: 'Privacy Policy',
                      trailing: const _OpenLinkIcon(),
                      onTap: () => _openUrl(
                        'https://glimpse-app-gray.vercel.app/privacy',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Help ──
                const SettingsGroupLabel('Help'),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: Icons.help_outline_rounded,
                      iconColor: SettingsAccents.blue,
                      title: 'FAQ',
                      trailing: const _OpenLinkIcon(),
                      onTap: () =>
                          _openUrl('https://glimpse-app-gray.vercel.app/faq'),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenLinkIcon extends StatelessWidget {
  const _OpenLinkIcon();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(
      Icons.open_in_new_rounded,
      size: 20,
      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
    );
  }
}
