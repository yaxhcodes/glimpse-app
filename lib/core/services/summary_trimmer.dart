/// Smart truncation for summary/description lines on cards and detail views.
class SummaryTrimmer {
  SummaryTrimmer._();

  static const _dangling = {
    'the',
    'a',
    'an',
    'in',
    'on',
    'at',
    'to',
    'of',
    'and',
    'but',
    'or',
    'for',
    'with',
    'about',
    'from',
    'focusing',
  };

  static bool _boundaryOk(String s, int i) {
    if (i >= s.length) return true;
    final c = s[i];
    return c == ' ' || c == '\n';
  }

  static String trim(String? summary, {int maxLength = 120}) {
    if (summary == null || summary.isEmpty) return '';
    final s = summary.trim();
    if (s.length <= maxLength) return s;

    final windowStart = maxLength > 30 ? maxLength - 30 : 0;
    var end = maxLength;

    int? sentenceEnd;
    for (var i = maxLength; i >= windowStart; i--) {
      if (i < 1) break;
      final c = s[i - 1];
      if (c != '.' && c != '!' && c != '?') continue;
      if (!_boundaryOk(s, i)) continue;
      sentenceEnd = i;
      break;
    }

    if (sentenceEnd != null) {
      end = sentenceEnd;
    } else {
      int? clauseEnd;
      for (var i = maxLength; i >= windowStart; i--) {
        if (i < 1) break;
        final c = s[i - 1];
        if (c != ',' && c != ';' && c != ':') continue;
        if (!_boundaryOk(s, i)) continue;
        clauseEnd = i;
        break;
      }
      if (clauseEnd != null) {
        end = clauseEnd;
      } else {
        final upto = maxLength.clamp(0, s.length);
        final space = s.lastIndexOf(' ', upto);
        end = (space > windowStart) ? space : upto;
      }
    }

    var slice = s.substring(0, end).trim();
    slice = _stripDanglingTail(slice);

    while (slice.isNotEmpty &&
        (slice.endsWith(',') ||
            slice.endsWith(';') ||
            slice.endsWith(':') ||
            slice.endsWith('.'))) {
      slice = slice.substring(0, slice.length - 1).trim();
    }

    if (slice.length >= s.length) return s;
    return '$slice…';
  }

  static String _stripDanglingTail(String text) {
    var t = text.trim();
    while (t.isNotEmpty) {
      final parts = t.split(RegExp(r'\s+'));
      if (parts.isEmpty) break;
      final last = parts.last.toLowerCase();
      if (_dangling.contains(last)) {
        parts.removeLast();
        t = parts.join(' ');
      } else {
        break;
      }
    }
    return t;
  }
}
