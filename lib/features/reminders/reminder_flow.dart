import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/saved_url.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/app_haptics.dart';
import '../../core/services/digest_notifications.dart';
import '../../core/services/reminders/reminder_times.dart';
import '../../core/services/reminders/save_reminders.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../home/home_provider.dart';

/// Saves with a reminder still to come, by when each next goes off. Follows
/// the live save stream, so setting, snoozing or finishing one shows at
/// once.
final upcomingRemindersProvider = Provider<List<SavedUrl>>((ref) {
  final urls = ref.watch(urlStreamProvider).valueOrNull ?? const [];
  final now = reminderNow();
  final live = [
    for (final url in urls)
      if (liveReminder(url, now: now) case final reminder?)
        (url, reminder.next),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (url, _) in live) url];
});

/// What the person picked in the reminder sheet.
class ReminderChoice {
  const ReminderChoice.at(
    DateTime this.at, {
    required this.ring,
    this.repeat = ReminderRepeat.none,
  });
  const ReminderChoice.remove()
    : at = null,
      ring = false,
      repeat = ReminderRepeat.none;

  /// The first time it goes off.
  final DateTime? at;
  final bool ring;
  final ReminderRepeat repeat;
}

/// The one way a reminder gets set, from the save pill, Details or the
/// sheet: checks the time, asks for what Android needs (notifications, and
/// for Ring the exact-alarm permission), stores and schedules it, then says
/// how it went. True when the reminder now stands as asked.
Future<bool> applyReminder(
  BuildContext context,
  WidgetRef ref, {
  required int urlId,
  required ReminderChoice choice,
}) async {
  final strings = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String message) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );

  final at = choice.at;
  if (at != null && !at.isAfter(reminderNow())) {
    say(strings.reminderPastTime);
    return false;
  }
  if (at != null) {
    // A reminder nobody can see isn't one.
    if (!await DigestNotifications.areNotificationsEnabled()) {
      await DigestNotifications.requestPermission();
    }
    if (choice.ring && !await SaveReminders.canRingExactly()) {
      if (!context.mounted) return false;
      final allow = await _askForRing(context);
      if (allow) await SaveReminders.requestRingPermission();
    }
  }

  final outcome = await SaveReminders.set(
    ref.read(isarServiceProvider),
    urlId,
    at,
    ring: choice.ring,
    repeat: choice.repeat,
  );
  switch (outcome) {
    case ReminderScheduling.failed:
      say(strings.reminderCouldNotSet);
      return false;
    case ReminderScheduling.inexactFallback:
      AppHaptics.play(AppHaptics.success);
      say(strings.reminderRingUnavailable);
      return true;
    case ReminderScheduling.scheduled:
      AppHaptics.play(at == null ? AppHaptics.tick : AppHaptics.success);
      say(
        at == null
            ? strings.reminderRemoved
            : strings.reminderSetFor(
                formatReminderSchedule(strings, locale, at, choice.repeat),
              ),
      );
      return true;
  }
}

Future<bool> _askForRing(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.l10n.reminderRing),
          content: Text(dialogContext.l10n.reminderRingNeedsPermission),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dialogContext.l10n.reminderAllow),
            ),
          ],
        ),
      ) ??
      false;
}

/// "Remind me" for a save already in Glimpse: the sheet, then
/// [applyReminder].
Future<void> showReminderSheet(
  BuildContext context,
  WidgetRef ref,
  SavedUrl url,
) async {
  final choice = await showModalBottomSheet<ReminderChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) {
      final live = liveReminder(url);
      return ReminderSheet(
        current: live?.anchor,
        ring: url.remindRing,
        repeat: live?.repeat ?? ReminderRepeat.none,
      );
    },
  );
  if (choice == null || !context.mounted) return;
  await applyReminder(context, ref, urlId: url.id, choice: choice);
}

/// Repeat and Ring, then when: quick picks or a date and time. Picking a
/// time closes it with a [ReminderChoice], so the options sit above.
class ReminderSheet extends StatefulWidget {
  const ReminderSheet({
    super.key,
    this.current,
    this.ring = false,
    this.repeat = ReminderRepeat.none,
  });

  /// The reminder already set, if any (offers Remove): its first time.
  final DateTime? current;
  final bool ring;
  final ReminderRepeat repeat;

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  late bool _ring = widget.ring;
  late ReminderRepeat _repeat = widget.repeat;

  void _pick(DateTime at) {
    AppHaptics.play(AppHaptics.tick);
    Navigator.pop(context, ReminderChoice.at(at, ring: _ring, repeat: _repeat));
  }

  Future<void> _pickCustom() async {
    final now = reminderNow();
    final start = widget.current ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: start.isBefore(now) ? now : start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: widget.current != null
          ? TimeOfDay.fromDateTime(widget.current!)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null || !mounted) return;
    _pick(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final current = widget.current;
    final whenStyle = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current == null ? strings.remindMe : strings.reminderChange,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (current != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      strings.reminderSetFor(
                        formatReminderSchedule(
                          strings,
                          locale,
                          current,
                          widget.repeat,
                        ),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                strings.reminderRepeat,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final repeat in ReminderRepeat.values)
                    ChoiceChip(
                      label: Text(reminderRepeatLabel(strings, repeat)),
                      selected: _repeat == repeat,
                      onSelected: (_) {
                        AppHaptics.play(AppHaptics.tick);
                        setState(() => _repeat = repeat);
                      },
                    ),
                ],
              ),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(strings.reminderRing),
              subtitle: Text(strings.reminderRingSubtitle),
              value: _ring,
              onChanged: (value) {
                AppHaptics.play(AppHaptics.tick);
                setState(() => _ring = value);
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Divider(height: 1),
            ),
            for (final (preset, at) in reminderPresets(reminderNow()))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(reminderPresetLabel(strings, preset)),
                trailing: Text(
                  reminderPresetTime(locale, preset, at),
                  style: whenStyle,
                ),
                onTap: () => _pick(at),
              ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(strings.reminderPickTime),
              trailing: Icon(AppIcons.calendar, color: cs.onSurfaceVariant),
              onTap: _pickCustom,
            ),
            if (current != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: cs.error),
                    onPressed: () =>
                        Navigator.pop(context, const ReminderChoice.remove()),
                    icon: const Icon(AppIcons.close, size: 18),
                    label: Text(strings.reminderRemove),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
