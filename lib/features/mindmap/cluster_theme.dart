import 'package:flutter/material.dart';

import '../../core/models/saved_url.dart';

/// Palette of distinct accent colors for cluster nodes.
/// Intentionally avoids pure primaries — these are muted/saturated tones that
/// look good on both light and dark surfaces.
const List<Color> kClusterAccentColors = [
  Color(0xFF6C8EBF), // slate blue
  Color(0xFF7EB89A), // sage green
  Color(0xFFBF8C6C), // warm terracotta
  Color(0xFF9B7EC8), // soft violet
  Color(0xFFBF6C8E), // dusty rose
  Color(0xFF6CBFBF), // muted teal
  Color(0xFFBFBF6C), // muted gold
  Color(0xFF8E6CBF), // indigo
];

/// A fine-grained sub-grouping within a [ClusterTheme].
/// Sub-clusters are only created when a parent cluster is large enough
/// (>= 4 URLs) and contains real semantic sub-structure.
class SubClusterTheme {
  const SubClusterTheme({
    required this.label,
    required this.summary,
    required this.urls,
  });

  final String label;
  final String summary;
  final List<SavedUrl> urls;
}

/// One semantic cluster of bookmarks (from embedding similarity + optional LLM naming).
/// May contain [subClusters] when the parent cluster is large and heterogeneous enough
/// to warrant finer-grained grouping.
class ClusterTheme {
  const ClusterTheme({
    required this.index,
    required this.label,
    required this.summary,
    required this.urls,
    this.subClusters = const [],
  });

  final int index;
  final String label;
  final String summary;

  /// All URLs in this cluster (including those in sub-clusters).
  final List<SavedUrl> urls;

  /// Optional sub-groupings within this cluster.
  /// Empty when no meaningful sub-structure was detected.
  final List<SubClusterTheme> subClusters;

  /// Whether this cluster has any meaningful sub-groupings.
  bool get hasSubClusters => subClusters.isNotEmpty;

  /// Accent color for this cluster derived from its index.
  Color get accentColor =>
      kClusterAccentColors[index % kClusterAccentColors.length];
}
