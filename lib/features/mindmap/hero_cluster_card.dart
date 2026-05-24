import 'package:flutter/material.dart';

import 'cluster_background.dart';
import 'cluster_card.dart' show InterestCluster;

class HeroClusterCard extends StatelessWidget {
  const HeroClusterCard({super.key, required this.cluster, required this.onTap});

  final InterestCluster cluster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${cluster.label}, ${cluster.saveCount} saves',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClusterBackground(cluster: cluster),
                    const _HeroScrim(),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: _DominantBadge(textTheme: tt),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cluster.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.5,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${cluster.saveCount} saves · your biggest interest',
                              style: tt.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                            if (cluster.subtopics.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final label in cluster.subtopics.take(3))
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
        ),
      ),
    );
  }
}

class _HeroScrim extends StatelessWidget {
  const _HeroScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xCC000000)],
          stops: [0.2, 1],
        ),
      ),
    );
  }
}

class _DominantBadge extends StatelessWidget {
  const _DominantBadge({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.5),
      ),
      child: Text(
        'Dominant interest',
        style: textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.75),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class SubtopicChip extends StatelessWidget {
  const SubtopicChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
      ),
    );
  }
}
