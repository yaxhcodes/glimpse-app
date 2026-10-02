/// Page text that is a site refusing us, not content: bot walls, rate limits,
/// error pages. Summarising one produced saves titled "Troubleshooting Reddit
/// Network Access". Mirrors `looksLikeBlockedPage` in the enrichment worker
/// (glimpse-enrichment-backend/src/services/shared.ts).
abstract final class BlockedPage {
  static final _patterns = <RegExp>[
    RegExp(r'\bblocked by network security\b', caseSensitive: false),
    RegExp(r"\byou(?:'|’)?ve been blocked\b", caseSensitive: false),
    RegExp(r'\bwhoa there,? pardner\b', caseSensitive: false),
    RegExp(
      r'^\s*(?:access denied|forbidden|403 forbidden|404 not found|page not found|not found)\s*$',
      caseSensitive: false,
    ),
    RegExp(r'^\s*just a moment\.{0,3}\s*$', caseSensitive: false),
    RegExp(r'\battention required!? \| cloudflare\b', caseSensitive: false),
    RegExp(r'\bverify (?:that )?you are (?:a )?human\b', caseSensitive: false),
    RegExp(r'\bare you a robot\b', caseSensitive: false),
    RegExp(r'\btoo many requests\b', caseSensitive: false),
    RegExp(r'\bplease enable (?:javascript|cookies)\b', caseSensitive: false),
    RegExp(r'\bjavascript is not available\b', caseSensitive: false),
  ];

  static bool looksBlocked(String? text) {
    final value = text?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (value.isEmpty) return false;
    return _patterns.any((pattern) => pattern.hasMatch(value));
  }
}
