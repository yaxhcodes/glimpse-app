// Text passed to Voyage for bookmark embeddings — keep in sync everywhere
// (new saves, backfill, and any re-embedding).

/// [DomainCategorizer] “platform” display names only — omit from embedding text
/// so vectors reflect title/summary/topic, not “everything is Reddit/YouTube”.
const _hostOnlyCategoriesLower = <String>{
  'reddit',
  'youtube',
  'instagram',
  'x',
  'facebook',
  'linkedin',
  'tiktok',
  'pinterest',
  'threads',
  'snapchat',
  'tumblr',
  'github',
  'gitlab',
  'stack overflow',
  'medium',
  'dev',
  'npm',
  'pub.dev',
  'crates.io',
  'pypi',
  'google docs',
  'notion',
  'amazon',
  'ebay',
  'flipkart',
  'netflix',
  'spotify',
  'twitch',
  'soundcloud',
  'wikipedia',
  'hacker news',
  'google maps',
  'google',
  'dribbble',
  'figma',
  'behance',
  'chatgpt',
  'claude',
  'gemini',
  'perplexity',
  'copilot',
  'bing',
  'hugging face',
  'replicate',
  'openai',
  'mistral',
  'obsidian',
  'trello',
  'linear',
  'airtable',
  'substack',
  'coinmarketcap',
  'binance',
  'web',
};

/// Strip platform boilerplate tags so one host does not dominate the vector.
List<String> _tagsForEmbedding(List<String> tags) {
  final trimmed = tags.map((t) => t.trim()).where((s) => s.isNotEmpty).toList();
  if (trimmed.isEmpty) return trimmed;

  final lower = trimmed.map((t) => t.toLowerCase()).toList();
  final drop = <String>{};

  for (final L in lower) {
    if (L == 'reddit' || L == 'forum' || L == 'subreddit') {
      drop.add(L);
    }
  }
  if (lower.contains('reddit') || lower.contains('forum')) {
    drop.add('social');
  }
  if (lower.contains('youtube')) {
    drop.addAll(['youtube', 'video']);
  }
  if (lower.contains('instagram')) {
    drop.addAll(['instagram', 'social']);
  }
  if (lower.contains('twitter') || lower.contains('x')) {
    drop.addAll(['twitter', 'x', 'social']);
  }
  if (lower.contains('tiktok')) {
    drop.addAll(['tiktok', 'video', 'social']);
  }
  if (lower.contains('facebook')) {
    drop.addAll(['facebook', 'social']);
  }
  if (lower.contains('linkedin')) {
    drop.addAll(['linkedin', 'professional']);
  }
  if (lower.contains('pinterest')) {
    drop.addAll(['pinterest', 'social', 'images']);
  }
  if (lower.contains('threads')) {
    drop.addAll(['threads', 'social']);
  }
  if (lower.contains('snapchat')) {
    drop.addAll(['snapchat', 'social']);
  }
  if (lower.contains('tumblr')) {
    drop.addAll(['tumblr', 'social', 'blog']);
  }
  if (lower.contains('hackernews')) {
    drop.add('hackernews');
  }

  return [
    for (var i = 0; i < trimmed.length; i++)
      if (!drop.contains(lower[i])) trimmed[i],
  ];
}

String buildBookmarkEmbeddingInput({
  required String title,
  required String description,
  required List<String> tags,
  required String category,
  String? summary,
  String? memoryIntentText,
}) {
  final catTrim = category.trim();
  final catLower = catTrim.toLowerCase();
  final includeCategory =
      catTrim.isNotEmpty && !_hostOnlyCategoriesLower.contains(catLower);

  final filteredTags = _tagsForEmbedding(tags);

  final parts = <String>[
    title.trim(),
    if (summary != null && summary.trim().isNotEmpty) summary.trim(),
    if (description.trim().isNotEmpty) description.trim(),
    if (memoryIntentText != null && memoryIntentText.trim().isNotEmpty)
      memoryIntentText.trim(),
    if (filteredTags.isNotEmpty) filteredTags.join(' '),
    if (includeCategory) catTrim,
  ].where((s) => s.isNotEmpty).toList();
  return parts.join(' · ');
}
