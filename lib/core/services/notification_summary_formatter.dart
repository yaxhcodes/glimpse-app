class NotificationSummaryFormatter {
  NotificationSummaryFormatter._();

  static String format(String value, {int maxLength = 150}) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';

    final completeSentence = RegExp(r'^.*?[.!?](?=\s|$)').firstMatch(text);
    if (completeSentence != null) {
      final sentence = completeSentence.group(0)!.trim();
      if (sentence.length <= maxLength) return sentence;
    }
    if (text.length <= maxLength) return _withClosingPunctuation(text);

    final candidate = text.substring(0, maxLength - 1);
    final clauseEnd = candidate.lastIndexOf(RegExp(r'[,;:]\s'));
    final wordEnd = candidate.lastIndexOf(' ');
    final cutAt = clauseEnd >= maxLength ~/ 2 ? clauseEnd : wordEnd;
    final shortened = (cutAt > 0 ? candidate.substring(0, cutAt) : candidate)
        .replaceFirst(RegExp(r'[,;:]$'), '')
        .trim();
    return _withClosingPunctuation(shortened);
  }

  static String _withClosingPunctuation(String value) {
    if (RegExp(r'[.!?]$').hasMatch(value)) return value;
    return '$value.';
  }
}
