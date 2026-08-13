import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A low-contrast placeholder that follows the current Material color scheme.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Applies one shared shimmer to a group of skeleton blocks.
class SkeletonShimmer extends StatelessWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final colorScheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: colorScheme.surfaceContainerHigh,
        highlightColor: colorScheme.surfaceContainerHighest,
        period: const Duration(milliseconds: 1500),
        child: child,
      ),
    );
  }
}
