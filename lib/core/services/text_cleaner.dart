import 'package:html_unescape/html_unescape.dart';

class TextCleaner {
  TextCleaner._();

  static final HtmlUnescape _unescape = HtmlUnescape();

  static String clean(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return _unescape
        .convert(raw)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String cleanLoose(Object? raw) {
    if (raw == null) return '';
    return clean(raw.toString()).replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
