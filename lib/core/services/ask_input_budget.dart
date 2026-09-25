/// Conservative local estimate; avoids a paid token-counting request. The proxy
/// also enforces an independent character limit and output-token ceiling.
abstract final class AskInputBudget {
  static const maxTokens = 12000;
  static const maxCharacters = 38000;

  static int estimate(String text) {
    var ascii = 0;
    var other = 0;
    for (final rune in text.runes) {
      if (rune < 128) {
        ascii++;
      } else {
        other++;
      }
    }
    return (ascii / 2).ceil() + other * 2;
  }

  static String clip(String text, int tokens) {
    if (estimate(text) <= tokens) return text;
    final buffer = StringBuffer();
    var units = 0;
    for (final rune in text.runes) {
      final cost = rune < 128 ? 1 : 4;
      if (units + cost > tokens * 2) break;
      buffer.writeCharCode(rune);
      units += cost;
    }
    return buffer.toString();
  }
}
