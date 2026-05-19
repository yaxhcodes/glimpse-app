/// Short link-count phrase for cards, subtitles, and semantics.
String formatLinkCount(int count) {
  if (count <= 0) return 'No links';
  if (count == 1) return '1 link';
  return '$count links';
}

/// Compact relative time for calm metadata surfaces.
String formatRelativeTime(DateTime value, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final localValue = value.toLocal();
  final today = DateTime(reference.year, reference.month, reference.day);
  final valueDay = DateTime(localValue.year, localValue.month, localValue.day);
  final dayDelta = today.difference(valueDay).inDays;

  if (dayDelta <= 0) {
    final delta = reference.difference(localValue);
    if (delta.inMinutes < 5) return 'just now';
    return 'today';
  }
  if (dayDelta == 1) return 'yesterday';
  if (dayDelta < 7) return '${dayDelta}d ago';
  if (dayDelta < 31) return '${(dayDelta / 7).floor()}w ago';

  final monthDelta = (today.year - valueDay.year) * 12 +
      today.month -
      valueDay.month -
      (today.day < valueDay.day ? 1 : 0);
  if (monthDelta < 1) return '4w ago';
  return '${monthDelta}mo ago';
}
