import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_environment.dart';
import '../../core/models/app_user.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/swipe_preferences_provider.dart';
import '../../core/services/entitlement_service.dart';
import '../ask/ask_empty_suggestions_provider.dart';
import '../collections/collections_provider.dart';
import '../mindmap/interest_clusters_provider.dart';
import '../../core/services/digest_background.dart';
import '../../core/services/digest_prefs.dart';
import '../../core/services/digest_scheduler.dart';
import '../../core/services/notif_bandit.dart';
import '../../core/services/notification_scheduler.dart';
import '../../core/providers/dev_simulation_providers.dart';
import '../../core/providers/usage_providers.dart';
import '../../core/services/tag_analyzer.dart';
import '../../core/services/usage_service.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_layout.dart';
import 'settings_components.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDeletingAccount = false;

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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete All'),
          ),
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
      ref.invalidate(collectionsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('All data cleared'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _requestAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This removes your Glimpse account metadata. Your on-device library is not uploaded to Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete account'),
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
          const SnackBar(
            content: Text('Account deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString()),
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
    final aiSaveRemaining = ref.watch(
      remainingUsageProvider(UsageFeature.aiSave),
    );
    final planSubtitle = isPro
        ? 'Manage your plan'
        : aiSaveRemaining.when(
            data: (remaining) {
              final label = remaining == 1 ? 'AI save' : 'AI saves';
              return '$remaining $label left this month';
            },
            loading: () => 'Checking save allowance',
            error: (_, _) => 'Manage your plan',
          );

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            title: Text(
              'Settings',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Account & plan ──────────────────────
                const SettingsGroupLabel('Account & plan'),
                SettingsGroup(
                  children: [
                    _AccountIdentityTile(
                      user: accountUser,
                      isLoading: authState.isLoading && accountUser == null,
                    ),
                    SettingsTile(
                      leading: SvgPicture.asset(
                        'assets/glimpse.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          SettingsAccents.gold,
                          BlendMode.srcIn,
                        ),
                      ),
                      iconColor: SettingsAccents.gold,
                      title: 'Glimpse AI',
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
                            Icons.chevron_right_rounded,
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
                const SettingsGroupLabel('Personalization'),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.appearance,
                      iconColor: SettingsAccents.violet,
                      title: 'Look & Feel',
                      subtitle: 'Theme and accent color',
                      onTap: () => context.push('/settings/look-and-feel'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Library gestures ────────────────────
                const SettingsGroupLabel('Library gestures'),
                const _SwipeActionsGroup(),
                const SizedBox(height: 24),

                // ─── Notifications ───────────────────────
                const SettingsGroupLabel('Notifications'),
                const SettingsGroup(children: [_DigestToggle()]),
                const SizedBox(height: 24),

                // ─── Privacy & data ──────────────────────
                const SettingsGroupLabel('Privacy & data'),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.privacy,
                      iconColor: SettingsAccents.indigo,
                      title: 'Privacy',
                      subtitle: 'What stays local and what is uploaded',
                      onTap: () => context.push('/settings/privacy'),
                    ),
                    SettingsTile(
                      icon: AppIcons.backup,
                      iconColor: SettingsAccents.green,
                      title: 'Data & Backup',
                      subtitle: 'Protect and restore your saved knowledge',
                      onTap: () => context.push('/settings/data-backup'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.clearData,
                      iconColor: cs.error,
                      destructive: true,
                      title: 'Clear All Data',
                      subtitle: 'Permanently delete all saved links',
                      trailing: const SizedBox.shrink(),
                      onTap: _clearData,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── About ───────────────────────────────
                const SettingsGroupLabel('About'),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.about,
                      iconColor: SettingsAccents.indigo,
                      title: 'About Glimpse',
                      subtitle: 'Version, legal & help',
                      trailing: const _VersionTrailing(),
                      onTap: () => context.push('/settings/about'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Account actions ─────────────────────
                const SettingsGroupLabel('Account actions'),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: AppIcons.logout,
                      iconColor: SettingsAccents.blue,
                      title: 'Log out',
                      subtitle: 'Sign out of this device',
                      onTap: _logout,
                    ),
                    SettingsTile(
                      icon: AppIcons.deleteAccount,
                      iconColor: cs.error,
                      destructive: true,
                      title: 'Delete account',
                      subtitle: _isDeletingAccount
                          ? 'Deleting your account…'
                          : 'Request account deletion',
                      trailing: _isDeletingAccount
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
    final title =
        accountName ??
        _nameFromEmail(email) ??
        (isLoading ? 'Loading account' : 'Signed in');
    final subtitle =
        email ?? (isLoading ? 'Checking session…' : 'Glimpse account');

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
          Icons.chevron_right_rounded,
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

    return SettingsGroup(
      children: [
        SettingsTile(
          leading: prefs.leftSwipeAction.iconWidget(
            color: SettingsAccents.rose,
            size: 22,
          ),
          iconColor: SettingsAccents.rose,
          title: 'Left swipe',
          subtitle: prefs.leftSwipeAction.label,
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
            color: SettingsAccents.teal,
            size: 22,
          ),
          iconColor: SettingsAccents.teal,
          title: 'Right swipe',
          subtitle: prefs.rightSwipeAction.label,
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
              'Choose swipe action',
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
                HapticFeedback.selectionClick();
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
                child: action.iconWidget(color: iconColor, size: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                action.label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications toggle (user-facing)
// ─────────────────────────────────────────────────────────────────────────────

class _DigestToggle extends ConsumerStatefulWidget {
  const _DigestToggle();

  @override
  ConsumerState<_DigestToggle> createState() => _DigestToggleState();
}

class _DigestToggleState extends ConsumerState<_DigestToggle> {
  bool _enabled = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = p.getBool(DigestPrefs.digestEnabledKey) ?? true;
      _loaded = true;
    });
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(DigestPrefs.digestEnabledKey, _enabled);
    await DigestScheduler.reschedule();
  }

  Future<void> _set(bool v) async {
    setState(() => _enabled = v);
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: AppIcons.smartNotifications,
      iconColor: SettingsAccents.amber,
      title: 'Smart notifications',
      subtitle: 'Behavior-based alerts',
      onTap: _loaded ? () => _set(!_enabled) : null,
      trailing: Switch(
        value: _enabled,
        thumbIcon: settingsSwitchThumbIcon(),
        onChanged: _loaded ? _set : null,
      ),
    );
  }
}

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
              trailing: const Icon(Icons.restart_alt),
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
              trailing: const Icon(Icons.replay),
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
              title: const Text('Reset First Save Celebration'),
              subtitle: const Text('Re-enable first-save celebration'),
              trailing: const Icon(Icons.celebration_outlined),
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
              trailing: const Icon(Icons.replay),
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
  String _testType = 'A';
  String? _previewTitle;
  String? _previewBody;

  String? _lastFiredType;
  String? _lastFiredTime;
  int? _peakHour;
  bool _firedToday = false;
  String? _lastRun;
  Map<String, double> _openRates = const {};
  List<NotifDiag> _diagnostics = const [];

  static const _testTypes = {
    'R': 'Rediscover Memory',
    'A': 'Geography Collector',
    'B': 'New Interest',
    'C': 'Deep Collector',
    'D': 'Saving Streak',
    'E': 'Resurface Link',
    'F': 'Weekly Digest',
    'G': 'Revisit Due',
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
    final openRates = await NotifBandit.openRates();
    final diagnostics = await NotificationScheduler.diagnostics(
      ref.read(isarServiceProvider),
    );
    if (!mounted) return;
    setState(() {
      _openRates = openRates;
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
                icon: const Icon(Icons.visibility_outlined, size: 18),
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send_outlined, size: 18),
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

        // What the on-device bandit has learned (open rate per type).
        if (_openRates.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'What Glimpse has learned',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'How often you open each type. Higher = surfaced more often.',
            style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
          ),
          const SizedBox(height: 10),
          ...(_openRates.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .map(
                (e) => _BanditRateRow(
                  label: _testTypes[e.key] ?? e.key,
                  rate: e.value,
                ),
              ),
        ],

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
class _BanditRateRow extends StatelessWidget {
  const _BanditRateRow({required this.label, required this.rate});
  final String label;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurface),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(rate * 100).round()}%',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

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
