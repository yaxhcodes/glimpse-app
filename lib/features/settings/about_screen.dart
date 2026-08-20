import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_assets.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import 'settings_components.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const _feedbackEmail = 'meyashjoshi3101@gmail.com';
  static const _productionPackageName = 'com.shinrinyoku.glimpse';
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=$_productionPackageName';
  static const _requiredVersionTaps = 7;

  late final Future<PackageInfo> _packageInfo;
  int _versionTapCount = 0;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  Future<bool> _tryLaunch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _openExternal(Uri uri) async {
    if (await _tryLaunch(uri) || !mounted) return;
    _showMessage(context.l10n.couldNotOpenLink);
  }

  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _feedbackEmail,
      query: _encodeQueryParameters({
        'subject': context.l10n.feedbackEmailSubject,
      }),
    );
    await _openExternal(uri);
  }

  Future<void> _rateOnPlayStore() async {
    final marketUri = Uri.parse('market://details?id=$_productionPackageName');
    if (await _tryLaunch(marketUri) || !mounted) return;
    await _openExternal(Uri.parse(_playStoreUrl));
  }

  Future<void> _shareApp() async {
    final strings = context.l10n;
    try {
      await Share.share(
        strings.shareGlimpseText(_playStoreUrl),
        subject: strings.shareGlimpse,
      );
    } catch (_) {
      if (mounted) _showMessage(strings.couldNotShareGlimpse);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _handleVersionTap() {
    _versionTapCount++;
    if (_versionTapCount < _requiredVersionTaps) return;

    _versionTapCount = 0;
    HapticFeedback.mediumImpact();
    final quotes = _keepsakeQuotes(context.l10n);
    final quote = quotes[Random().nextInt(quotes.length)];
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _KeepsakeScreen(quote: quote)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = context.l10n;
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
              strings.about,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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
                    strings.appName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    strings.aboutTagline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      final version = info == null
                          ? strings.loadingVersion
                          : strings.versionBuild(
                              info.buildNumber,
                              info.version,
                            );
                      return Semantics(
                        button: info != null,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: info == null ? null : _handleVersionTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              version,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.outline,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 26),
                SettingsGroupLabel(strings.legal),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.terms,
                      iconColor: SettingsAccents.indigo,
                      title: strings.termsOfService,
                      trailing: const _ActionIcon(Icons.open_in_new_rounded),
                      onTap: () => _openExternal(
                        Uri.parse('https://www.getglimpse.xyz/terms'),
                      ),
                    ),
                    SettingsTile(
                      icon: AppIcons.privacy,
                      iconColor: SettingsAccents.green,
                      title: strings.privacyPolicy,
                      trailing: const _ActionIcon(Icons.open_in_new_rounded),
                      onTap: () => _openExternal(
                        Uri.parse('https://www.getglimpse.xyz/privacy'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SettingsGroupLabel(strings.help),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.feedback,
                      iconColor: SettingsAccents.rose,
                      title: strings.sendFeedback,
                      trailing: const _ActionIcon(Icons.open_in_new_rounded),
                      onTap: _sendFeedback,
                    ),
                    SettingsTile(
                      icon: AppIcons.rate,
                      iconColor: SettingsAccents.gold,
                      title: strings.rateOnPlayStore,
                      trailing: const _ActionIcon(Icons.open_in_new_rounded),
                      onTap: _rateOnPlayStore,
                    ),
                    SettingsTile(
                      icon: AppIcons.share,
                      iconColor: SettingsAccents.teal,
                      title: strings.shareGlimpse,
                      trailing: const _ActionIcon(Icons.share_rounded),
                      onTap: _shareApp,
                    ),
                    SettingsTile(
                      icon: AppIcons.help,
                      iconColor: SettingsAccents.blue,
                      title: strings.faq,
                      trailing: const _ActionIcon(Icons.open_in_new_rounded),
                      onTap: () => _openExternal(
                        Uri.parse('https://www.getglimpse.xyz/faq'),
                      ),
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

String _encodeQueryParameters(Map<String, String> parameters) => parameters
    .entries
    .map(
      (entry) =>
          '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
    )
    .join('&');

List<String> _keepsakeQuotes(AppLocalizations strings) => [
  strings.keepsakeQuoteCuriosity,
  strings.keepsakeQuoteIdea,
  strings.keepsakeQuoteSpark,
  strings.keepsakeQuoteFutureSelf,
  strings.keepsakeQuoteNoticing,
];

class _KeepsakeScreen extends StatelessWidget {
  const _KeepsakeScreen({required this.quote});

  final String quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      key: const Key('about-easter-egg'),
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 12,
              left: 12,
              child: IconButton.filledTonal(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      quote,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.28,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: cs.onSurface,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(
      icon,
      size: 20,
      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
    );
  }
}
