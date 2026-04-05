import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/service_providers.dart';
import '../../core/providers/user_display_name_provider.dart';
import '../ask/ask_empty_suggestions_provider.dart';
import '../collections/collections_provider.dart';
import '../mindmap/interest_clusters_provider.dart';
import '../../core/services/digest_background.dart';
import '../../core/services/digest_notifications.dart';
import '../../core/services/digest_prefs.dart';
import '../../core/services/digest_scheduler.dart';
import '../../core/services/notification_scheduler.dart';
import '../../core/services/tag_analyzer.dart';

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
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete All')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared')),
        );
      }
    }
  }

  Future<void> _editDisplayName() async {
    final prefsName = await ref.read(userDisplayNameProvider.future);
    if (!mounted) return;
    final controller = TextEditingController(text: prefsName ?? '');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Your name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Used in Ask Glimpse greetings',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        await setUserDisplayName(controller.text);
        ref.invalidate(userDisplayNameProvider);
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayNameAsync = ref.watch(userDisplayNameProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Settings'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // ─── Look & Feel ────────────────────────
              ListTile(
                title: const Text('Look & Feel'),
                subtitle: const Text('Theme, colors, dynamic color'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/look-and-feel'),
              ),
              ListTile(
                title: const Text('Your name'),
                subtitle: Text(
                  displayNameAsync.when(
                    data: (n) =>
                        n == null || n.isEmpty ? 'Optional — for Ask greetings' : n,
                    loading: () => '…',
                    error: (_, _) => 'Optional — for Ask greetings',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _editDisplayName,
              ),
              const Divider(indent: 16, endIndent: 16),

              // ─── AI ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('AI',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary)),
              ),
              ListTile(
                title: const Text('Subscription'),
                subtitle: const Text('Manage your Glimpse plan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/subscription'),
              ),

              const Divider(indent: 16, endIndent: 16),

              // ─── Digest ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Digest',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary)),
              ),
              const _DigestSettingsCard(),

              const Divider(indent: 16, endIndent: 16),

              // ─── Data ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Data',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary)),
              ),
              ListTile(
                title: const Text('Clear All Data'),
                subtitle: const Text('Delete all saved URLs'),
                onTap: _clearData,
              ),

              const Divider(indent: 16, endIndent: 16),

              // ─── About ─────────────────────────────
              ListTile(
                title: const Text('About'),
                subtitle: const Text('Version & info'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/about'),
              ),

              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }
}

class _DigestSettingsCard extends ConsumerStatefulWidget {
  const _DigestSettingsCard();

  @override
  ConsumerState<_DigestSettingsCard> createState() =>
      _DigestSettingsCardState();
}

class _DigestSettingsCardState extends ConsumerState<_DigestSettingsCard> {
  bool _enabled = true;
  bool _loaded = false;
  String? _lastRun;
  bool _testing = false;
  String _testType = 'A';
  String? _previewTitle;
  String? _previewBody;

  // Status info.
  String? _lastFiredType;
  String? _lastFiredTime;
  int? _peakHour;
  bool _firedToday = false;

  static const _testTypes = {
    'A': 'Geography Collector',
    'B': 'New Interest',
    'C': 'Deep Collector',
    'D': 'Saving Streak',
    'E': 'Resurface Link',
    'F': 'Weekly Digest',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final lastRun = await DigestPrefs.loadLastRunStatus();
    final lastType = await DigestPrefs.lastFiredType();
    final lastTs = await DigestPrefs.lastFiredTimestamp();
    final peak = await TagAnalyzer.peakOpenHour();
    final canFire = await DigestPrefs.canFireToday();
    if (!mounted) return;
    setState(() {
      _enabled = p.getBool(DigestPrefs.digestEnabledKey) ?? true;
      _lastRun = lastRun;
      _lastFiredType = lastType != null ? NotificationScheduler.labelFor(lastType) : null;
      _lastFiredTime = lastTs != null
          ? '${lastTs.hour.toString().padLeft(2, '0')}:${lastTs.minute.toString().padLeft(2, '0')}'
          : null;
      _peakHour = peak;
      _firedToday = !canFire;
      _loaded = true;
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
      await DigestNotifications.init(onOpenNotification: (_) {});
      await DigestBackgroundTask.run(singleType: _testType);
    } catch (e) {
      await DigestPrefs.saveLastRunStatus('error: $e');
    }
    await _load();
    if (!mounted) return;
    setState(() => _testing = false);
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(DigestPrefs.digestEnabledKey, _enabled);
    await DigestScheduler.reschedule();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        SwitchListTile(
          title: const Text('Smart notifications'),
          subtitle: const Text('Personalized alerts based on your saving behavior'),
          value: _enabled,
          onChanged: (v) async {
            setState(() => _enabled = v);
            await _persist();
          },
        ),
        if (_enabled) ...[
          const Divider(height: 1),

          // Status row.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
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
          ),

          const Divider(height: 1),

          // Type picker.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _testType,
              decoration: const InputDecoration(
                labelText: 'Notification type',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: _testTypes.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text('${e.key} — ${e.value}',
                            style: const TextStyle(fontSize: 14)),
                      ))
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
          ),

          // Preview + Fire buttons.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
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
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined, size: 18),
                    label: const Text('Fire now'),
                  ),
                ),
              ],
            ),
          ),

          // Preview card.
          if (_previewTitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                color: cs.surfaceContainerHighest,
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
            ),

          // Last run status.
          if (_lastRun != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _lastRun!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.outline,
                ),
              ),
            ),
        ],
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
        Text('$label ', style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
        Text(value, style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        )),
      ],
    );
  }
}
