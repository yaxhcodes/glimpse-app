import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_environment.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/swipe_preferences_provider.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/providers/user_display_name_provider.dart';
import '../ask/ask_empty_suggestions_provider.dart';
import '../collections/collections_provider.dart';
import '../mindmap/interest_clusters_provider.dart';
import '../../core/services/digest_background.dart';
import '../../core/services/digest_prefs.dart';
import '../../core/services/digest_scheduler.dart';
import '../../core/services/notification_scheduler.dart';
import '../../core/providers/dev_simulation_providers.dart';
import '../../core/providers/usage_providers.dart';
import '../../core/services/tag_analyzer.dart';
import '../../core/services/usage_service.dart';
import 'settings_components.dart';

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

  Future<void> _editDisplayName() async {
    final prefsName = await ref.read(userDisplayNameProvider.future);
    if (!mounted) return;
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) => _DisplayNameDialog(initialName: prefsName),
    );
    if (name != null && mounted) {
      await setUserDisplayName(name);
      ref.invalidate(userDisplayNameProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayNameAsync = ref.watch(userDisplayNameProvider);
    final isPro = ref.watch(isProUserProvider);

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Preferences ─────────────────────────
                const SettingsGroupLabel('Preferences'),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: Icons.palette_outlined,
                      iconColor: SettingsAccents.violet,
                      title: 'Look & Feel',
                      subtitle: 'Theme and accent color',
                      onTap: () => context.push('/settings/look-and-feel'),
                    ),
                    SettingsTile(
                      icon: Icons.badge_outlined,
                      iconColor: SettingsAccents.blue,
                      title: 'Your name',
                      subtitle: displayNameAsync.when(
                        data: (n) => n == null || n.isEmpty ? 'Optional' : n,
                        loading: () => '…',
                        error: (_, _) => 'Optional',
                      ),
                      onTap: _editDisplayName,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Swipe actions ───────────────────────
                const SettingsGroupLabel('Swipe actions'),
                const _SwipeActionsGroup(),
                const SizedBox(height: 24),

                // ─── Subscription ────────────────────────
                const SettingsGroupLabel('Subscription'),
                SettingsGroup(
                  children: [
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
                      subtitle: 'Manage your plan',
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

                // ─── Notifications ───────────────────────
                const SettingsGroupLabel('Notifications'),
                const SettingsGroup(children: [_DigestToggle()]),
                const SizedBox(height: 24),

                // ─── Data ────────────────────────────────
                const SettingsGroupLabel('Data'),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: Icons.cloud_outlined,
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
                      icon: Icons.delete_outline_rounded,
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
                      icon: Icons.info_outline_rounded,
                      iconColor: SettingsAccents.indigo,
                      title: 'About Glimpse',
                      subtitle: 'Version, legal & help',
                      trailing: const _VersionTrailing(),
                      onTap: () => context.push('/settings/about'),
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

class _DisplayNameDialog extends StatefulWidget {
  const _DisplayNameDialog({required this.initialName});

  final String? initialName;

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close(String? value) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Used in Ask Glimpse greetings',
        ),
        textCapitalization: TextCapitalization.words,
        autofocus: true,
        onSubmitted: (_) => _close(_controller.text),
      ),
      actions: [
        TextButton(onPressed: () => _close(null), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => _close(_controller.text),
          child: const Text('Save'),
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
      icon: Icons.notifications_active_outlined,
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
                          .read(
                            hasSimulatedFirstSaveInSessionProvider.notifier,
                          )
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

  static const _testTypes = {
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
    if (!mounted) return;
    setState(() {
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
      ],
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
