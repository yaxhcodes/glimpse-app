import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:glimpse/shared/theme/app_icons.dart';
import 'settings_components.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return SettingsPageScaffold(
      title: strings.privacy,
      children: [
        SettingsGroupLabel(strings.local),
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
        const SizedBox(height: 24),
        SettingsGroupLabel(strings.uploaded),
        SettingsGroup(
          children: [
            _PrivacyRow(
              icon: AppIcons.account,
              accent: SettingsAccents.blue,
              label: strings.accountInformation,
            ),
            _PrivacyRow(
              icon: AppIcons.gem,
              accent: SettingsAccents.gold,
              label: strings.subscriptionStatus,
            ),
            _PrivacyRow(
              icon: AppIcons.analytics,
              accent: SettingsAccents.slate,
              label: strings.anonymousProductAnalytics,
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
  });

  final IconData icon;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) =>
      SettingsTile(icon: icon, iconColor: accent, title: label);
}
