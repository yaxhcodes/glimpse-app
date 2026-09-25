import 'dart:convert';

/// Reads only a complete JSON string prefix. Escapes split across network chunks
/// are held back, so neither JSON syntax nor broken Unicode reaches the UI.
abstract final class AskStreamDecoder {
  static String answerPrefix(String raw) {
    final start = RegExp(r'"intro"\s*:\s*"').firstMatch(raw);
    if (start == null) return '';
    final content = raw.substring(start.end);
    var end = 0;
    while (end < content.length) {
      final char = content[end];
      if (char == '"') break;
      if (char == '\\') {
        if (end + 1 >= content.length) break;
        if (content[end + 1] == 'u') {
          if (end + 6 > content.length) break;
          end += 6;
          continue;
        }
        end += 2;
      } else {
        end++;
      }
    }
    try {
      final decoded = jsonDecode('"${content.substring(0, end)}"') as String;
      if (decoded.isNotEmpty &&
          decoded.codeUnitAt(decoded.length - 1) >= 0xD800 &&
          decoded.codeUnitAt(decoded.length - 1) <= 0xDBFF) {
        return decoded.substring(0, decoded.length - 1);
      }
      return decoded;
    } on FormatException {
      return '';
    }
  }
}
