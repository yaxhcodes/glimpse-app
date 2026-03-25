import '../../core/models/saved_url.dart';

/// One semantic cluster of bookmarks (from embedding similarity + optional LLM naming).
class ClusterTheme {
  const ClusterTheme({
    required this.index,
    required this.label,
    required this.emoji,
    required this.summary,
    required this.urls,
  });

  final int index;
  final String label;
  final String emoji;
  final String summary;
  final List<SavedUrl> urls;
}
