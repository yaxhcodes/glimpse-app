import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/reminders/reminder_times.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/swipeable_url_card.dart';
import '../home/home_section_header.dart';
import 'reminder_flow.dart';

/// Home's "Coming up": the saves due in the next day, as the very same
/// cards "Your saves" shows (the byline carries the time). Further-off
/// reminders wait in the Reminders filter, which the header opens.
class ComingUpSection extends ConsumerWidget {
  const ComingUpSection({super.key, this.onSeeAll});

  /// Shows every reminder (Your saves, filtered to Reminders).
  final VoidCallback? onSeeAll;

  static const window = Duration(hours: 24);
  static const _maxShown = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = reminderNow();
    final soon = ref
        .watch(upcomingRemindersProvider)
        .where(
          (url) =>
              liveReminder(url, now: now)!.next.difference(now) <= window,
        )
        .take(_maxShown)
        .toList(growable: false);
    if (soon.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: context.l10n.comingUp,
          subtitle: context.l10n.comingUpSubtitle,
          tooltip: context.l10n.remindersFilter,
          onTap: onSeeAll,
        ),
        for (final url in soon)
          SwipeableUrlCard(
            key: ValueKey('coming-up-${url.id}'),
            url: url,
            filledSwipeIcons: true,
            contentPadding: const EdgeInsets.all(10),
            onTap: () => context.push('/url/${url.id}'),
          ),
      ],
    );
  }
}
