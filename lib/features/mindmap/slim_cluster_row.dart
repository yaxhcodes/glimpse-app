import 'package:flutter/material.dart';

import 'cluster_background.dart' show accentFromLabel;
import 'cluster_card.dart' show InterestCluster;

class SlimClusterRow extends StatelessWidget {
  const SlimClusterRow({super.key, required this.cluster, required this.onTap});

  final InterestCluster cluster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = cluster.accentColor ?? accentFromLabel(cluster.label);
    final subtitle = [
      '${cluster.saveCount} saves',
      ...cluster.subtopics.take(2),
    ].join(' · ');

    return Material(
      color: Color.alphaBlend(
        accent.withValues(alpha: 0.10),
        cs.surfaceContainerHigh,
      ),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_iconForLabel(cluster.label), color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cluster.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(color: cs.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(color: accent),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconForLabel(String label) {
  final l = label.toLowerCase();
  if (l.contains('type') || l.contains('font')) return Icons.text_fields_rounded;
  if (l.contains('growth') || l.contains('seo') || l.contains('revenue')) {
    return Icons.trending_up_rounded;
  }
  if (l.contains('farm') || l.contains('agri') || l.contains('plant')) {
    return Icons.grass_rounded;
  }
  if (l.contains('photo') || l.contains('camera')) return Icons.photo_camera_rounded;
  if (l.contains('book') || l.contains('read') || l.contains('essay')) {
    return Icons.menu_book_rounded;
  }
  if (l.contains('finance') || l.contains('invest') || l.contains('market')) {
    return Icons.candlestick_chart_rounded;
  }
  if (l.contains('bird') || l.contains('animal') || l.contains('nature')) {
    return Icons.pest_control_rounded;
  }
  if (l.contains('code') || l.contains('dev') || l.contains('github')) {
    return Icons.code_rounded;
  }
  if (l.contains('ai') || l.contains('agent') || l.contains('llm')) {
    return Icons.account_tree_rounded;
  }
  if (l.contains('trek') || l.contains('hike') || l.contains('mountain')) {
    return Icons.terrain_rounded;
  }
  if (l.contains('design') || l.contains('ui') || l.contains('ux')) {
    return Icons.palette_rounded;
  }
  return Icons.bookmark_rounded;
}
