import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/providers/dev_simulation_providers.dart';
import '../../shared/widgets/tag_group.dart' show tagChipColors;

/// Post-onboarding guide, deliberately styled as a real URL card (same fill,
/// radius, 64px thumbnail, title, `source · meta` line and tag chips) so new
/// users learn the card format by example. The content teaches what Glimpse
/// does; the chips show what it offers. Dismissible; pinned atop Home above the
/// seeded demo card.
class GuideCard extends ConsumerWidget {
  const GuideCard({super.key});

  static const _features = [
    'share from any app',
    'auto-sorted',
    'rediscover',
    'search',
    'mind map',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final tagColors = tagChipColors(cs);
    final metaStyle = TextStyle(fontSize: 12, color: cs.outline);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
      child: Material(
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/guide');
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.asset(AppAssets.logo, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 22),
                            child: Text(
                              'Save anything — Glimpse sorts it',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: (tt.titleSmall ?? const TextStyle())
                                  .copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                    fontSize:
                                        (tt.titleSmall?.fontSize ?? 14) + 0.5,
                                    color: cs.onSurface,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Glimpse · Tap to learn how', style: metaStyle),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 3,
                            children: [
                              for (final feature in _features)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tagColors.background,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    feature,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: tagColors.foreground,
                                      fontFamily: tt.labelSmall?.fontFamily,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: () =>
                      ref.read(hasSeenGuideCardProvider.notifier).set(true),
                  tooltip: 'Dismiss guide',
                  icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
