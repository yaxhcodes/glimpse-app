/// Short link-count phrase for cards, subtitles, and semantics.
String formatLinkCount(int count) {
  if (count <= 0) return 'No links';
  if (count == 1) return '1 link';
  return '$count links';
}
