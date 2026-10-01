import '../ask/ask_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/widgets/notification_permission_prompt.dart';
import '../../core/services/digest_notifications.dart';
import '../../core/constants/app_assets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_environment.dart';
import '../../core/models/app_user.dart';
import '../../core/providers/pinned_urls_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/swipe_preferences_provider.dart';
import '../../core/services/entitlement_service.dart';
import '../ask/ask_empty_suggestions_provider.dart';
import '../collections/collections_provider.dart';
import '../mindmap/interest_clusters_provider.dart';
import '../shell/navigation_discovery_provider.dart';
import '../../core/services/digest_background.dart';
import '../../core/services/digest_prefs.dart';
import '../../core/services/digest_scheduler.dart';
import '../../core/services/notification_scheduler.dart';
import '../../core/providers/dev_simulation_providers.dart';
import '../../core/providers/usage_providers.dart';
import '../../core/services/tag_analyzer.dart';
import '../../core/services/usage_service.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import 'settings_components.dart';
import 'haptics_lab_screen.dart';
import 'bin_provider.dart';
import '../../l10n/l10n.dart';
import '../glimpses/glimpse.dart';
import '../library/library_provider.dart';
import '../glimpses/glimpse_notification_prefs.dart';
import '../../core/models/music_provider.dart';
import '../../core/providers/music_provider_preference_provider.dart';
import '../../core/services/app_haptics.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDeletingAccount = false;

  Future<void> _chooseLanguage() async {
    final current = ref.read(appLocaleProvider).preference;
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final strings = sheetContext.l10n;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    strings.chooseLanguage,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                for (final language in AppLanguage.values)
                  ListTile(
                    leading: AppIcon(
                      language == current
                          ? AppIcons.radioSelected
                          : AppIcons.radioUnselected,
                    ),
                    title: Text(_languageLabel(strings, language)),
                    onTap: () => Navigator.pop(sheetContext, language),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      await ref.read(appLocaleProvider.notifier).setLanguage(selected);
    }
  }

  String _languageLabel(AppLocalizations strings, AppLanguage language) =>
      switch (language) {
        AppLanguage.system => strings.languageSystem,
        AppLanguage.english => strings.languageEnglish,
        AppLanguage.japanese => strings.languageJapanese,
        AppLanguage.spanish => strings.languageSpanish,
        AppLanguage.french => strings.languageFrench,
        AppLanguage.portugueseBrazil => strings.languagePortugueseBrazil,
        AppLanguage.german => strings.languageGerman,
      };

  Future<void> _clearData() async {
    final strings = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.clearAllDataQuestion),
        content: Text(strings.clearAllDataWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(strings.deleteAll),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final isarService = ref.read(isarServiceProvider);
      await ref.read(askProvider.notifier).resetForDataClear();
      await isarService.deleteAll();
      await ref
          .read(pinnedUrlsProvider.notifier)
          .unpinAll(ref.read(pinnedUrlsProvider));
      await clearAskSuggestionsCache();
      await clearInterestClusterCache();
      await ref
          .read(navigationDiscoveryProvider.notifier)
          .resetAfterDataClear();
      ref.invalidate(askEmptySuggestionsProvider);
      ref.invalidate(interestClusterThemesProvider);
      ref.invalidate(collectionsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(strings.allDataCleared),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
      }
    }
  }

  Future<void> _logout() async {
    final strings = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.logOutQuestion),
        content: Text(strings.logOutWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.logOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _requestAccountDeletion() async {
    final strings = context.l10n;
    final isPro = ref.read(isProUserProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteAccountQuestion),
        content: Text(
          isPro
              ? strings.deleteAccountProWarning
              : strings.deleteAccountFreeWarning,
        ),
        actions: [
          if (isPro)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
                context.push('/settings/subscription');
              },
              child: Text(strings.manageSubscription),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(strings.deleteAccount),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isDeletingAccount = true);
    try {
      await ref.read(authControllerProvider.notifier).requestAccountDeletion();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(strings.accountDeleted),
            behavior: SnackBarBehavior.floating,
          ),
        );
      context.go('/');
    } catch (error, stack) {
      debugPrint('Account deletion failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(strings.couldNotDeleteAccount),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pagePadding = AppLayout.pageHorizontalPadding(
      MediaQuery.sizeOf(context).width,
    );
    final authState = ref.watch(authControllerProvider);
    final accountUser = authState.valueOrNull;
    final isPro = ref.watch(isProUserProvider);
    final strings = context.l10n;
    final localeState = ref.watch(appLocaleProvider);
    final aiSaveRemaining = ref.watch(
      remainingUsageProvider(UsageFeature.aiSave),
    );
    final planSubtitle = isPro
        ? strings.manageYourPlan
        : aiSaveRemaining.when(
            data: strings.aiSavesLeft,
            loading: () => strings.checkingSaveAllowance,
            error: (_, _) => strings.manageYourPlan,
          );
    final binCount = ref.watch(binCountProvider).valueOrNull;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SettingsLargeAppBar(title: strings.settings),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Account & plan ──────────────────────
                SettingsGroupLabel(strings.accountAndPlan),
                SettingsGroup(
                  children: [
                    _AccountIdentityTile(
                      user: accountUser,
                      isLoading: authState.isLoading && accountUser == null,
                    ),
                    SettingsTile(
                      // The real app icon, in colour: this row is Glimpse
                      // itself, not a setting.
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          AppAssets.launcherIcon,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      iconColor: SettingsAccents.gold,
                      title: isPro ? strings.planNamePro : strings.planNameFree,
                      subtitle: planSubtitle,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SettingsBadge(
                            label: isPro ? 'Pro' : 'Free',
                            emphasized: isPro,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            AppIcons.chevronRight,
                            size: 24,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                      onTap: () => context.push('/settings/subscription'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Personalization ─────────────────────
                SettingsGroupLabel(strings.personalization),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.appearance,
                      iconColor: SettingsAccents.violet,
                      title: strings.lookAndFeel,
                      subtitle: strings.themeAndAccent,
                      onTap: () => context.push('/settings/look-and-feel'),
                    ),
                    SettingsTile(
                      icon: AppIcons.language,
                      iconColor: SettingsAccents.blue,
                      title: strings.language,
                      subtitle: _languageLabel(strings, localeState.preference),
                      onTap: _chooseLanguage,
                    ),
                    const _HapticsTile(),
                    // Only once there's music to open — or a choice to undo.
                    if (_hasMusic(ref)) const _MusicAppTile(),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Library gestures ────────────────────
                SettingsGroupLabel(strings.libraryGestures),
                const _SwipeActionsGroup(),
                const SizedBox(height: 24),

                // ─── Notifications ───────────────────────
                SettingsGroupLabel(strings.notifications),
                const _NotificationsGroup(),
                const SizedBox(height: 24),

                // ─── Privacy & data ──────────────────────
                SettingsGroupLabel(strings.privacyAndData),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.vault,
                      iconColor: SettingsAccents.violet,
                      title: strings.vault,
                      subtitle: strings.vaultSubtitle,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isPro) ...[
                            const SettingsBadge(label: 'Pro'),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            AppIcons.chevronRight,
                            size: 24,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                      onTap: () => context.push('/vault'),
                    ),
                    SettingsTile(
                      icon: AppIcons.privacy,
                      iconColor: SettingsAccents.indigo,
                      title: strings.privacy,
                      subtitle: strings.privacySubtitle,
                      onTap: () => context.push('/settings/privacy'),
                    ),
                    SettingsTile(
                      icon: AppIcons.backup,
                      iconColor: SettingsAccents.green,
                      title: strings.dataAndBackup,
                      subtitle: strings.dataAndBackupSubtitle,
                      onTap: () => context.push('/settings/data-backup'),
                    ),
                    SettingsTile(
                      icon: AppIcons.clearData,
                      iconColor: SettingsAccents.rose,
                      title: strings.bin,
                      subtitle: strings.binSubtitle,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (binCount != null && binCount > 0) ...[
                            SettingsBadge(label: '$binCount'),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            AppIcons.chevronRight,
                            size: 24,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                      onTap: () => context.push('/settings/bin'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── About ───────────────────────────────
                SettingsGroupLabel(strings.about),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.about,
                      iconColor: SettingsAccents.indigo,
                      title: strings.aboutGlimpse,
                      subtitle: strings.aboutSubtitle,
                      trailing: const _VersionTrailing(),
                      onTap: () => context.push('/settings/about'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Account actions ─────────────────────
                SettingsGroupLabel(strings.accountActions),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.logout,
                      iconColor: SettingsAccents.blue,
                      title: strings.logOut,
                      subtitle: strings.logOutSubtitle,
                      onTap: _logout,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // The two things that can't be undone, together and last.
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.eraseAll,
                      iconColor: cs.error,
                      destructive: true,
                      title: strings.clearAllData,
                      subtitle: strings.clearAllDataSubtitle,
                      onTap: _clearData,
                    ),
                    SettingsTile(
                      icon: AppIcons.deleteAccount,
                      iconColor: cs.error,
                      destructive: true,
                      title: strings.deleteAccount,
                      subtitle: _isDeletingAccount
                          ? strings.deletingAccount
                          : strings.deleteAccountSubtitle,
                      trailing: _isDeletingAccount
                          ? const SizedBox.square(
                              dimension: 20,
                              child: ExpressiveLoadingIndicator(size: 20),
                            )
                          : null,
                      onTap: _isDeletingAccount
                          ? null
                          : _requestAccountDeletion,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Developer ───────────────────────────
                if (AppEnvironment.isDevContext) ...[
                  const SettingsGroupLabel('Developer'),
                  const _DeveloperSection(),
                  const SizedBox(height: 16),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountIdentityTile extends StatelessWidget {
  const _AccountIdentityTile({required this.user, required this.isLoading});

  final AppUser? user;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final email = _trimOrNull(user?.email);
    final accountName = _trimOrNull(user?.displayName);
    final strings = context.l10n;
    final title =
        accountName ??
        _nameFromEmail(email) ??
        (isLoading ? strings.accountLoading : strings.accountSignedIn);
    final subtitle =
        email ??
        (isLoading
            ? strings.accountCheckingSession
            : strings.accountFallbackSubtitle);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _AccountAvatar(
              imageUrl: _trimOrNull(user?.photoUrl),
              label: title,
              email: email,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _trimOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _nameFromEmail(String? email) {
    if (email == null) return null;
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return null;
    return localPart;
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({
    required this.imageUrl,
    required this.label,
    required this.email,
  });

  final String? imageUrl;
  final String label;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final fallback = _AccountAvatarFallback(initial: _initial);
    final imageUrl = this.imageUrl;

    return SizedBox(
      width: 48,
      height: 48,
      child: ClipOval(
        child: imageUrl == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }

  String get _initial {
    final source = label.trim().isNotEmpty ? label : email ?? '';
    final trimmed = source.trim();
    if (trimmed.isEmpty) return 'G';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

class _AccountAvatarFallback extends StatelessWidget {
  const _AccountAvatarFallback({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: cs.primaryContainer),
      child: Center(
        child: Text(
          initial,
          style: theme.textTheme.titleMedium?.copyWith(
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Compact version label shown as the About row's trailing widget.
class _VersionTrailing extends StatelessWidget {
  const _VersionTrailing();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final v = snapshot.data?.version;
            if (v == null) return const SizedBox.shrink();
            return Text(
              'v$v',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Icon(
          AppIcons.chevronRight,
          size: 24,
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ],
    );
  }
}

/// The two swipe-action rows, grouped and styled like the rest of the page.
class _SwipeActionsGroup extends ConsumerWidget {
  const _SwipeActionsGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(swipePreferencesProvider);
    final strings = context.l10n;

    return SettingsGroup(
      children: [
        SettingsTile(
          leading: prefs.leftSwipeAction.iconWidget(
            color: SettingsAccents.chip(
              Theme.of(context).colorScheme,
              SettingsAccents.rose,
            ).glyph,
            size: 22,
            filled: true,
          ),
          iconColor: SettingsAccents.rose,
          title: strings.leftSwipe,
          subtitle: _localizedSwipeActionLabel(strings, prefs.leftSwipeAction),
          onTap: () async {
            final action = await _pickSwipeAction(
              context,
              prefs.leftSwipeAction,
            );
            if (action != null) {
              await ref.read(swipePreferencesProvider.notifier).setLeft(action);
            }
          },
        ),
        SettingsTile(
          leading: prefs.rightSwipeAction.iconWidget(
            color: SettingsAccents.chip(
              Theme.of(context).colorScheme,
              SettingsAccents.teal,
            ).glyph,
            size: 22,
            filled: true,
          ),
          iconColor: SettingsAccents.teal,
          title: strings.rightSwipe,
          subtitle: _localizedSwipeActionLabel(strings, prefs.rightSwipeAction),
          onTap: () async {
            final action = await _pickSwipeAction(
              context,
              prefs.rightSwipeAction,
            );
            if (action != null) {
              await ref
                  .read(swipePreferencesProvider.notifier)
                  .setRight(action);
            }
          },
        ),
      ],
    );
  }

  Future<SwipeActionType?> _pickSwipeAction(
    BuildContext context,
    SwipeActionType selected,
  ) {
    return showModalBottomSheet<SwipeActionType>(
      context: context,
      showDragHandle: true,
      builder: (context) => _SwipeActionSheet(selected: selected),
    );
  }
}

class _SwipeActionSheet extends StatelessWidget {
  const _SwipeActionSheet({required this.selected});

  final SwipeActionType selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Text(
              context.l10n.chooseSwipeAction,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final action in SwipeActionType.values)
            _SwipeActionOption(
              action: action,
              selected: action == selected,
              colorScheme: cs,
              onTap: () {
                AppHaptics.play(AppHaptics.tick);
                Navigator.pop(context, action);
              },
            ),
        ],
      ),
    );
  }
}

class _SwipeActionOption extends StatelessWidget {
  const _SwipeActionOption({
    required this.action,
    required this.selected,
    required this.colorScheme,
    required this.onTap,
  });

  final SwipeActionType action;
  final bool selected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = colorScheme;
    final iconColor = selected ? cs.primary : cs.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Center(
                child: action.iconWidget(
                  color: iconColor,
                  size: 22,
                  filled: selected,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _localizedSwipeActionLabel(context.l10n, action),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) Icon(AppIcons.check, size: 20, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications toggle (user-facing)
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsGroup extends ConsumerStatefulWidget {
  const _NotificationsGroup();

  @override
  ConsumerState<_NotificationsGroup> createState() =>
      _NotificationsGroupState();
}

class _NotificationsGroupState extends ConsumerState<_NotificationsGroup>
    with WidgetsBindingObserver {
  bool _enabled = true;
  bool _loaded = false;
  bool _osEnabled = false;
  bool _busy = false;
  GlimpseNotificationPrefs _prefs = const GlimpseNotificationPrefs();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final osEnabled = await DigestNotifications.areNotificationsEnabled();
    final prefs = await GlimpseNotificationPrefs.load();
    if (!mounted) return;
    setState(() {
      _enabled = p.getBool(DigestPrefs.digestEnabledKey) ?? true;
      _loaded = true;
      _osEnabled = osEnabled;
      _prefs = prefs;
    });
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(DigestPrefs.digestEnabledKey, _enabled);
    await DigestScheduler.reschedule();
  }

  Future<void> _set(bool v) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (v) await enableNotificationsInContext(context, ref);
      if (!mounted) return;
      _enabled = v;
      await _persist();
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _hour(BuildContext context, int hour) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(hour: hour % 24, minute: 0),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  String _window(BuildContext context, int start, int end) =>
      context.l10n.timeRange(_hour(context, start), _hour(context, end));

  String _kindsSummary(AppLocalizations strings) {
    final count = _prefs.enabledCount;
    if (count == GlimpseNotificationPrefs.notifiableKinds.length) {
      return strings.notifKindsAll;
    }
    if (count == 0) return strings.notifKindsNone;
    return strings.notifKindsSome(count);
  }

  Future<void> _chooseKinds() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _NotificationKindsSheet(initial: _prefs),
    );
    await _load();
  }

  Future<void> _chooseHours() async {
    final picked = await showModalBottomSheet<(int, int)>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final strings = sheetContext.l10n;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Text(
                  strings.notifDeliveryHours,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  strings.notifDeliveryHoursDetail,
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final (start, end) in GlimpseNotificationPrefs.windowChoices)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: AppIcon(
                    start == _prefs.startHour && end == _prefs.endHour
                        ? AppIcons.radioSelected
                        : AppIcons.radioUnselected,
                  ),
                  title: Text(_window(sheetContext, start, end)),
                  onTap: () => Navigator.pop(sheetContext, (start, end)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    await GlimpseNotificationPrefs.setWindow(picked.$1, picked.$2);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final on = _enabled && _osEnabled;
    return SettingsGroup(
      children: [
        SettingsTile(
          icon: AppIcons.smartNotifications,
          iconColor: SettingsAccents.amber,
          title: strings.smartNotifications,
          subtitle: _osEnabled
              ? strings.behaviorBasedAlerts
              : strings.obAlertsOff,
          onTap: _loaded && !_busy ? () => _set(!on) : null,
          trailing: Switch(
            value: on,
            thumbIcon: settingsSwitchThumbIcon(),
            onChanged: _loaded && !_busy ? _set : null,
          ),
        ),
        // Only worth tuning while they're on.
        if (on) ...[
          SettingsTile(
            icon: AppIcons.notifications,
            iconColor: SettingsAccents.violet,
            title: strings.notifWhatToSend,
            subtitle: _kindsSummary(strings),
            onTap: _chooseKinds,
          ),
          SettingsTile(
            icon: AppIcons.clock,
            iconColor: SettingsAccents.teal,
            title: strings.notifDeliveryHours,
            subtitle: _window(context, _prefs.startHour, _prefs.endHour),
            onTap: _chooseHours,
          ),
        ],
      ],
    );
  }
}

/// The four kinds of notification, each with its own switch.
class _NotificationKindsSheet extends StatefulWidget {
  const _NotificationKindsSheet({required this.initial});

  final GlimpseNotificationPrefs initial;

  @override
  State<_NotificationKindsSheet> createState() =>
      _NotificationKindsSheetState();
}

class _NotificationKindsSheetState extends State<_NotificationKindsSheet> {
  late final Set<GlimpseKind> _disabled = {...widget.initial.disabled};

  (String, String) _copy(AppLocalizations strings, GlimpseKind kind) =>
      switch (kind) {
        GlimpseKind.connection => (
          strings.notifKindConnections,
          strings.notifKindConnectionsDetail,
        ),
        GlimpseKind.idea => (
          strings.notifKindIdeas,
          strings.notifKindIdeasDetail,
        ),
        GlimpseKind.weekly => (
          strings.notifKindWeekly,
          strings.notifKindWeeklyDetail,
        ),
        _ => (strings.notifKindReminders, strings.notifKindRemindersDetail),
      };

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              strings.notifWhatToSend,
              style: theme.textTheme.titleLarge,
            ),
          ),
          for (final kind in GlimpseNotificationPrefs.notifiableKinds)
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(_copy(strings, kind).$1),
              subtitle: Text(_copy(strings, kind).$2),
              thumbIcon: settingsSwitchThumbIcon(),
              value: !_disabled.contains(kind),
              onChanged: (enabled) {
                AppHaptics.play(AppHaptics.tick);
                setState(
                  () => enabled ? _disabled.remove(kind) : _disabled.add(kind),
                );
                GlimpseNotificationPrefs.setKindEnabled(kind, enabled);
              },
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Full, Subtle or Off — felt right away when chosen.
class _HapticsTile extends StatefulWidget {
  const _HapticsTile();

  @override
  State<_HapticsTile> createState() => _HapticsTileState();
}

class _HapticsTileState extends State<_HapticsTile> {
  String _label(AppLocalizations strings, HapticsLevel level) =>
      switch (level) {
        HapticsLevel.full => strings.hapticsFull,
        HapticsLevel.subtle => strings.hapticsSubtle,
        HapticsLevel.off => strings.off,
      };

  String _detail(AppLocalizations strings, HapticsLevel level) =>
      switch (level) {
        HapticsLevel.full => strings.hapticsFullDetail,
        HapticsLevel.subtle => strings.hapticsSubtleDetail,
        HapticsLevel.off => strings.hapticsOffDetail,
      };

  Future<void> _choose() async {
    final picked = await showModalBottomSheet<HapticsLevel>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final strings = sheetContext.l10n;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  strings.hapticsTitle,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              for (final level in HapticsLevel.values)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: AppIcon(
                    level == AppHaptics.level
                        ? AppIcons.radioSelected
                        : AppIcons.radioUnselected,
                  ),
                  title: Text(_label(strings, level)),
                  subtitle: Text(_detail(strings, level)),
                  onTap: () => Navigator.pop(sheetContext, level),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    await AppHaptics.setLevel(picked);
    // Feel the choice.
    AppHaptics.play(AppHaptics.confirm);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return SettingsTile(
      icon: AppIcons.haptics,
      iconColor: SettingsAccents.rose,
      title: strings.hapticsTitle,
      subtitle: _label(strings, AppHaptics.level),
      onTap: _choose,
    );
  }
}

/// Whether the music-app choice means anything yet: the library holds a
/// song, or one was already picked.
bool _hasMusic(WidgetRef ref) {
  final picked = ref.watch(
    musicProviderPreferenceProvider.select((state) => state.provider != null),
  );
  if (picked) return true;
  final snapshot = ref.watch(librarySnapshotProvider).valueOrNull;
  return snapshot?.songs.isNotEmpty ?? false;
}

/// Which app a song opens in: one you choose, or asked each time.
class _MusicAppTile extends ConsumerWidget {
  const _MusicAppTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.l10n;
    final provider = ref.watch(musicProviderPreferenceProvider).provider;
    return SettingsTile(
      icon: AppIcons.musicProvider,
      iconColor: SettingsAccents.green,
      title: strings.defaultMusicApp,
      subtitle: provider?.label ?? strings.musicAskEachTime,
      onTap: () async {
        // `null` is a real choice here (ask each time), so the sheet hands
        // back a record.
        final picked = await showModalBottomSheet<({MusicProvider? value})>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    strings.defaultMusicApp,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                for (final option in <MusicProvider?>[
                  null,
                  ...MusicProvider.values,
                ])
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: AppIcon(
                      option == provider
                          ? AppIcons.radioSelected
                          : AppIcons.radioUnselected,
                    ),
                    title: Text(option?.label ?? strings.musicAskEachTime),
                    onTap: () => Navigator.pop(sheetContext, (value: option)),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (picked == null) return;
        final notifier = ref.read(musicProviderPreferenceProvider.notifier);
        final value = picked.value;
        value == null
            ? await notifier.clear()
            : await notifier.setProvider(value);
      },
    );
  }
}

String _localizedSwipeActionLabel(
  AppLocalizations strings,
  SwipeActionType action,
) => switch (action) {
  SwipeActionType.delete => strings.delete,
  SwipeActionType.toggleRead => strings.markReadUnread,
  SwipeActionType.addToCollection => strings.addToCollection,
  SwipeActionType.pin => strings.pin,
  SwipeActionType.askGlimpse => strings.askGlimpse,
  SwipeActionType.share => strings.share,
  SwipeActionType.none => strings.none,
};

// ─────────────────────────────────────────────────────────────────────────────
// Developer section (dev context only)
// ─────────────────────────────────────────────────────────────────────────────

class _DeveloperSection extends ConsumerWidget {
  const _DeveloperSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(kSettingsGroupRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Digest Testing ──
            _SubsectionHeader(text: 'Digest Testing'),
            const SizedBox(height: 12),
            const _DigestTestingContent(),
            const SizedBox(height: 24),

            // ── System Tools ──
            _SubsectionHeader(text: 'System Tools'),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Force Pro'),
              subtitle: const Text('Local dev override'),
              thumbIcon: settingsSwitchThumbIcon(),
              value: ref.watch(devProOverrideProvider).valueOrNull ?? false,
              onChanged: ref.watch(devProOverrideProvider).isLoading
                  ? null
                  : (v) {
                      ref
                          .read(devProOverrideProvider.notifier)
                          .setDevProOverride(v);
                    },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reset usage counters'),
              subtitle: const Text('Clear monthly AI counters'),
              trailing: const Icon(AppIcons.refresh),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(usageServiceProvider).resetAll();
                ref.read(usageRevisionProvider.notifier).state++;
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Usage counters reset'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
              },
            ),
            const _UsageDebugContent(),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Force Empty Library'),
              subtitle: const Text('Simulate empty library'),
              thumbIcon: settingsSwitchThumbIcon(),
              value: ref.watch(forceEmptyLibraryProvider),
              onChanged: (v) {
                ref.read(forceEmptyLibraryProvider.notifier).set(v);
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simulate First Save'),
              subtitle: const Text('Test first-save animation'),
              thumbIcon: settingsSwitchThumbIcon(),
              value: ref.watch(simulateFirstSaveProvider),
              onChanged: (v) {
                ref.read(simulateFirstSaveProvider.notifier).set(v);
                if (!v) {
                  ref
                          .read(hasSimulatedFirstSaveInSessionProvider.notifier)
                          .state =
                      false;
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reset Onboarding'),
              subtitle: const Text('Show onboarding on next launch'),
              trailing: const Icon(AppIcons.refresh),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(hasSeenOnboardingProvider.notifier).reset();
                // Refresh the in-session state of the first-run guidance too,
                // so they reappear without needing a full app restart.
                await ref.read(hasSeenGuideCardProvider.notifier).set(false);
                await ref
                    .read(hasSeenRediscoverTipProvider.notifier)
                    .set(false);
                ref
                        .read(hasSimulatedFirstSaveInSessionProvider.notifier)
                        .state =
                    false;
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Onboarding reset'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Haptics lab'),
              subtitle: const Text('Feel every haptic pattern'),
              trailing: const Icon(AppIcons.chevronRight),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HapticsLabScreen(),
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reset First Save Celebration'),
              subtitle: const Text('Re-enable first-save celebration'),
              trailing: const Icon(AppIcons.celebrate),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref
                    .read(hasShownFirstSaveCelebrationProvider.notifier)
                    .reset();
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('First save celebration reset'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reset First Save Simulation'),
              subtitle: const Text('Reset simulation session'),
              trailing: const Icon(AppIcons.refresh),
              onTap: () {
                final messenger = ScaffoldMessenger.of(context);
                ref
                        .read(hasSimulatedFirstSaveInSessionProvider.notifier)
                        .state =
                    false;
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('First save simulation reset'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SubsectionHeader extends StatelessWidget {
  const _SubsectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Digest testing (developer-only)
// ─────────────────────────────────────────────────────────────────────────────

class _DigestTestingContent extends ConsumerStatefulWidget {
  const _DigestTestingContent();

  @override
  ConsumerState<_DigestTestingContent> createState() =>
      _DigestTestingContentState();
}

class _DigestTestingContentState extends ConsumerState<_DigestTestingContent> {
  bool _testing = false;
  String _testType = 'R';
  String? _previewTitle;
  String? _previewBody;

  String? _lastFiredType;
  String? _lastFiredTime;
  int? _peakHour;
  bool _firedToday = false;
  String? _lastRun;
  List<NotifDiag> _diagnostics = const [];

  static const _testTypes = {
    'R': 'Connections',
    'E': 'Saved ideas',
    'F': 'Weekly brief',
    'G': 'Revisit reminders',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lastRun = await DigestPrefs.loadLastRunStatus();
    final lastType = await DigestPrefs.lastFiredType();
    final lastTs = await DigestPrefs.lastFiredTimestamp();
    final peak = await TagAnalyzer.peakOpenHour();
    final canFire = await DigestPrefs.canFireToday();
    final diagnostics = await NotificationScheduler.diagnostics(
      ref.read(isarServiceProvider),
    );
    if (!mounted) return;
    setState(() {
      _diagnostics = diagnostics;
      _lastRun = lastRun;
      _lastFiredType = lastType != null
          ? NotificationScheduler.labelFor(lastType)
          : null;
      _lastFiredTime = lastTs != null
          ? '${lastTs.hour.toString().padLeft(2, '0')}:${lastTs.minute.toString().padLeft(2, '0')}'
          : null;
      _peakHour = peak;
      _firedToday = !canFire;
    });
  }

  Future<void> _previewNow() async {
    setState(() => _testing = true);
    try {
      final isar = ref.read(isarServiceProvider);
      final copy = await NotificationScheduler.preview(isar, _testType);
      if (!mounted) return;
      setState(() {
        _previewTitle = copy?.title ?? '(no data for this type)';
        _previewBody = copy?.body;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewTitle = 'Error: $e';
        _previewBody = null;
      });
    }
    setState(() => _testing = false);
  }

  Future<void> _fireNow() async {
    setState(() => _testing = true);
    try {
      await DigestBackgroundTask.run(singleType: _testType);
    } catch (e) {
      await DigestPrefs.saveLastRunStatus('error: $e');
    }
    await _load();
    if (!mounted) return;
    setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status row.
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            if (_lastFiredType != null)
              _StatusChip(label: 'Last', value: _lastFiredType!),
            if (_lastFiredTime != null)
              _StatusChip(label: 'At', value: _lastFiredTime!),
            if (_peakHour != null)
              _StatusChip(label: 'Peak', value: '$_peakHour:00'),
            _StatusChip(
              label: 'Today',
              value: _firedToday ? 'Fired' : 'Available',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Type picker.
        DropdownButtonFormField<String>(
          icon: const Icon(AppIcons.chevronDown),
          initialValue: _testType,
          decoration: InputDecoration(
            labelText: 'Notification type',
            isDense: true,
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: _testTypes.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    '${e.key} — ${e.value}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _testType = v;
                _previewTitle = null;
                _previewBody = null;
              });
            }
          },
        ),
        const SizedBox(height: 12),

        // Preview + Fire buttons.
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _testing ? null : _previewNow,
                icon: const Icon(AppIcons.visibility, size: 18),
                label: const Text('Preview'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _testing ? null : _fireNow,
                icon: _testing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: ExpressiveLoadingIndicator(
                          size: 16,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Icon(AppIcons.send, size: 18),
                label: const Text('Fire now'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Preview card.
        if (_previewTitle != null)
          Card(
            color: cs.surfaceContainerLow,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _previewTitle!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_previewBody != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _previewBody!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

        // Last run status.
        if (_lastRun != null)
          Text(
            _lastRun!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
          ),

        // Per-type readiness: which of the 7 types can fire right now, and why.
        if (_diagnostics.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'Notification readiness',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Why some types fire and others stay quiet, on your data right now.',
            style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
          ),
          const SizedBox(height: 10),
          ..._diagnostics.map((d) => _DiagRow(diag: d)),
        ],
      ],
    );
  }
}

/// One row of the readiness panel: type + status pill + reason.
class _DiagRow extends StatelessWidget {
  const _DiagRow({required this.diag});
  final NotifDiag diag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (label, color) = diag.eligible
        ? diag.onCooldown
              ? ('Cooling', cs.tertiary)
              : ('Ready', cs.primary)
        : ('Waiting', cs.outline);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            margin: const EdgeInsets.only(top: 1),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${diag.type} — ${diag.label}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  diag.detail,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the bandit diagnostics: type label + open-rate bar.

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
        ),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Usage debug (dev only)
// ─────────────────────────────────────────────────────────────────────────────

class _UsageDebugContent extends StatelessWidget {
  const _UsageDebugContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget row(UsageFeature feature, String label) {
      final limit = UsageService.limitFor(feature);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              '$limit / month',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Limits',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          row(UsageFeature.aiSave, 'AI saves'),
          row(UsageFeature.ask, 'Ask Glimpse'),
          row(UsageFeature.search, 'Search'),
        ],
      ),
    );
  }
}
