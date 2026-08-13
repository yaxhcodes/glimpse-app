import 'package:flutter/material.dart';

import '../../shared/widgets/app_glass_surface.dart';
import '../../shared/widgets/skeleton.dart';

class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: const AppGlassSurface(),
            title: Text(
              'Glimpse',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            actions: const [
              _HeaderActionSkeleton(),
              _HeaderActionSkeleton(),
              _HeaderActionSkeleton(),
              SizedBox(width: 4),
            ],
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: SkeletonShimmer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 112, height: 20, borderRadius: 7),
                    SizedBox(height: 8),
                    SkeletonBox(width: 156, height: 13, borderRadius: 6),
                    SizedBox(height: 18),
                    SkeletonBox(
                      width: double.infinity,
                      height: 92,
                      borderRadius: 20,
                    ),
                    SizedBox(height: 24),
                    HomeSourcesSkeleton(includeShimmer: false),
                    SizedBox(height: 26),
                    SkeletonBox(width: 104, height: 18, borderRadius: 7),
                    SizedBox(height: 14),
                    _SaveCardSkeleton(),
                    SizedBox(height: 12),
                    _SaveCardSkeleton(),
                    SizedBox(height: 12),
                    _SaveCardSkeleton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSourcesSkeleton extends StatelessWidget {
  const HomeSourcesSkeleton({super.key, this.includeShimmer = true});

  final bool includeShimmer;

  @override
  Widget build(BuildContext context) {
    const content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 72, height: 16, borderRadius: 6),
        SizedBox(height: 14),
        Row(
          children: [
            SkeletonBox(width: 104, height: 34, borderRadius: 17),
            SizedBox(width: 8),
            SkeletonBox(width: 88, height: 34, borderRadius: 17),
            SizedBox(width: 8),
            SkeletonBox(width: 72, height: 34, borderRadius: 17),
          ],
        ),
      ],
    );
    if (!includeShimmer) return content;
    return const SkeletonShimmer(child: content);
  }
}

class _HeaderActionSkeleton extends StatelessWidget {
  const _HeaderActionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: SkeletonShimmer(
        child: SkeletonBox(width: 24, height: 24, borderRadius: 12),
      ),
    );
  }
}

class _SaveCardSkeleton extends StatelessWidget {
  const _SaveCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 132,
      child: Row(
        children: [
          SkeletonBox(width: 88, height: 88, borderRadius: 16),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  width: double.infinity,
                  height: 17,
                  borderRadius: 6,
                ),
                SizedBox(height: 9),
                SkeletonBox(width: 176, height: 13, borderRadius: 6),
                SizedBox(height: 14),
                Row(
                  children: [
                    SkeletonBox(width: 58, height: 25, borderRadius: 13),
                    SizedBox(width: 7),
                    SkeletonBox(width: 72, height: 25, borderRadius: 13),
                    SizedBox(width: 7),
                    SkeletonBox(width: 46, height: 25, borderRadius: 13),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
