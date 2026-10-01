import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/analytics_consent.dart';
import '../../core/services/app_haptics.dart';
import '../../l10n/l10n.dart';
import 'package:glimpse/shared/theme/app_icons.dart';
import 'settings_components.dart';

/// What stays on the phone and what leaves it — kept in step with the Play
/// Data safety form and the privacy policy.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  static final privacyPolicyUri = Uri.parse(
    'https://www.getglimpse.xyz/privacy',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.l10n;
    final analyticsOn = ref.watch(analyticsConsentProvider);
    void setAnalytics(bool enabled) {
      AppHaptics.play(AppHaptics.tick);
      ref.read(analyticsConsentProvider.notifier).set(enabled);
    }

    return SettingsPageScaffold(
      title: strings.privacy,
      children: [
        SettingsGroupLabel(strings.privacyOnDevice),
        SettingsGroup(
          children: [
            _PrivacyRow(
              icon: AppIcons.bookmark,
              accent: SettingsAccents.violet,
              label: strings.bookmarks,
            ),
            _PrivacyRow(
              icon: AppIcons.note,
              accent: SettingsAccents.amber,
              label: strings.notes,
            ),
            _PrivacyRow(
              icon: AppIcons.collections,
              accent: SettingsAccents.teal,
              label: strings.collections,
            ),
            _PrivacyRow(
              icon: AppIcons.tag,
              accent: SettingsAccents.rose,
              label: strings.tags,
            ),
            _PrivacyRow(
              icon: AppIcons.sparkle,
              accent: SettingsAccents.indigo,
              label: strings.aiSummaries,
            ),
          ],
        ),
        SettingsFootnote(strings.privacyOnDeviceNote),
        const SizedBox(height: 24),
        SettingsGroupLabel(strings.privacySentToServers),
        SettingsGroup(
          children: [
            _PrivacyRow(
              icon: AppIcons.link,
              accent: SettingsAccents.blue,
              label: strings.privacyLinksTitle,
              detail: strings.privacyLinksDetail,
            ),
            _PrivacyRow(
              icon: AppIcons.chat,
              accent: SettingsAccents.indigo,
              label: strings.privacyAskTitle,
              detail: strings.privacyAskDetail,
            ),
            _PrivacyRow(
              icon: AppIcons.account,
              accent: SettingsAccents.teal,
              label: strings.accountInformation,
              detail: strings.privacyAccountDetail,
            ),
            _PrivacyRow(
              icon: AppIcons.gem,
              accent: SettingsAccents.gold,
              label: strings.subscriptionStatus,
              detail: strings.privacySubscriptionDetail,
            ),
            SettingsTile(
              icon: AppIcons.analytics,
              iconColor: SettingsAccents.slate,
              title: strings.privacyAnalyticsTitle,
              subtitle: analyticsOn
                  ? strings.privacyAnalyticsDetail
                  : strings.privacyAnalyticsOff,
              onTap: () => setAnalytics(!analyticsOn),
              trailing: Switch(
                value: analyticsOn,
                thumbIcon: settingsSwitchThumbIcon(),
                onChanged: setAnalytics,
              ),
            ),
          ],
        ),
        SettingsFootnote(strings.privacyServersNote),
        const SizedBox(height: 24),
        SettingsGroup(
          children: [
            SettingsTile(
              icon: AppIcons.privacy,
              iconColor: SettingsAccents.green,
              title: strings.privacyPolicy,
              trailing: AppIcon(
                AppIcons.externalLink,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              onTap: () => launchUrl(
                privacyPolicyUri,
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One kind of data, named with its own icon — information, not a row to
/// tap.
class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.icon,
    required this.accent,
    required this.label,
    this.detail,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) => SettingsTile(
    icon: icon,
    iconColor: accent,
    title: label,
    subtitle: detail,
  );
}
