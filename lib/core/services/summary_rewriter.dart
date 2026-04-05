/// Display-time cleanup for AI summaries. Never persists to Isar.
class SummaryRewriter {
  SummaryRewriter._();

  /// Strips repetitive AI openers at display time only.
  static String clean(String? summary, {String platform = ''}) {
    if (summary == null || summary.isEmpty) return '';

    final patterns = [
      r'^this instagram reel (showcases|highlights|features|details|shows|explores|covers)\s+',
      r'^this instagram post (showcases|highlights|features|details|shows|explores|covers)\s+',
      r'^this (reel|post|video|article|page|link|content)\s+(showcases|highlights|features|details|shows|explores|covers)\s+',
      r'^this is (a|an)\s+',
      r'^in this (reel|post|video|article),?\s+',
      r'^the (reel|post|video|article|content)\s+(showcases|highlights|features|details|shows)\s+',
    ];

    var result = summary;
    for (final pattern in patterns) {
      result = result.replaceFirst(
        RegExp(pattern, caseSensitive: false),
        '',
      );
    }

    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }

    return result.trim();
  }
}
