/// Categorizes URLs by their domain/platform — no AI needed.
class DomainCategorizer {
  /// Known platform mappings: domain pattern → (category, emoji, tags).
  static const _platformRules = <String, _PlatformInfo>{
    // Video
    'youtube.com': _PlatformInfo('YouTube', '▶️', ['video', 'youtube']),
    'youtu.be': _PlatformInfo('YouTube', '▶️', ['video', 'youtube']),
    'm.youtube.com': _PlatformInfo('YouTube', '▶️', ['video', 'youtube']),
    'music.youtube.com': _PlatformInfo('YouTube', '🎵', ['music', 'youtube']),

    // Social
    'instagram.com': _PlatformInfo('Instagram', '📸', ['social', 'instagram']),
    'www.instagram.com': _PlatformInfo('Instagram', '📸', ['social', 'instagram']),
    'x.com': _PlatformInfo('X', '🐦', ['social', 'x', 'twitter']),
    'twitter.com': _PlatformInfo('X', '🐦', ['social', 'x', 'twitter']),
    'mobile.twitter.com': _PlatformInfo('X', '🐦', ['social', 'x', 'twitter']),

    // Reddit
    'reddit.com': _PlatformInfo('Reddit', '🤖', ['social', 'reddit', 'forum']),
    'www.reddit.com': _PlatformInfo('Reddit', '🤖', ['social', 'reddit', 'forum']),
    'old.reddit.com': _PlatformInfo('Reddit', '🤖', ['social', 'reddit', 'forum']),

    // Messaging & social
    'facebook.com': _PlatformInfo('Facebook', '👤', ['social', 'facebook']),
    'www.facebook.com': _PlatformInfo('Facebook', '👤', ['social', 'facebook']),
    'linkedin.com': _PlatformInfo('LinkedIn', '💼', ['professional', 'linkedin']),
    'www.linkedin.com': _PlatformInfo('LinkedIn', '💼', ['professional', 'linkedin']),
    'tiktok.com': _PlatformInfo('TikTok', '🎵', ['video', 'tiktok', 'social']),
    'www.tiktok.com': _PlatformInfo('TikTok', '🎵', ['video', 'tiktok', 'social']),
    'pinterest.com': _PlatformInfo('Pinterest', '📌', ['social', 'pinterest', 'images']),
    'www.pinterest.com': _PlatformInfo('Pinterest', '📌', ['social', 'pinterest', 'images']),
    'pin.it': _PlatformInfo('Pinterest', '📌', ['social', 'pinterest', 'images']),
    'threads.net': _PlatformInfo('Threads', '🧵', ['social', 'threads']),
    'www.threads.net': _PlatformInfo('Threads', '🧵', ['social', 'threads']),
    'snapchat.com': _PlatformInfo('Snapchat', '👻', ['social', 'snapchat']),
    'www.snapchat.com': _PlatformInfo('Snapchat', '👻', ['social', 'snapchat']),
    'tumblr.com': _PlatformInfo('Tumblr', '📝', ['social', 'tumblr', 'blog']),

    // Dev
    'github.com': _PlatformInfo('GitHub', '💻', ['dev', 'github', 'code']),
    'gitlab.com': _PlatformInfo('GitLab', '💻', ['dev', 'gitlab', 'code']),
    'stackoverflow.com': _PlatformInfo('Stack Overflow', '💡', ['dev', 'stackoverflow', 'qa']),
    'medium.com': _PlatformInfo('Medium', '📰', ['article', 'medium', 'blog']),
    'dev.to': _PlatformInfo('DEV', '👩‍💻', ['dev', 'article', 'blog']),
    'npmjs.com': _PlatformInfo('npm', '📦', ['dev', 'npm', 'package']),
    'www.npmjs.com': _PlatformInfo('npm', '📦', ['dev', 'npm', 'package']),
    'pub.dev': _PlatformInfo('pub.dev', '🎯', ['dev', 'dart', 'flutter']),
    'crates.io': _PlatformInfo('crates.io', '🦀', ['dev', 'rust', 'package']),
    'pypi.org': _PlatformInfo('PyPI', '🐍', ['dev', 'python', 'package']),
    'docs.google.com': _PlatformInfo('Google Docs', '📄', ['docs', 'google']),
    'notion.so': _PlatformInfo('Notion', '📋', ['docs', 'notion', 'notes']),

    // Shopping
    'amazon.com': _PlatformInfo('Amazon', '🛒', ['shopping', 'amazon']),
    'www.amazon.com': _PlatformInfo('Amazon', '🛒', ['shopping', 'amazon']),
    'amazon.in': _PlatformInfo('Amazon', '🛒', ['shopping', 'amazon']),
    'www.amazon.in': _PlatformInfo('Amazon', '🛒', ['shopping', 'amazon']),
    'ebay.com': _PlatformInfo('eBay', '🏷️', ['shopping', 'ebay']),
    'www.ebay.com': _PlatformInfo('eBay', '🏷️', ['shopping', 'ebay']),
    'flipkart.com': _PlatformInfo('Flipkart', '🛒', ['shopping', 'flipkart']),
    'www.flipkart.com': _PlatformInfo('Flipkart', '🛒', ['shopping', 'flipkart']),

    // Streaming
    'netflix.com': _PlatformInfo('Netflix', '🎬', ['streaming', 'netflix']),
    'www.netflix.com': _PlatformInfo('Netflix', '🎬', ['streaming', 'netflix']),
    'open.spotify.com': _PlatformInfo('Spotify', '🎧', ['music', 'spotify']),
    'spotify.com': _PlatformInfo('Spotify', '🎧', ['music', 'spotify']),
    'twitch.tv': _PlatformInfo('Twitch', '🎮', ['streaming', 'twitch', 'gaming']),
    'www.twitch.tv': _PlatformInfo('Twitch', '🎮', ['streaming', 'twitch', 'gaming']),
    'soundcloud.com': _PlatformInfo('SoundCloud', '🔊', ['music', 'soundcloud']),

    // News / Knowledge
    'en.wikipedia.org': _PlatformInfo('Wikipedia', '📚', ['reference', 'wikipedia']),
    'wikipedia.org': _PlatformInfo('Wikipedia', '📚', ['reference', 'wikipedia']),
    'news.ycombinator.com': _PlatformInfo('Hacker News', '🟧', ['dev', 'news', 'hackernews']),

    // Maps
    'maps.google.com': _PlatformInfo('Google Maps', '🗺️', ['maps', 'location']),
    'goo.gl': _PlatformInfo('Google', '🔗', ['google', 'shortlink']),

    // Design
    'dribbble.com': _PlatformInfo('Dribbble', '🎨', ['design', 'dribbble']),
    'www.figma.com': _PlatformInfo('Figma', '🎨', ['design', 'figma']),
    'figma.com': _PlatformInfo('Figma', '🎨', ['design', 'figma']),
    'behance.net': _PlatformInfo('Behance', '🎨', ['design', 'behance']),
    'www.behance.net': _PlatformInfo('Behance', '🎨', ['design', 'behance']),

    // AI / Chat
    'chat.openai.com': _PlatformInfo('ChatGPT', '🤖', ['ai', 'chatgpt', 'openai']),
    'chatgpt.com': _PlatformInfo('ChatGPT', '🤖', ['ai', 'chatgpt', 'openai']),
    'claude.ai': _PlatformInfo('Claude', '🧠', ['ai', 'claude', 'anthropic']),
    'gemini.google.com': _PlatformInfo('Gemini', '✨', ['ai', 'gemini', 'google']),
    'www.perplexity.ai': _PlatformInfo('Perplexity', '🔍', ['ai', 'perplexity', 'search']),
    'perplexity.ai': _PlatformInfo('Perplexity', '🔍', ['ai', 'perplexity', 'search']),
    'copilot.microsoft.com': _PlatformInfo('Copilot', '🤖', ['ai', 'copilot', 'microsoft']),
    'www.bing.com': _PlatformInfo('Bing', '🔍', ['search', 'bing', 'microsoft']),
    'huggingface.co': _PlatformInfo('Hugging Face', '🤗', ['ai', 'ml', 'huggingface']),
    'replicate.com': _PlatformInfo('Replicate', '🔄', ['ai', 'ml', 'replicate']),
    'openai.com': _PlatformInfo('OpenAI', '🤖', ['ai', 'openai']),
    'www.openai.com': _PlatformInfo('OpenAI', '🤖', ['ai', 'openai']),
    'mistral.ai': _PlatformInfo('Mistral', '🌬️', ['ai', 'mistral']),
    'console.mistral.ai': _PlatformInfo('Mistral', '🌬️', ['ai', 'mistral']),

    // Productivity / Notes
    'obsidian.md': _PlatformInfo('Obsidian', '💎', ['notes', 'obsidian', 'productivity']),
    'www.notion.so': _PlatformInfo('Notion', '📋', ['docs', 'notion', 'notes']),
    'trello.com': _PlatformInfo('Trello', '📌', ['productivity', 'trello', 'kanban']),
    'www.trello.com': _PlatformInfo('Trello', '📌', ['productivity', 'trello', 'kanban']),
    'linear.app': _PlatformInfo('Linear', '📐', ['productivity', 'linear', 'dev']),
    'www.linear.app': _PlatformInfo('Linear', '📐', ['productivity', 'linear', 'dev']),
    'airtable.com': _PlatformInfo('Airtable', '📊', ['productivity', 'airtable']),
    'www.airtable.com': _PlatformInfo('Airtable', '📊', ['productivity', 'airtable']),
    'substack.com': _PlatformInfo('Substack', '📧', ['newsletter', 'substack', 'blog']),

    // Finance / Crypto
    'coinmarketcap.com': _PlatformInfo('CoinMarketCap', '₿', ['crypto', 'finance']),
    'www.coinmarketcap.com': _PlatformInfo('CoinMarketCap', '₿', ['crypto', 'finance']),
    'binance.com': _PlatformInfo('Binance', '💰', ['crypto', 'binance']),
    'www.binance.com': _PlatformInfo('Binance', '💰', ['crypto', 'binance']),
  };

  /// Categorizes a URL by matching its domain against known platforms.
  /// Returns a categorization result without any network calls.
  static CategorizationInfo categorize(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return const CategorizationInfo(
        category: 'Web',
        emoji: '🌐',
        tags: ['web'],
      );
    }

    final host = uri.host.toLowerCase();

    // Direct match
    final direct = _platformRules[host];
    if (direct != null) {
      return CategorizationInfo(
        category: direct.category,
        emoji: direct.emoji,
        tags: direct.tags,
      );
    }

    // Try without "www."
    final withoutWww = host.startsWith('www.') ? host.substring(4) : host;
    final noWww = _platformRules[withoutWww];
    if (noWww != null) {
      return CategorizationInfo(
        category: noWww.category,
        emoji: noWww.emoji,
        tags: noWww.tags,
      );
    }

    // Subdomain matching — check if host ends with a known domain
    for (final entry in _platformRules.entries) {
      if (host.endsWith('.${entry.key}')) {
        return CategorizationInfo(
          category: entry.value.category,
          emoji: entry.value.emoji,
          tags: entry.value.tags,
        );
      }
    }

    // Default: "Web"
    return const CategorizationInfo(
      category: 'Web',
      emoji: '🌐',
      tags: ['web'],
    );
  }

  /// Returns platform info by category name when the category is a known app/platform.
  static CategorizationInfo? infoForCategory(String categoryName) {
    for (final info in _platformRules.values) {
      if (info.category == categoryName) {
        return CategorizationInfo(
          category: info.category,
          emoji: info.emoji,
          tags: info.tags,
        );
      }
    }
    return null;
  }
}

/// Simple struct for a platform mapping rule.
class _PlatformInfo {
  final String category;
  final String emoji;
  final List<String> tags;

  const _PlatformInfo(this.category, this.emoji, this.tags);
}

/// The result of domain-based categorization (no AI needed).
class CategorizationInfo {
  final String category;
  final String emoji;
  final List<String> tags;

  const CategorizationInfo({
    required this.category,
    required this.emoji,
    required this.tags,
  });
}
