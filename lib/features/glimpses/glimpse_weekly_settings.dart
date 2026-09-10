import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import 'glimpse_weekly_preparation.dart';

Future<void> showWeeklyReviewSettings(
  BuildContext context,
  WidgetRef ref,
) async {
  final enabled = await ref.read(weeklyReviewEnabledProvider.future);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _WeeklySummarySettings(
      initiallyEnabled: enabled,
      onSaved: () {
        if (context.mounted) ref.invalidate(weeklyReviewEnabledProvider);
      },
    ),
  );
}

class _WeeklySummarySettings extends StatefulWidget {
  const _WeeklySummarySettings({
    required this.initiallyEnabled,
    required this.onSaved,
  });
  final bool initiallyEnabled;
  final VoidCallback onSaved;

  @override
  State<_WeeklySummarySettings> createState() => _WeeklySummarySettingsState();
}

class _WeeklySummarySettingsState extends State<_WeeklySummarySettings> {
  late bool _enabled = widget.initiallyEnabled;
  bool _saving = false;

  Future<void> _setEnabled(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WeeklyReviewPreferences.setEnabled(value);
      widget.onSaved();
      if (!mounted) return;
      setState(() => _enabled = value);
    } on Object catch (error, stack) {
      developer.log(
        'Could not update weekly summary preference',
        name: 'WeeklySummarySettings',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.glimpsesActionFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l.glimpsesReviewSettings,
                style: theme.textTheme.titleLarge,
              ),
              value: _enabled,
              onChanged: _saving ? null : _setEnabled,
            ),
            const SizedBox(height: 4),
            Text(
              l.glimpsesReviewDescription,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const Divider(height: 28),
            Text(
              l.glimpsesReviewConsent,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
