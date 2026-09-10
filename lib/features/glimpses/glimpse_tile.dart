import 'package:flutter/material.dart';

import '../../core/models/saved_url.dart';
import '../../l10n/l10n.dart';
import '../rediscover/journey_visual.dart';
import '../rediscover/rediscover_memory.dart';
import 'glimpse.dart';
import 'glimpse_card_menu.dart';
import 'glimpse_journey.dart';
import 'glimpse_copy.dart';

class GlimpseTile extends StatelessWidget {
  const GlimpseTile({
    super.key,
    required this.glimpse,
    required this.urls,
    required this.onTap,
    this.showActions = false,
  });
  final Glimpse glimpse;
  final Map<int, SavedUrl> urls;
  final VoidCallback onTap;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final g = glimpse;
    final label = glimpseLabel(g.kind, context.l10n);
    final journey = glimpseJourney(g, context.l10n, urls);
    final memory = RediscoverMemory.fromJourney(journey);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          RediscoverArtworkCard(
            journey: journey,
            title: glimpseTitle(g, context.l10n, urls),
            supportingText: memory.rediscoverCopy.subtitle,
            metadata: label,
            height: 224,
            onTap: onTap,
            hasMenu: showActions,
          ),
          if (showActions)
            Positioned.directional(
              textDirection: Directionality.of(context),
              bottom: 8,
              end: 8,
              child: GlimpseCardMenu(glimpse: g),
            ),
        ],
      ),
    );
  }
}
