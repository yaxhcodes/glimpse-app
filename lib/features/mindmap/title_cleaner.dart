class TitleCleaner {
  const TitleCleaner._();

  static const _blocked = {
    'social',
    'x',
    'instagram',
    'twitter',
    'facebook',
    'home',
    'untitled',
    'article',
    'post',
    'status',
    'photo',
  };

  static String? clean(String? raw) {
    if (raw == null) return null;

    final stripped = raw
        .replaceAll(RegExp(r'&#x[0-9a-fA-F]+;'), '')
        .replaceAll(RegExp(r'&[a-z]+;'), '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true), '')
        .replaceAll(RegExp(r'https?://\S+'), '')
        .trim();

    if (stripped.isEmpty || _blocked.contains(stripped.toLowerCase())) {
      return null;
    }
    return stripped;
  }
}
