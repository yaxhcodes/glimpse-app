import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_assets.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import 'settings_components.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<String> _versionString(AppLocalizations strings) async {
    final info = await PackageInfo.fromPlatform();
    return strings.versionBuild(info.buildNumber, info.version);
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
    final pagePadding = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            title: Text(
              context.l10n.about,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, 40),
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
                    context.l10n.appName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    context.l10n.aboutTagline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: FutureBuilder<String>(
                    future: _versionString(context.l10n),
                    builder: (context, snapshot) {
                      final text = snapshot.data ?? context.l10n.loadingVersion;
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
                SettingsGroupLabel(context.l10n.legal),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.terms,
                      iconColor: SettingsAccents.indigo,
                      title: context.l10n.termsOfService,
                      trailing: const _OpenLinkIcon(),
                      onTap: () => _openUrl('https://www.getglimpse.xyz/terms'),
                    ),
                    SettingsTile(
                      icon: AppIcons.privacy,
                      iconColor: SettingsAccents.green,
                      title: context.l10n.privacyPolicy,
                      trailing: const _OpenLinkIcon(),
                      onTap: () =>
                          _openUrl('https://www.getglimpse.xyz/privacy'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Help ──
                SettingsGroupLabel(context.l10n.help),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.help,
                      iconColor: SettingsAccents.blue,
                      title: context.l10n.faq,
                      trailing: const _OpenLinkIcon(),
                      onTap: () => _openUrl('https://www.getglimpse.xyz/faq'),
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
