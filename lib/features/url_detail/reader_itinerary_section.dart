import 'package:flutter/material.dart';

import '../../core/services/transcript_enrichment_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../../shared/widgets/section_header.dart';

/// The plan a travel save lays out, day by day, with the way to turn it into
/// the reader's own itinerary.
class ReaderItinerarySection extends StatefulWidget {
  const ReaderItinerarySection({
    super.key,
    required this.itinerary,
    required this.accent,
    required this.hasPlan,
    required this.onPlan,
    this.onOpenStop,
  });

  final EnrichedItinerary itinerary;
  final Color accent;

  /// Whether this save's plan was already made; the button then opens it.
  final bool hasPlan;
  final VoidCallback onPlan;

  /// Opens the Library page for a stop, when the Library knows the place.
  final VoidCallback? Function(EnrichedItineraryStop stop)? onOpenStop;

  @override
  State<ReaderItinerarySection> createState() => _ReaderItinerarySectionState();
}

class _ReaderItinerarySectionState extends State<ReaderItinerarySection> {
  int _dayIndex = 0;

  @override
  void didUpdateWidget(covariant ReaderItinerarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dayIndex >= widget.itinerary.days.length) _dayIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = context.l10n;
    final itinerary = widget.itinerary;
    final day = itinerary.days[_dayIndex];
    final subtitle = [
      if (itinerary.title?.trim().isNotEmpty == true) itinerary.title!.trim(),
      strings.itineraryStopCount(itinerary.stopCount),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: strings.itineraryHeading, accent: widget.accent),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        if (itinerary.isMultiDay) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: itinerary.days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ChoiceChip(
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                selected: index == _dayIndex,
                onSelected: (_) => setState(() => _dayIndex = index),
                label: Text(strings.itineraryDay(itinerary.days[index].day)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          child: Container(
            key: ValueKey(day.day),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 16, 16, 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (itinerary.isMultiDay || day.title != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 12),
                    child: Text(
                      [
                        if (itinerary.isMultiDay) strings.itineraryDay(day.day),
                        ?day.title,
                      ].join(' · '),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                for (final (index, stop) in day.stops.indexed)
                  _StopTile(
                    number: index + 1,
                    stop: stop,
                    isFirst: index == 0,
                    isLast: index == day.stops.length - 1,
                    onOpen: widget.onOpenStop?.call(stop),
                  ),
              ],
            ),
          ),
        ),
        if (itinerary.tips.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            strings.itineraryTips,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final tip in itinerary.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AppIcon(AppIcons.idea, size: 16, color: cs.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          onPressed: widget.onPlan,
          icon: AppIcon(
            widget.hasPlan ? AppIcons.arrowForward : AppIcons.route,
            size: 18,
          ),
          label: Text(
            widget.hasPlan ? strings.openYourPlan : strings.planThisTrip,
          ),
        ),
      ],
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.number,
    required this.stop,
    required this.isFirst,
    required this.isLast,
    this.onOpen,
  });

  final int number;
  final EnrichedItineraryStop stop;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rail = cs.outlineVariant;
    final meta = [?stop.time, ?stop.duration].join(' · ');
    final travel = isFirst ? null : stop.travel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // How to get here, on the rail between this stop and the last.
        if (travel != null)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Center(child: _Rail(color: rail)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        AppIcon(
                          AppIcons.route,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            travel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$number',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!isLast) Expanded(child: _Rail(color: rail)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 2, bottom: isLast ? 10 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                stop.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (onOpen != null)
                              AppIcon(
                                AppIcons.chevronRight,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                          ],
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              AppIcon(
                                AppIcons.clock,
                                size: 13,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  meta,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (stop.note?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            stop.note!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 2,
    margin: const EdgeInsets.symmetric(vertical: 3),
    color: color,
  );
}

/// For a save that names places but lays out no plan: plan them in the order
/// the save gives.
class ReaderPlanPlacesCard extends StatelessWidget {
  const ReaderPlanPlacesCard({
    super.key,
    required this.count,
    required this.hasPlan,
    required this.onPlan,
  });

  final int count;
  final bool hasPlan;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = context.l10n;
    return Material(
      color: cs.secondaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPlan,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  AppIcons.route,
                  size: 20,
                  color: cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPlan
                          ? strings.openYourPlan
                          : strings.planThesePlaces(count),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.planFromSaveHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSecondaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(
                AppIcons.chevronRight,
                size: 18,
                color: cs.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
