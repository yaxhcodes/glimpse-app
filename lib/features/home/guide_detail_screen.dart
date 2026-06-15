import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';

/// "How Glimpse works" explainer, opened by tapping the guide card — mirroring
/// how tapping a real URL card opens its detail.
class GuideDetailScreen extends StatelessWidget {
  const GuideDetailScreen({super.key});

  static const _brands = ['instagram', 'youtube', 'tiktok', 'x', 'pinterest'];

  static const _features = <(IconData, String, String)>[
    (
      Icons.ios_share,
      'Save from anywhere',
      'Tap Share in any app and pick Glimpse — or paste a link on Home. '
          'Reels, videos, articles, posts, tracks: it all comes in.',
    ),
    (
      Icons.auto_awesome,
      'Enriched automatically',
      'Glimpse reads each save and pulls out a summary, topics and tags — '
          'plus any books, recipes or places it mentions.',
    ),
    (
      Icons.folder_special_outlined,
      'Sorted for you',
      'Everything is grouped into topics automatically. No folders to '
          'manage, nothing to file.',
    ),
    (
      Icons.bubble_chart_outlined,
      'Rediscover',
      'Glimpse quietly resurfaces saves worth a second look, based on what '
          'you keep coming back to.',
    ),
    (
      Icons.search,
      'Search by meaning',
      'Find anything by what it is about — not just the exact words you '
          'remember.',
    ),
    (
      Icons.hub_outlined,
      'Mind Map',
      'See how your interests connect across everything you have saved.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('How Glimpse works')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Image.asset(AppAssets.homeHero, width: 150, height: 150),
          ),
          const SizedBox(height: 8),
          Text(
            'Save anything. Find it when it matters.',
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          // Brand strip — share targets.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final brand in _brands) ...[
                  SvgPicture.asset(
                    'assets/brands/$brand.svg',
                    width: 20,
                    height: 20,
                    colorFilter:
                        ColorFilter.mode(cs.onSurface, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 14),
                ],
                Text('& more',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (final feature in _features) _FeatureRow(feature: feature),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final (IconData, String, String) feature;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(feature.$1, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.$2,
                  style: tt.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  feature.$3,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
