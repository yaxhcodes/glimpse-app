import 'package:flutter/material.dart';

import 'cluster_background.dart';
import 'cluster_card.dart' show InterestCluster;
import 'hero_cluster_card.dart' show SubtopicChip;

class MediumClusterCard extends StatelessWidget {
  const MediumClusterCard({
    super.key,
    required this.cluster,
    required this.onTap,
    this.featured = false,
  });

  final InterestCluster cluster;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${cluster.label}, ${cluster.saveCount} saves',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClusterBackground(cluster: cluster),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xBB000000)],
                      stops: [0.15, 1],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(13, 0, 13, featured ? 16 : 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cluster.label,
                          maxLines: featured ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${cluster.saveCount} saves',
                          style: tt.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                        if (cluster.subtopics.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              for (final label in cluster.subtopics.take(2))
                                SubtopicChip(label: label),
                            ],
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
      ),
    );
  }
}
